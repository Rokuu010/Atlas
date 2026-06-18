package io.tastecard.ui

import android.app.Application
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import io.tastecard.engine.AnalysisEngine
import io.tastecard.engine.CategoryStore
import io.tastecard.engine.EmbeddingCache
import io.tastecard.engine.EngineResult
import io.tastecard.engine.OnnxImageEmbedder
import io.tastecard.engine.PhotoRepository
import io.tastecard.engine.TextEmbeddingStore
import io.tastecard.engine.WarmingReason
import io.tastecard.model.Category
import io.tastecard.model.Tastecard
import io.tastecard.persistence.CardStore
import io.tastecard.persistence.LocalImageStore
import io.tastecard.security.InputSanitizer
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

sealed interface Phase {
    data object Greeting : Phase
    data object Priming : Phase
    data object Generating : Phase
    data object CardReady : Phase
    data class WarmingUp(val reason: WarmingReason, val scanned: Int) : Phase
    data object Denied : Phase
    data class Setup(val message: String) : Phase
}

class TastecardViewModel(app: Application) : AndroidViewModel(app) {

    var phase by mutableStateOf<Phase>(Phase.Greeting)
        private set
    var card by mutableStateOf<Tastecard?>(null)
        private set
    var toast by mutableStateOf<String?>(null)
        private set

    /** True when only a user-selected subset of photos is shared (Android 14 partial access). */
    var partialAccess by mutableStateOf(false)
        private set

    val progress = MutableStateFlow(0 to 0)

    private val store = CardStore(app)
    private val imageStore = LocalImageStore(app)
    private var categories: List<Category> = emptyList()
    private var job: Job? = null

    init {
        try {
            categories = CategoryStore.loadFromAssets(app)
            val saved = store.load()
            if (saved != null) { card = saved; phase = Phase.CardReady }
        } catch (e: Exception) {
            phase = Phase.Setup(e.message ?: "Invalid category dataset")
        }
    }

    fun begin() { phase = Phase.Priming }

    fun onPermissionResult(granted: Boolean, partial: Boolean) {
        partialAccess = partial
        if (granted) startAnalysis() else phase = Phase.Denied
    }

    fun startAnalysis() {
        val engine = buildEngine() ?: run {
            phase = Phase.Setup(
                "The on-device analysis model isn't bundled in this build yet. " +
                    "Run scripts/precompute_text_embeddings.py and scripts/convert_siglip_onnx.py, " +
                    "rebuild, and reinstall."
            )
            return
        }
        progress.value = 0 to 0
        phase = Phase.Generating
        job = viewModelScope.launch {
            val result = engine.run { p, t -> progress.value = p to t }
            when (result) {
                is EngineResult.Card -> {
                    store.save(result.card)
                    card = result.card
                    phase = Phase.CardReady
                }
                is EngineResult.WarmingUp -> phase = Phase.WarmingUp(result.reason, result.scanned)
            }
        }
    }

    fun cancel() {
        job?.cancel()
        job = null
        phase = if (card != null) Phase.CardReady else Phase.Greeting
    }

    fun goGreeting() { phase = Phase.Greeting }

    fun drop() {
        val c = card ?: return
        // Shuffling implies the curated palettes — drop any solid custom colour override.
        val updated = c.copy(themeIndex = nextDropIndex(c.themeIndex), customBackgroundColorArgb = null)
        update(updated)
        showToast("Theme: ${paletteAt(updated.themeIndex).name}")
    }

    fun rename(raw: String) {
        val c = card ?: return
        val cleaned = InputSanitizer.displayNameOrDefault(raw)
        if (cleaned == c.displayName) return
        update(c.copy(displayName = cleaned))
    }

    fun setAboutMe(raw: String) {
        val c = card ?: return
        val new = InputSanitizer.aboutMe(raw).ifEmpty { null }
        if (new == c.aboutMe) return
        update(c.copy(aboutMe = new))
    }

    // MARK: profile picture

    fun setProfilePhoto(uri: Uri) {
        val c = card ?: return
        val path = imageStore.store(uri, "profile") ?: run { showToast("Couldn't use that image"); return }
        imageStore.delete(c.profileImagePath)
        update(c.copy(profileImagePath = path))
        showToast("Profile photo updated")
    }

    fun clearProfilePhoto() {
        val c = card ?: return
        imageStore.delete(c.profileImagePath)
        update(c.copy(profileImagePath = null))
    }

    // MARK: appearance (custom colour, background photo, glass opacity)

    fun setCustomColor(argb: Long) {
        val c = card ?: return
        imageStore.delete(c.customBackgroundPath)
        update(c.copy(customBackgroundColorArgb = argb, customBackgroundPath = null))
    }

    fun clearCustomColor() {
        val c = card ?: return
        if (c.customBackgroundColorArgb == null) return
        update(c.copy(customBackgroundColorArgb = null))
    }

    fun setBackgroundPhoto(uri: Uri) {
        val c = card ?: return
        val path = imageStore.store(uri, "bg") ?: run { showToast("Couldn't use that image"); return }
        imageStore.delete(c.customBackgroundPath)
        update(c.copy(customBackgroundPath = path, customBackgroundColorArgb = null))
        showToast("Background updated")
    }

    fun clearBackgroundPhoto() {
        val c = card ?: return
        imageStore.delete(c.customBackgroundPath)
        update(c.copy(customBackgroundPath = null))
    }

    fun setGlassOpacity(value: Double) {
        val c = card ?: return
        val clamped = value.coerceIn(0.0, 1.0)
        if (clamped == c.glassTintMultiplier) return
        update(c.copy(glassOpacity = clamped))
    }

    fun resetAppearance() {
        val c = card ?: return
        imageStore.delete(c.customBackgroundPath)
        update(c.copy(customBackgroundPath = null, customBackgroundColorArgb = null, glassOpacity = null))
        showToast("Appearance reset")
    }

    private fun update(c: Tastecard) {
        card = c
        store.save(c)
    }

    fun swapHero(themeId: String, uri: String) {
        val c = card ?: return
        val themes = c.themes.map { if (it.categoryId == themeId) it.copy(heroPhotoUri = uri) else it }
        val heroTop = if (c.themes.firstOrNull()?.categoryId == themeId) uri else c.heroPhotoUri
        val updated = c.copy(themes = themes, heroPhotoUri = heroTop)
        card = updated
        store.save(updated)
        showToast("Photo updated")
    }

    fun deleteData() {
        cancel()
        store.clear()
        imageStore.deleteAll()
        getApplication<Application>().filesDir.listFiles()
            ?.filter { it.name.startsWith("embeddings_v1_dim") }
            ?.forEach { it.delete() }
        card = null
        phase = Phase.Greeting
        showToast("Data deleted")
    }

    private fun buildEngine(): AnalysisEngine? = try {
        val app = getApplication<Application>()
        val embedder = OnnxImageEmbedder.loadFromAssets(app)
        val textStore = TextEmbeddingStore.loadFromAssets(app)
        if (embedder.dimension != textStore.dimension) null
        else AnalysisEngine(
            photos = PhotoRepository(app),
            embedder = embedder,
            textStore = textStore,
            categories = categories,
            cache = EmbeddingCache(app.filesDir, embedder.dimension),
        )
    } catch (e: Exception) {
        null
    }

    private var toastJob: Job? = null
    fun showToast(message: String) {
        toast = message
        toastJob?.cancel()
        toastJob = viewModelScope.launch {
            kotlinx.coroutines.delay(3000)
            toast = null
        }
    }
}
