package io.tastecard.engine

/**
 * Emergent-theme selection (§4) — a faithful Kotlin port of the iOS ThemeSelector.
 *
 *   count: photos that cleared this category's threshold (multi-label)
 *   score: strength = sum of margins (similarity - threshold), for ranking
 *
 * A category only "exists" once detected in at least [SelectionConfig.minPhotosPerCategory]
 * photos. select() returns EVERY qualifying category (most-photos-first); the engine displays
 * the strongest 3–6 and saves the rest as the shadow set.
 */
data class CategoryTally(val categoryId: String, val count: Int, val score: Double)

enum class WarmingReason { NOT_ENOUGH_PHOTOS, NOT_ENOUGH_EVIDENCE }

sealed interface SelectionOutcome {
    data class Themes(val themes: List<CategoryTally>) : SelectionOutcome
    data class WarmingUp(val reason: WarmingReason) : SelectionOutcome
}

data class SelectionConfig(
    val globalMinimumPhotos: Int = 50,
    val minThemes: Int = 3,
    val maxThemes: Int = 6,
    // User spec: a category needs 10 photos to count (both displayed + shadow).
    val minPhotosPerCategory: Int = 10,
)

object ThemeSelector {
    fun select(
        tallies: List<CategoryTally>,
        photosAnalysed: Int,
        config: SelectionConfig = SelectionConfig(),
    ): SelectionOutcome {
        if (photosAnalysed < config.globalMinimumPhotos) {
            return SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_PHOTOS)
        }

        // Rank EVERY matched category, most-photos-first. The card is built from your strongest
        // categories; the per-category photo floor governs only the saved shadow set, so a normal
        // roll is never left with nothing.
        val ranked = tallies
            .filter { it.count > 0 }
            .sortedWith(
                compareByDescending<CategoryTally> { it.count }
                    .thenByDescending { it.score }
                    .thenBy { it.categoryId }
            )

        return if (ranked.size >= config.minThemes) {
            SelectionOutcome.Themes(ranked)
        } else {
            SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE)
        }
    }
}
