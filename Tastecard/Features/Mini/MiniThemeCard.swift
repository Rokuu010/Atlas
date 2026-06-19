//
//  MiniThemeCard.swift
//  Tastecard
//
//  A punchy single-theme shareable image ("18% of your camera roll is Player One").
//  Highly viral, fully on-device. Rendered via ImageExport and shared with the native sheet.
//

import SwiftUI
import UIKit

struct MiniThemeCardView: View {
    let theme: EmergentTheme
    let card: Tastecard
    let heroImage: UIImage?

    static let baseWidth: CGFloat = 400
    static let baseHeight: CGFloat = baseWidth * 16.0 / 9.0

    private var pctText: String? {
        let total = card.photosAnalysed
        guard total > 0 else { return nil }
        let pct = Double(theme.photoCount) / Double(total) * 100
        return pct >= 1 ? String(format: "%.0f%%", pct) : "<1%"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let heroImage {
                    Image(uiImage: heroImage).resizable().scaledToFill()
                } else {
                    CategoryPlaceholder(categoryId: theme.categoryId)
                }
            }
            .frame(width: Self.baseWidth, height: Self.baseHeight)
            .clipped()

            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55), .black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                if let pctText {
                    Text(pctText)
                        .font(AppFont.display(72, weight: .black))
                        .foregroundColor(.white)
                    Text("of your camera roll is")
                        .font(AppFont.sans(15))
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(theme.displayName)
                    .font(AppFont.display(34, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    RarityBadge(tier: theme.rarityTier, fontSize: 12)
                    Text("· \(theme.photoCount) photos")
                        .font(AppFont.sans(12)).foregroundColor(.white.opacity(0.7))
                }
                Text(theme.tagline)
                    .font(AppFont.sans(14)).italic()
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)

            VStack {
                HStack {
                    Text("MY TASTECARD").font(AppFont.mono(11, weight: .heavy)).tracking(2)
                    Spacer()
                    Text(card.serialDisplay).font(AppFont.mono(11, weight: .bold))
                }
                .foregroundColor(.white).opacity(0.85)
                .padding(24)
                Spacer()
            }
        }
        .frame(width: Self.baseWidth, height: Self.baseHeight)
        .clipped()
    }
}

@MainActor
func shareMiniThemeCard(theme: EmergentTheme, card: Tastecard, heroImage: UIImage?) {
    let view = MiniThemeCardView(theme: theme, card: card, heroImage: heroImage)
    let filename = "\(InputSanitizer.filenameSlug(card.displayName))_\(theme.categoryId).png"
    if let url = ImageExport.renderToTempFile(view,
                                              width: MiniThemeCardView.baseWidth,
                                              height: MiniThemeCardView.baseHeight,
                                              filename: filename) {
        Haptics.success()
        ShareService.present(items: [url])
    }
}
