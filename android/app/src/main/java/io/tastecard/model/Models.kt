package io.tastecard.model

/** Bundled dataset row (§6). detectionPrompts are engine-only and never shown. */
data class Category(
    val id: String,
    val displayName: String,
    val tagline: String,
    val detectionPrompts: List<String>,
    val rarityIndex: Double,
    val threshold: Double,
) {
    val rarityTier: RarityTier get() = Rarity.tier(rarityIndex)
}

/** A theme that emerged from the gallery (§5) — display + persistence data only. */
data class EmergentTheme(
    val categoryId: String,
    val displayName: String,
    val tagline: String,
    val photoCount: Int,
    val rarityIndex: Double,
    val rarityTier: RarityTier,
    val heroPhotoUri: String?, // MediaStore content URI string; null -> bundled fallback
)

/** The production card (§5). Derived, non-identifying data only. */
data class Tastecard(
    val id: String,
    var displayName: String,
    var themeIndex: Int,
    var heroPhotoUri: String?,
    val photosAnalysed: Int,
    val emergentThemeCount: Int,
    val placesCount: Int,
    var cardRarity: RarityTier,
    val themes: List<EmergentTheme>,
    val createdAt: Long,
) {
    companion object {
        private val ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ"

        /** Local, per-device short code (§11 decision b) — e.g. "#A7F3". Not a global serial. */
        fun makeLocalCode(): String = "#" + (1..4).map { ALPHABET.random() }.joinToString("")

        fun assemble(
            displayName: String,
            themeIndex: Int,
            heroPhotoUri: String?,
            photosAnalysed: Int,
            placesCount: Int,
            themes: List<EmergentTheme>,
        ): Tastecard = Tastecard(
            id = makeLocalCode(),
            displayName = displayName,
            themeIndex = themeIndex,
            heroPhotoUri = heroPhotoUri,
            photosAnalysed = photosAnalysed,
            emergentThemeCount = themes.size,
            placesCount = placesCount,
            cardRarity = Rarity.cardRarity(themes.map { it.rarityTier }),
            themes = themes,
            createdAt = System.currentTimeMillis(),
        )
    }
}
