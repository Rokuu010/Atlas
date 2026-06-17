//
//  EmergentTheme.swift
//  Tastecard
//
//  A theme that emerged from the user's gallery (§5). This is display + persistence
//  data only. detectionPrompts deliberately do NOT live here — they are engine-only
//  (held on Category) and must never reach the UI.
//

import Foundation

struct EmergentTheme: Codable, Identifiable, Equatable {
    var id: String { categoryId }

    let categoryId: String          // FK into the bundled category dataset
    let displayName: String         // e.g. "Always on the Run"
    let tagline: String             // revealed in DetailView (progressive disclosure)
    let photoCount: Int             // photos that cleared the threshold for this category
    let rarityIndex: Double         // 0–1, from the category dataset
    let rarityTier: RarityTier
    var heroPhotoLocalId: String?   // auto-picked; user-swappable; nil -> bundled fallback

    init(category: Category, photoCount: Int, heroPhotoLocalId: String?) {
        self.categoryId = category.id
        self.displayName = category.displayName
        self.tagline = category.tagline
        self.photoCount = photoCount
        self.rarityIndex = category.rarityIndex
        self.rarityTier = category.rarityTier
        self.heroPhotoLocalId = heroPhotoLocalId
    }
}
