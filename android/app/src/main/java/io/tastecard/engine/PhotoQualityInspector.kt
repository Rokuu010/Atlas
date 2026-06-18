package io.tastecard.engine

import android.graphics.Bitmap

/**
 * Deterministic hero-quality signals (ported from the iOS PhotoQualityInspector). Computes
 * mean brightness + Laplacian-variance sharpness from a 64x64 grayscale downscale, used to
 * skip near-black/blown-out/very-blurry photos as heroes.
 *
 * NOTE: iOS additionally runs Apple Vision (face/document/text detection) to avoid surfacing
 * IDs or other people's faces. That has no zero-dependency Android equivalent; the screenshot
 * heuristic + this quality gate are the Android-side substitute until ML Kit is added.
 */
object PhotoQualityInspector {

    data class Signals(val sharpness: Double, val brightness: Double)

    fun inspect(bitmap: Bitmap): Signals {
        val side = 64
        val small = Bitmap.createScaledBitmap(bitmap, side, side, true)
        val px = IntArray(side * side)
        small.getPixels(px, 0, side, 0, 0, side, side)
        if (small !== bitmap) small.recycle()

        val gray = DoubleArray(px.size)
        var sum = 0.0
        for (i in px.indices) {
            val p = px[i]
            val g = 0.299 * (p shr 16 and 0xFF) + 0.587 * (p shr 8 and 0xFF) + 0.114 * (p and 0xFF)
            gray[i] = g
            sum += g
        }
        val brightness = sum / px.size

        fun at(x: Int, y: Int) = gray[y * side + x]
        val lap = ArrayList<Double>((side - 2) * (side - 2))
        for (y in 1 until side - 1) {
            for (x in 1 until side - 1) {
                lap.add(4 * at(x, y) - at(x - 1, y) - at(x + 1, y) - at(x, y - 1) - at(x, y + 1))
            }
        }
        val mean = lap.sum() / lap.size
        var v = 0.0
        for (l in lap) { val d = l - mean; v += d * d }
        return Signals(sharpness = v / lap.size, brightness = brightness)
    }

    /** Unsuitable as a hero: near-black, blown-out, or extremely blurry. */
    fun isUnsuitable(s: Signals): Boolean {
        if (s.brightness < 18 || s.brightness > 248) return true
        if (s.sharpness < 12) return true
        return false
    }
}
