//
//  CardViewModel.swift
//  Tastecard
//
//  Owns the live, editable card once analysis is done: "the drop" theme randomiser,
//  display-name editing (sanitised), custom background (validated + brightness-adapted),
//  and per-theme hero swapping. Persists every change via TastecardStore.
//

import SwiftUI
import UIKit

@MainActor
final class CardViewModel: ObservableObject {

    @Published var card: Tastecard
    @Published var customBackground: UIImage?
    @Published var isBgDark: Bool = false
    @Published var toast: String?

    private let store: TastecardStore
    private let imageStore = LocalImageStore()
    private var toastTask: Task<Void, Never>?

    init(card: Tastecard, store: TastecardStore) {
        self.card = card
        self.store = store
        if let filename = card.customBackgroundFilename, let image = imageStore.load(filename) {
            self.customBackground = image
            self.isBgDark = Brightness.isDark(image)
        }
    }

    var theme: AppTheme { AppTheme.theme(at: card.themeIndex) }

    // Adaptive foreground + glass, matching App.tsx exactly.
    var textColor: Color {
        customBackground != nil ? (isBgDark ? Color(hex: 0xFDF9F6) : Color(hex: 0x0C1519)) : theme.text
    }
    // With a custom background we want true glassmorphism — the blurred photo visible
    // THROUGH the card — so the tint over the .ultraThinMaterial is kept light.
    var cardFill: Color {
        guard customBackground != nil else { return theme.glassFill }
        return isBgDark ? Color.black.opacity(0.12) : Color.white.opacity(0.10)
    }
    var cardBorder: Color {
        guard customBackground != nil else { return theme.glassBorder }
        return isBgDark ? Color.white.opacity(0.18) : Color.white.opacity(0.30)
    }
    // Only a whisper of scrim so the background photo stays visible behind the glass.
    var backgroundScrim: Color? {
        guard customBackground != nil else { return nil }
        return isBgDark ? Color.black.opacity(0.12) : Color.white.opacity(0.04)
    }

    // MARK: - The drop

    func drop() {
        card.themeIndex = AppTheme.nextDropIndex(current: card.themeIndex)
        persist()
        Haptics.select()
        showToast("Theme: \(theme.name)")
    }

    // MARK: - Display name

    func rename(_ raw: String) {
        let cleaned = InputSanitizer.displayNameOrDefault(raw)
        guard cleaned != card.displayName else { return }
        card.displayName = cleaned
        persist()
    }

    // MARK: - Custom background

    func setCustomBackground(data: Data) {
        do {
            // Remove any previous file first.
            if let old = card.customBackgroundFilename { imageStore.delete(old) }
            let filename = try imageStore.store(data: data)
            guard let image = imageStore.load(filename) else { return }
            card.customBackgroundFilename = filename
            customBackground = image
            isBgDark = Brightness.isDark(image)
            persist()
            Haptics.tap()
            showToast("Background updated 🌌")
        } catch {
            Haptics.warning()
            showToast((error as? LocalizedError)?.errorDescription ?? "Couldn't use that image")
        }
    }

    func clearCustomBackground() {
        if let old = card.customBackgroundFilename { imageStore.delete(old) }
        card.customBackgroundFilename = nil
        customBackground = nil
        isBgDark = false
        persist()
        showToast("Background reset")
    }

    // MARK: - Hero swap (DetailView "change photo")

    func swapHero(themeId: String, toAssetId assetId: String) {
        guard let idx = card.themes.firstIndex(where: { $0.id == themeId }) else { return }
        card.themes[idx].heroPhotoLocalId = assetId
        if idx == 0 { card.heroPhotoLocalId = assetId }
        persist()
        Haptics.tap()
        showToast("Photo updated 🎨")
    }

    // MARK: - Helpers

    private func persist() { store.save(card) }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}
