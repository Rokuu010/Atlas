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
    /// ALL categories that reached the per-category photo floor, ranked most-photos-first.
    /// The engine displays the top 3–6 (those with a usable hero) and saves the rest as the
    /// "shadow" set for the rarest-find insight + future cross-user comparison.
    case themes([CategoryTally])
    case warmingUp(WarmingReason)
}

struct SelectionConfig: Equatable {
    /// §4: enforce a global minimum total photo count before a card is built at all.
    var globalMinimumPhotos: Int = 50
    var minThemes: Int = 3
    var maxThemes: Int = 6
    /// A category only "exists" once it's detected in at least this many photos (user spec:
    /// 10 photos make a category). Applies to both the displayed themes and the saved shadow
    /// set, so nothing built on a couple of stray matches ever counts.
    var minPhotosPerCategory: Int = 10
}

enum ThemeSelector {

    static func select(tallies: [CategoryTally],
                       photosAnalysed: Int,
                       config: SelectionConfig = SelectionConfig()) -> SelectionOutcome {
        // Global library floor — never build a card from a near-empty gallery.
        guard photosAnalysed >= config.globalMinimumPhotos else {
            return .warmingUp(.notEnoughPhotos)
        }

        // A category qualifies only if it reaches the per-category photo floor. Rank
        // most-photos-first (the card shows the categories you photograph the most), with
        // strength then id as deterministic tie-breakers.
        let qualified = tallies
            .filter { $0.count >= config.minPhotosPerCategory }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.score != b.score { return a.score > b.score }
                return a.categoryId < b.categoryId
            }

        // Need at least minThemes distinct qualifying categories to build a card.
        guard qualified.count >= config.minThemes else {
            return .warmingUp(.notEnoughEvidence)
        }
        return .themes(qualified)
    }
}
