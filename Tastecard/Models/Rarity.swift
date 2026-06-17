//
//  Rarity.swift
//  Tastecard
//
//  The single documented module for rarity, replacing the hardcoded
//  `bookworm -> common` map from the web mockup (§6). Theme rarity derives from a
//  category's rarityIndex via fixed bands; card rarity aggregates its themes.
//

import Foundation

enum RarityTier: String, Codable, CaseIterable, Comparable {
    case common
    case rare
    case epic
    case legendary

    private var order: Int {
        switch self {
        case .common: return 0
        case .rare: return 1
        case .epic: return 2
        case .legendary: return 3
        }
    }

    static func < (lhs: RarityTier, rhs: RarityTier) -> Bool {
        lhs.order < rhs.order
    }

    var displayName: String { rawValue }
}

enum Rarity {
    /// Bands over rarityIndex (0...1). Kept in one place so they are tunable.
    ///   common    [0.00, 0.33)
    ///   rare      [0.33, 0.60)
    ///   epic      [0.60, 0.80)
    ///   legendary [0.80, 1.00]
    static func tier(forIndex index: Double) -> RarityTier {
        switch index {
        case ..<0.33: return .common
        case ..<0.60: return .rare
        case ..<0.80: return .epic
        default: return .legendary
        }
    }

    /// Card rarity aggregates its themes:
    ///   legendary if >= 3 high-rarity (epic+) themes
    ///   epic      if >= 2 high-rarity themes
    ///   rare      if >= 1 high-rarity theme OR >= 3 rare+ themes
    ///   common    otherwise
    static func cardRarity(from tiers: [RarityTier]) -> RarityTier {
        let high = tiers.filter { $0 >= .epic }.count
        let mid = tiers.filter { $0 >= .rare }.count
        if high >= 3 { return .legendary }
        if high >= 2 { return .epic }
        if high >= 1 || mid >= 3 { return .rare }
        return .common
    }
}
