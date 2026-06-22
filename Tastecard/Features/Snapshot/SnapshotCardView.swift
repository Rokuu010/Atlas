//
//  SnapshotCardView.swift
//  Tastecard
//
//  The 9:16 export surface (§7) — recreated from REPLICATING_ROLLCARD.md. Rendered by
//  ImageRenderer, which can't reproduce live Material blur, so the "glass" is built from
//  layered gradients + borders (the doc's note #2: html-to-image / ImageRenderer reproduce
//  CSS/SwiftUI gradients far more reliably than heavy blur).
//
//  Fidelity to the on-screen card: the background is the SAME photo shown on the card
//  screen (custom background if set, otherwise the card hero), under a dark legibility
//  scrim with WHITE text — so the export reads identically to the app, not as a flat
//  coloured panel. The 2x2 theme grid mirrors the on-screen GridThemeCard (title + rarity
//  on top, photo crop below) so every label TRUNCATES inside its tile and can never be
//  clipped at the edge of the card.
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

    /// White-ish ink — readable over the dark scrim, matching the app's white-on-photo card.
    private let ink = Color(hex: 0xFDF9F6)

    private var themes: [EmergentTheme] { Array(card.themes.prefix(4)) }

    /// The background photo — the SAME image the card screen shows: a user-chosen custom
    /// background if set, otherwise the card hero (first theme's hero). nil -> category art.
    private var backgroundImage: UIImage? {
        if let customBackground { return customBackground }
        if let id = card.heroPhotoLocalId { return heroImages[id] }
        return nil
    }

    /// The themes split into rows of two (matches the on-screen 2-column grid).
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
            background
            VStack(spacing: 14) {
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

    // MARK: - Full-bleed photo background + legibility scrim

    private var background: some View {
        ZStack {
            Color.black
            Group {
                if let img = backgroundImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else if let cat = themes.first?.categoryId {
                    CategoryPlaceholder(categoryId: cat)
                } else {
                    backgroundColor
                }
            }
            .frame(width: baseWidth, height: baseHeight)
            .clipped()

            // Dark scrim + bottom-weighted gradient — keeps the photo visible (like the app)
            // while guaranteeing white text and the glass card pop. Gradients only (no blur)
            // so ImageRenderer reproduces it crisply.
            Color.black.opacity(0.30)
            LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.34), .black.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var brandRow: some View {
        HStack {
            Text("MY TASTECARD")
                .font(AppFont.mono(11, weight: .heavy)).tracking(2)
            Spacer()
            Text(card.serialDisplay)
                .font(AppFont.mono(11, weight: .bold))
        }
        .foregroundStyle(ink.opacity(0.85))
    }

    /// The big glass card. Fills the available vertical space; the footer is pinned to its
    /// bottom edge by a flexible spacer.
    private var cardBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            identityRow
            stats
            aboutMe
            grid
            Spacer(minLength: 0)
            footer
        }
        .foregroundStyle(ink)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panel)
    }

    private var identityRow: some View {
        HStack(alignment: .center, spacing: 12) {
            ProfileAvatar(image: profileImage, ink: ink, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.cardTitle)
                    .font(AppFont.display(22, weight: .black))
                    .lineLimit(2).minimumScaleFactor(0.5)
                HStack(spacing: 5) {
                    Text("TASTECARD RARITY:")
                        .font(AppFont.mono(8)).tracking(0.5).opacity(0.7)
                    // Export rarity reads in gold with a soft glow (doc §3), distinct from
                    // the per-tile accent colours.
                    Text(card.cardRarity.displayName.uppercased())
                        .font(AppFont.mono(10, weight: .heavy)).tracking(1)
                        .foregroundStyle(Color(hex: 0xFBBF24))
                        .shadow(color: Color(hex: 0xFBBF24).opacity(0.5), radius: 6)
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
                    .opacity(0.92)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Glass panel — crisp under ImageRenderer (no Material). A translucent white fill lets
    /// the photo glow through, with a top sheen + border + shadow selling the glass. The
    /// frosting still scales with the user's opacity slider, over a solid floor.
    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return shape
            .fill(.white.opacity(0.06 + 0.08 * glassOpacity))
            .overlay(
                shape.fill(LinearGradient(colors: [.white.opacity(0.14), .clear],
                                          startPoint: .top, endPoint: .center))
            )
            .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
    }

    private var stats: some View {
        HStack(spacing: 6) {
            snapStat(card.photosAnalysed.abbreviated, "Photos")
            snapStat("\(card.emergentThemeCount)", "Themes")
            snapStat("\(card.placesCount)", "Places")
        }
        .padding(.vertical, 2)
    }

    /// Big gradient-filled numerals (doc §3: bg-clip-text from-white to-white/70) over a
    /// wide-tracked mono label.
    private func snapStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(AppFont.mono(16, weight: .heavy))
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)],
                                                startPoint: .top, endPoint: .bottom))
            Text(label.uppercased())
                .font(AppFont.mono(7, weight: .bold)).tracking(1)
                .foregroundStyle(Color(hex: 0x8F9BAC).opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 2x2 theme grid (title/rarity header + photo crop — mirrors GridThemeCard)

    private var grid: some View {
        let gap: CGFloat = 10
        // interior width = surface - outer .horizontal(22*2) - card .padding(18*2)
        let cellW = (baseWidth - 44 - 36 - gap) / 2
        return VStack(spacing: gap) {
            ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    tile(row.first, w: cellW)
                    tile(row.count > 1 ? row[1] : nil, w: cellW)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func tile(_ theme: EmergentTheme?, w: CGFloat) -> some View {
        if let theme {
            let accent = RarityStyle.solid(for: theme.rarityTier)
            let pad: CGFloat = 10
            let photoW = w - pad * 2
            let photoH = photoW * 0.78
            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName.uppercased())
                        .font(AppFont.display(11, weight: .black)).tracking(0.8)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("RARITY: \(theme.rarityTier.displayName.uppercased())")
                        .font(AppFont.mono(7, weight: .heavy)).tracking(1)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                heroImage(for: theme)
                    .frame(width: photoW, height: photoH)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.06))) // brightness-95
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.10)))
            }
            .padding(pad)
            .frame(width: w, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RarityStyle.cardTint(for: theme.rarityTier)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(RarityStyle.cardStroke(for: theme.rarityTier), lineWidth: 1))
        } else {
            // Keeps the surviving cell column-aligned when a row has a single theme.
            Color.clear.frame(width: w, height: 10)
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
            .foregroundStyle(ink.opacity(0.6))
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
