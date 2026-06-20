//
//  FaceOffView.swift
//  Tastecard
//
//  "Theme face-off" — a quick tournament that pits your top categories head-to-head
//  ("which is more you?") until one is crowned. Fun, interactive, on-device, shareable.
//

import SwiftUI
import UIKit

struct FaceOffView: View {
    let card: Tastecard
    @Environment(\.dismiss) private var dismiss

    @State private var heroes: [String: UIImage] = [:]
    @State private var ready = false
    @State private var contenders: [EmergentTheme] = []
    @State private var nextRound: [EmergentTheme] = []
    @State private var index = 0
    @State private var champion: EmergentTheme?

    private var allThemes: [EmergentTheme] { Array(card.themes.prefix(6)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x3F2A52), Color(hex: 0x0B1220)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if !ready {
                ProgressView().tint(.white)
            } else if let champ = champion {
                championView(champ)
            } else {
                matchup
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
                    .buttonStyle(.plain).padding()
                }
                Spacer()
            }
        }
        .task {
            heroes = await ThemeImageLoader.heroes(for: allThemes)
            contenders = allThemes
            ready = true
        }
    }

    private var matchup: some View {
        VStack(spacing: 14) {
            Text("WHICH IS MORE YOU?")
                .font(AppFont.mono(13, weight: .bold)).tracking(3)
                .foregroundColor(.white.opacity(0.85)).padding(.top, 64)
            if index < contenders.count { contenderCard(contenders[index]) }
            Text("VS").font(AppFont.display(20, weight: .black)).foregroundColor(.white.opacity(0.6))
            if index + 1 < contenders.count { contenderCard(contenders[index + 1]) }
            Spacer()
        }
        .padding(20)
    }

    private func contenderCard(_ theme: EmergentTheme) -> some View {
        Button { pick(theme) } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let id = theme.heroPhotoLocalId, let img = heroes[id] {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        CategoryPlaceholder(categoryId: theme.categoryId)
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                Text(theme.displayName).font(AppFont.display(22, weight: .bold)).foregroundColor(.white).padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func pick(_ winner: EmergentTheme) {
        Haptics.select()
        var nr = nextRound + [winner]
        var nextIndex = index + 2
        // A lone leftover at the end of a round auto-advances.
        if nextIndex == contenders.count - 1 {
            nr.append(contenders[nextIndex])
            nextIndex = contenders.count
        }
        if nextIndex >= contenders.count {
            if nr.count <= 1 {
                champion = nr.first ?? winner
            } else {
                contenders = nr; nextRound = []; index = 0
            }
        } else {
            nextRound = nr; index = nextIndex
        }
    }

    private func championView(_ champ: EmergentTheme) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("YOUR #1 VIBE").font(AppFont.mono(13, weight: .bold)).tracking(3).foregroundColor(.white.opacity(0.7))
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let id = champ.heroPhotoLocalId, let img = heroes[id] {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        CategoryPlaceholder(categoryId: champ.categoryId)
                    }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text(champ.displayName).font(AppFont.display(28, weight: .black)).foregroundColor(.white)
                    if !champ.tagline.isEmpty {
                        Text(champ.tagline).font(AppFont.sans(13)).italic().foregroundColor(.white.opacity(0.85))
                    }
                }.padding(16)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Spacer()
            Button {
                shareMiniThemeCard(theme: champ, card: card, heroImage: champ.heroPhotoLocalId.flatMap { heroes[$0] })
            } label: {
                Text("SHARE THE WINNER").font(AppFont.sans(13, weight: .black)).tracking(1).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0xEC4899), Color(hex: 0xE11D48)], startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(.plain)
            Button("Play again") {
                champion = nil; contenders = allThemes; nextRound = []; index = 0
            }
            .foregroundColor(.white.opacity(0.7)).padding(.top, 4)
            Spacer()
        }
        .padding(24)
    }
}
