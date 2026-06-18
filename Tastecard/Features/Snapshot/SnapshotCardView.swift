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
    let backgroundColor: Color
    let customBackground: UIImage?
    let isBgDark: Bool
    let glassOpacity: Double
    let profileImage: UIImage?
    let selectedThemeId: String?
    let heroImages: [String: UIImage]

    static let baseWidth: CGFloat = 400
    var baseWidth: CGFloat { Self.baseWidth }
    var baseHeight: CGFloat { baseWidth * 16.0 / 9.0 }

    // Mirrors CardViewModel.textColor: photo -> photo brightness, solid colour -> colour
    // brightness, preset theme -> the theme's own ink.
    private var textColor: Color {
        if customBackground != nil { return isBgDark ? Color(hex: 0xFDF9F6) : Color(hex: 0x0C1519) }
        if card.customBackgroundColorHex != nil { return Brightness.isDark(backgroundColor) ? Color(hex: 0xFDF9F6) : Color(hex: 0x0C1519) }
        return theme.text
    }

    private var themes: [EmergentTheme] { Array(card.themes.prefix(4)) }

    var body: some View {
        ZStack {
            backgroundColor
            if let bg = customBackground {
                Image(uiImage: bg).resizable().scaledToFill()
                    .frame(width: baseWidth, height: baseHeight).clipped()
                // Stronger scrim in the export so the card + photos pop crisply.
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
            }

            // Subtle depth vignette.
            RadialGradient(colors: [.clear, .black.opacity(0.22)],
                           center: .center, startRadius: baseWidth * 0.55, endRadius: baseWidth * 1.15)
                .blendMode(.multiply)
                .allowsHitTesting(false)

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
            Text("MY TASTECARD")
                .font(AppFont.mono(11, weight: .heavy)).tracking(2)
            Spacer()
            Text(card.serialDisplay)
                .font(AppFont.mono(11, weight: .bold))
        }
        .foregroundColor(textColor)
        .opacity(0.8)
    }

    private var innerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ProfileAvatar(image: profileImage, ink: textColor, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.cardTitle)
                        .font(AppFont.display(22, weight: .black))
                        .lineLimit(2).minimumScaleFactor(0.5)
                    HStack(spacing: 5) {
                        Text("TASTECARD RARITY:")
                            .font(AppFont.mono(8)).tracking(0.5).opacity(0.6)
                        RarityBadge(tier: card.cardRarity, fontSize: 10)
                    }
                }
                Spacer(minLength: 0)
            }
            stats
            aboutMe
            grid
        }
        .foregroundColor(textColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }

    @ViewBuilder private var aboutMe: some View {
        if let about = card.aboutMe, !about.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("ABOUT ME").font(AppFont.mono(8, weight: .bold)).tracking(1.5).opacity(0.65)
                Text(about)
                    .font(AppFont.sans(11))
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Explicit glass panel — crisp under ImageRenderer (no Material dependency). The base
    /// fill uses the text color so it lightens dark themes and darkens light ones (good
    /// contrast either way); a top white sheen + adaptive border + shadow sell the glass.
    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        // Scale the frosting with the user's opacity slider, with a floor so the export
        // card never disappears entirely.
        return shape
            .fill(textColor.opacity(0.06 + 0.12 * glassOpacity))
            .overlay(
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.14), .clear],
                                          startPoint: .top, endPoint: .center))
            )
            .overlay(shape.strokeBorder(textColor.opacity(0.30), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }

    private var stats: some View {
        HStack(spacing: 6) {
            snapStat(card.photosAnalysed.abbreviated, "Photos")
            snapStat("\(card.emergentThemeCount)", "Themes")
            snapStat("\(card.placesCount)", "Places")
        }
        .padding(.vertical, 2)
    }

    private func snapStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(AppFont.mono(15, weight: .heavy))
            Text(label.uppercased()).font(AppFont.sans(7, weight: .semibold)).opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                // .fit keeps each tile inside its grid column (the previous .fill let tiles
                // overflow the card edges in the export). The image still fills via scaledToFill.
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
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
        Text("\(card.cardTitle) • \(card.serialDisplay)".uppercased())
            .font(AppFont.mono(8)).tracking(2)
            .foregroundColor(textColor).opacity(0.55)
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }
}
