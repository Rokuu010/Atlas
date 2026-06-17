package io.tastecard

import io.tastecard.engine.CategoryTally
import io.tastecard.engine.SelectionConfig
import io.tastecard.engine.SelectionOutcome
import io.tastecard.engine.ThemeSelector
import io.tastecard.engine.WarmingReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ThemeSelectorTest {
    private fun t(id: String, count: Int, score: Double) = CategoryTally(id, count, score)

    private fun ids(o: SelectionOutcome): List<String> =
        (o as SelectionOutcome.Themes).themes.map { it.categoryId }

    @Test fun belowGlobalMinimumWarmsUp() {
        val o = ThemeSelector.select(listOf(t("a", 5, 5.0)), photosAnalysed = 10)
        assertEquals(SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_PHOTOS), o)
    }

    @Test fun fewerThanThreeClearedWarmsUp() {
        val tallies = listOf(t("a", 8, 8.0), t("b", 4, 4.0), t("c", 2, 2.0))
        assertEquals(
            SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE),
            ThemeSelector.select(tallies, photosAnalysed = 100)
        )
    }

    @Test fun selectsRankedByScore() {
        val tallies = listOf(t("low", 10, 1.0), t("high", 10, 9.0), t("mid", 10, 5.0), t("mid2", 10, 4.0))
        assertEquals(listOf("high", "mid", "mid2", "low"), ids(ThemeSelector.select(tallies, 100)))
    }

    @Test fun capsAtSix() {
        val tallies = (0 until 10).map { t("c$it", 10, (10 - it).toDouble()) }
        val sel = ids(ThemeSelector.select(tallies, 100))
        assertEquals(6, sel.size)
        assertEquals(listOf("c0", "c1", "c2", "c3", "c4", "c5"), sel)
    }

    @Test fun evidenceFloorScales() {
        val c = SelectionConfig()
        assertEquals(3, c.evidenceFloor(100))
        assertEquals(3, c.evidenceFloor(1000))
        assertEquals(6, c.evidenceFloor(2000))
        assertEquals(9, c.evidenceFloor(3000))
    }

    @Test fun largeLibraryFallsBack() {
        val tallies = listOf(t("a", 5, 5.0), t("b", 4, 4.0), t("c", 3, 3.0), t("d", 2, 2.0))
        assertEquals(listOf("a", "b", "c", "d"), ids(ThemeSelector.select(tallies, 2000)))
    }

    @Test fun largeLibraryTooFewCategoriesWarmsUp() {
        val tallies = listOf(t("a", 50, 50.0), t("b", 30, 30.0))
        assertEquals(
            SelectionOutcome.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE),
            ThemeSelector.select(tallies, 2000)
        )
    }

    @Test fun topThreeByStrengthFillsSlotUnderFloor() {
        val tallies = listOf(t("d", 5, 100.0), t("a", 30, 30.0), t("b", 20, 20.0), t("c", 15, 15.0))
        val sel = ids(ThemeSelector.select(tallies, 2000))
        assertEquals("d", sel.first())
        assertTrue(sel.toSet() == setOf("d", "a", "b", "c"))
    }
}
