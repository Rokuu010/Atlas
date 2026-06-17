//
//  SnapshotCardView.swift
//  Tastecard
//
//  The 9:16 export surface (§7), a faithful native port of SnapshotModal's inner layout:
//  brand row (NAME … #code), an inner glass card replicating the main card's glass /
//  scrim / brightness adaptation, the same active highlight/dim states, MAX 4 themes,
//  and NO droplet/edit icons on the title. It is the highest-fidelity surface in the app.
//
//  Rendered synchronously by ImageRenderer, so every image is a pre-resolved UIImage
//  (local only — no async, no network, no CORS taint).
//

import SwiftUI
import UIKit

struct SnapshotCardView: View {
    let card: Tastecard
    let theme: AppTheme
    let customBackground: UIImage?
    let isBgDark: Bool
    let selectedThemeId: String?
    /// Pre-resolved hero images keyed by PHAsset local id.
    let heroImages: [String: UIImage]

    /// Base width of the 9:16 surface in points; the renderer scales it ×3.
    static let baseWidth: CGFloat = 400
    var baseWidth: CGFloat { Self.baseWidth }
    var baseHeight: CGFloat { baseWidth * 16.0 / 9.0 }

    // Adaptive styling (mirrors SnapshotModal; custom-bg dark uses black/35, light white/20).
    private var textColor: Color {
        customBackground != nil ? (isBgDark ? Color(hex: 0xFDF9F6) : Color(hex: 0x0C1519)) : theme.text
    }
    private var cardFill: Color {
        guard customBackground != nil else { return theme.glassFill }
        return isBgDark ? .black.opacity(0.35) : .white.opacity(0.20)
    }
    private var cardBorder: Color {
        guard customBackground != nil else { return theme.glassBorder }
        return isBgDark ? .white.opacity(0.10) : .white.opacity(0.20)
    }

    private var themes: [EmergentTheme] { Array(card.themes.prefix(4)) }   // MAX 4

    var body: some View {
        ZStack {
            theme.background
            if let bg = customBackground {
                Image(uiImage: bg).resizable().scaledToFill()
                (isBgDark ? Color.black.opacity(0.25) : Color.white.opacity(0.05))
            }

            VStack(spacing: 0) {
                brandRow
                innerCard
                    .padding(.top, 10)
                Spacer(minLength: 8)
                footer
            }
            .padding(18)
        }
        .frame(width: baseWidth, height: baseHeight)
        .clipped()
    }

    private var brandRow: some View {
        HStack {
            Text(card.displayName.uppercased())
                .font(AppFont.mono(11, weight: .heavy)).tracking(2)
            Spacer()
            Text(card.serialDisplay)
                .font(AppFont.mono(11, weight: .bold))
        }
        .foregroundColor(textColor)
        .opacity(0.75)
    }

    private var innerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title — NO droplet, NO icons, per the snapshot rule. Rarity badge stays.
            VStack(alignment: .leading, spacing: 3) {
                Text(card.displayName)
                    .font(AppFont.display(22, weight: .black))
                    .lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    Text("TASTECARD RARITY:")
                        .font(AppFont.mono(8)).tracking(0.5).opacity(0.6)
                    RarityBadge(tier: card.cardRarity, fontSize: 9)
                }
            }

            stats
            chips
            grid
        }
        .foregroundColor(textColor)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24, fill: cardFill, border: cardBorder, shadow: false)
    }

    private var stats: some View {
        HStack(spacing: 6) {
            snapStat(card.photosAnalysed.abbreviated, "Photos")
            snapStat("\(card.emergentThemeCount)", "themes")
            snapStat("\(card.placesCount)", "Places")
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Rectangle().fill(textColor.opacity(0.15)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(textColor.opacity(0.15)).frame(height: 1) }
    }

    private func snapStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(AppFont.mono(13, weight: .bold))
            Text(label.uppercased()).font(AppFont.mono(7)).opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        FlowLayout(spacing: 5, lineSpacing: 5) {
            ForEach(themes) { theme in
                let isActive = selectedThemeId == theme.categoryId
                Text(theme.displayName)
                    .font(AppFont.sans(9, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(isActive ? 0.30 : 0.10)))
                    .overlay(Capsule().strokeBorder(.white.opacity(isActive ? 0.55 : 0.05)))
                    .opacity(isActive ? 1 : 0.6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(themes) { theme in
                let highlighted = selectedThemeId == nil || selectedThemeId == theme.categoryId
                ZStack(alignment: .bottomLeading) {
                    heroImage(for: theme)
                    PhotoVignette()
                    Text(theme.displayName)
                        .font(AppFont.sans(9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(6)
                }
                .aspectRatio(3.0/4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(highlighted ? 1 : 0.35)
                .scaleEffect(highlighted ? 1 : 0.95)
            }
        }
    }

    @ViewBuilder private func heroImage(for theme: EmergentTheme) -> some View {
        if let id = theme.heroPhotoLocalId, let img = heroImages[id] {
            Image(uiImage: img).resizable().scaledToFill()
        } else if UIImage(named: HeroPhotoPicker.fallbackImageName(forCategoryId: theme.categoryId)) != nil {
            Image(HeroPhotoPicker.fallbackImageName(forCategoryId: theme.categoryId)).resizable().scaledToFill()
        } else {
            PlaceholderGradient()
        }
    }

    private var footer: some View {
        Text("\(card.displayName) • \(card.serialDisplay)".uppercased())
            .font(AppFont.mono(8)).tracking(2)
            .foregroundColor(textColor).opacity(0.5)
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }
}
