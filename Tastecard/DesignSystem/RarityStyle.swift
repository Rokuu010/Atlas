//
//  RarityStyle.swift
//  Tastecard
//
//  Rarity badge gradients, ported from the DetailModal Tailwind classes. Replaces the
//  hardcoded per-category map with a per-tier style driven by real data.
//

import SwiftUI

enum RarityStyle {
    static func colors(for tier: RarityTier) -> [Color] {
        switch tier {
        case .common:    // from-zinc-400 via-zinc-200 to-zinc-500
            return [Color(hex: 0xA1A1AA), Color(hex: 0xE4E4E7), Color(hex: 0x71717A)]
        case .rare:      // from-amber-400 via-rose-300 to-amber-600
            return [Color(hex: 0xFBBF24), Color(hex: 0xFDA4AF), Color(hex: 0xD97706)]
        case .epic:      // from-fuchsia-400 via-pink-200 to-violet-500
            return [Color(hex: 0xE879F9), Color(hex: 0xFBCFE8), Color(hex: 0x8B5CF6)]
        case .legendary: // from-emerald-400 via-teal-100 to-amber-500
            return [Color(hex: 0x34D399), Color(hex: 0xCCFBF1), Color(hex: 0xF59E0B)]
        }
    }

    static func gradient(for tier: RarityTier) -> LinearGradient {
        LinearGradient(colors: colors(for: tier), startPoint: .leading, endPoint: .trailing)
    }

    /// Flat per-tier accent (Rollcard spec): drives the rarity sub-label colour and each
    /// card's outline. Pinned by the design brief — epic is purple, not amber.
    ///   common = teal-400 · rare = rose-500 · epic = purple-400 · legendary = emerald-400
    static func solid(for tier: RarityTier) -> Color {
        switch tier {
        case .common:    return Color(hex: 0x2DD4BF) // teal-400
        case .rare:      return Color(hex: 0xF43F5E) // rose-500
        case .epic:      return Color(hex: 0xC084FC) // purple-400
        case .legendary: return Color(hex: 0x34D399) // emerald-400
        }
    }

    /// Near-black card fill, tinted toward the tier hue (the Rollcard `bg-[#141121]/95` set).
    /// Gives each rarity card its own quiet temperature under bright white text.
    static func cardTint(for tier: RarityTier) -> Color {
        switch tier {
        case .common:    return Color(hex: 0x111A1C) // teal-tinted black
        case .rare:      return Color(hex: 0x1C1114) // rose-tinted black
        case .epic:      return Color(hex: 0x141121) // purple-tinted black
        case .legendary: return Color(hex: 0x111C14) // emerald-tinted black
        }
    }

    /// Tier-coloured hairline border for the rarity card (`border-{hue}-500/20`, nudged up
    /// slightly so it reads over the near-black fill).
    static func cardStroke(for tier: RarityTier) -> Color {
        solid(for: tier).opacity(0.28)
    }
}

/// A rarity word rendered with the tier gradient (matches the bg-clip-text look).
struct RarityBadge: View {
    let tier: RarityTier
    var fontSize: CGFloat = 12

    var body: some View {
        Text(tier.displayName.uppercased())
            .font(AppFont.display(fontSize, weight: .black))
            .tracking(1)
            .foregroundStyle(RarityStyle.gradient(for: tier))
            .accessibilityLabel("Rarity \(tier.displayName)")
    }
}
