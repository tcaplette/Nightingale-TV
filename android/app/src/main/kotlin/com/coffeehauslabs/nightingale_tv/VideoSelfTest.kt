package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.graphics.ImageFormat
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo.CodecCapabilities
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Format
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import io.flutter.FlutterInjector
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/** The video report's self-test (video-report, design D5): the bundled test
 *  cards decoded by the hardware decoder playback would pick. Dart drives it
 *  one run at a time:
 *  - [decoder]: which decoder takes the card, or why the card is skipped;
 *  - [cpu]: the first frame decoded into memory the app reads, as RGBA;
 *  - [probe]: the first frame decoded into a hardware buffer, and what that
 *    buffer is ([VideoBufferProbe]).
 *  Each run releases its decoder before the next and gives up after
 *  [TIMEOUT_MS]. Playback goes on beside it: Android does not reclaim a
 *  codec from the calling process for itself. */
@UnstableApi
class VideoSelfTest(private val context: Context) {

    /** A test card: its file and what it is. */
    data class Card(
        val name: String,
        val mime: String,
        val codecs: String?,
        val tenBit: Boolean,
        val width: Int = 1920,
        val height: Int = 1080,
        val extension: String = "mp4",
        /** The matrix its colours are in; BT.709 otherwise. */
        val bt601: Boolean = false,
    )

    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "ntv-self-test") }
    private val main = Handler(Looper.getMainLooper())

    /** Work for [worker] (anything that blocks), its answer on the main
     *  thread. */
    fun background(work: () -> Any?, done: (Any?) -> Unit) {
        worker.execute {
            val result = try {
                work()
            } catch (e: Throwable) {
                mapOf("error" to (e.message ?: e.toString()))
            }
            main.post { done(result) }
        }
    }

    /** The card's file: copied out of the app's assets once. */
    private fun file(card: Card): File {
        val out = File(context.cacheDir, "video_test/${card.name}.${card.extension}")
        if (out.exists() && out.length() > 0) return out
        out.parentFile?.mkdirs()
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/video_test/${card.name}.${card.extension}")
        context.assets.open(key).use { input -> out.outputStream().use { input.copyTo(it) } }
        return out
    }

    /** The decoder playback would pick for [card] (hardware only, best
     *  format support first), or why there's none to run. */
    fun decoder(card: Card): Map<String, Any?> {
        val format = Format.Builder()
            .setSampleMimeType(card.mime)
            .setCodecs(card.codecs)
            .setWidth(card.width)
            .setHeight(card.height)
            .build()
        val software = VideoReport.debugFlag(context, "software_video")
        val hardware = MediaCodecUtil.getDecoderInfos(card.mime, false, false).filter { DeviceCapabilities.isHardware(it) != software }
        val sorted = MediaCodecUtil.getDecoderInfosSortedByFormatSupport(context, hardware, format)
        val chosen = sorted.firstOrNull { it.isFormatSupported(context, format) }
        val maxInstances = chosen?.capabilities?.maxSupportedInstances ?: 0
        val skipped = skipReason(chosen != null, maxInstances)
        return mapOf(
            "decoder" to chosen?.name,
            "max_instances" to maxInstances,
            "skipped" to skipped,
        )
    }

    /** Decodes [card]'s first frame with [decoderName] in buffer mode and
     *  converts it to RGBA with its matrix, limited range, at its bit depth. */
    fun cpu(card: Card, decoderName: String): Map<String, Any?> = firstFrame(card, decoderName, null) { codec, index, _ ->
        val image = codec.getOutputImage(index) ?: return@firstFrame mapOf("error" to "no output image")
        image.use { rgbaOf(it, card) }
    }

    /** The decoder's output in a hardware buffer: what that buffer is. */
    fun probe(card: Card, decoderName: String): Map<String, Any?> = VideoBufferProbe.run(card.width, card.height) { surface ->
        val done = firstFrame(card, decoderName, surface) { codec, index, _ ->
            codec.releaseOutputBuffer(index, true)
            null
        }
        done.ifEmpty { null }
    }

    /** Feeds [card] to [decoderName] until its first frame is out, and hands
     *  that output buffer to [use] (which releases it, or not); nothing from
     *  it is an empty answer. The decoder is released after. */
    private fun firstFrame(
        card: Card,
        decoderName: String,
        surface: android.view.Surface?,
        use: (MediaCodec, Int, MediaCodec.BufferInfo) -> Map<String, Any?>?,
    ): Map<String, Any?> {
        val deadline = System.nanoTime() + TIMEOUT_MS * 1_000_000
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(file(card).path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
            } ?: return mapOf("error" to "no video track")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            if (surface == null) {
                format.setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    if (card.tenBit && Build.VERSION.SDK_INT >= 33) CodecCapabilities.COLOR_FormatYUVP010
                    else CodecCapabilities.COLOR_FormatYUV420Flexible,
                )
            }
            codec = try {
                MediaCodec.createByCodecName(decoderName).also {
                    it.configure(format, surface, null, 0)
                    it.start()
                }
            } catch (e: Exception) {
                // No instance to spare beside playback, or the decoder won't
                // take this configuration: the run is skipped, not failed.
                return mapOf("skipped" to "decoder unavailable: ${e.message ?: e.javaClass.simpleName}")
            }
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            while (System.nanoTime() < deadline) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buffer = codec.getInputBuffer(inIndex)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(info, 10_000)
                if (outIndex >= 0) {
                    if (info.size > 0 || surface != null) {
                        return use(codec, outIndex, info) ?: emptyMap()
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return mapOf("error" to "no frame before the end")
                }
            }
            return mapOf("skipped" to "timeout")
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    /** [image] (YUV_420_888, or P010 for 10-bit) as RGBA over its crop. */
    private fun rgbaOf(image: Image, card: Card): Map<String, Any?> {
        val tenBit = when (image.format) {
            ImageFormat.YUV_420_888 -> false
            ImageFormat.YCBCR_P010 -> true
            else -> return mapOf("error" to "image format 0x${Integer.toHexString(image.format)}")
        }
        val crop = image.cropRect
        val p = image.planes
        val rgba = YuvConvert.toRgba(
            crop.width(), crop.height(), crop.left, crop.top,
            YuvConvert.Plane(p[0].buffer, p[0].rowStride, p[0].pixelStride),
            YuvConvert.Plane(p[1].buffer, p[1].rowStride, p[1].pixelStride),
            YuvConvert.Plane(p[2].buffer, p[2].rowStride, p[2].pixelStride),
            tenBit,
            card.bt601,
        )
        return mapOf(
            "rgba" to rgba,
            "width" to crop.width(),
            "height" to crop.height(),
            "image_format" to "0x" + Integer.toHexString(image.format),
            "bit_depth" to if (tenBit) 10 else 8,
            "card_bit_depth" to if (card.tenBit) 10 else 8,
        )
    }

    companion object {
        const val TIMEOUT_MS = 5_000L

        val cards = listOf(
            Card("h264", "video/avc", "avc1.640028", false),
            Card("hevc", "video/hevc", "hvc1.1.6.L120.90", false),
            Card("hevc10", "video/hevc", "hvc1.2.4.L120.90", true),
            // A width decoders pad (720 in 768).
            Card("mpeg2", "video/mpeg2", null, false, 720, 480, "ts", bt601 = true),
        ).associateBy { it.name }

        /** Why a card's runs can't go (design D5), or null. */
        fun skipReason(decoderFound: Boolean, maxInstances: Int): String? = when {
            !decoderFound -> "no hardware decoder"
            maxInstances == 1 -> "single instance"
            else -> null
        }
    }
}

