package io.tastecard.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import androidx.core.content.FileProvider
import io.tastecard.engine.PhotoRepository
import io.tastecard.model.EmergentTheme
import io.tastecard.model.RarityTier
import io.tastecard.model.Tastecard
import io.tastecard.security.InputSanitizer
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Renders the single-theme 9:16 share image ("18% of your camera roll is X") — the Android
 * twin of iOS's MiniThemeCardView. Deterministic Canvas rendering (no async capture).
 */
object MiniThemeRenderer {

    private const val W = 1080
    private const val H = 1920

    suspend fun renderToShareUri(context: Context, card: Tastecard, theme: EmergentTheme): Uri? = withContext(Dispatchers.IO) {
        val repo = PhotoRepository(context)
        val hero = theme.heroPhotoUri?.let { runCatching { repo.loadBitmap(Uri.parse(it), 1080) }.getOrNull() }

        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)

        // Full-bleed hero (or a tinted placeholder when there's no usable photo).
        if (hero != null) {
            canvas.drawBitmap(hero, centerCropSrc(hero, W.toFloat() / H), RectF(0f, 0f, W.toFloat(), H.toFloat()), null)
        } else {
            canvas.drawColor(android.graphics.Color.parseColor("#5B5680"))
        }

        // Top-to-bottom darkening so the text is always legible.
        val grad = LinearGradient(
            0f, 0f, 0f, H.toFloat(),
            intArrayOf(0x26000000, 0x8C000000.toInt(), 0xE6000000.toInt()),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, W.toFloat(), H.toFloat(), Paint().apply { shader = grad })

        fun paint(
            size: Float, bold: Boolean = false, mono: Boolean = false, italic: Boolean = false,
            alpha: Int = 255, color: Int = android.graphics.Color.WHITE,
        ) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.alpha = alpha
            textSize = size
            val style = when {
                bold && italic -> Typeface.BOLD_ITALIC
                bold -> Typeface.BOLD
                italic -> Typeface.ITALIC
                else -> Typeface.NORMAL
            }
            typeface = Typeface.create(if (mono) Typeface.MONOSPACE else Typeface.SANS_SERIF, style)
        }

        val pad = 70f
        val contentW = W - pad * 2

        // Brand row at the top.
        canvas.drawText("MY ROLLCARD", pad, 120f, paint(34f, bold = true, mono = true, alpha = 217))
        val codeP = paint(34f, bold = true, mono = true, alpha = 217)
        canvas.drawText(card.serialDisplay, W - pad - codeP.measureText(card.serialDisplay), 120f, codeP)

        // Bottom content, laid out from the bottom upward.
        var by = H - 110f

        // Tagline (italic, up to 2 lines).
        if (theme.tagline.isNotEmpty()) {
            val tp = paint(38f, italic = true, alpha = 217)
            for (line in wrap(theme.tagline, contentW, tp, 2).reversed()) {
                canvas.drawText(line, pad, by, tp); by -= 48f
            }
            by -= 6f
        }

        // Rarity + photo count.
        canvas.drawText(
            "${theme.rarityTier.displayName.uppercase()} · ${theme.photoCount} PHOTOS",
            pad, by, paint(32f, bold = true, mono = true, color = rarityColor(theme.rarityTier)),
        )
        by -= 74f

        // Theme name (big, up to 2 lines).
        val np = paint(92f, bold = true)
        for (line in wrap(theme.displayName, contentW, np, 2).reversed()) {
            canvas.drawText(line, pad, by, np); by -= 100f
        }
        by -= 4f

        // "of your camera roll is" + the big percentage.
        val pct = if (card.photosAnalysed > 0) {
            val p = theme.photoCount * 100.0 / card.photosAnalysed
            if (p >= 1) "${p.toInt()}%" else "<1%"
        } else {
            null
        }
        if (pct != null) {
            canvas.drawText("of your camera roll is", pad, by, paint(40f, alpha = 217))
            by -= 72f
            canvas.drawText(pct, pad, by, paint(190f, bold = true))
        }

        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, "${InputSanitizer.filenameSlug(card.displayName)}_${theme.categoryId}.png")
        FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    /** Greedy word-wrap to at most maxLines. */
    private fun wrap(s: String, maxWidth: Float, paint: Paint, maxLines: Int): List<String> {
        val lines = ArrayList<String>()
        var cur = ""
        for (word in s.split(" ")) {
            val t = if (cur.isEmpty()) word else "$cur $word"
            if (paint.measureText(t) <= maxWidth) {
                cur = t
            } else {
                if (cur.isNotEmpty()) lines.add(cur)
                cur = word
                if (lines.size >= maxLines) break
            }
        }
        if (cur.isNotEmpty() && lines.size < maxLines) lines.add(cur)
        return lines.take(maxLines)
    }

    private fun rarityColor(tier: RarityTier): Int = when (tier) {
        RarityTier.COMMON -> android.graphics.Color.parseColor("#D4D4D8")
        RarityTier.RARE -> android.graphics.Color.parseColor("#FBBF24")
        RarityTier.EPIC -> android.graphics.Color.parseColor("#E879F9")
        RarityTier.LEGENDARY -> android.graphics.Color.parseColor("#34D399")
    }

    private fun centerCropSrc(bmp: Bitmap, targetAspect: Float): Rect {
        val bw = bmp.width; val bh = bmp.height
        val bAspect = bw.toFloat() / bh
        return if (bAspect > targetAspect) {
            val w = (bh * targetAspect).toInt(); val x = (bw - w) / 2
            Rect(x, 0, x + w, bh)
        } else {
            val h = (bw / targetAspect).toInt(); val yy = (bh - h) / 2
            Rect(0, yy, bw, yy + h)
        }
    }
}
