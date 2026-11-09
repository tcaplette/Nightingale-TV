package com.coffeehauslabs.nightingale_tv

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RendererChoiceTest {
    @Test
    fun nvidiaDevicesUseOpenGles() {
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
        assertEquals("--impeller-backend=opengles", RendererChoice.OPENGLES_ARGUMENT)
        assertArrayEquals(arrayOf("--impeller-backend=opengles"), RendererChoice.engineArguments("nvidia"))
        assertArrayEquals(arrayOf("--impeller-backend=opengles"), RendererChoice.engineArguments("debug override"))
        assertArrayEquals(emptyArray<String>(), RendererChoice.engineArguments(null))
    }

    @Test
    fun diagnosticsWording() {
        assertEquals("impeller opengles (nvidia)", RendererChoice.describe("nvidia"))
        assertEquals("impeller opengles (debug override)", RendererChoice.describe("debug override"))
        assertEquals("default", RendererChoice.describe(null))
        assertEquals("ntv_treat_as_shield", RendererChoice.DEBUG_EXTRA)
    }
}
