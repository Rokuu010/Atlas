//
//  Tastecard.swift
//  Tastecard
//
//  The production data model (§5), replacing the web mockup's CreatorProfile/MediaItem.
//  Persisted locally as derived, non-identifying data only (§5, §8): theme ids, counts,
//  and opaque PHAsset local identifiers — never pixels, never raw coordinates.
//

import Foundation

struct Tastecard: Codable, Equatable {
    /// Local, per-device short code (§11 decision b) — e.g. "#A7F3". NOT a global serial.
    let id: String
    /// User-editable, sanitised at the edge (see InputSanitizer).
    var displayName: String
    /// Index into AppTheme.all; "the drop" randomises it.
    var themeIndex: Int
    /// Filename of a user-chosen background stored in the app sandbox (local only), or nil.
    var customBackgroundFilename: String?
    /// Auto-picked card hero (opaque PHAsset local id), user-swappable.
    var heroPhotoLocalId: String?

    let photosAnalysed: Int
    let emergentThemeCount: Int
    /// From EXIF GPS clusters — coarse counts only, never raw coordinates.
    let placesCount: Int

    var cardRarity: RarityTier
    /// Length 3–6 (enforced by ThemeSelector).
    var themes: [EmergentTheme]
    let createdAt: Date

    /// The serial as displayed (e.g. "#A7F3").
    var serialDisplay: String { id }
}

extension Tastecard {
    /// Generates a short, local, non-global card code like "#A7F3".
    /// Crockford-style alphabet (no ambiguous 0/O, 1/I) for legibility.
    static func makeLocalCode() -> String {
        let alphabet = Array("23456789ABCDEFGHJKMNPQRSTVWXYZ")
        let code = (0..<4).map { _ in alphabet.randomElement()! }
        return "#" + String(code)
    }

    /// Assembles a finished card from the engine's selected themes + tallies.
    init(displayName: String,
         themeIndex: Int,
         heroPhotoLocalId: String?,
         photosAnalysed: Int,
         placesCount: Int,
         themes: [EmergentTheme],
         id: String = Tastecard.makeLocalCode(),
         createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.themeIndex = themeIndex
        self.customBackgroundFilename = nil
        self.heroPhotoLocalId = heroPhotoLocalId
        self.photosAnalysed = photosAnalysed
        self.emergentThemeCount = themes.count
        self.placesCount = placesCount
        self.cardRarity = Rarity.cardRarity(from: themes.map(\.rarityTier))
        self.themes = themes
        self.createdAt = createdAt
    }
}
