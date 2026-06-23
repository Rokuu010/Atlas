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

/**
 * Lightweight per-category summary saved for EVERY found category that reached the
 * per-category photo floor — not just the 3–6 displayed. Powers the "rarest find" insight
 * and future cross-user category comparison. Derived, non-identifying data only.
 */
data class CategoryStat(
    val categoryId: String,
    val displayName: String,
    val photoCount: Int,
    val rarityIndex: Double,
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
    /** Top matching photos for this category (content URIs, best-first) for "change photo". */
    val candidatePhotoUris: List<String> = emptyList(),
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
    /** Every found category (>= the photo floor), including ones too small to display.
     *  Saved for the rarest-find insight + future cross-user comparison. */
    val allCategories: List<CategoryStat> = emptyList(),
    // Appearance + profile (mirrors iOS). All optional/backward-compatible.
    var aboutMe: String? = null,
    var profileImagePath: String? = null,        // local file path of the profile picture
    var customBackgroundPath: String? = null,    // local file path of a custom background photo
    var customBackgroundColorArgb: Long? = null, // packed 0xFFRRGGBB solid background colour
    var glassOpacity: Double? = null,            // 0..1 glass tint multiplier (1.0 default)
) {
    /** The serial as displayed (e.g. "#A7F3"). */
    val serialDisplay: String get() = id

    /** Glass tint multiplier with a safe default for cards saved before this field. */
    val glassTintMultiplier: Double get() = glassOpacity ?: 1.0

    /** The card headline: "<name>'s Tastecard"; the default name is shown as-is. */
    val cardTitle: String get() = title(displayName)

    /** Highest-rarity found category (even if too small to be an emergent theme). */
    val rarestCategory: CategoryStat? get() = allCategories.maxByOrNull { it.rarityIndex }

    companion object {
        private val ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ"

        /** Local, per-device short code (§11 decision b) — e.g. "#A7F3". Not a global serial. */
        fun makeLocalCode(): String = "#" + (1..4).map { ALPHABET.random() }.joinToString("")

        /** Possessive card title for a name. Exposed so Settings can preview it live. */
        fun title(name: String): String {
            val trimmed = name.trim()
            // Treat both the new and old default as "no custom name" so older saved cards
            // don't render as "My Tastecard's Rollcard".
            if (trimmed.isEmpty() ||
                trimmed.equals("My Rollcard", ignoreCase = true) ||
                trimmed.equals("My Tastecard", ignoreCase = true)
            ) return "My Rollcard"
            val suffix = if (trimmed.lowercase().endsWith("s")) "'" else "'s"
            return "$trimmed$suffix Rollcard"
        }

        fun assemble(
            displayName: String,
            themeIndex: Int,
            heroPhotoUri: String?,
            photosAnalysed: Int,
            placesCount: Int,
            themes: List<EmergentTheme>,
            allCategories: List<CategoryStat> = emptyList(),
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
            allCategories = allCategories,
        )
    }
}
