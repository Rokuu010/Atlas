package io.tastecard.engine

import kotlin.math.ceil

/**
 * Emergent-theme selection (§4) — a faithful Kotlin port of the iOS ThemeSelector,
 * including the recalibrated evidence floor and the large-library fallback.
 *
 *   count: photos that cleared this category's threshold (multi-label)
 *   score: strength = sum of margins (similarity - threshold), for ranking
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
    val guaranteedTopSlots: Int = 3,
    val floorBase: Int = 3,
    val floorPerThousand: Double = 3.0,
    val relativeFallbackMinPhotos: Int = 400,
) {
    fun evidenceFloor(librarySize: Int): Int {
        val scaled = ceil(librarySize / 1000.0 * floorPerThousand).toInt()
        return maxOf(floorBase, scaled)
    }
}

object ThemeSelector {
    fun select(
        tallies: List<CategoryTally>,
        photosAnalysed: Int,
        config: SelectionConfig = SelectionConfig(),
    ): SelectionOutcome {
        if (photosAnalysed < config.globalMinimumPhotos) {
            return SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_PHOTOS)
        }

        val floor = config.evidenceFloor(photosAnalysed)

        val ranked = tallies
            .filter { it.count > 0 }
            .sortedWith(
                compareByDescending<CategoryTally> { it.score }
                    .thenByDescending { it.count }
                    .thenBy { it.categoryId }
            )

        val clearedCount = ranked.count { it.count >= floor }

        // Primary path: enough categories clear the evidence floor.
        if (clearedCount >= config.minThemes) {
            val selected = mutableListOf<CategoryTally>()
            for ((rank, candidate) in ranked.withIndex()) {
                if (selected.size >= config.maxThemes) break
                val guaranteedByStrength = rank < config.guaranteedTopSlots
                if (candidate.count >= floor || guaranteedByStrength) {
                    selected.add(candidate)
                }
            }
            return SelectionOutcome.Themes(selected)
        }

        // Safety net: a non-sparse library should never be left with nothing.
        if (photosAnalysed >= config.relativeFallbackMinPhotos && ranked.size >= config.minThemes) {
            return SelectionOutcome.Themes(ranked.take(config.maxThemes))
        }

        return SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE)
    }
}
