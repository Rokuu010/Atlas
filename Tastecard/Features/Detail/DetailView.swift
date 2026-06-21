//
//  DetailView.swift
//  Tastecard
//
//  Immersive "Theme Gallery" view (recreated from the theme-gallery reference). The active
//  photo fills the screen; a swipe-down indicator returns; a bottom glass panel shows the
//  title, rarity, photo count, and a horizontal strip of this theme's photos. Tapping a
//  thumbnail changes the context (and persists it as the theme's hero). "View all photos"
//  opens a frosted-glass grid of every photo in the theme. detectionPrompts are never shown.
//
//  Robustness: the gallery is sourced from the theme's matched photos, but always falls back
//  to the hero (and a designed placeholder) so a card saved by an older build — which lacks
//  the per-theme candidate list — still shows imagery instead of an empty panel.
//

import SwiftUI
import UIKit
import PhotosUI

struct DetailView: View {
    let theme: EmergentTheme
    @ObservedObject var vm: CardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var activeId: String?
    @State private var showAllPhotos = false

    init(theme: EmergentTheme, vm: CardViewModel) {
        self.theme = theme
        self.vm = vm
        _activeId = State(initialValue: theme.heroPhotoLocalId)
    }

    /// Every photo we can show for this theme, best-first, with the hero guaranteed present
    /// and first. Falls back to [hero] for older cards that never stored the candidate list.
    private var galleryIds: [String] {
        var ids = theme.candidatePhotoLocalIds
        if let hero = theme.heroPhotoLocalId, !ids.contains(hero) {
            ids.insert(hero, at: 0)
        }
        return ids
    }

    /// The currently-shown photo (background + ACTIVE badge), tolerant of a nil hero.
    private var currentId: String? { activeId ?? galleryIds.first }

    var body: some View {
        ZStack {
            background
            scrim
            VStack(spacing: 0) {
                swipeIndicator
                    .padding(.top, 14)
                Spacer(minLength: 0)
                bottomContent
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showAllPhotos) {
            ThemeAllPhotosView(theme: theme,
                               galleryIds: galleryIds,
                               backdropId: currentId,
                               currentId: currentId,
                               vm: vm,
                               onSelect: { select($0) })
        }
    }

    private func select(_ id: String) {
        guard id != currentId else { return }
        Haptics.select()
        activeId = id
        vm.swapHero(themeId: theme.id, toAssetId: id)
    }

    // MARK: - Background (active photo, full-bleed) + legibility scrim

    private var background: some View {
        AssetImage(assetId: currentId, categoryId: theme.categoryId, targetSide: 1400)
            .ignoresSafeArea()
    }

    private var scrim: some View {
        LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0.20), .black.opacity(0.80)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Swipe-down indicator (tap or drag down to return)

    private var swipeIndicator: some View {
        Button {
            Haptics.tap(); dismiss()
        } label: {
            VStack(spacing: 5) {
                Capsule().fill(.black.opacity(0.55)).frame(width: 44, height: 5)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Swipe Down to Return".uppercased())
                    .font(AppFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return")
        .accessibilityHint("Closes this theme")
    }

    // MARK: - Bottom content (title row + glass gallery panel)

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleRow
            galleryPanel
        }
    }

    private var titleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(theme.displayName)
                    .font(AppFont.display(34, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                rarityPill
            }
            Spacer(minLength: 8)
            countPill
        }
    }

    private var rarityPill: some View {
        Text("✦ Theme Rarity: \(theme.rarityTier.displayName.uppercased())")
            .font(AppFont.mono(9, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(RarityStyle.solid(for: theme.rarityTier))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.55)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.10)))
    }

    private var countPill: some View {
        HStack(spacing: 4) {
            Text("\(theme.photoCount)")
                .font(AppFont.mono(11, weight: .bold))
                .foregroundStyle(.white)
            Text("photos")
                .font(AppFont.mono(11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .tracking(1)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.6)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.10)))
    }

    private var galleryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("Explore Theme Gallery".uppercased())
                    .font(AppFont.sans(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(width: 130, alignment: .leading)
                Spacer()
                Text("Tap to change context".uppercased())
                    .font(AppFont.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: 0xFBBF24).opacity(0.9))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100, alignment: .trailing)
            }

            thumbnailStrip
            viewAllButton
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.04)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }

    @ViewBuilder private var thumbnailStrip: some View {
        if galleryIds.isEmpty {
            Text("No photos available for this theme yet.")
                .font(AppFont.sans(12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(galleryIds, id: \.self) { id in
                        ThemeThumbnail(assetId: id,
                                       categoryId: theme.categoryId,
                                       isActive: id == currentId) { select(id) }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
        }
    }

    private var viewAllButton: some View {
        Button {
            Haptics.tap(); showAllPhotos = true
        } label: {
            Text("View all photos in the theme".uppercased())
                .font(AppFont.sans(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View all photos in the theme")
    }
}

/// One thumbnail in the horizontal strip. Active = amber gradient border + scale + ACTIVE badge.
private struct ThemeThumbnail: View {
    let assetId: String
    let categoryId: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AssetImage(assetId: assetId, categoryId: categoryId, targetSide: 200)
                .frame(width: isActive ? 64 : 68, height: isActive ? 64 : 68)
                .clipShape(RoundedRectangle(cornerRadius: isActive ? 18 : 20, style: .continuous))
                .frame(width: 68, height: 68)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isActive
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFCD34D), Color(hex: 0xF59E0B)],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.clear))
                )
                .overlay {
                    if !isActive {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.10))
                    }
                }
                .overlay(alignment: .bottom) {
                    if isActive {
                        Text("Active".uppercased())
                            .font(AppFont.mono(8, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(hex: 0xFBBF24)))
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                            .offset(y: 7)
                    }
                }
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Active photo" : "Set as theme photo")
    }
}

