//
//  SnapshotCardView.swift
//  Tastecard
//
//  The 9:16 export surface (§7). Rendered by ImageRenderer, which can't reproduce live
//  blur (Material) — so the export uses an EXPLICIT crisp glass panel (gradient + border +
//  shadow) instead of a flat grey blob.
//
//  Layout mirrors the Android SnapshotRenderer canvas: ONE big glass card that fills the
//  frame, with a 2x2 photo grid sized to fill the remaining space *inside* the card so the
//  photos always read as INSIDE the box. The grid is a non-lazy VStack/HStack of fixed-frame
//  cells (LazyVGrid collapses/overlaps cells under ImageRenderer — the "mesh" bug); a
//  GeometryReader supplies the exact leftover height so nothing ever overflows the panel.
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

    /// The themes split into rows of two (matches Android's 2-column grid).
    private var gridRows: [[EmergentTheme]] {
        var rows: [[EmergentTheme]] = []
        var i = 0
        while i < themes.count {
            rows.append(Array(themes[i..<min(i + 2, themes.count)]))
            i += 2
        }
        return rows.isEmpty ? [[]] : rows
    }

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

            // Brand row sits ABOVE the card; the card then fills the rest of the frame.
            VStack(spacing: 12) {
                brandRow
                cardBox
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 24)
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

    /// The big glass card. It fills the available vertical space so it's a prominent box,
    /// with the photo grid expanding to consume whatever room is left inside it.
    private var cardBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            identityRow
            stats
            aboutMe
            grid                 // expands to fill remaining height inside the card
            footer               // inside the card, like Android
        }
        .foregroundColor(textColor)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panel)
    }

    private var identityRow: some View {
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
    }

    @ViewBuilder private var aboutMe: some View {
        if let about = card.aboutMe, !about.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("ABOUT ME").font(AppFont.mono(8, weight: .bold)).tracking(1.5).opacity(0.65)
                Text(about)
                    .font(AppFont.sans(11))
                    .opacity(0.9)
                    .lineLimit(2)
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
        // A clearly-defined card so the photos read as INSIDE the box. The frosting still
        // scales with the user's opacity slider, but with a solid floor + visible border.
        return shape
            .fill(textColor.opacity(0.16 + 0.10 * glassOpacity))
            .overlay(
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                          startPoint: .top, endPoint: .center))
            )
            .overlay(shape.strokeBorder(textColor.opacity(0.40), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.30), radius: 22, y: 12)
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

    /// Deterministic 2x2 grid (non-lazy). GeometryReader gives the exact remaining height
    /// inside the card; we size each portrait (3:4) cell to fill it and center the block
    /// horizontally — the same maths Android's canvas renderer uses. Because the cells are
    /// explicitly bounded to that measured space, they can never overflow the card panel.
    private var grid: some View {
        GeometryReader { geo in
            let gap: CGFloat = 9
            let rowCount = max(gridRows.count, 1)
            let cellH = (geo.size.height - gap * CGFloat(rowCount - 1)) / CGFloat(rowCount)
            let cellW = min(cellH * 3.0 / 4.0, (geo.size.width - gap) / 2)

            VStack(spacing: gap) {
                ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: gap) {
                        tile(row.first, w: cellW, h: cellH)
                        tile(row.count > 1 ? row[1] : nil, w: cellW, h: cellH)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private func tile(_ theme: EmergentTheme?, w: CGFloat, h: CGFloat) -> some View {
        if let theme {
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
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
        } else {
            // Keeps the surviving cell column-aligned when a row has a single theme.
            Color.clear.frame(width: w, height: h)
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
            .padding(.top, 2)
    }
}
