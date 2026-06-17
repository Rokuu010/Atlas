//
//  ThemeSelector.swift
//  Tastecard
//
//  Emergent-theme selection rules (§4 "Emergent-theme selection rules"). Pure,
//  deterministic, fully unit-tested. Given per-category tallies, it decides whether
//  enough evidence exists to build a card and, if so, which 3–6 themes to show.
//

import Foundation

/// Per-category aggregate produced by the engine.
///   count: photos whose similarity cleared this category's threshold (multi-label)
///   score: strength = sum of margins (similarity - threshold) over those photos,
///          combining prevalence and confidence. Used for ranking.
struct CategoryTally: Equatable {
    let categoryId: String
    let count: Int
    let score: Double
}

enum WarmingReason: Equatable {
    case notEnoughPhotos     // below the global minimum library size
    case notEnoughEvidence   // fewer than minThemes categories cleared the evidence floor
}

enum SelectionOutcome: Equatable {
    case themes([CategoryTally])   // 3...6, ranked by score (strongest first)
    case warmingUp(WarmingReason)
}

struct SelectionConfig: Equatable {
    /// §4: enforce a global minimum total photo count before a card is built at all.
    var globalMinimumPhotos: Int = 50
    var minThemes: Int = 3
    var maxThemes: Int = 6
    /// Top-N by strength always qualify for a slot, even if marginally under the floor.
    var guaranteedTopSlots: Int = 3
    /// Evidence floor = max(floorBase, ceil(librarySize/1000 * floorPerThousand)).
    /// Larger libraries demand more evidence (someone with 2k photos needs more than 100).
    var floorBase: Int = 3
    var floorPerThousand: Double = 3.0
    /// Above this library size we never show "warming up": if the evidence floor isn't met
    /// we still surface the strongest themes by score. Keeps a big, varied gallery from
    /// being left with nothing when thresholds are conservative.
    var relativeFallbackMinPhotos: Int = 400

    func evidenceFloor(librarySize: Int) -> Int {
        let scaled = Int((Double(librarySize) / 1000.0 * floorPerThousand).rounded(.up))
        return max(floorBase, scaled)
    }
}

enum ThemeSelector {

    static func select(tallies: [CategoryTally],
                       photosAnalysed: Int,
                       config: SelectionConfig = SelectionConfig()) -> SelectionOutcome {
        // Global library floor — never build a card from a near-empty gallery.
        guard photosAnalysed >= config.globalMinimumPhotos else {
            return .warmingUp(.notEnoughPhotos)
        }

        let floor = config.evidenceFloor(librarySize: photosAnalysed)

        // Rank by strength; tie-break on count then id for determinism.
        let ranked = tallies
            .filter { $0.count > 0 }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                if a.count != b.count { return a.count > b.count }
                return a.categoryId < b.categoryId
            }

        let clearedCount = ranked.filter { $0.count >= floor }.count

        // Primary path: enough categories clear the evidence floor. Fill 3rd–6th slots
        // only with categories that appear in >= floor photos OR are top-N by strength,
        // so a fragile statistical hiccup never fills a slot.
        if clearedCount >= config.minThemes {
            var selected: [CategoryTally] = []
            for (rank, candidate) in ranked.enumerated() {
                if selected.count >= config.maxThemes { break }
                let isGuaranteedByStrength = rank < config.guaranteedTopSlots
                if candidate.count >= floor || isGuaranteedByStrength {
                    selected.append(candidate)
                }
            }
            return .themes(selected)
        }

        // Safety net: a clearly non-sparse library should never be left with nothing.
        // If at least minThemes categories registered any matches, surface the strongest.
        if photosAnalysed >= config.relativeFallbackMinPhotos, ranked.count >= config.minThemes {
            return .themes(Array(ranked.prefix(config.maxThemes)))
        }

        // Truly sparse / weak signal -> "still warming up".
        return .warmingUp(.notEnoughEvidence)
    }
}
