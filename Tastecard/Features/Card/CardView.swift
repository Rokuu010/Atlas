//
//  CardView.swift
//  Tastecard
//
//  The identity card — a faithful native port of App.tsx. Header (settings • title •
//  background upload), name + dynamic rarity badge, "the drop" randomiser, the
//  Photos/Themes/Places stats, theme filter chips, the 2-col emergent-themes grid with
//  highlight/dim, the Share CTA, and the footer with the local code. Real data only.
//

import SwiftUI
import UIKit
import PhotosUI

struct CardView: View {
    @ObservedObject var vm: CardViewModel
    @EnvironmentObject private var model: AppModel

    @State private var selectedThemeId: String?
    @State private var sheet: CardSheet?
    @State private var bgPickerItem: PhotosPickerItem?

    private var card: Tastecard { vm.card }

    /// Single enum-driven sheet (avoids the multiple-.sheet-on-one-view pitfall).
    enum CardSheet: Identifiable {
        case detail(EmergentTheme)
        case snapshot
        case settings
        var id: String {
            switch self {
            case .detail(let t): return "detail-\(t.id)"
            case .snapshot: return "snapshot"
            case .settings: return "settings"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 0)
                        cardSurface
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 18)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geo.size.height)
                }
                toastIsland
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .detail(let theme):
                DetailView(theme: theme, vm: vm)
            case .snapshot:
                SnapshotView(card: card,
                             theme: vm.theme,
                             customBackground: vm.customBackground,
                             isBgDark: vm.isBgDark,
                             selectedThemeId: selectedThemeId)
            case .settings:
                SettingsView(vm: vm).environmentObject(model)
            }
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

    // MARK: - Background (whole screen)

    private var background: some View {
        ZStack {
            vm.theme.background
            if let bg = vm.customBackground {
                Image(uiImage: bg).resizable().scaledToFill()
                if let scrim = vm.backgroundScrim { scrim }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - The glass card

    private var cardSurface: some View {
        VStack(spacing: 20) {
            header
            identity
            stats
            chips
            emergentHeader
            grid
            shareButton
            footer
        }
        .padding(22)
        .glassCard(cornerRadius: 40, fill: vm.cardFill, border: vm.cardBorder)
        .foregroundColor(vm.textColor)
    }

    private var header: some View {
        HStack {
            roundIconButton(systemImage: "gearshape") { sheet = .settings }
            Spacer()
            Text("Tastecard")
                .font(AppFont.mono(12, weight: .bold))
                .tracking(3)
                .foregroundColor(vm.textColor.opacity(0.9))
            Spacer()
            PhotosPicker(selection: $bgPickerItem, matching: .images, photoLibrary: .shared()) {
                roundIconLabel(systemImage: "photo")
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(vm.textColor.opacity(0.15)).frame(height: 1)
        }
    }

    private var identity: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(AppFont.display(30, weight: .bold))
                    .foregroundColor(vm.textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Text("TASTECARD RARITY:")
                        .font(AppFont.mono(10))
                        .tracking(0.5)
                        .foregroundColor(vm.textColor.opacity(0.6))
                    RarityBadge(tier: card.cardRarity, fontSize: 12)
                }
            }
            Spacer()
            DropButton(color: vm.textColor) { vm.drop() }
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statCell(value: card.photosAnalysed.abbreviated, label: "Photos")
            statCell(value: "\(card.emergentThemeCount)", label: "emerging themes")
            statCell(value: "\(card.placesCount)", label: "Places")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(vm.textColor.opacity(0.15)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(vm.textColor.opacity(0.15)).frame(height: 1) }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppFont.mono(18, weight: .heavy))
                .foregroundColor(vm.textColor)
            Text(label.uppercased())
                .font(AppFont.sans(9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(vm.textColor.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(card.themes) { theme in
                let isActive = selectedThemeId == theme.categoryId
                Button {
                    Haptics.select()
                    selectedThemeId = isActive ? nil : theme.categoryId
                } label: {
                    Text(theme.displayName)
                        .font(AppFont.sans(12, weight: isActive ? .bold : .regular))
                        .foregroundColor(vm.textColor)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .glassPill(cornerRadius: 999,
                                   fill: .white.opacity(isActive ? 0.35 : 0.10),
                                   border: .white.opacity(isActive ? 0.50 : 0.15))
                        .scaleEffect(isActive ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 325)
    }

    private var emergentHeader: some View {
        Text("Emergent Themes")
            .font(AppFont.mono(13, weight: .bold))
            .tracking(3)
            .foregroundColor(vm.textColor.opacity(0.9))
            .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(card.themes) { theme in
                let highlighted = selectedThemeId == nil || selectedThemeId == theme.categoryId
                ThemeGridCard(theme: theme, highlighted: highlighted)
                    .onTapGesture { Haptics.tap(); sheet = .detail(theme) }
            }
        }
    }

    private var shareButton: some View {
        Button {
            Haptics.tap(); sheet = .snapshot
        } label: {
            Text("Share Tastecard".uppercased())
                .font(AppFont.sans(12, weight: .black))
                .tracking(2)
                .foregroundColor(vm.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassPill(cornerRadius: 16, fill: .white.opacity(0.15), border: .white.opacity(0.35))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Text("\(card.displayName) • \(card.serialDisplay)".uppercased())
            .font(AppFont.mono(10))
            .tracking(2)
            .foregroundColor(vm.textColor.opacity(0.4))
            .frame(maxWidth: .infinity)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    // MARK: - Toast

    @ViewBuilder private var toastIsland: some View {
        if let toast = vm.toast {
            VStack {
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: 0xF59E0B)).frame(width: 6, height: 6)
                    Text(toast)
                        .font(AppFont.sans(12, weight: .medium))
                        .foregroundColor(.white)
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

    // MARK: - Buttons

    private func roundIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) { roundIconLabel(systemImage: systemImage) }
            .buttonStyle(.plain)
    }

    private func roundIconLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(vm.textColor)
            .frame(width: 36, height: 36)
            .background(Circle().fill(vm.textColor.opacity(0.10)))
    }
}

/// One photo tile in the emergent-themes grid.
struct ThemeGridCard: View {
    let theme: EmergentTheme
    let highlighted: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssetImage(assetId: theme.heroPhotoLocalId,
                       fallbackName: HeroPhotoPicker.fallbackImageName(forCategoryId: theme.categoryId),
                       targetSide: 500)
            PhotoVignette()
            Text(theme.displayName)
                .font(AppFont.sans(12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(12)
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.black.opacity(0.05)))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .opacity(highlighted ? 1 : 0.35)
        .scaleEffect(highlighted ? 1 : 0.95)
        .blur(radius: highlighted ? 0 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: highlighted)
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
