package com.coffeehauslabs.nightingale_tv

import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.File

@UnstableApi
class VideoEffectsTest {
    private val place = listOf(0.5, 0.5, 0.5, 0.5, 0.002, 0.004)
    private val identity = listOf(1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)

    /** Colours (0–1) through GL's column-major 4×4. */
    private fun gl(m: FloatArray, r: Double, g: Double, b: Double) =
        (0..2).map { row -> m[row] * r + m[4 + row] * g + m[8 + row] * b + m[12 + row] }

    @Test
    fun nothingThatChangesTheVideoIsNoLook() {
        assertNull(VideoLook.from(null, 0.0, 0.0, place))
        assertNotNull(VideoLook.from(identity, 0.0, 0.0, place))
        assertNotNull(VideoLook.from(null, 0.05, 0.0, place))
        assertNotNull(VideoLook.from(null, 0.0, 0.3, place))
    }

    @Test
    fun theMatrixIsFlutters() {
        // crtColorMatrix's "faded": mixed channels and an offset of 8 in 255.
        val m = listOf(
            0.76378, 0.21456, 0.02166, 0.0, 8.0,
            0.06378, 0.91456, 0.02166, 0.0, 8.0,
            0.06378, 0.21456, 0.72166, 0.0, 8.0,
            0.0, 0.0, 0.0, 1.0, 0.0,
        )
        for ((r, g, b) in listOf(Triple(1.0, 0.0, 0.0), Triple(0.2, 0.5, 0.9), Triple(0.0, 0.0, 0.0))) {
            val flutter = (0..2).map { m[it * 5] * r + m[it * 5 + 1] * g + m[it * 5 + 2] * b + m[it * 5 + 4] / 255 }
            gl(VideoLook.rgbMatrix(m), r, g, b).zip(flutter).forEach { (a, e) -> assertEquals(e, a, 1e-5) }
        }
    }

    @Test
    fun theOverlayIsAllThereOrNotAtAll() {
        assertEquals(0, VideoLook.from(null, 0.0, 0.3, place)!!.overlay.size)
        assertEquals(0, VideoLook.from(null, 0.0, 0.3, place, listOf(1.0))!!.overlay.size)
        assertEquals(10, VideoLook.from(null, 0.0, 0.3, place, List(VideoLook.OVERLAY_VALUES) { 1.0 })!!.overlay.size)
    }

    /** The video's shader has the interface's sums: shaders/crt.frag. */
    @Test
    fun theTubeIsTheInterfacesOwn() {
        fun sums(text: String) = text.lines().map { it.substringBefore("//").replace(Regex("\\s+"), "") }.filter { it.isNotEmpty() }
        val flutter = sums(File("../../shaders/crt.frag").readText())
        val android = sums(File("src/main/kotlin/com/coffeehauslabs/nightingale_tv/VideoEffects.kt").readText())
        for (line in listOf("c*=1.0+uCurvature*dot(c,c);", "if(abs(c.x)>1.0||abs(c.y)>1.0){")) {
            assert(line in flutter) { "crt.frag: $line" }
            assert(line in android) { "VideoEffects.kt: $line" }
        }
        val glow = Regex("""color\+=max\(blur(\.rgb)?/8\.0-0\.4,0\.0\)\*uGlow;""")
        assert(flutter.any { glow.matches(it) })
        assert(android.any { glow.matches(it) })
    }
}
