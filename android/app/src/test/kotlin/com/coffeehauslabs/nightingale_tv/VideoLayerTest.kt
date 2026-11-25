package com.coffeehauslabs.nightingale_tv

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VideoLayerTest {
    private fun edges(l: Double, t: Double, r: Double, b: Double) = VideoLayer.edges(l, t, r, b)

    @Test
    fun wholePixelsStay() {
        assertArrayEquals(intArrayOf(0, 0, 1920, 1080), edges(0.0, 0.0, 1920.0, 1080.0))
        assertArrayEquals(intArrayOf(240, 0, 1680, 1080), edges(240.0, 0.0, 1680.0, 1080.0))
    }

    @Test
    fun fractionsAreCovered() {
        assertArrayEquals(intArrayOf(174, 0, 1746, 1080), edges(174.75, 0.0, 1745.25, 1080.0))
        assertArrayEquals(intArrayOf(0, 139, 1920, 941), edges(0.0, 139.5, 1920.0, 940.5))
    }

    @Test
    fun aScalingErrorTakesNoPixel() {
        assertArrayEquals(intArrayOf(240, 0, 1680, 1080), edges(239.999, 0.0001, 1680.001, 1079.9999))
        assertArrayEquals(intArrayOf(240, 0, 1680, 1080), edges(240.001, 0.0, 1679.995, 1080.004))
    }

    @Test
    fun largerThanTheScreenStaysLarger() {
        // A 16:9 picture filling a 4:3 frame.
        assertArrayEquals(intArrayOf(0, -135, 1920, 1215), edges(0.0, -135.0, 1920.0, 1215.0))
        assertArrayEquals(intArrayOf(-240, 0, 2160, 1350), edges(-240.0, 0.0, 2160.0, 1350.0))
    }

    @Test
    fun nothingHasNoPlace() {
        assertNull(edges(0.0, 0.0, 0.0, 0.0))
        assertNull(edges(10.0, 10.0, 10.2, 500.0))
        assertNull(edges(Double.NaN, 0.0, 100.0, 100.0))
    }
}
