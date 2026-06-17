package io.tastecard

import io.tastecard.engine.GeoClustering
import io.tastecard.model.Rarity
import io.tastecard.model.RarityTier
import io.tastecard.security.InputSanitizer
import org.junit.Assert.assertEquals
import org.junit.Test

class RarityTest {
    @Test fun bands() {
        assertEquals(RarityTier.COMMON, Rarity.tier(0.0))
        assertEquals(RarityTier.COMMON, Rarity.tier(0.32))
        assertEquals(RarityTier.RARE, Rarity.tier(0.33))
        assertEquals(RarityTier.EPIC, Rarity.tier(0.60))
        assertEquals(RarityTier.LEGENDARY, Rarity.tier(0.80))
    }

    @Test fun aggregation() {
        assertEquals(RarityTier.LEGENDARY, Rarity.cardRarity(listOf(RarityTier.EPIC, RarityTier.EPIC, RarityTier.LEGENDARY)))
        assertEquals(RarityTier.EPIC, Rarity.cardRarity(listOf(RarityTier.EPIC, RarityTier.EPIC, RarityTier.RARE)))
        assertEquals(RarityTier.RARE, Rarity.cardRarity(listOf(RarityTier.EPIC, RarityTier.COMMON, RarityTier.COMMON)))
        assertEquals(RarityTier.RARE, Rarity.cardRarity(listOf(RarityTier.RARE, RarityTier.RARE, RarityTier.RARE)))
        assertEquals(RarityTier.COMMON, Rarity.cardRarity(listOf(RarityTier.RARE, RarityTier.RARE, RarityTier.COMMON)))
    }
}

class GeoClusteringTest {
    private fun c(lat: Double, lon: Double) = GeoClustering.Coordinate(lat, lon)

    @Test fun emptyIsZero() = assertEquals(0, GeoClustering.placesCount(emptyList()))

    @Test fun nearbyCollapse() {
        assertEquals(1, GeoClustering.placesCount(listOf(c(51.5074, -0.1278), c(51.5155, -0.0922))))
    }

    @Test fun distantSeparate() {
        assertEquals(3, GeoClustering.placesCount(listOf(c(51.5074, -0.1278), c(48.8566, 2.3522), c(35.6762, 139.6503))))
    }

    @Test fun orderIndependent() {
        val pts = listOf(c(51.5074, -0.1278), c(48.8566, 2.3522), c(51.5155, -0.0922), c(48.8606, 2.3376))
        assertEquals(2, GeoClustering.placesCount(pts))
        assertEquals(2, GeoClustering.placesCount(pts.reversed()))
    }
}

class InputSanitizerTest {
    @Test fun trimsAndCollapses() {
        assertEquals("Lina the Great", InputSanitizer.displayName("   Lina   the   Great  "))
    }

    @Test fun capsLength() {
        assertEquals(InputSanitizer.MAX_DISPLAY_NAME_LENGTH, InputSanitizer.displayName("a".repeat(100)).length)
    }

    @Test fun stripsControlAndZeroWidth() {
        // zero-width space, bell, RTL override - all ASCII escapes in source.
        assertEquals("Lina", InputSanitizer.displayName("Li\u200Bna\u202E"))
    }

    @Test fun emptyFallsBack() {
        assertEquals("My Tastecard", InputSanitizer.displayNameOrDefault("   \u200B "))
    }

    @Test fun filenameSlug() {
        assertEquals("lina_s_tastecard", InputSanitizer.filenameSlug("Lina's Tastecard!"))
        assertEquals("tastecard", InputSanitizer.filenameSlug("   "))
    }
}
