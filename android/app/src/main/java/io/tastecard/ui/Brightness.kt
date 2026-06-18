package io.tastecard.ui

import android.graphics.Bitmap
import androidx.compose.ui.graphics.Color
import kotlin.math.sqrt

/**
 * Luminance-weighted RMS brightness test (ported from iOS Brightness, threshold 135).
 * Drives adaptive ink + glass over a custom colour or photo background.
 */
object Brightness {
    private const val THRESHOLD = 135.0

    fun isDark(color: Color): Boolean {
        val r = color.red * 255.0
        val g = color.green * 255.0
        val b = color.blue * 255.0
        return sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b) < THRESHOLD
    }

    /** Averages a 10x10 downscale of the bitmap; null-safe fallback keeps light ink. */
    fun isDark(bitmap: Bitmap): Boolean {
        return try {
            val small = Bitmap.createScaledBitmap(bitmap, 10, 10, true)
            var rs = 0.0; var gs = 0.0; var bs = 0.0
            val px = IntArray(100)
            small.getPixels(px, 0, 10, 0, 0, 10, 10)
            for (p in px) {
                rs += (p shr 16 and 0xFF)
                gs += (p shr 8 and 0xFF)
                bs += (p and 0xFF)
            }
            if (small !== bitmap) small.recycle()
            val n = px.size.toDouble()
            val r = rs / n; val g = gs / n; val b = bs / n
            sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b) < THRESHOLD
        } catch (e: Exception) {
            false
        }
    }
}
