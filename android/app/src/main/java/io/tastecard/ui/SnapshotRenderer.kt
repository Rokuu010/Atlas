package io.tastecard.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import androidx.compose.ui.graphics.Color
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
    private val LIGHT = 0xFFFDF9F6.toInt()
    private val DARK = 0xFF0C1519.toInt()

    suspend fun renderToShareUri(context: Context, card: Tastecard): Uri? = withContext(Dispatchers.IO) {
        val palette = paletteAt(card.themeIndex)
        val themes = card.themes.take(4)

        val repo = PhotoRepository(context)
        val heroes = themes.associate { t ->
            t.categoryId to (t.heroPhotoUri?.let { runCatching { repo.loadBitmap(Uri.parse(it), 640) }.getOrNull() })
        }
        val profileBmp = card.profileImagePath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
        val bgBmp = card.customBackgroundPath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
        val customColor = card.customBackgroundColorArgb?.let { Color(it.toInt()) }

        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(customColor?.toArgb() ?: palette.background.toArgb())
        if (bgBmp != null) {
            val src = centerCropSrc(bgBmp, W.toFloat() / H)
            canvas.drawBitmap(bgBmp, src, RectF(0f, 0f, W.toFloat(), H.toFloat()), null)
            canvas.drawRect(RectF(0f, 0f, W.toFloat(), H.toFloat()),
                Paint().apply { color = android.graphics.Color.BLACK; alpha = 110 })
        }

        // Adaptive ink: light over a photo, brightness-based over a solid colour, else the theme ink.
        val text = when {
            bgBmp != null -> LIGHT
            customColor != null -> if (Brightness.isDark(customColor)) LIGHT else DARK
            else -> palette.text.toArgb()
        }
        fun paint(size: Float, bold: Boolean = false, mono: Boolean = false, alpha: Int = 255, color: Int = text) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.alpha = alpha
            textSize = size
            typeface = Typeface.create(if (mono) Typeface.MONOSPACE else Typeface.SANS_SERIF, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

        val pad = 70f
        // Brand row.
        canvas.drawText("MY TASTECARD", pad, 130f, paint(34f, bold = true, mono = true, alpha = 190))
        val codeP = paint(34f, bold = true, mono = true, alpha = 190)
        canvas.drawText(card.serialDisplay, W - pad - codeP.measureText(card.serialDisplay), 130f, codeP)

        // Inner glass card, frosting scaled by the opacity slider.
        val cardRect = RectF(pad, 200f, W - pad, H - 180f)
        val opacity = card.glassTintMultiplier.toFloat()
        val glassAlpha = ((0.06f + 0.12f * opacity) * 255f).toInt().coerceIn(10, 255)
        val glass = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = text; alpha = glassAlpha }
        canvas.drawRoundRect(cardRect, 56f, 56f, glass)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 2f; color = text; alpha = 76
        }
        canvas.drawRoundRect(cardRect, 56f, 56f, border)

        val inX = pad + 48f
        val innerRight = cardRect.right - 48f

        // Header: profile circle + possessive title + rarity.
        val pr = 48f
        val pcx = inX + pr
        val pcy = 312f
        canvas.drawCircle(pcx, pcy, pr, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = text; alpha = 30 })
        if (profileBmp != null) {
            canvas.save()
            canvas.clipPath(Path().apply { addCircle(pcx, pcy, pr, Path.Direction.CW) })
            canvas.drawBitmap(profileBmp, centerCropSrc(profileBmp, 1f),
                RectF(pcx - pr, pcy - pr, pcx + pr, pcy + pr), null)
            canvas.restore()
        }
        val titleX = pcx + pr + 28f
        val titleP = paint(52f, bold = true)
        fitText(card.cardTitle, innerRight - titleX, titleP)
        canvas.drawText(card.cardTitle, titleX, pcy - 2f, titleP)
        canvas.drawText("TASTECARD RARITY: ${card.cardRarity.displayName.uppercase()}", titleX, pcy + 44f,
            paint(26f, bold = true, mono = true, color = rarityColor(card.cardRarity)))

        // Stats.
        var y = 470f
        val cellW = (cardRect.width() - 96f) / 3f
        drawStat(canvas, inX, y, card.photosAnalysed.abbreviated(), "PHOTOS", text)
        drawStat(canvas, inX + cellW, y, card.emergentThemeCount.toString(), "THEMES", text)
        drawStat(canvas, inX + cellW * 2, y, card.placesCount.toString(), "PLACES", text)
        y += 70f

        // About me (wrapped, up to 2 lines).
        val about = card.aboutMe
        if (!about.isNullOrEmpty()) {
            canvas.drawText("ABOUT ME", inX, y, paint(22f, bold = true, mono = true, alpha = 165))
            y += 34f
            val ap = paint(28f, alpha = 230)
            for (line in wrap(about, innerRight - inX, ap, 2)) {
                canvas.drawText(line, inX, y, ap)
                y += 38f
            }
            y += 8f
        }

        // 2x2 grid — sized to fit the remaining space (never overflows the card).
        val footerY = cardRect.bottom - 70f
        val gridTop = y + 16f
        val gridGap = 24f
        val availH = footerY - gridTop - 20f
        val ch = (availH - gridGap) / 2f
        val cw = ch * 3f / 4f
        val gridW = cw * 2 + gridGap
        val gridLeft = (W - gridW) / 2f
        themes.forEachIndexed { i, t ->
            val col = i % 2; val row = i / 2
            val left = gridLeft + col * (cw + gridGap)
            val top = gridTop + row * (ch + gridGap)
            val r = RectF(left, top, left + cw, top + ch)
            val path = Path().apply { addRoundRect(r, 32f, 32f, Path.Direction.CW) }
            canvas.save(); canvas.clipPath(path)
            val hero = heroes[t.categoryId]
            if (hero != null) {
                canvas.drawBitmap(hero, centerCropSrc(hero, cw / ch), r, null)
            } else {
                canvas.drawRect(r, Paint().apply { color = android.graphics.Color.parseColor("#5B5680") })
            }
            canvas.drawRect(RectF(r.left, r.bottom - 90f, r.right, r.bottom),
                Paint().apply { color = android.graphics.Color.BLACK; alpha = 150 })
            canvas.restore()
            canvas.drawText(ellipsize(t.displayName, 18), left + 18f, r.bottom - 26f,
                paint(26f, bold = true, color = android.graphics.Color.WHITE))
        }

        // Footer.
        val footer = "${card.cardTitle} • ${card.serialDisplay}".uppercase()
        val fp = paint(24f, mono = true, alpha = 130)
        fitText(footer, cardRect.width() - 96f, fp, minSize = 16f)
        canvas.drawText(footer, (W - fp.measureText(footer)) / 2f, cardRect.bottom - 40f, fp)

        val dir = File(context.cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, "${InputSanitizer.filenameSlug(card.displayName)}_tastecard.png")
        FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    /** Shrinks the paint's text size until the string fits maxWidth (down to minSize). */
    private fun fitText(s: String, maxWidth: Float, paint: Paint, minSize: Float = 32f) {
        while (paint.textSize > minSize && paint.measureText(s) > maxWidth) paint.textSize -= 2f
    }

    /** Greedy word-wrap to at most maxLines, ellipsising the last line if needed. */
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
