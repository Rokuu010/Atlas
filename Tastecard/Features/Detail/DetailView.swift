//
//  DetailView.swift
//  Tastecard
//
//  Port of DetailModal. Expanded theme card: hero image, title, dynamic rarity badge,
//  the "Atlas Insight" box (the tagline — the shareable hook revealed here), and
//  change-photo. Change-photo shows THIS category's matched photos to choose from (not
//  the whole library), with an "all photos" escape hatch. detectionPrompts are never shown.
//

import SwiftUI
import UIKit
import PhotosUI

struct DetailView: View {
    let theme: EmergentTheme
    @ObservedObject var vm: CardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var heroId: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var sharing = false

    private let gridColumns = [GridItem(.flexible(), spacing: 8),
                               GridItem(.flexible(), spacing: 8),
                               GridItem(.flexible(), spacing: 8)]

    init(theme: EmergentTheme, vm: CardViewModel) {
        self.theme = theme
        self.vm = vm
        _heroId = State(initialValue: theme.heroPhotoLocalId)
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0B1220).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        hero
                        titleRow
                        insight
                        shareThemeButton
                        matchesPicker
                        allPhotosFallback
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: pickerItem) { item in
            guard let item, let newId = item.itemIdentifier else { return }
            select(newId)
            pickerItem = nil
        }
    }

    private func select(_ id: String) {
        heroId = id
        vm.swapHero(themeId: theme.id, toAssetId: id)
    }

    /// Engagement: how much of the analysed roll this theme represents.
    private var shareOfRoll: String {
        let total = vm.card.photosAnalysed
        guard total > 0 else { return "Seen across \(theme.photoCount) of your photos." }
        let pct = Double(theme.photoCount) / Double(total) * 100
        let pctText = pct >= 1 ? String(format: "%.0f%%", pct) : "<1%"
        return "Seen across \(theme.photoCount) photos — about \(pctText) of your roll."
    }

    private var header: some View {
        HStack {
            Text(theme.displayName.uppercased())
                .font(AppFont.mono(12, weight: .bold)).tracking(2)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            AssetImage(assetId: heroId, categoryId: theme.categoryId, targetSide: 1000)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }

    private var titleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.displayName)
                    .font(AppFont.display(22, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("Theme rarity:")
                        .font(AppFont.sans(12)).foregroundColor(.white.opacity(0.6))
                    RarityBadge(tier: theme.rarityTier, fontSize: 12)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(theme.photoCount)")
                    .font(AppFont.mono(15, weight: .semibold)).foregroundColor(.white)
                Text("PHOTOS")
                    .font(AppFont.mono(8)).tracking(0.5).foregroundColor(.white.opacity(0.45))
            }
        }
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .font(.system(size: 11)).foregroundColor(Color(hex: 0xF59E0B))
                Text("ATLAS INSIGHT")
                    .font(AppFont.mono(10)).tracking(1).foregroundColor(.white.opacity(0.6))
            }
            Text(theme.tagline)
                .font(AppFont.sans(15))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text(shareOfRoll)
                .font(AppFont.sans(12))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.10)))
    }

    /// Grid of this category's matched photos — pick one as the hero.
    @ViewBuilder private var matchesPicker: some View {
        if !theme.candidatePhotoLocalIds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHOOSE FROM THIS THEME'S PHOTOS")
                    .font(AppFont.mono(10)).tracking(1).foregroundColor(.white.opacity(0.6))
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(theme.candidatePhotoLocalIds, id: \.self) { id in
                        let selected = heroId == id
                        AssetImage(assetId: id, categoryId: theme.categoryId, targetSide: 400)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? Color(hex: 0xF59E0B) : .white.opacity(0.08),
                                                  lineWidth: selected ? 3 : 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { Haptics.select(); select(id) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shareThemeButton: some View {
        Button { shareTheme() } label: {
            HStack(spacing: 8) {
                if sharing { ProgressView().tint(.white) } else { Image(systemName: "square.and.arrow.up") }
                Text(sharing ? "Preparing…" : "Share this theme")
            }
            .font(AppFont.sans(13, weight: .black)).tracking(1)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xEC4899), Color(hex: 0xE11D48)],
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
        .disabled(sharing)
    }

    private func shareTheme() {
        guard !sharing else { return }
        sharing = true
        Task {
            var img: UIImage?
            if let id = heroId {
                img = await PhotoAssetLoader().requestImage(forIdentifier: id, targetSide: 1200)
            }
            shareMiniThemeCard(theme: theme, card: vm.card, heroImage: img)
            sharing = false
        }
    }

    private var allPhotosFallback: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Text("Choose from all photos…")
                .font(AppFont.sans(13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
