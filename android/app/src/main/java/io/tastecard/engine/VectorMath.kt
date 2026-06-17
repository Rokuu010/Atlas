package io.tastecard.engine

import kotlin.math.sqrt

object VectorMath {
    fun l2Normalize(v: FloatArray): FloatArray {
        var sum = 0f
        for (x in v) sum += x * x
        val norm = sqrt(sum)
        if (norm <= 0f) return v
        val out = FloatArray(v.size)
        for (i in v.indices) out[i] = v[i] / norm
        return out
    }

    /** Dot product; for two L2-normalised vectors this is cosine similarity. */
    fun dot(a: FloatArray, b: FloatArray): Float {
        val n = minOf(a.size, b.size)
        var sum = 0f
        var i = 0
        while (i < n) { sum += a[i] * b[i]; i++ }
        return sum
    }
}
