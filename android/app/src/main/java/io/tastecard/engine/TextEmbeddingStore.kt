package io.tastecard.engine

import android.content.Context
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Loads the precomputed, L2-normalised category text vectors (§6), produced by
 * scripts/precompute_text_embeddings.py. Same TCTE binary format as iOS:
 *   "TCTE" | u32 version | u32 dim | u32 count | { u16 idLen, id bytes, dim*f32 }...
 */
class TextEmbeddingStore private constructor(
    val dimension: Int,
    private val vectors: Map<String, FloatArray>,
) {
    fun vector(categoryId: String): FloatArray? = vectors[categoryId]

    class MissingModelException(message: String) : Exception(message)

    companion object {
        fun loadFromAssets(context: Context, name: String = "category_text_embeddings.bin"): TextEmbeddingStore {
            val bytes = try {
                context.assets.open(name).use { it.readBytes() }
            } catch (e: Exception) {
                throw MissingModelException("text vectors not bundled: ${e.message}")
            }
            return parse(bytes)
        }

        fun parse(bytes: ByteArray): TextEmbeddingStore {
            val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            val magic = ByteArray(4); buf.get(magic)
            if (String(magic, Charsets.US_ASCII) != "TCTE") throw MissingModelException("bad magic")
            val version = buf.int
            if (version != 1) throw MissingModelException("unsupported version $version")
            val dim = buf.int
            val count = buf.int
            if (dim <= 0 || count <= 0) throw MissingModelException("empty text vectors")

            val map = HashMap<String, FloatArray>(count)
            repeat(count) {
                val idLen = buf.short.toInt() and 0xFFFF
                val idBytes = ByteArray(idLen); buf.get(idBytes)
                val id = String(idBytes, Charsets.UTF_8)
                val vec = FloatArray(dim) { buf.float }
                map[id] = vec
            }
            return TextEmbeddingStore(dim, map)
        }
    }
}
