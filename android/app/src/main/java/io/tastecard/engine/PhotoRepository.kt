package io.tastecard.engine

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface

/** MediaStore photo enumeration + downsampled loading + EXIF GPS (§6). On-device only. */
class PhotoRepository(private val context: Context) {

    data class PhotoMeta(
        val id: Long,
        val uri: Uri,
        val isScreenshot: Boolean,
        val pixelCount: Int,
    )

    fun queryImages(): List<PhotoMeta> {
        val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.WIDTH,
            MediaStore.Images.Media.HEIGHT,
        )
        val hasBucket = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        if (hasBucket) projection.add(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)

        val sort = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        val out = ArrayList<PhotoMeta>()
        context.contentResolver.query(collection, projection.toTypedArray(), null, null, sort)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val wCol = c.getColumnIndex(MediaStore.Images.Media.WIDTH)
            val hCol = c.getColumnIndex(MediaStore.Images.Media.HEIGHT)
            val bucketCol = if (hasBucket) c.getColumnIndex(MediaStore.Images.Media.BUCKET_DISPLAY_NAME) else -1
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val uri = ContentUris.withAppendedId(collection, id)
                val w = if (wCol >= 0) c.getInt(wCol) else 0
                val h = if (hCol >= 0) c.getInt(hCol) else 0
                val bucket = if (bucketCol >= 0) (c.getString(bucketCol) ?: "") else ""
                val isScreenshot = bucket.contains("screenshot", ignoreCase = true)
                out.add(PhotoMeta(id, uri, isScreenshot, w * h))
            }
        }
        return out
    }

    /** Downsampled bitmap suitable for inference; null if it can't be decoded. */
    fun loadBitmap(uri: Uri, targetSide: Int): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        val maxDim = maxOf(bounds.outWidth, bounds.outHeight)
        while (maxDim > 0 && maxDim / sample > targetSide * 2) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    } catch (e: Exception) {
        null
    }

    /** Coarse GPS from EXIF (requires ACCESS_MEDIA_LOCATION). Null when absent. */
    fun location(uri: Uri): GeoClustering.Coordinate? = try {
        val mediaUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.setRequireOriginal(uri)
        } else uri
        context.contentResolver.openInputStream(mediaUri)?.use { stream ->
            val exif = ExifInterface(stream)
            val ll = exif.latLong
            if (ll != null) GeoClustering.Coordinate(ll[0], ll[1]) else null
        }
    } catch (e: Exception) {
        null
    }
}
