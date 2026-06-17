package io.tastecard.engine

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import android.content.Context
import android.graphics.Bitmap
import java.nio.FloatBuffer

/**
 * On-device SigLIP image encoder via ONNX Runtime (§6). The .onnx is produced by
 * scripts/convert_siglip_onnx.py and bundled in assets. Preprocessing (resize +
 * normalise to [-1, 1], matching SigLIP mean=std=0.5) is done here in Kotlin.
 */
class OnnxImageEmbedder private constructor(
    private val env: OrtEnvironment,
    private val session: OrtSession,
    private val inputName: String,
    val dimension: Int,
) {
    val inputSide = 224

    class MissingModelException(message: String) : Exception(message)

    fun embed(bitmap: Bitmap): FloatArray {
        val input = preprocess(bitmap)
        val shape = longArrayOf(1, 3, inputSide.toLong(), inputSide.toLong())
        OnnxTensor.createTensor(env, FloatBuffer.wrap(input), shape).use { tensor ->
            session.run(mapOf(inputName to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                val out = result[0].value as Array<FloatArray>
                return VectorMath.l2Normalize(out[0])
            }
        }
    }

    private fun preprocess(bitmap: Bitmap): FloatArray {
        val scaled = if (bitmap.width == inputSide && bitmap.height == inputSide) bitmap
            else Bitmap.createScaledBitmap(bitmap, inputSide, inputSide, true)
        val plane = inputSide * inputSide
        val px = IntArray(plane)
        scaled.getPixels(px, 0, inputSide, 0, 0, inputSide, inputSide)
        val out = FloatArray(3 * plane)   // NCHW
        for (i in 0 until plane) {
            val p = px[i]
            out[i] = ((p shr 16 and 0xFF) / 127.5f) - 1f          // R
            out[plane + i] = ((p shr 8 and 0xFF) / 127.5f) - 1f   // G
            out[2 * plane + i] = ((p and 0xFF) / 127.5f) - 1f     // B
        }
        if (scaled !== bitmap) scaled.recycle()
        return out
    }

    fun close() {
        try { session.close() } catch (_: Exception) {}
    }

    companion object {
        fun loadFromAssets(context: Context, modelAsset: String = "siglip_image_encoder.onnx"): OnnxImageEmbedder {
            val bytes = try {
                context.assets.open(modelAsset).use { it.readBytes() }
            } catch (e: Exception) {
                throw MissingModelException("model not bundled: ${e.message}")
            }
            val env = OrtEnvironment.getEnvironment()
            val opts = OrtSession.SessionOptions()
            val session = env.createSession(bytes, opts)
            val inputName = session.inputNames.first()
            val outInfo = session.outputInfo.values.first().info as TensorInfo
            val dim = outInfo.shape.lastOrNull { it > 0 }?.toInt()
                ?: throw MissingModelException("could not read output dim")
            return OnnxImageEmbedder(env, session, inputName, dim)
        }
    }
}
