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

    /**
     * Downsampled bitmap suitable for inference / rendering; null if it can't be decoded.
     * `applyExif` rotates the bitmap to its display orientation — BitmapFactory ignores EXIF,
     * so without it a portrait photo with a rotation tag draws sideways (the export bug).
     * Coil already handles EXIF for the live grid, so inference leaves it off for speed.
     */
    fun loadBitmap(uri: Uri, targetSide: Int, applyExif: Boolean = false): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        val maxDim = maxOf(bounds.outWidth, bounds.outHeight)
        while (maxDim > 0 && maxDim / sample > targetSide * 2) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bmp = context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
        if (applyExif && bmp != null) orientedToExif(uri, bmp) else bmp
    } catch (e: Exception) {
        null
    }

    /** Rotates/flips a bitmap to match its EXIF orientation tag (no-op when already upright). */
    private fun orientedToExif(uri: Uri, bmp: Bitmap): Bitmap = try {
        val orientation = context.contentResolver.openInputStream(uri)?.use { stream ->
            ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        } ?: ExifInterface.ORIENTATION_NORMAL
        val m = android.graphics.Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
            else -> return bmp
        }
        val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        if (rotated !== bmp) bmp.recycle()
        rotated
    } catch (e: Exception) {
        bmp
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
