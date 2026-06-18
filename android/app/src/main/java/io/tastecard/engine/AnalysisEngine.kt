package io.tastecard.engine

import io.tastecard.model.Category
import io.tastecard.model.EmergentTheme
import io.tastecard.model.Tastecard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlin.math.log10

sealed interface EngineResult {
    data class Card(val card: Tastecard) : EngineResult
    data class WarmingUp(val reason: WarmingReason, val scanned: Int) : EngineResult
}

/**
 * Orchestrates the on-device pipeline (§6), mirroring the iOS AnalysisEngine:
 * enumerate -> (cache | downsample+embed+release) -> bias-corrected relative affinity vs
 * precomputed text vectors -> distinctive-match tally -> evidence-floor 3–6 selection (with
 * a relative-ranking safety net) -> rarity -> hero pick -> EXIF Places -> card.
 * Runs off the main thread and is cancellable via coroutine cancellation.
 *
 * Why relative affinity, not absolute cosine: SigLIP image-text cosines are compressed and
 * carry a strong per-prompt prior (some prompts sit "close" to every image). A fixed cutoff
 * therefore either matched nothing ("still warming up") or matched junk. Instead, for each
 * photo we subtract that photo's MEAN affinity across all categories and keep the ones it is
 * distinctively closest to — scale-invariant, bias-free, and naturally multi-label.
 */
