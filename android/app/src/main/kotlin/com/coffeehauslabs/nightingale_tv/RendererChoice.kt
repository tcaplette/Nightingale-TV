package com.coffeehauslabs.nightingale_tv

/** Which renderer Flutter starts with (android-playback, "NVIDIA Shield draws
 *  video through OpenGL ES"). Impeller's Vulkan backend imports the video's
 *  hardware buffers wrongly on Tegra drivers (red and green carry each
 *  pixel's texture position, only blue the picture), so every channel's
 *  colours are off on a Shield while the menus look right. On NVIDIA devices
 *  Impeller is turned off, so Flutter draws with Skia on OpenGL ES, where the
 *  driver converts the frames itself as an external texture.
 *
 *  `--impeller-backend=opengles` can't do this: release engines ignore it
 *  (flutter_main.cc reads the requested backend only outside
 *  FLUTTER_RELEASE) and pick Vulkan. `--enable-impeller=false` is honoured
 *  in release builds. Every other device starts as before. */
object RendererChoice {
    /** The engine argument that turns Impeller off: Skia on OpenGL ES. */
    const val SKIA_ARGUMENT = "--enable-impeller=false"

    /** The launch intent extra that makes any device count as a Shield, in a
     *  debuggable build only, so the switch can be tested on an emulator. */
    const val DEBUG_EXTRA = "ntv_treat_as_shield"

    /** Why Skia OpenGL ES is asked for ("nvidia" or "debug override"), or null for
     *  the default renderer. */
    fun reason(manufacturer: String?, debuggable: Boolean, overrideAsked: Boolean): String? = when {
        manufacturer.equals("NVIDIA", ignoreCase = true) -> "nvidia"
        debuggable && overrideAsked -> "debug override"
        else -> null
    }

    /** The engine arguments for [reason]: none for the default renderer. */
    fun engineArguments(reason: String?): Array<String> =
        if (reason == null) emptyArray() else arrayOf(SKIA_ARGUMENT)

    /** The diagnostics wording: "skia opengles (nvidia)" or "default". */
    fun describe(reason: String?): String = if (reason == null) "default" else "skia opengles ($reason)"
}
