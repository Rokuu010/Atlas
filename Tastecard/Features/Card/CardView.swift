//
//  CardView.swift
//  Tastecard
//
//  The results screen after a scan — "My Gallery's Top Themes". A full-bleed hero photo
//  under a dark glassmatic scrim, a back · title · EDIT header, the rarity line, a 2-column
//  grid of rarity-outlined theme cards, and the Share CTA. Recreated from the provided
//  grid-view reference. Profile/about/appearance live behind EDIT (Settings); tapping a
//  card opens its detail. Real data only.
//

import SwiftUI
import UIKit
import PhotosUI

struct CardView: View {
    @ObservedObject var vm: CardViewModel
    @EnvironmentObject private var model: AppModel

    @State private var sheet: CardSheet?

    private var card: Tastecard { vm.card }

    /// Single enum-driven sheet (avoids the multiple-.sheet-on-one-view pitfall).
    enum CardSheet: Identifiable {
        case detail(EmergentTheme)
        case snapshot
        case settings
        case appearance
        var id: String {
            switch self {
            case .detail(let t): return "detail-\(t.id)"
            case .snapshot: return "snapshot"
            case .settings: return "settings"
            case .appearance: return "appearance"
            }
        }
    }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    titleBlock
                        .padding(.top, 26)
                        .padding(.bottom, 22)
                    grid
                        .padding(.horizontal, 20)
                    shareButton
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                }
            }
            toastIsland
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .detail(let theme):
                DetailView(theme: theme, vm: vm)
            case .snapshot:
                SnapshotView(card: card,
                             theme: vm.theme,
                             backgroundColor: vm.backgroundColor,
                             customBackground: vm.customBackground,
                             isBgDark: vm.isBgDark,
                             glassOpacity: vm.glassOpacity,
                             profileImage: vm.profileImage,
                             selectedThemeId: nil)
            case .settings:
                SettingsView(vm: vm).environmentObject(model)
            case .appearance:
                AppearanceSheet(vm: vm)
            }
        }
    }

    // MARK: - Background (full-bleed hero photo + dark scrim)

    private var background: some View {
        ZStack {
            Color.black
            if let bg = vm.customBackground {
                GeometryReader { g in
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: g.size.width, height: g.size.height)
                        .clipped()
                }
            } else {
                AssetImage(assetId: card.heroPhotoLocalId,
                           categoryId: card.themes.first?.categoryId,
                           targetSide: 1200)
            }
            // Glassmatic darkening so the white UI reads over any photo.
            Color.black.opacity(0.62)
            LinearGradient(colors: [.black.opacity(0.45), .clear, .black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header (back · title · edit)

    private var header: some View {
        ZStack {
            Text(card.cardTitle.uppercased())
                .font(AppFont.display(18, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 56)

            HStack {
                Button {
                    Haptics.tap(); model.phase = .greeting
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.06)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()

                Button {
                    Haptics.tap(); sheet = .settings
                } label: {
                    Text("EDIT")
                        .font(AppFont.mono(10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit Tastecard")
            }
        }
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("My Gallery's Top Themes".uppercased())
                .font(AppFont.display(14, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text("TASTECARD RARITY:")
                    .font(AppFont.mono(10))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                Text(card.cardRarity.displayName.uppercased())
                    .font(AppFont.mono(10, weight: .black))
                    .tracking(1)
                    .foregroundStyle(RarityStyle.solid(for: card.cardRarity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            ForEach(card.themes) { theme in
                Button {
                    Haptics.tap(); sheet = .detail(theme)
                } label: {
                    GridThemeCard(theme: theme)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Share

    private var shareButton: some View {
        Button {
            Haptics.tap(); sheet = .snapshot
        } label: {
            Text("✨ Share Tastecard".uppercased())
                .font(AppFont.sans(13, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().fill(.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toast

    @ViewBuilder private var toastIsland: some View {
        if let toast = vm.toast {
            VStack {
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: 0xF59E0B)).frame(width: 6, height: 6)
                    Text(toast)
                        .font(AppFont.sans(12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Capsule().fill(Color(hex: 0x0C1519).opacity(0.95)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                Spacer()
            }
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.toast)
        }
    }
}

/// One rarity-outlined theme card in the grid: title + rarity sub-label over a square hero.
struct GridThemeCard: View {
    let theme: EmergentTheme

    var body: some View {
        let accent = RarityStyle.solid(for: theme.rarityTier)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.displayName.uppercased())
                    .font(AppFont.display(12, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("RARITY: \(theme.rarityTier.displayName.uppercased())")
                    .font(AppFont.mono(8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                AssetImage(assetId: theme.heroPhotoLocalId,
                           categoryId: theme.categoryId,
                           targetSide: 600)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.06)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.40)))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(accent.opacity(0.30), lineWidth: 1))
    }
}

extension Int {
    /// "2.3K" style abbreviation matching the mockup (one decimal under 10k).
    var abbreviated: String {
        if self >= 1000 {
            let v = Double(self) / 1000.0
            return v < 10 ? String(format: "%.1fK", v) : String(format: "%.0fK", v)
        }
        return "\(self)"
    }
}

/// Circular profile avatar — the user's photo, else a neutral person glyph on a tinted disc.
struct ProfileAvatar: View {
    let image: UIImage?
    let ink: Color
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(ink.opacity(0.12))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(ink.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ink.opacity(0.25), lineWidth: 1))
    }
}

/// The Appearance menu: a colour wheel, a photo background, a glass-opacity slider, the
/// preset "Shuffle palette", and a reset. Reached from EDIT → Settings.
struct AppearanceSheet: View {
    @ObservedObject var vm: CardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bgPickerItem: PhotosPickerItem?

    private var colorBinding: Binding<Color> {
        Binding(
            get: { vm.customColor ?? vm.theme.background },
            set: { vm.setCustomColor($0) }
        )
    }
    private var opacityBinding: Binding<Double> {
        Binding(get: { vm.glassOpacity }, set: { vm.setGlassOpacity($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Background") {
                    ColorPicker("Background colour", selection: colorBinding, supportsOpacity: false)
                    PhotosPicker(selection: $bgPickerItem, matching: .images, photoLibrary: .shared()) {
                        Label("Choose a background photo", systemImage: "photo")
                    }
                    if vm.customBackground != nil {
                        Button("Remove background photo", role: .destructive) { vm.clearCustomBackground() }
                    }
                    Button { vm.drop() } label: {
                        Label("Shuffle palette", systemImage: "shuffle")
                    }
                }

                Section("Glass") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Card opacity").font(.subheadline)
                        Slider(value: opacityBinding, in: 0.0...1.0)
                        Text("Lower is more see-through; higher is more frosted.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Reset appearance", role: .destructive) { vm.resetAppearance() }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: bgPickerItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        vm.setCustomBackground(data: data)
                    }
                    bgPickerItem = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
