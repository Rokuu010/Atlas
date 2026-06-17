//
//  AnalysisEngine.swift
//  Tastecard
//
//  Orchestrates the on-device pipeline (§6):
//    enumerate assets -> (cache hit | downsample + SigLIP embed) -> cosine vs precomputed
//    category text vectors -> threshold tally (multi-label) -> evidence-floor 3–6 selection
//    -> rarity -> hero pick -> EXIF Places -> assemble Tastecard.
//
//  Chunked, backgrounded, cancellable, bounded memory (downsample/infer/release; cache
//  keyed by localIdentifier for incremental re-runs). Runs OFF the main actor.
//

import Foundation
import CoreGraphics

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

        var counts: [String: Int] = [:]
        var scores: [String: Double] = [:]
        var heroCandidates: [String: [HeroCandidate]] = [:]
        var coords: [GeoClustering.Coordinate] = []

        var processed = 0
        let progressStride = max(1, total / 100)   // throttle UI updates to ~100 ticks
        let side = CGFloat(embedder.inputSide)

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

                for a in aligned {
                    let sim = VectorMath.dot(embedding, a.vector)
                    let threshold = Float(a.category.threshold)
                    if sim >= threshold {
                        counts[a.category.id, default: 0] += 1
                        scores[a.category.id, default: 0] += Double(sim - threshold)
                        heroCandidates[a.category.id, default: []].append(
                            HeroCandidate(assetId: id, similarity: sim,
                                          isScreenshot: isScreenshot, pixelCount: pixelCount))
                        // Bound memory: a popular category needn't retain thousands of
                        // candidates — keep only the strongest for hero selection.
                        if heroCandidates[a.category.id]!.count > 60 {
                            heroCandidates[a.category.id] =
                                Array(HeroPhotoPicker.ranked(heroCandidates[a.category.id]!).prefix(40))
                        }
                    }
                }
            }
        }

        await cache.flush()
        onProgress(AnalysisProgress(processed: total, total: total))

        // Selection.
        let tallies: [CategoryTally] = aligned.compactMap { a in
            guard let count = counts[a.category.id], count > 0 else { return nil }
            return CategoryTally(categoryId: a.category.id, count: count,
                                 score: scores[a.category.id] ?? 0)
        }

        switch ThemeSelector.select(tallies: tallies, photosAnalysed: processed, config: config.selection) {
        case .warmingUp(let reason):
            return .warmingUp(reason, photosScanned: processed)

        case .themes(let selected):
            var themes: [EmergentTheme] = []
            for tally in selected {
                guard let category = categoryById[tally.categoryId] else { continue }
                let hero = await chooseHero(candidates: heroCandidates[tally.categoryId] ?? [])
                themes.append(EmergentTheme(category: category, photoCount: tally.count,
                                            heroPhotoLocalId: hero))
            }

            let placesCount = GeoClustering.placesCount(coords)
            let card = Tastecard(
                displayName: config.defaultDisplayName,
                themeIndex: Int.random(in: 0..<AppTheme.all.count),
                heroPhotoLocalId: themes.first?.heroPhotoLocalId,
                photosAnalysed: processed,
                placesCount: placesCount,
                themes: themes
            )
            return .card(card)
        }
    }

    /// Ranks candidates, then runs a bounded Vision sensitivity check on the top few;
    /// returns the first clean asset id, or nil so the UI uses the bundled fallback.
    private func chooseHero(candidates: [HeroCandidate]) async -> String? {
        let ranked = HeroPhotoPicker.ranked(candidates)
        for candidate in ranked.prefix(config.heroInspectTopN) {
            guard let asset = loader.asset(for: candidate.assetId),
                  let image = await loader.requestImage(for: asset, targetSide: 512),
                  let cg = image.cgImage else {
                continue
            }
            let signals = autoreleasepool { PhotoQualityInspector.inspect(cg) }
            if !PhotoQualityInspector.isSensitiveForHero(signals) {
                return candidate.assetId
            }
        }
        return nil   // all flagged sensitive -> bundled fallback (privacy-safe default)
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
