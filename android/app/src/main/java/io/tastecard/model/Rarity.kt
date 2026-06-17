package io.tastecard.model

/** Rarity bands + card aggregation (§6) — ported from the iOS Rarity module. */
enum class RarityTier(val displayName: String) {
    COMMON("common"),
    RARE("rare"),
    EPIC("epic"),
    LEGENDARY("legendary");

    val rank: Int get() = ordinal
}

object Rarity {
    /** common [0,0.33) · rare [0.33,0.60) · epic [0.60,0.80) · legendary [0.80,1.0] */
    fun tier(index: Double): RarityTier = when {
        index < 0.33 -> RarityTier.COMMON
        index < 0.60 -> RarityTier.RARE
        index < 0.80 -> RarityTier.EPIC
        else -> RarityTier.LEGENDARY
    }

    /**
     * legendary if >=3 high-rarity (epic+) themes; epic if >=2; rare if >=1 high OR >=3
     * rare+ themes; common otherwise.
     */
    fun cardRarity(tiers: List<RarityTier>): RarityTier {
        val high = tiers.count { it.rank >= RarityTier.EPIC.rank }
        val mid = tiers.count { it.rank >= RarityTier.RARE.rank }
        return when {
            high >= 3 -> RarityTier.LEGENDARY
            high >= 2 -> RarityTier.EPIC
            high >= 1 || mid >= 3 -> RarityTier.RARE
            else -> RarityTier.COMMON
        }
    }
}
