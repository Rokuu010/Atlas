package io.tastecard.engine

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Persists per-photo embeddings keyed by MediaStore id so re-runs are incremental (§6/§12).
 * Stored in the app's private files dir; wiped by data deletion (§8).
 */
class EmbeddingCache(dir: File, private val dimension: Int) {
    private val file = File(dir, "embeddings_v1_dim$dimension.bin")
    private val memory = HashMap<Long, FloatArray>()
    private var dirty = false

    init { load() }

    fun get(id: Long): FloatArray? = memory[id]

    fun put(id: Long, vec: FloatArray) {
        if (vec.size != dimension) return
        memory[id] = vec
        dirty = true
    }

    fun flush() {
        if (!dirty) return
        try {
            DataOutputStream(BufferedOutputStream(FileOutputStream(file))).use { dos ->
                dos.writeInt(memory.size)
                for ((id, vec) in memory) {
                    dos.writeLong(id)
                    for (f in vec) dos.writeFloat(f)
                }
            }
            dirty = false
        } catch (_: Exception) {
        }
    }

    fun wipe() {
        memory.clear()
        file.delete()
        dirty = false
    }

    private fun load() {
        if (!file.exists()) return
        try {
            DataInputStream(BufferedInputStream(FileInputStream(file))).use { dis ->
                val count = dis.readInt()
                repeat(count) {
                    val id = dis.readLong()
                    val vec = FloatArray(dimension) { dis.readFloat() }
                    memory[id] = vec
                }
            }
        } catch (_: Exception) {
            memory.clear()
        }
    }
}
