package com.coffeehauslabs.nightingale_tv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.nio.ByteBuffer

class VideoSelfTestTest {
    private fun rgb(out: ByteArray, pixel: Int) =
        Triple(out[pixel * 4].toInt() and 0xff, out[pixel * 4 + 1].toInt() and 0xff, out[pixel * 4 + 2].toInt() and 0xff)

    /** A 2×2 frame of one colour, 8-bit planar (I420-like strides). */
    private fun frame8(y: Int, u: Int, v: Int): Triple<YuvConvert.Plane, YuvConvert.Plane, YuvConvert.Plane> {
        val yp = ByteBuffer.wrap(ByteArray(4) { y.toByte() })
        return Triple(
            YuvConvert.Plane(yp, 2, 1),
            YuvConvert.Plane(ByteBuffer.wrap(byteArrayOf(u.toByte())), 1, 1),
            YuvConvert.Plane(ByteBuffer.wrap(byteArrayOf(v.toByte())), 1, 1),
        )
    }

    /** The same as P010: 16-bit little-endian samples, 10 bits at the top,
     *  chroma interleaved (U and V planes share one buffer, 4 bytes apart). */
    private fun frameP010(y: Int, u: Int, v: Int): Triple<YuvConvert.Plane, YuvConvert.Plane, YuvConvert.Plane> {
        fun put(b: ByteArray, at: Int, value: Int) {
            val s = value shl 6
            b[at] = (s and 0xff).toByte()
            b[at + 1] = ((s shr 8) and 0xff).toByte()
        }
        val yb = ByteArray(8).also { for (i in 0 until 4) put(it, i * 2, y) }
        val uv = ByteArray(4).also { put(it, 0, u); put(it, 2, v) }
        val uvBuffer = ByteBuffer.wrap(uv)
        return Triple(
            YuvConvert.Plane(ByteBuffer.wrap(yb), 4, 2),
            YuvConvert.Plane(uvBuffer, 4, 4),
            YuvConvert.Plane(ByteBuffer.wrap(uv, 2, 2).slice(), 4, 4),
        )
    }

    private fun convert(f: Triple<YuvConvert.Plane, YuvConvert.Plane, YuvConvert.Plane>, tenBit: Boolean) =
        YuvConvert.toRgba(2, 2, 0, 0, f.first, f.second, f.third, tenBit)

    private fun assertNear(expected: Triple<Int, Int, Int>, actual: Triple<Int, Int, Int>) {
        for ((e, a) in listOf(expected.first to actual.first, expected.second to actual.second, expected.third to actual.third)) {
            if (kotlin.math.abs(e - a) > 2) throw AssertionError("expected $expected, got $actual")
        }
    }

    @Test
    fun eightBitBt709LimitedRange() {
        // Limited range: 16 is black, 235 white, chroma 128 neutral.
        assertEquals(Triple(0, 0, 0), rgb(convert(frame8(16, 128, 128), false), 0))
        assertEquals(Triple(255, 255, 255), rgb(convert(frame8(235, 128, 128), false), 3))
        // BT.709 75% red (191, 0, 0): Y 51, Cb 109, Cr 212.
        assertNear(Triple(191, 0, 0), rgb(convert(frame8(51, 109, 212), false), 0))
        // 75% blue (0, 0, 191): Y 28, Cb 212, Cr 120.
        assertNear(Triple(0, 0, 191), rgb(convert(frame8(28, 212, 120), false), 0))
    }

    @Test
    fun tenBitP010() {
        // The same colours at 10 bits: black 64, white 940, neutral 512.
        assertEquals(Triple(0, 0, 0), rgb(convert(frameP010(64, 512, 512), true), 0))
        assertEquals(Triple(255, 255, 255), rgb(convert(frameP010(940, 512, 512), true), 3))
        assertNear(Triple(191, 0, 0), rgb(convert(frameP010(51 * 4, 109 * 4, 212 * 4), true), 0))
        // Mid grey: 10-bit 502 is 8-bit 125.5 → (128, 128, 128).
        assertNear(Triple(128, 128, 128), rgb(convert(frameP010(502, 512, 512), true), 1))
    }

