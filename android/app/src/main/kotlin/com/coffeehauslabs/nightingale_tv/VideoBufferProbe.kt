package com.coffeehauslabs.nightingale_tv

import android.graphics.ImageFormat
import android.hardware.HardwareBuffer
import android.media.Image
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import androidx.annotation.RequiresApi
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** What buffer a decoder makes, and which part of it is the picture
 *  (video-report D5, system-video-layer D8): its output in an ImageReader the
 *  GPU can read. Android 10 (API 29) and later. */
object VideoBufferProbe {
    const val TIMEOUT_MS = 5_000L

    /** [decode] decodes a frame to the surface it's given and says null, or
     *  why it couldn't; then the first picture on it, as [describe]d. */
    fun run(width: Int, height: Int, decode: (Surface) -> Map<String, Any?>?): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 29) return mapOf("skipped" to "api ${Build.VERSION.SDK_INT}")
        val thread = HandlerThread("ntv-probe").apply { start() }
        val reader = ImageReader.newInstance(width, height, ImageFormat.PRIVATE, 7, HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE)
        val arrived = CountDownLatch(1)
        var found: Map<String, Any?>? = null
        reader.setOnImageAvailableListener({ r ->
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            image.use {
                if (found == null) found = describe(it)
            }
            arrived.countDown()
        }, Handler(thread.looper))
        try {
            val failed = decode(reader.surface)
            if (failed == null && !arrived.await(TIMEOUT_MS, TimeUnit.MILLISECONDS)) return mapOf("skipped" to "timeout")
            return found ?: failed ?: mapOf("skipped" to "no picture")
        } finally {
            reader.close()
            thread.quitSafely()
        }
    }

    /** One keyframe ([sample], in [format]) through [decoderName]. */
    fun keyframe(decoderName: String, format: MediaFormat, sample: ByteArray): Map<String, Any?> =
        run(format.getInteger(MediaFormat.KEY_WIDTH), format.getInteger(MediaFormat.KEY_HEIGHT)) { surface ->
            var codec: MediaCodec? = null
            try {
                codec = MediaCodec.createByCodecName(decoderName)
                codec.configure(format, surface, null, 0)
                codec.start()
                val deadline = System.nanoTime() + TIMEOUT_MS * 1_000_000
                val info = MediaCodec.BufferInfo()
                var sent = 0
                while (System.nanoTime() < deadline) {
                    if (sent < 2) {
                        val at = codec.dequeueInputBuffer(10_000)
                        if (at >= 0) {
                            if (sent == 0) {
                                codec.getInputBuffer(at)!!.put(sample)
                                codec.queueInputBuffer(at, 0, sample.size, 0, 0)
                            } else {
                                // The end, so a decoder that waits for more
                                // hands the frame over.
                                codec.queueInputBuffer(at, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            }
                            sent++
                        }
                    }
                    val out = codec.dequeueOutputBuffer(info, 10_000)
                    if (out >= 0) {
                        val end = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                        codec.releaseOutputBuffer(out, info.size > 0)
                        if (info.size > 0) return@run null
                        if (end) return@run mapOf("skipped" to "no frame")
                    }
                }
                mapOf("skipped" to "timeout")
            } catch (e: Exception) {
                mapOf("skipped" to "decoder unavailable: ${e.message ?: e.javaClass.simpleName}")
            } finally {
                try {
                    codec?.stop()
                } catch (_: Exception) {
                }
                codec?.release()
            }
        }

    @RequiresApi(28)
    private fun describe(image: Image): Map<String, Any?> {
        val buffer = image.hardwareBuffer
        val crop = image.cropRect
        return mapOf(
            "image_width" to image.width,
            "image_height" to image.height,
            "image_format" to "0x" + Integer.toHexString(image.format),
            "crop" to "${crop.left},${crop.top},${crop.right},${crop.bottom}",
            "buffer_format" to buffer?.let { "0x" + Integer.toHexString(it.format) },
            "buffer_width" to buffer?.width,
            "buffer_height" to buffer?.height,
            "buffer_layers" to buffer?.layers,
            "buffer_usage" to buffer?.let { "0x" + java.lang.Long.toHexString(it.usage) },
        ).also { buffer?.close() }
    }
}
