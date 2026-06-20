//
//  WrappedView.swift
//  Tastecard
//
//  "Tastecard Wrapped" — a full-screen, swipeable reveal (intro → one slide per top theme
//  → finale) you tap through and screen-record/share. On-device, high engagement.
//

import SwiftUI
import UIKit

struct WrappedView: View {
    let card: Tastecard
    @Environment(\.dismiss) private var dismiss

    @State private var heroes: [String: UIImage] = [:]
    @State private var ready = false
    @State private var page = 0

    private var palette: AppTheme { AppTheme.theme(at: card.themeIndex) }
    private var topThemes: [EmergentTheme] { Array(card.themes.prefix(5)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.background, Color(hex: 0x0B1220)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if ready {
                TabView(selection: $page) {
                    intro.tag(0)
                    ForEach(Array(topThemes.enumerated()), id: \.offset) { idx, theme in
                        slide(theme: theme, rank: idx + 1).tag(idx + 1)
                    }
                    finale.tag(topThemes.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .task {
            heroes = await ThemeImageLoader.heroes(for: topThemes)
            ready = true
        }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("TASTECARD").font(AppFont.mono(13, weight: .bold)).tracking(4).foregroundColor(.white.opacity(0.7))
            Text("Your camera roll,\ndecoded")
                .font(AppFont.display(34, weight: .black))
                .multilineTextAlignment(.center).foregroundColor(.white)
            Text("\(card.photosAnalysed.formatted()) photos · \(card.emergentThemeCount) themes · \(card.placesCount) places")
                .font(AppFont.sans(14)).foregroundColor(.white.opacity(0.75))
            Text("Swipe to reveal →").font(AppFont.sans(13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5)).padding(.top, 8)
            Spacer()
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func slide(theme: EmergentTheme, rank: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let id = theme.heroPhotoLocalId, let img = heroes[id] {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    CategoryPlaceholder(categoryId: theme.categoryId)
                }
            }
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Text("THEME #\(rank)").font(AppFont.mono(12, weight: .bold)).tracking(2).foregroundColor(.white.opacity(0.8))
                Text(theme.displayName)
                    .font(AppFont.display(40, weight: .black)).foregroundColor(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
                if card.photosAnalysed > 0 {
                    let pct = Double(theme.photoCount) / Double(card.photosAnalysed) * 100
                    Text(pct >= 1 ? String(format: "%.0f%% of your roll", pct) : "<1% of your roll")
                        .font(AppFont.sans(16, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                }
                if !theme.tagline.isEmpty {
                    Text(theme.tagline).font(AppFont.sans(15)).italic()
                        .foregroundColor(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28).padding(.bottom, 56)
        }
        .ignoresSafeArea()
    }

    private var finale: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("THAT'S YOUR TASTE").font(AppFont.mono(13, weight: .bold)).tracking(3).foregroundColor(.white.opacity(0.7))
            RarityBadge(tier: card.cardRarity, fontSize: 26)
            Text(card.cardTitle).font(AppFont.display(28, weight: .black))
                .foregroundColor(.white).multilineTextAlignment(.center)
            Spacer()
            if let first = topThemes.first {
                Button {
                    shareMiniThemeCard(theme: first, card: card, heroImage: first.heroPhotoLocalId.flatMap { heroes[$0] })
                } label: {
                    Text("SHARE YOUR TOP THEME").font(AppFont.sans(13, weight: .black)).tracking(1).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: 0xEC4899), Color(hex: 0xE11D48)], startPoint: .leading, endPoint: .trailing)))
                }
                .buttonStyle(.plain)
            }
            Button("Done") { dismiss() }.foregroundColor(.white.opacity(0.7)).padding(.top, 4)
            Spacer()
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
