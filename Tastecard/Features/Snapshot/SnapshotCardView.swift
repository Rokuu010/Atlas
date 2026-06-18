//
//  SnapshotCardView.swift
//  Tastecard
//
//  The 9:16 export surface (§7). Rendered by ImageRenderer, which can't reproduce live
//  blur (Material) — so the export uses an EXPLICIT crisp glass panel (gradient + border +
//  shadow) instead, giving a clean, high-contrast card rather than a flat grey blob.
//  Max 4 themes, no droplet/edit icons on the title.
//

import SwiftUI
import UIKit

struct SnapshotCardView: View {
    let card: Tastecard
    let theme: AppTheme
    let customBackground: UIImage?
    let isBgDark: Bool
    let selectedThemeId: String?
    let heroImages: [String: UIImage]

    static let baseWidth: CGFloat = 400
    var baseWidth: CGFloat { Self.baseWidth }
    var baseHeight: CGFloat { baseWidth * 16.0 / 9.0 }

    private var textColor: Color {
        customBackground != nil ? (isBgDark ? Color(hex: 0xFDF9F6) : Color(hex: 0x0C1519)) : theme.text
    }

    private var themes: [EmergentTheme] { Array(card.themes.prefix(4)) }

    var body: some View {
        ZStack {
            theme.background
            if let bg = customBackground {
                Image(uiImage: bg).resizable().scaledToFill()
                    .frame(width: baseWidth, height: baseHeight).clipped()
                // Stronger scrim in the export so the card + photos pop crisply.
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
            }

            VStack(spacing: 0) {
                brandRow
                innerCard.padding(.top, 12)
                Spacer(minLength: 10)
                footer
            }
            .padding(20)
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
        .opacity(0.8)
    }

    private var innerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(AppFont.display(26, weight: .black))
                    .lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    Text("TASTECARD RARITY:")
                        .font(AppFont.mono(8)).tracking(0.5).opacity(0.6)
                    RarityBadge(tier: card.cardRarity, fontSize: 10)
                }
            }
            stats
            chips
            grid
        }
        .foregroundColor(textColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }

    /// Explicit glass panel — crisp under ImageRenderer (no Material dependency). The base
    /// fill uses the text color so it lightens dark themes and darkens light ones (good
    /// contrast either way); a top white sheen + adaptive border + shadow sell the glass.
    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return shape
            .fill(textColor.opacity(0.08))
            .overlay(
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear],
                                          startPoint: .top, endPoint: .center))
            )
            .overlay(shape.strokeBorder(textColor.opacity(0.28), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }

    private var stats: some View {
        HStack(spacing: 6) {
            snapStat(card.photosAnalysed.abbreviated, "Photos")
            snapStat("\(card.emergentThemeCount)", "Themes")
            snapStat("\(card.placesCount)", "Places")
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(textColor.opacity(0.15)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(textColor.opacity(0.15)).frame(height: 1) }
    }

    private func snapStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(AppFont.mono(15, weight: .heavy))
            Text(label.uppercased()).font(AppFont.sans(7, weight: .semibold)).opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        FlowLayout(spacing: 5, lineSpacing: 5) {
            ForEach(themes) { theme in
                let isActive = selectedThemeId == theme.categoryId
                Text(theme.displayName)
                    .font(AppFont.sans(9, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(isActive ? 0.32 : 0.12)))
                    .overlay(Capsule().strokeBorder(.white.opacity(isActive ? 0.55 : 0.10)))
                    .opacity(isActive ? 1 : 0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(themes) { theme in
                ZStack(alignment: .bottomLeading) {
                    heroImage(for: theme)
                    LinearGradient(stops: [.init(color: .black.opacity(0.8), location: 0),
                                           .init(color: .clear, location: 0.55)],
                                   startPoint: .bottom, endPoint: .top)
                    Text(theme.displayName)
                        .font(AppFont.sans(9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(7)
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
            }
        }
    }

    @ViewBuilder private func heroImage(for theme: EmergentTheme) -> some View {
        if let id = theme.heroPhotoLocalId, let img = heroImages[id] {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            CategoryPlaceholder(categoryId: theme.categoryId)
        }
    }

    private var footer: some View {
        Text("\(card.displayName) • \(card.serialDisplay)".uppercased())
            .font(AppFont.mono(8)).tracking(2)
            .foregroundColor(textColor).opacity(0.55)
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }
}
