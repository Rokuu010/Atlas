package io.tastecard.engine

import android.net.Uri
import io.tastecard.model.Category
import io.tastecard.model.CategoryStat
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
 * enumerate -> (cache | downsample+embed+release) -> bias-corrected relative affinity +
 * absolute confidence gate -> distinctive-match tally -> 3–6 selection (relative-ranking
 * safety net) -> quality-aware, de-duplicated hero pick that prefers themes with a real
 * photo -> EXIF Places -> card.
 *
 * Two match conditions, as on iOS:
 *   1. relative: a photo's affinity for a category exceeds that photo's MEAN affinity by a
 *      margin (scale-invariant; removes SigLIP's universal-prompt prior).
 *   2. absolute: the raw cosine clears a floor (kills weak "nearest-of-nothing" matches).
 */
class AnalysisEngine(
    private val photos: PhotoRepository,
    private val embedder: OnnxImageEmbedder,
    private val textStore: TextEmbeddingStore,
    private val categories: List<Category>,
    private val cache: EmbeddingCache,
    private val config: SelectionConfig = SelectionConfig(),
    private val defaultDisplayName: String = "My Tastecard",
    private val relativeMargin: Float = 0.05f,
    private val absoluteFloor: Float = 0.06f,
    private val backupPool: Int = 10,
    private val heroInspectTopN: Int = 8,
    // Cap analysis to the most recent N photos. 500 ≈ a typical 1–2 month camera roll,
    // keeping the scan fast and the surfaced themes the ones the user relates to most.
    private val maxScanPhotos: Int = 500,
) {
    private data class Aligned(val category: Category, val vector: FloatArray)
    private data class HeroCandidate(val uri: String, val similarity: Float, val screenshot: Boolean, val pixelCount: Int)

    suspend fun run(onProgress: (Int, Int) -> Unit): EngineResult = withContext(Dispatchers.Default) {
        // queryImages() is newest-first, so take() keeps the most recent maxScanPhotos.
        val metas = photos.queryImages().take(maxScanPhotos)
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
        val softCounts = HashMap<String, Int>()
        val heroes = HashMap<String, MutableList<HeroCandidate>>()
        val coords = ArrayList<GeoClustering.Coordinate>()

        var processed = 0
        val stride = maxOf(1, total / 100)
        val margin = relativeMargin
        val absFloor = absoluteFloor

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

                softCounts[cid] = (softCounts[cid] ?: 0) + 1

                val list = heroes.getOrPut(cid) { mutableListOf() }
                list.add(HeroCandidate(m.uri.toString(), cosines[i], m.isScreenshot, m.pixelCount))
                if (list.size > 60) {
                    list.sortByDescending { heroScore(it) }
                    while (list.size > 40) list.removeAt(list.size - 1)
                }

                if (delta >= margin && cosines[i] >= absFloor) {
                    counts[cid] = (counts[cid] ?: 0) + 1
                    scores[cid] = (scores[cid] ?: 0.0) + delta.toDouble()
                }
            }
        }

        cache.flush()
        onProgress(total, total)

        val placesCount = GeoClustering.placesCount(coords)
        val byId = categories.associateBy { it.id }

        fun photoCount(id: String): Int = counts[id] ?: softCounts[id] ?: 1

        val tallies = aligned.mapNotNull { a ->
            val count = counts[a.category.id] ?: 0
            if (count > 0) CategoryTally(a.category.id, count, scores[a.category.id] ?: 0.0) else null
        }

        when (val outcome = ThemeSelector.select(tallies, processed, config)) {
            is SelectionOutcome.Themes -> {
                // outcome.themes is EVERY qualifying category (most-photos-first). assembleThemes
                // shows the strongest 3–6 with a usable hero; the full list becomes the shadow set.
                val pool = outcome.themes.map { it.categoryId }
                val themes = assembleThemes(pool, byId, heroes, ::photoCount)
                val allCategories = outcome.themes.mapNotNull { t ->
                    byId[t.categoryId]?.let { c -> CategoryStat(c.id, c.displayName, t.count, c.rarityIndex) }
                }
                EngineResult.Card(assemble(themes, allCategories, processed, placesCount))
            }
            is SelectionOutcome.WarmingUp ->
                EngineResult.WarmingUp(outcome.reason, processed)
        }
    }

    /** Quality, de-duplicated hero per theme; themes with a real photo come first. */
    private fun assembleThemes(
        orderedIds: List<String>,
        byId: Map<String, Category>,
        heroes: Map<String, MutableList<HeroCandidate>>,
        photoCount: (String) -> Int,
    ): List<EmergentTheme> {
        val maxThemes = config.maxThemes
        val minThemes = config.minThemes
        val used = HashSet<String>()
        val withHero = ArrayList<EmergentTheme>()
        val withoutHero = ArrayList<EmergentTheme>()

        for (id in orderedIds) {
            if (withHero.size >= maxThemes) break
            val cat = byId[id] ?: continue
            val candidates = heroes[id] ?: emptyList()
            val rankedUris = ranked(candidates).map { it.uri }
            val hero = chooseHero(candidates, used)
            val theme = EmergentTheme(
                categoryId = cat.id,
                displayName = cat.displayName,
                tagline = cat.tagline,
                photoCount = photoCount(id),
                rarityIndex = cat.rarityIndex,
                rarityTier = cat.rarityTier,
                heroPhotoUri = hero,
                candidatePhotoUris = rankedUris.take(15),
            )
            if (hero != null) {
                used.add(hero)
                withHero.add(theme)
            } else if (withoutHero.size < minThemes) {
                withoutHero.add(theme)
            }
        }

        val result = ArrayList(withHero.take(maxThemes))
        if (result.size < minThemes) {
            result += withoutHero.take(minThemes - result.size)
        }
        return result
    }

    /** Sharpest non-poor candidate not already used by another theme. */
    private fun chooseHero(candidates: List<HeroCandidate>, exclude: Set<String>): String? {
        val ranked = ranked(candidates).filter { it.uri !in exclude }
        var bestId: String? = null
        var bestSharpness = -1.0
        var inspected = 0
        for (c in ranked) {
            if (inspected >= heroInspectTopN) break
            val bmp = try { photos.loadBitmap(Uri.parse(c.uri), 64) } catch (e: Exception) { null } ?: continue
            inspected++
            val signals = PhotoQualityInspector.inspect(bmp)
            bmp.recycle()
            if (PhotoQualityInspector.isUnsuitable(signals)) continue
            if (signals.sharpness > bestSharpness) {
                bestSharpness = signals.sharpness
                bestId = c.uri
            }
        }
        return bestId
    }

    private fun assemble(
        themes: List<EmergentTheme>,
        allCategories: List<CategoryStat>,
        processed: Int,
        places: Int,
    ): Tastecard =
        Tastecard.assemble(
            displayName = defaultDisplayName,
            themeIndex = (0 until 16).random(),
            heroPhotoUri = themes.firstOrNull()?.heroPhotoUri,
            photosAnalysed = processed,
            placesCount = places,
            themes = themes,
            allCategories = allCategories,
        )

    private fun ranked(candidates: List<HeroCandidate>): List<HeroCandidate> =
        candidates.sortedByDescending { heroScore(it) }

    private fun heroScore(h: HeroCandidate): Double {
        val screenshotPenalty = if (h.screenshot) 0.5 else 0.0
        val resolutionBonus = minOf(0.1, log10(maxOf(h.pixelCount, 1).toDouble()) / 100.0)
        return h.similarity - screenshotPenalty + resolutionBonus
    }
}