/** YUV to RGBA with BT.709 (or BT.601) limited range (video-report, design D5): 8-bit
 *  samples, or P010 (10 bits in the top of each little-endian 16-bit
 *  sample). Chroma is taken from the 2×2 block each pixel is in. */
object YuvConvert {
    class Plane(val buffer: ByteBuffer, val rowStride: Int, val pixelStride: Int)

    fun toRgba(width: Int, height: Int, left: Int, top: Int, y: Plane, u: Plane, v: Plane, tenBit: Boolean, bt601: Boolean = false): ByteArray {
        val out = ByteArray(width * height * 4)
        val scale = if (tenBit) 4.0 else 1.0
        val yBlack = 16 * scale
        val yRange = 219 * scale
        val cMid = 128 * scale
        val cRange = 224 * scale
        fun sample(p: Plane, x: Int, row: Int): Int {
            val at = row * p.rowStride + x * p.pixelStride
            return if (tenBit) {
                (((p.buffer.get(at + 1).toInt() and 0xff) shl 8) or (p.buffer.get(at).toInt() and 0xff)) ushr 6
            } else {
                p.buffer.get(at).toInt() and 0xff
            }
        }
        var o = 0
        for (row in 0 until height) {
            val sy = top + row
            for (col in 0 until width) {
                val sx = left + col
                val yy = (sample(y, sx, sy) - yBlack) / yRange
                val cb = (sample(u, sx / 2, sy / 2) - cMid) / cRange
                val cr = (sample(v, sx / 2, sy / 2) - cMid) / cRange
                if (bt601) {
                    out[o] = channel(yy + 1.402 * cr)
                    out[o + 1] = channel(yy - 0.3441 * cb - 0.7141 * cr)
                    out[o + 2] = channel(yy + 1.772 * cb)
                } else {
                    out[o] = channel(yy + 1.5748 * cr)
                    out[o + 1] = channel(yy - 0.1873 * cb - 0.4681 * cr)
                    out[o + 2] = channel(yy + 1.8556 * cb)
                }
                out[o + 3] = 255.toByte()
                o += 4
            }
        }
        return out
    }

    private fun channel(v: Double): Byte = Math.round(v * 255).coerceIn(0, 255).toInt().toByte()
}