class AnalysisEngine(
    private val photos: PhotoRepository,
    private val embedder: OnnxImageEmbedder,
    private val textStore: TextEmbeddingStore,
    private val categories: List<Category>,
    private val cache: EmbeddingCache,
    private val config: SelectionConfig = SelectionConfig(),
    private val defaultDisplayName: String = "My Tastecard",
    // A photo "matches" a category when its affinity exceeds the photo's own mean affinity
    // by at least this margin (bias-corrected, scale-invariant).
    private val relativeMargin: Float = 0.05f,
) {
    private data class Aligned(val category: Category, val vector: FloatArray)
    private data class HeroCandidate(val uri: String, val similarity: Float, val screenshot: Boolean, val pixelCount: Int)

    suspend fun run(onProgress: (Int, Int) -> Unit): EngineResult = withContext(Dispatchers.Default) {
        val metas = photos.queryImages()
        val total = metas.size
        if (total < config.globalMinimumPhotos) {
            return@withContext EngineResult.WarmingUp(WarmingReason.NOT_ENOUGH_PHOTOS, total)
        }

        val aligned = categories.mapNotNull { c ->
            textStore.vector(c.id)?.let { v -> if (v.size == embedder.dimension) Aligned(c, v) else null }
        }
        if (aligned.isEmpty()) {
            return@withContext EngineResult.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE, total)
        }

        // Per-category accumulators.
        val counts = HashMap<String, Int>()        // photos where delta >= relativeMargin
        val scores = HashMap<String, Double>()      // sum of margins for matched photos
        val softScores = HashMap<String, Double>()  // sum of positive delta over ALL photos (ranking net)
        val softCounts = HashMap<String, Int>()     // photos where delta > 0 (prominence)
        val heroes = HashMap<String, MutableList<HeroCandidate>>()
        val coords = ArrayList<GeoClustering.Coordinate>()

        var processed = 0
        val stride = maxOf(1, total / 100)
        val margin = relativeMargin

        for (m in metas) {
            ensureActive()

            var emb = cache.get(m.id)
            if (emb == null) {
                val bmp = photos.loadBitmap(m.uri, embedder.inputSide)
                if (bmp != null) {
                    emb = try { embedder.embed(bmp) } catch (e: Exception) { null }
                    bmp.recycle()
                    if (emb != null) cache.put(m.id, emb)
                }
            }

            processed++
            if (processed % stride == 0 || processed == total) onProgress(processed, total)

            photos.location(m.uri)?.let { coords.add(it) }

            val embedding = emb ?: continue

            // Cosine to every category, then subtract this photo's mean affinity.
            val cosines = FloatArray(aligned.size)
            var sum = 0f
            for (i in aligned.indices) {
                val c = VectorMath.dot(embedding, aligned[i].vector)
                cosines[i] = c
                sum += c
            }
            val mean = sum / aligned.size

            for (i in aligned.indices) {
                val delta = cosines[i] - mean
                if (delta <= 0f) continue
                val cid = aligned[i].category.id

                softScores[cid] = (softScores[cid] ?: 0.0) + delta.toDouble()
                softCounts[cid] = (softCounts[cid] ?: 0) + 1

                // Hero candidate (use raw cosine as the quality/representativeness signal).
                val list = heroes.getOrPut(cid) { mutableListOf() }
                list.add(HeroCandidate(m.uri.toString(), cosines[i], m.isScreenshot, m.pixelCount))
                if (list.size > 60) {
                    list.sortByDescending { heroScore(it) }
                    while (list.size > 40) list.removeAt(list.size - 1)
                }

                if (delta >= margin) {
                    counts[cid] = (counts[cid] ?: 0) + 1
                    scores[cid] = (scores[cid] ?: 0.0) + delta.toDouble()
                }
            }
        }

        cache.flush()
        onProgress(total, total)

        val placesCount = GeoClustering.placesCount(coords)
        val byId = categories.associateBy { it.id }

        // Primary selection from distinctive-match tallies.
        val tallies = aligned.mapNotNull { a ->
            val count = counts[a.category.id] ?: 0
            if (count > 0) CategoryTally(a.category.id, count, scores[a.category.id] ?: 0.0) else null
        }

        when (val outcome = ThemeSelector.select(tallies, processed, config)) {
            is SelectionOutcome.Themes -> {
                val themes = buildThemes(outcome.themes.map { it.categoryId to it.count }, byId, heroes)
                EngineResult.Card(assemble(themes, processed, placesCount))
            }
            is SelectionOutcome.WarmingUp -> when (outcome.reason) {
                WarmingReason.NOT_ENOUGH_PHOTOS ->
                    EngineResult.WarmingUp(WarmingReason.NOT_ENOUGH_PHOTOS, processed)

                // Relative-ranking safety net: a non-sparse library always gets its strongest,
                // most-distinctive themes rather than the "still warming up" dead end.
                WarmingReason.NOT_ENOUGH_EVIDENCE -> {
                    val ranked = aligned
                        .mapNotNull { a -> (softScores[a.category.id] ?: 0.0).let { if (it > 0.0) a.category.id to it else null } }
                        .sortedByDescending { it.second }
                    if (processed < config.relativeFallbackMinPhotos || ranked.size < config.minThemes) {
                        EngineResult.WarmingUp(WarmingReason.NOT_ENOUGH_EVIDENCE, processed)
                    } else {
                        val picks = ranked.take(config.maxThemes).map { it.first to maxOf(softCounts[it.first] ?: 0, 1) }
                        EngineResult.Card(assemble(buildThemes(picks, byId, heroes), processed, placesCount))
                    }
                }
            }
        }
    }

    private fun buildThemes(
        picks: List<Pair<String, Int>>,
        byId: Map<String, Category>,
        heroes: Map<String, MutableList<HeroCandidate>>,
    ): List<EmergentTheme> = picks.mapNotNull { (categoryId, photoCount) ->
        val cat = byId[categoryId] ?: return@mapNotNull null
        val hero = heroes[categoryId]?.maxByOrNull { heroScore(it) }?.uri
        EmergentTheme(cat.id, cat.displayName, cat.tagline, photoCount, cat.rarityIndex, cat.rarityTier, hero)
    }

    private fun assemble(themes: List<EmergentTheme>, processed: Int, places: Int): Tastecard =
        Tastecard.assemble(
            displayName = defaultDisplayName,
            themeIndex = (0 until 16).random(),
            heroPhotoUri = themes.firstOrNull()?.heroPhotoUri,
            photosAnalysed = processed,
            placesCount = places,
            themes = themes,
        )

    private fun heroScore(h: HeroCandidate): Double {
        val screenshotPenalty = if (h.screenshot) 0.5 else 0.0
        val resolutionBonus = minOf(0.1, log10(maxOf(h.pixelCount, 1).toDouble()) / 100.0)
        return h.similarity - screenshotPenalty + resolutionBonus
    }
}
