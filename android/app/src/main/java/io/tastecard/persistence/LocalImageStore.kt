package io.tastecard.persistence

import android.content.Context
import android.net.Uri
import java.io.File
import java.util.UUID

/**
 * Copies a user-picked image (profile picture / custom background) into app-private
 * storage so it survives beyond the photo-picker's temporary URI grant (§8 local-only).
 * Returns the absolute file path; Coil loads it via a java.io.File model.
 */
class LocalImageStore(context: Context) {
    private val dir = File(context.filesDir, "images").apply { mkdirs() }
    private val resolver = context.contentResolver

    /** Stores the image, returning its file path, or null if it couldn't be read. */
    fun store(uri: Uri, prefix: String): String? = try {
        val file = File(dir, "${prefix}_${UUID.randomUUID()}.jpg")
        resolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        }
        if (file.exists() && file.length() > 0) file.absolutePath else { file.delete(); null }
    } catch (e: Exception) {
        null
    }

    fun delete(path: String?) {
        if (path.isNullOrEmpty()) return
        runCatching { File(path).delete() }
    }

    fun deleteAll() {
        runCatching { dir.listFiles()?.forEach { it.delete() } }
    }
}
