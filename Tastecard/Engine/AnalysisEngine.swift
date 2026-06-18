//
//  AnalysisEngine.swift
//  Tastecard
//
//  Orchestrates the on-device pipeline (§6):
//    enumerate assets -> (cache hit | downsample + SigLIP embed) -> bias-corrected
//    relative affinity vs precomputed category text vectors -> distinctive-match tally
//    -> evidence-floor 3–6 selection (with a relative-ranking safety net) -> rarity
//    -> hero pick -> EXIF Places -> assemble Tastecard.
//
//  Why relative affinity, not absolute cosine: SigLIP image-text cosines are compressed
//  and carry a strong per-prompt prior (some category prompts sit "close" to every image).
//  A fixed cosine cutoff therefore either matches nothing (the "still warming up" bug) or
//  matches junk. Instead, for each photo we subtract that photo's MEAN affinity across all
//  categories and keep the categories it is distinctively closest to. This is scale-
//  invariant, removes the universal-prompt bias, and is naturally multi-label — the standard
//  senior-level way to get reliable SigLIP/CLIP zero-shot signal on real-world libraries.
//
//  Chunked, backgrounded, cancellable, bounded memory. Runs OFF the main actor.
//

import Foundation
import CoreGraphics
import UIKit   // UIImage.cgImage member access on images returned by PhotoAssetLoader

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
        var heroInspectTopN = 5
        var defaultDisplayName = "My Tastecard"
        /// A photo "matches" a category when its affinity exceeds the photo's own mean
        /// affinity by at least this margin (bias-corrected, scale-invariant).
        var relativeMargin: Float = 0.05
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

    /// Runs the full analysis. Throws `CancellationError` if cancelled.
    func run(onProgress: @escaping @Sendable (AnalysisProgress) -> Void) async throws -> EngineResult {
        let allIds = loader.imageAssetIdentifiers()
        let total = allIds.count

        // §4: enforce a global minimum library size before building a card at all.
        guard total >= config.selection.globalMinimumPhotos else {
            return .warmingUp(.notEnoughPhotos, photosScanned: total)
        }

        // Align dataset categories with the precomputed text vectors of matching dimension.
        struct Aligned { let category: Category; let vector: [Float] }
        let aligned: [Aligned] = categories.compactMap { c in
            guard let v = textStore.vector(for: c.id), v.count == embedder.dimension else { return nil }
            return Aligned(category: c, vector: v)
        }
        guard !aligned.isEmpty else { throw EngineError.noAlignedCategories }
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        // Per-category accumulators.
        var counts: [String: Int] = [:]            // photos where delta >= relativeMargin
        var scores: [String: Double] = [:]          // sum of margins for matched photos
        var softScores: [String: Double] = [:]      // sum of positive delta over ALL photos (ranking net)
        var softCounts: [String: Int] = [:]         // photos where delta > 0 (prominence)
        var heroCandidates: [String: [HeroCandidate]] = [:]
        var coords: [GeoClustering.Coordinate] = []

        var processed = 0
        let progressStride = max(1, total / 100)   // throttle UI updates to ~100 ticks
        let side = CGFloat(embedder.inputSide)
        let margin = config.relativeMargin

        for chunk in allIds.chunked(into: config.batchSize) {
            try Task.checkCancellation()
            let assets = loader.assets(for: chunk)
            for asset in assets {
                try Task.checkCancellation()
                let id = asset.localIdentifier

                // Cache hit, or downsample + embed + release.
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

                // Cosine to every category, then subtract this photo's mean affinity.
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

                    // Hero candidate (use raw cosine as the quality/representativeness signal).
                    heroCandidates[cid, default: []].append(
                        HeroCandidate(assetId: id, similarity: cosines[i],
                                      isScreenshot: isScreenshot, pixelCount: pixelCount))
                    if heroCandidates[cid]!.count > 60 {
                        heroCandidates[cid] = Array(HeroPhotoPicker.ranked(heroCandidates[cid]!).prefix(40))
                    }

                    if delta >= margin {
                        counts[cid, default: 0] += 1
                        scores[cid, default: 0] += Double(delta)
                    }
                }
            }
        }

        await cache.flush()
        onProgress(AnalysisProgress(processed: total, total: total))

        let placesCount = GeoClustering.placesCount(coords)

        // Primary selection from distinctive-match tallies.
        let tallies: [CategoryTally] = aligned.compactMap { a in
            guard let count = counts[a.category.id], count > 0 else { return nil }
            return CategoryTally(categoryId: a.category.id, count: count, score: scores[a.category.id] ?? 0)
        }

        switch ThemeSelector.select(tallies: tallies, photosAnalysed: processed, config: config.selection) {
        case .themes(let selected):
            let themes = await buildThemes(
                selected.map { ($0.categoryId, $0.count) },
                categoryById: categoryById, heroCandidates: heroCandidates)
            return .card(assemble(themes: themes, processed: processed, places: placesCount))

        case .warmingUp(.notEnoughPhotos):
            return .warmingUp(.notEnoughPhotos, photosScanned: processed)

        case .warmingUp(.notEnoughEvidence):
            // Relative-ranking safety net: a non-sparse library always gets its strongest,
            // most-distinctive themes rather than the "still warming up" dead end.
            guard processed >= config.selection.relativeFallbackMinPhotos else {
                return .warmingUp(.notEnoughEvidence, photosScanned: processed)
            }
            let ranked = aligned
                .compactMap { a -> (String, Double)? in
                    guard let s = softScores[a.category.id], s > 0 else { return nil }
                    return (a.category.id, s)
                }
                .sorted { $0.1 > $1.1 }
            guard ranked.count >= config.selection.minThemes else {
                return .warmingUp(.notEnoughEvidence, photosScanned: processed)
            }
            let picks = ranked.prefix(config.selection.maxThemes).map { ($0.0, max(softCounts[$0.0] ?? 0, 1)) }
            let themes = await buildThemes(Array(picks), categoryById: categoryById, heroCandidates: heroCandidates)
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

    private func buildThemes(_ picks: [(String, Int)],
                             categoryById: [String: Category],
                             heroCandidates: [String: [HeroCandidate]]) async -> [EmergentTheme] {
        var themes: [EmergentTheme] = []
        var used = Set<String>()   // de-dup: a photo is the hero of at most one theme
        for (categoryId, photoCount) in picks {
            guard let category = categoryById[categoryId] else { continue }
            let candidates = heroCandidates[categoryId] ?? []
            let rankedIds = HeroPhotoPicker.ranked(candidates).map { $0.assetId }
            let hero = await chooseHero(candidates: candidates, exclude: used)
            if let hero { used.insert(hero) }
            themes.append(EmergentTheme(
                category: category,
                photoCount: photoCount,
                heroPhotoLocalId: hero,
                candidatePhotoLocalIds: Array(rankedIds.prefix(15))   // powers "change photo"
            ))
        }
        return themes
    }

    /// Ranks candidates (skipping any already used by another theme), then runs a bounded
    /// Vision sensitivity check; returns the first clean, unused asset id, or nil so the
    /// UI shows the designed per-category placeholder (privacy-safe default).
    private func chooseHero(candidates: [HeroCandidate], exclude: Set<String>) async -> String? {
        let ranked = HeroPhotoPicker.ranked(candidates).filter { !exclude.contains($0.assetId) }
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
            if !PhotoQualityInspector.isSensitiveForHero(signals) {
                return candidate.assetId
            }
        }
        return nil
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
