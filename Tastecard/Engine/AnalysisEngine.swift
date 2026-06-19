//
//  AnalysisEngine.swift
//  Tastecard
//
//  Orchestrates the on-device pipeline (§6):
//    enumerate -> (cache | downsample + SigLIP embed) -> bias-corrected relative affinity
//    + absolute confidence gate -> distinctive-match tally -> 3–6 selection (relative-
//    ranking safety net) -> quality-aware, de-duplicated hero pick that prefers themes
//    with a real photo -> EXIF Places -> assemble Tastecard.
//
//  Matching uses TWO conditions so we get distinctive AND genuinely-confident matches:
//    1. relative: a photo's affinity for a category exceeds that photo's MEAN affinity by
//       a margin (scale-invariant; removes SigLIP's universal-prompt prior).
//    2. absolute: the raw cosine clears a floor (kills weak "nearest-of-nothing" matches,
//       e.g. a product leaflet drifting into "Tech Forward").
//
//  Chunked, backgrounded, cancellable, bounded memory. Runs OFF the main actor.
//

import Foundation
import CoreGraphics
import UIKit

struct AnalysisProgress: Equatable, Sendable {
    let processed: Int
    let total: Int
    var fraction: Double { total > 0 ? Double(processed) / Double(total) : 0 }
}

enum EngineResult {
    case card(Tastecard)
    case warmingUp(WarmingReason, photosScanned: Int)
}

enum EngineError: Error, LocalizedError {
    case noAlignedCategories
    var errorDescription: String? {
        switch self {
        case .noAlignedCategories:
            return "The bundled category text vectors don't match the dataset/model."
        }
    }
}

final class AnalysisEngine {

    struct Config {
        var selection = SelectionConfig()
        var batchSize = 32
        var heroInspectTopN = 8
        var defaultDisplayName = "My Tastecard"
        /// Cap analysis to the most recent N photos to bound scan time on large libraries.
        var maxScanPhotos = 3000
        /// Relative margin above the photo's mean affinity (bias-corrected, scale-invariant).
        var relativeMargin: Float = 0.05
        /// Absolute cosine floor — a match must also clear this, removing weak noise matches.
        var absoluteFloor: Float = 0.06
        /// How many backup categories to consider so themes with no usable photo can be
        /// replaced by the next-strongest theme that does (avoids placeholder tiles).
        var backupPool = 10
    }

    private let loader: PhotoAssetLoader
    private let embedder: ImageEmbedder
    private let textStore: TextEmbeddingStore
    private let categories: [Category]
    private let cache: EmbeddingCache
    private let config: Config

    init(loader: PhotoAssetLoader,
         embedder: ImageEmbedder,
         textStore: TextEmbeddingStore,
         categories: [Category],
         cache: EmbeddingCache,
         config: Config = Config()) {
        self.loader = loader
        self.embedder = embedder
        self.textStore = textStore
        self.categories = categories
        self.cache = cache
        self.config = config
    }

    private struct Aligned { let category: Category; let vector: [Float] }

