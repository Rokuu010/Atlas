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
 * enumerate -> (cache | downsample+embed+release) -> cosine vs precomputed text vectors
 * -> threshold tally -> 3–6 selection -> rarity -> hero pick -> EXIF Places -> card.
 * Runs off the main thread and is cancellable via coroutine cancellation.
 */
class AnalysisEngine(
    private val photos: PhotoRepository,
    private val embedder: OnnxImageEmbedder,
    private val textStore: TextEmbeddingStore,
    private val categories: List<Category>,
    private val cache: EmbeddingCache,
    private val config: SelectionConfig = SelectionConfig(),
    private val defaultDisplayName: String = "My Tastecard",
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

        val counts = HashMap<String, Int>()
        val scores = HashMap<String, Double>()
        val heroes = HashMap<String, MutableList<HeroCandidate>>()
        val coords = ArrayList<GeoClustering.Coordinate>()

        var processed = 0
        val stride = maxOf(1, total / 100)

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
            for (a in aligned) {
                val sim = VectorMath.dot(embedding, a.vector)
                val threshold = a.category.threshold.toFloat()
                if (sim >= threshold) {
                    counts[a.category.id] = (counts[a.category.id] ?: 0) + 1
                    scores[a.category.id] = (scores[a.category.id] ?: 0.0) + (sim - threshold).toDouble()
                    val list = heroes.getOrPut(a.category.id) { mutableListOf() }
                    list.add(HeroCandidate(m.uri.toString(), sim, m.isScreenshot, m.pixelCount))
                    if (list.size > 60) {
                        list.sortByDescending { heroScore(it) }
                        while (list.size > 40) list.removeAt(list.size - 1)
                    }
                }
            }
        }

        cache.flush()
        onProgress(total, total)

        val tallies = aligned.mapNotNull { a ->
            val count = counts[a.category.id] ?: 0
            if (count > 0) CategoryTally(a.category.id, count, scores[a.category.id] ?: 0.0) else null
        }
        val byId = categories.associateBy { it.id }

        when (val outcome = ThemeSelector.select(tallies, processed, config)) {
            is SelectionOutcome.WarmingUp -> EngineResult.WarmingUp(outcome.reason, processed)
            is SelectionOutcome.Themes -> {
                val themes = outcome.themes.mapNotNull { tally ->
                    val cat = byId[tally.categoryId] ?: return@mapNotNull null
                    val hero = heroes[tally.categoryId]?.maxByOrNull { heroScore(it) }?.uri
                    EmergentTheme(cat.id, cat.displayName, cat.tagline, tally.count, cat.rarityIndex, cat.rarityTier, hero)
                }
                val card = Tastecard.assemble(
                    displayName = defaultDisplayName,
                    themeIndex = (0 until 16).random(),
                    heroPhotoUri = themes.firstOrNull()?.heroPhotoUri,
                    photosAnalysed = processed,
                    placesCount = GeoClustering.placesCount(coords),
                    themes = themes,
                )
                EngineResult.Card(card)
            }
        }
    }

    private fun heroScore(h: HeroCandidate): Double {
        val screenshotPenalty = if (h.screenshot) 0.5 else 0.0
        val resolutionBonus = minOf(0.1, log10(maxOf(h.pixelCount, 1).toDouble()) / 100.0)
        return h.similarity - screenshotPenalty + resolutionBonus
    }
}
