package com.coffeehauslabs.nightingale_tv

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RendererChoiceTest {
    @Test
    fun nvidiaDevicesUseSkia() {
        assertEquals("nvidia", RendererChoice.reason("NVIDIA", debuggable = false, overrideAsked = false))
        assertEquals("nvidia", RendererChoice.reason("nvidia", debuggable = false, overrideAsked = false))
        assertEquals("nvidia", RendererChoice.reason("Nvidia", debuggable = true, overrideAsked = true))
    }

    @Test
    fun otherManufacturersKeepTheDefault() {
        for (maker in listOf("Google", "Amazon", "Xiaomi", "unknown", "", "NVIDIA Corp", null)) {
            assertNull(maker, RendererChoice.reason(maker, debuggable = false, overrideAsked = false))
            assertNull(maker, RendererChoice.reason(maker, debuggable = true, overrideAsked = false))
        }
    }

    @Test
    fun debugBuildsHonourTheOverride() {
        assertEquals("debug override", RendererChoice.reason("Google", debuggable = true, overrideAsked = true))
    }

    @Test
    fun releaseBuildsIgnoreTheOverride() {
        assertNull(RendererChoice.reason("Google", debuggable = false, overrideAsked = true))
    }

    @Test
    fun engineArguments() {
        assertEquals("--enable-impeller=false", RendererChoice.SKIA_ARGUMENT)
        assertArrayEquals(arrayOf("--enable-impeller=false"), RendererChoice.engineArguments("nvidia"))
        assertArrayEquals(arrayOf("--enable-impeller=false"), RendererChoice.engineArguments("debug override"))
        assertArrayEquals(emptyArray<String>(), RendererChoice.engineArguments(null))
    }

    @Test
    fun diagnosticsWording() {
        assertEquals("skia opengles (nvidia)", RendererChoice.describe("nvidia"))
        assertEquals("skia opengles (debug override)", RendererChoice.describe("debug override"))
        assertEquals("default", RendererChoice.describe(null))
        assertEquals("ntv_treat_as_shield", RendererChoice.DEBUG_EXTRA)
    }
}