    func run(onProgress: @escaping @Sendable (AnalysisProgress) -> Void) async throws -> EngineResult {
        // Most recent N photos (newest-first) to keep scan time bounded on big libraries.
        let allIds = Array(loader.imageAssetIdentifiers().prefix(config.maxScanPhotos))
        let total = allIds.count

        guard total >= config.selection.globalMinimumPhotos else {
            return .warmingUp(.notEnoughPhotos, photosScanned: total)
        }

        let aligned: [Aligned] = categories.compactMap { c in
            guard let v = textStore.vector(for: c.id), v.count == embedder.dimension else { return nil }
            return Aligned(category: c, vector: v)
        }
        guard !aligned.isEmpty else { throw EngineError.noAlignedCategories }
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        var counts: [String: Int] = [:]
        var scores: [String: Double] = [:]
        var softScores: [String: Double] = [:]
        var softCounts: [String: Int] = [:]
        var heroCandidates: [String: [HeroCandidate]] = [:]
        var coords: [GeoClustering.Coordinate] = []

        var processed = 0
        let progressStride = max(1, total / 100)
        let side = CGFloat(embedder.inputSide)
        let margin = config.relativeMargin
        let absFloor = config.absoluteFloor

        for chunk in allIds.chunked(into: config.batchSize) {
            try Task.checkCancellation()
            let assets = loader.assets(for: chunk)
            for asset in assets {
                try Task.checkCancellation()
                let id = asset.localIdentifier

                var embedding = await cache.embedding(for: id)
                if embedding == nil {
                    if let image = await loader.requestImage(for: asset, targetSide: side),
                       let cg = image.cgImage {
                        embedding = autoreleasepool { try? embedder.embed(cg) }
                        if let e = embedding { await cache.store(e, for: id) }
                    }
                }

                processed += 1
                if processed % progressStride == 0 || processed == total {
                    onProgress(AnalysisProgress(processed: processed, total: total))
                }

                if let loc = asset.location {
                    coords.append(.init(latitude: loc.coordinate.latitude,
                                        longitude: loc.coordinate.longitude))
                }

                guard let embedding else { continue }
                let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
                let pixelCount = asset.pixelWidth * asset.pixelHeight

                var cosines = [Float](repeating: 0, count: aligned.count)
                var sum: Float = 0
                for i in aligned.indices {
                    let c = VectorMath.dot(embedding, aligned[i].vector)
                    cosines[i] = c
                    sum += c
                }
                let mean = sum / Float(aligned.count)

                for i in aligned.indices {
                    let delta = cosines[i] - mean
                    guard delta > 0 else { continue }
                    let cid = aligned[i].category.id

                    softScores[cid, default: 0] += Double(delta)
                    softCounts[cid, default: 0] += 1

                    heroCandidates[cid, default: []].append(
                        HeroCandidate(assetId: id, similarity: cosines[i],
                                      isScreenshot: isScreenshot, pixelCount: pixelCount))
                    if heroCandidates[cid]!.count > 60 {
                        heroCandidates[cid] = Array(HeroPhotoPicker.ranked(heroCandidates[cid]!).prefix(40))
                    }

                    if delta >= margin && cosines[i] >= absFloor {
                        counts[cid, default: 0] += 1
                        scores[cid, default: 0] += Double(delta)
                    }
                }
            }
        }

        await cache.flush()
        onProgress(AnalysisProgress(processed: total, total: total))
        let placesCount = GeoClustering.placesCount(coords)

        let tallies: [CategoryTally] = aligned.compactMap { a in
            guard let count = counts[a.category.id], count > 0 else { return nil }
            return CategoryTally(categoryId: a.category.id, count: count, score: scores[a.category.id] ?? 0)
        }

        func photoCount(_ id: String) -> Int { counts[id] ?? softCounts[id] ?? 1 }
        func backups(excluding primary: [String]) -> [String] {
            aligned.map { $0.category.id }
                .filter { !primary.contains($0) && (softScores[$0] ?? 0) > 0 }
                .sorted { (softScores[$0] ?? 0) > (softScores[$1] ?? 0) }
        }

        switch ThemeSelector.select(tallies: tallies, photosAnalysed: processed, config: config.selection) {
        case .themes(let selected):
            let primary = selected.map(\.categoryId)
            let pool = primary + Array(backups(excluding: primary).prefix(config.backupPool))
            let themes = await assembleThemes(pool, categoryById: categoryById,
                                              heroCandidates: heroCandidates, photoCount: photoCount)
            return .card(assemble(themes: themes, processed: processed, places: placesCount))

        case .warmingUp(.notEnoughPhotos):
            return .warmingUp(.notEnoughPhotos, photosScanned: processed)

        case .warmingUp(.notEnoughEvidence):
            guard processed >= config.selection.relativeFallbackMinPhotos else {
                return .warmingUp(.notEnoughEvidence, photosScanned: processed)
            }
            let ranked = backups(excluding: [])
            guard ranked.count >= config.selection.minThemes else {
                return .warmingUp(.notEnoughEvidence, photosScanned: processed)
            }
            let themes = await assembleThemes(ranked, categoryById: categoryById,
                                              heroCandidates: heroCandidates, photoCount: photoCount)
            guard themes.count >= config.selection.minThemes else {
                return .warmingUp(.notEnoughEvidence, photosScanned: processed)
            }
            return .card(assemble(themes: themes, processed: processed, places: placesCount))
        }
    }

    private func assemble(themes: [EmergentTheme], processed: Int, places: Int) -> Tastecard {
        Tastecard(
            displayName: config.defaultDisplayName,
            themeIndex: Int.random(in: 0..<AppTheme.all.count),
            heroPhotoLocalId: themes.first?.heroPhotoLocalId,
            photosAnalysed: processed,
            placesCount: places,
            themes: themes
        )
    }

    /// Walks the ordered candidate pool, choosing a quality, de-duplicated hero for each.
    /// Themes that get a real photo come first (in strength order); placeholder-only themes
    /// are used only to reach the 3-theme minimum, so the card prefers real photos.
    private func assembleThemes(_ orderedIds: [String],
                                categoryById: [String: Category],
                                heroCandidates: [String: [HeroCandidate]],
                                photoCount: (String) -> Int) async -> [EmergentTheme] {
        let maxThemes = config.selection.maxThemes
        let minThemes = config.selection.minThemes

        var used = Set<String>()
        var withHero: [EmergentTheme] = []
        var withoutHero: [EmergentTheme] = []

        for id in orderedIds {
            if withHero.count >= maxThemes { break }
            guard let category = categoryById[id] else { continue }
            let candidates = heroCandidates[id] ?? []
            let rankedIds = HeroPhotoPicker.ranked(candidates).map { $0.assetId }
            let hero = await chooseHero(candidates: candidates, exclude: used)
            let theme = EmergentTheme(
                category: category,
                photoCount: photoCount(id),
                heroPhotoLocalId: hero,
                candidatePhotoLocalIds: Array(rankedIds.prefix(15))
            )
            if let hero {
                used.insert(hero)
                withHero.append(theme)
            } else if withoutHero.count < minThemes {
                withoutHero.append(theme)
            }
        }

        var result = Array(withHero.prefix(maxThemes))
        if result.count < minThemes {
            result += withoutHero.prefix(minThemes - result.count)
        }
        return result
    }

    /// Among the top candidates (by relevance), returns the SHARPEST one that is neither
    /// sensitive nor visually poor, skipping anything already used by another theme.
    private func chooseHero(candidates: [HeroCandidate], exclude: Set<String>) async -> String? {
        let ranked = HeroPhotoPicker.ranked(candidates).filter { !exclude.contains($0.assetId) }
        var bestId: String?
        var bestSharpness = -1.0
        var inspected = 0
        for candidate in ranked {
            if inspected >= config.heroInspectTopN { break }
            guard let asset = loader.asset(for: candidate.assetId),
                  let image = await loader.requestImage(for: asset, targetSide: 512),
                  let cg = image.cgImage else {
                continue
            }
            inspected += 1
            let signals = autoreleasepool { PhotoQualityInspector.inspect(cg) }
            if PhotoQualityInspector.isUnsuitableHero(signals) { continue }
            if signals.sharpness > bestSharpness {
                bestSharpness = signals.sharpness
                bestId = candidate.assetId
            }
        }
        return bestId
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