/// "View all photos in the theme": the original 3-column grid, recreated inside a frosted-glass
/// container (translucent over the blurred active photo) rather than a solid panel. Preserves
/// the Atlas insight, the per-theme share, and the "choose from all photos" escape hatch.
struct ThemeAllPhotosView: View {
    let theme: EmergentTheme
    let galleryIds: [String]
    let backdropId: String?
    let currentId: String?
    @ObservedObject var vm: CardViewModel
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedId: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var sharing = false

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    init(theme: EmergentTheme, galleryIds: [String], backdropId: String?,
         currentId: String?, vm: CardViewModel, onSelect: @escaping (String) -> Void) {
        self.theme = theme
        self.galleryIds = galleryIds
        self.backdropId = backdropId
        self.currentId = currentId
        self.vm = vm
        self.onSelect = onSelect
        _selectedId = State(initialValue: currentId)
    }

    /// Engagement line — how much of the analysed roll this theme represents.
    private var shareOfRoll: String {
        let total = vm.card.photosAnalysed
        guard total > 0 else { return "Seen across \(theme.photoCount) of your photos." }
        let pct = Double(theme.photoCount) / Double(total) * 100
        let pctText = pct >= 1 ? String(format: "%.0f%%", pct) : "<1%"
        return "Seen across \(theme.photoCount) photos — about \(pctText) of your roll."
    }

    var body: some View {
        ZStack {
            glassBackdrop
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        insight
                        grid
                        allPhotosFallback
                    }
                    .padding(18)
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: pickerItem) { item in
            guard let item, let newId = item.itemIdentifier else { return }
            choose(newId)
            pickerItem = nil
        }
    }

    private func choose(_ id: String) {
        selectedId = id
        onSelect(id)
    }

    // MARK: - Frosted-glass backdrop (translucent, not solid)

    private var glassBackdrop: some View {
        ZStack {
            Color.black
            AssetImage(assetId: backdropId, categoryId: theme.categoryId, targetSide: 600)
                .ignoresSafeArea()
                .blur(radius: 50)
                .opacity(0.8)
            Color.black.opacity(0.25)
            Rectangle().fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(theme.displayName.uppercased())
                .font(AppFont.mono(12, weight: .bold)).tracking(2)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Button { shareTheme() } label: {
                HStack(spacing: 6) {
                    if sharing { ProgressView().controlSize(.small).tint(.white) }
                    else { Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .semibold)) }
                    Text(sharing ? "…" : "Share")
                        .font(AppFont.sans(12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(0.14)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(sharing)
            .accessibilityLabel("Share this theme")

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(16)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .font(.system(size: 11)).foregroundStyle(Color(hex: 0xF59E0B))
                Text("ATLAS INSIGHT")
                    .font(AppFont.mono(10)).tracking(1).foregroundStyle(.white.opacity(0.6))
            }
            if !theme.tagline.isEmpty {
                Text(theme.tagline)
                    .font(AppFont.sans(15))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(shareOfRoll)
                .font(AppFont.sans(12))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.10)))
    }

    @ViewBuilder private var grid: some View {
        if galleryIds.isEmpty {
            Text("No photos available for this theme yet. Re-analyse your camera roll to refresh it.")
                .font(AppFont.sans(13))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHOOSE FROM THIS THEME'S PHOTOS")
                    .font(AppFont.mono(10)).tracking(1).foregroundStyle(.white.opacity(0.6))
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(galleryIds, id: \.self) { id in
                        let selected = (selectedId ?? currentId) == id
                        Button {
                            Haptics.select(); choose(id); dismiss()
                        } label: {
                            AssetImage(assetId: id, categoryId: theme.categoryId, targetSide: 400)
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selected ? Color(hex: 0xF59E0B) : .white.opacity(0.10),
                                                      lineWidth: selected ? 3 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(selected ? "Selected photo" : "Choose this photo")
                    }
                }
            }
        }
    }

    private var allPhotosFallback: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Text("Choose from all photos…")
                .font(AppFont.sans(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private func shareTheme() {
        guard !sharing else { return }
        sharing = true
        Task {
            var img: UIImage?
            if let id = selectedId ?? currentId {
                img = await PhotoAssetLoader().requestImage(forIdentifier: id, targetSide: 1200)
            }
            shareMiniThemeCard(theme: theme, card: vm.card, heroImage: img)
            sharing = false
        }
    }
}
