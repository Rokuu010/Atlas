//
//  EmergentTheme.swift
//  Tastecard
//
//  A theme that emerged from the user's gallery (§5). Display + persistence data only.
//  detectionPrompts deliberately do NOT live here — they are engine-only (held on
//  Category) and must never reach the UI.
//

import Foundation

struct EmergentTheme: Codable, Identifiable, Equatable {
    var id: String { categoryId }

    let categoryId: String          // FK into the bundled category dataset
    let displayName: String         // e.g. "Always on the Run"
    let tagline: String             // revealed in DetailView (progressive disclosure)
    let photoCount: Int             // photos that matched this category
    let rarityIndex: Double         // 0–1, from the category dataset
    let rarityTier: RarityTier
    var heroPhotoLocalId: String?   // auto-picked; user-swappable; nil -> designed placeholder
    /// Top matching photos for this category (opaque PHAsset local ids), best-first.
    /// Powers "change photo" so the user picks from this category's matches, not the
    /// whole library. Pointers only — no pixels, no coordinates.
    var candidatePhotoLocalIds: [String]

    init(category: Category,
         photoCount: Int,
         heroPhotoLocalId: String?,
         candidatePhotoLocalIds: [String] = []) {
        self.categoryId = category.id
        self.displayName = category.displayName
        self.tagline = category.tagline
        self.photoCount = photoCount
        self.rarityIndex = category.rarityIndex
        self.rarityTier = category.rarityTier
        self.heroPhotoLocalId = heroPhotoLocalId
        self.candidatePhotoLocalIds = candidatePhotoLocalIds
    }

    // Migration-safe decoding: cards saved by older builds lack candidatePhotoLocalIds.
    private enum CodingKeys: String, CodingKey {
        case categoryId, displayName, tagline, photoCount, rarityIndex, rarityTier
        case heroPhotoLocalId, candidatePhotoLocalIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryId = try c.decode(String.self, forKey: .categoryId)
        displayName = try c.decode(String.self, forKey: .displayName)
        tagline = try c.decode(String.self, forKey: .tagline)
        photoCount = try c.decode(Int.self, forKey: .photoCount)
        rarityIndex = try c.decode(Double.self, forKey: .rarityIndex)
        rarityTier = try c.decode(RarityTier.self, forKey: .rarityTier)
        heroPhotoLocalId = try c.decodeIfPresent(String.self, forKey: .heroPhotoLocalId)
        candidatePhotoLocalIds = try c.decodeIfPresent([String].self, forKey: .candidatePhotoLocalIds) ?? []
    }
}
