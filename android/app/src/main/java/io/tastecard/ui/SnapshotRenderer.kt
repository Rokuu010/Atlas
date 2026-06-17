package io.tastecard.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.FileProvider
import io.tastecard.engine.PhotoRepository
import io.tastecard.model.RarityTier
import io.tastecard.model.Tastecard
import io.tastecard.security.InputSanitizer
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Renders the 9:16 share image with Android Canvas (deterministic; no async capture). */
object SnapshotRenderer {

    private const val W = 1080
    private const val H = 1920

    suspend fun renderToShareUri(context: Context, card: Tastecard): Uri? = withContext(Dispatchers.IO) {
        val palette = paletteAt(card.themeIndex)
        val themes = card.themes.take(4)

        // Pre-load hero bitmaps synchronously.
        val repo = PhotoRepository(context)
        val heroes = themes.associate { t ->
            t.categoryId to (t.heroPhotoUri?.let { runCatching { repo.loadBitmap(Uri.parse(it), 640) }.getOrNull() })
        }

        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(palette.background.toArgb())

        val text = palette.text.toArgb()
        fun paint(size: Float, bold: Boolean = false, mono: Boolean = false, alpha: Int = 255, color: Int = text) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.alpha = alpha
            textSize = size
            typeface = Typeface.create(if (mono) Typeface.MONOSPACE else Typeface.SANS_SERIF, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

        val pad = 70f
        // Brand row.
        canvas.drawText(card.displayName.uppercase(), pad, 130f, paint(34f, bold = true, mono = true, alpha = 190))
        val codeP = paint(34f, bold = true, mono = true, alpha = 190)
        canvas.drawText(card.serialDisplay, W - pad - codeP.measureText(card.serialDisplay), 130f, codeP)

        // Inner glass card.
        val cardRect = RectF(pad, 200f, W - pad, H - 180f)
        val glass = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE; alpha = 38 }
        canvas.drawRoundRect(cardRect, 56f, 56f, glass)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 2f; color = android.graphics.Color.WHITE; alpha = 60
        }
        canvas.drawRoundRect(cardRect, 56f, 56f, border)

        val inX = pad + 48f
        var y = 320f
        canvas.drawText(card.displayName, inX, y, paint(64f, bold = true))
        y += 56f
        canvas.drawText("TASTECARD RARITY: ${card.cardRarity.displayName.uppercase()}", inX, y,
            paint(28f, bold = true, mono = true, color = rarityColor(card.cardRarity)))

        // Stats.
        y += 90f
        val cellW = (cardRect.width() - 96f) / 3f
        drawStat(canvas, inX, y, card.photosAnalysed.abbreviated(), "PHOTOS", text)
        drawStat(canvas, inX + cellW, y, card.emergentThemeCount.toString(), "THEMES", text)
        drawStat(canvas, inX + cellW * 2, y, card.placesCount.toString(), "PLACES", text)

        // 2x2 grid.
        val gridTop = y + 70f
        val gridGap = 28f
        val gridW = cardRect.width() - 96f
        val cw = (gridW - gridGap) / 2f
        val ch = cw * 4f / 3f
        themes.forEachIndexed { i, t ->
            val col = i % 2; val row = i / 2
            val left = inX + col * (cw + gridGap)
            val top = gridTop + row * (ch + gridGap)
            val r = RectF(left, top, left + cw, top + ch)
            val path = Path().apply { addRoundRect(r, 36f, 36f, Path.Direction.CW) }
            canvas.save(); canvas.clipPath(path)
            val hero = heroes[t.categoryId]
            if (hero != null) {
                val src = centerCropSrc(hero, cw / ch)
                canvas.drawBitmap(hero, src, r, null)
            } else {
                val g = Paint().apply { color = android.graphics.Color.parseColor("#5B5680") }
                canvas.drawRect(r, g)
            }
            // bottom scrim + label
            val scrim = Paint().apply { color = android.graphics.Color.BLACK; alpha = 150 }
            canvas.drawRect(RectF(r.left, r.bottom - 90f, r.right, r.bottom), scrim)
            canvas.restore()
            canvas.drawText(ellipsize(t.displayName, 18), left + 18f, top + ch - 30f, paint(28f, bold = true, color = android.graphics.Color.WHITE))
        }

        // Footer.
        val footer = "${card.displayName} • ${card.serialDisplay}".uppercase()
        val fp = paint(24f, mono = true, alpha = 130)
        canvas.drawText(footer, (W - fp.measureText(footer)) / 2f, H - 110f, fp)

        // Write PNG to cache/shared and return a FileProvider Uri.
        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, "${InputSanitizer.filenameSlug(card.displayName)}_tastecard.png")
        FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    private fun drawStat(c: Canvas, x: Float, y: Float, value: String, label: String, textColor: Int) {
        val vp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor; textSize = 48f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
        c.drawText(value, x, y, vp)
        val lp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor; alpha = 180; textSize = 22f
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        }
        c.drawText(label, x, y + 34f, lp)
    }

    private fun rarityColor(tier: RarityTier): Int = when (tier) {
        RarityTier.COMMON -> android.graphics.Color.parseColor("#D4D4D8")
        RarityTier.RARE -> android.graphics.Color.parseColor("#FBBF24")
        RarityTier.EPIC -> android.graphics.Color.parseColor("#E879F9")
        RarityTier.LEGENDARY -> android.graphics.Color.parseColor("#34D399")
    }

    private fun centerCropSrc(bmp: Bitmap, targetAspect: Float): android.graphics.Rect {
        val bw = bmp.width; val bh = bmp.height
        val bAspect = bw.toFloat() / bh
        return if (bAspect > targetAspect) {
            val w = (bh * targetAspect).toInt()
            val x = (bw - w) / 2
            android.graphics.Rect(x, 0, x + w, bh)
        } else {
            val h = (bw / targetAspect).toInt()
            val yy = (bh - h) / 2
            android.graphics.Rect(0, yy, bw, yy + h)
        }
    }

    private fun ellipsize(s: String, max: Int): String = if (s.length <= max) s else s.take(max - 1) + "…"
}

fun Int.abbreviated(): String =
    if (this >= 1000) {
        val v = this / 1000.0
        if (v < 10) String.format("%.1fK", v) else String.format("%.0fK", v)
    } else toString()
