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
    @Published var profileImage: UIImage?
    @Published var toast: String?

    private let store: TastecardStore
    private let imageStore = LocalImageStore()
    private var toastTask: Task<Void, Never>?

    private let lightInk = Color(hex: 0xFDF9F6)
    private let darkInk = Color(hex: 0x0C1519)

    init(card: Tastecard, store: TastecardStore) {
        self.card = card
        self.store = store
        if let filename = card.customBackgroundFilename, let image = imageStore.load(filename) {
            self.customBackground = image
            self.isBgDark = Brightness.isDark(image)
        }
        if let filename = card.profileImageFilename, let image = imageStore.load(filename) {
            self.profileImage = image
        }
    }

    var theme: AppTheme { AppTheme.theme(at: card.themeIndex) }

    /// User-chosen solid background colour (from the colour wheel), or nil.
    var customColor: Color? {
        card.customBackgroundColorHex.map { Color(hex: $0) }
    }

    /// The flat colour shown behind the card: custom colour, else the theme background.
    var backgroundColor: Color { customColor ?? theme.background }

    /// Glass tint strength (0...1) from the opacity slider; 1.0 for older cards.
    var glassOpacity: Double { card.glassTintMultiplier }

    // Adaptive foreground + glass. Photo background -> brightness of the photo; solid
    // custom colour -> brightness of the colour; otherwise the theme's own ink.
    var textColor: Color {
        if customBackground != nil { return isBgDark ? lightInk : darkInk }
        if let c = customColor { return Brightness.isDark(c) ? lightInk : darkInk }
        return theme.text
    }

    // Tint over the blurred PHOTO (true glassmorphism), scaled by the opacity slider.
    // Opacity is applied once on a fully-opaque base so it's exact (no chained .opacity).
    var cardFill: Color {
        guard customBackground != nil else { return materialGlassFill }
        let base = isBgDark ? 0.12 : 0.10
        return (isBgDark ? Color.black : Color.white).opacity(base * glassOpacity)
    }

    // Tint over the Material when there's no photo (preset theme OR solid custom colour).
    var materialGlassFill: Color {
        if let c = customColor {
            let dark = Brightness.isDark(c)
            return (dark ? Color.white : Color.black).opacity((dark ? 0.16 : 0.06) * glassOpacity)
        }
        return theme.glassTint.opacity(theme.glassTintOpacity * glassOpacity)
    }

    var cardBorder: Color {
        if customBackground != nil { return isBgDark ? Color.white.opacity(0.18) : Color.white.opacity(0.30) }
        if let c = customColor { return Brightness.isDark(c) ? Color.white.opacity(0.22) : Color.black.opacity(0.12) }
        return theme.glassBorder
    }
    // Only a whisper of scrim so the background photo stays visible behind the glass.
    var backgroundScrim: Color? {
        guard customBackground != nil else { return nil }
        return isBgDark ? Color.black.opacity(0.12) : Color.white.opacity(0.04)
    }

    // MARK: - The drop

    func drop() {
        // Shuffling implies the curated palettes, so drop any solid custom colour override.
        card.customBackgroundColorHex = nil
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

    // MARK: - About me

    func setAboutMe(_ raw: String) {
        let cleaned = InputSanitizer.aboutMe(raw)
        let new = cleaned.isEmpty ? nil : cleaned
        guard new != card.aboutMe else { return }
        card.aboutMe = new
        persist()
    }

    // MARK: - Appearance (colour wheel, glass opacity)

    func setCustomColor(_ color: Color) {
        guard let hex = color.rgbHex else { return }
        // A solid colour and a photo background are mutually exclusive.
        if let old = card.customBackgroundFilename { imageStore.delete(old) }
        card.customBackgroundFilename = nil
        customBackground = nil
        isBgDark = false
        card.customBackgroundColorHex = hex
        persist()
    }

    func clearCustomColor() {
        guard card.customBackgroundColorHex != nil else { return }
        card.customBackgroundColorHex = nil
        persist()
    }

    func setGlassOpacity(_ value: Double) {
        let clamped = max(0.0, min(1.0, value))
        guard clamped != card.glassTintMultiplier else { return }
        card.glassOpacity = clamped
        persist()
    }

    /// Resets all appearance overrides back to the current preset theme.
    func resetAppearance() {
        if let old = card.customBackgroundFilename { imageStore.delete(old) }
        card.customBackgroundFilename = nil
        card.customBackgroundColorHex = nil
        card.glassOpacity = nil
        customBackground = nil
        isBgDark = false
        persist()
        Haptics.tap()
        showToast("Appearance reset")
    }

    // MARK: - Profile picture

    func setProfileImage(data: Data) {
        do {
            if let old = card.profileImageFilename { imageStore.delete(old) }
            let filename = try imageStore.store(data: data)
            guard let image = imageStore.load(filename) else { return }
            card.profileImageFilename = filename
            profileImage = image
            persist()
            Haptics.tap()
            showToast("Profile photo updated 🙂")
        } catch {
            Haptics.warning()
            showToast((error as? LocalizedError)?.errorDescription ?? "Couldn't use that image")
        }
    }

    func clearProfileImage() {
        if let old = card.profileImageFilename { imageStore.delete(old) }
        card.profileImageFilename = nil
        profileImage = nil
        persist()
    }

    // MARK: - Custom background (photo)

    func setCustomBackground(data: Data) {
        do {
            // Remove any previous file first.
            if let old = card.customBackgroundFilename { imageStore.delete(old) }
            let filename = try imageStore.store(data: data)
            guard let image = imageStore.load(filename) else { return }
            card.customBackgroundFilename = filename
            // A photo background and a solid colour are mutually exclusive.
            card.customBackgroundColorHex = nil
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