    @Test
    fun cropOffsetsAreHonoured() {
        // 4×2 luma, left half black, right half white; crop the right half.
        val y = YuvConvert.Plane(ByteBuffer.wrap(byteArrayOf(16, 16, -21, -21, 16, 16, -21, -21)), 4, 1)
        val c = YuvConvert.Plane(ByteBuffer.wrap(byteArrayOf(-128, -128)), 2, 1)
        val out = YuvConvert.toRgba(2, 2, 2, 0, y, c, c, false)
        assertEquals(Triple(255, 255, 255), rgb(out, 0))
    }

    @Test
    fun skipReasons() {
        assertEquals("no hardware decoder", VideoSelfTest.skipReason(decoderFound = false, maxInstances = 0))
        assertEquals("single instance", VideoSelfTest.skipReason(decoderFound = true, maxInstances = 1))
        assertNull(VideoSelfTest.skipReason(decoderFound = true, maxInstances = 16))
        assertEquals("vulkan", VideoSelfTest.surfaceTextureSkip("Vulkan"))
        assertEquals("vulkan", VideoSelfTest.surfaceTextureSkip("Vulkan with Validation Layers"))
        assertEquals("vulkan", VideoSelfTest.surfaceTextureSkip(null))
        assertNull(VideoSelfTest.surfaceTextureSkip("OpenGLES"))
        assertNull(VideoSelfTest.surfaceTextureSkip("Skia OpenGLES"))
        assertEquals(5_000L, VideoSelfTest.TIMEOUT_MS)
    }

    @Test
    fun theBackendLineIsFound() {
        val log = """
            11-09 14:00:01.000 I/flutter (1234): Using the Impeller rendering backend (OpenGLES).
            11-09 14:00:02.000 I/flutter (1234): something else
        """.trimIndent()
        assertEquals("OpenGLES", VideoReport.parseBackend(log))
        assertEquals("Vulkan", VideoReport.parseBackend("I/flutter: Using the Impeller rendering backend (Vulkan)."))
        assertNull(VideoReport.parseBackend("I/flutter: no line here"))
    }

    @Test
    fun skiaIsReadFromTheOptOutLine() {
        val optOut = "11-10 09:00:01.000  2404  2404 W flutter : [Action Required]: Impeller opt-out deprecated."
        assertEquals("Skia OpenGLES", VideoReport.parseBackend("$optOut\n11-10 09:00:02.000 I flutter : later"))
        assertEquals(VideoReport.SKIA_BACKEND, VideoReport.parseBackend(optOut))
        // The backend line wins when both are there.
        assertEquals("Vulkan", VideoReport.parseBackend("$optOut\nI/flutter: Using the Impeller rendering backend (Vulkan)."))
        assertNull(VideoReport.parseBackend("11-10 09:00:01.000 I flutter : neither line"))
        assertEquals("$optOut\nlater", VideoReport.withBackendLine("later", optOut))
    }

    @Test
    fun theBackendLineLeadsTheLog() {
        val line = "11-09 13:30:01.569  2404  2404 I flutter : Using the Impeller rendering backend (OpenGLES)."
        assertEquals("$line\nlater", VideoReport.withBackendLine("later", line))
        assertEquals("a\n$line\nb", VideoReport.withBackendLine("a\n$line\nb", line))
        assertEquals("later", VideoReport.withBackendLine("later", null))
    }

    @Test
    fun producerKindFollowsFlutter() {
        assertEquals("image_reader", VideoReport.producerKind(29, "Google"))
        assertEquals("image_reader", VideoReport.producerKind(36, "NVIDIA"))
        assertEquals("surface_texture", VideoReport.producerKind(28, "NVIDIA"))
        assertEquals("surface_texture", VideoReport.producerKind(29, "HUAWEI"))
        assertEquals("image_reader", VideoReport.producerKind(30, "HUAWEI"))
    }

    @Test
    fun logcatTailIsCappedAtALineStart() {
        val text = (1..100).joinToString("\n") { "line $it" }
        val capped = VideoReport.capTail(text, 40)
        assert(capped.toByteArray().size <= 40)
        assert(capped.startsWith("line "))
        assert(capped.endsWith("line 100"))
        assertEquals(text, VideoReport.capTail(text, 10_000))
    }
}
