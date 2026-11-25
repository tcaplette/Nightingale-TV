package com.coffeehauslabs.nightingale_tv

/** Which renderer Flutter starts with (android-playback, "NVIDIA Shield draws
 *  the interface through OpenGL ES"). Impeller was turned off on NVIDIA
 *  devices when Flutter still drew the video: its Vulkan backend imported the
 *  video's buffers wrongly on Tegra drivers. The video is on a system layer
 *  now (VideoLayer), so the picture no longer depends on this; the interface
 *  keeps Skia on OpenGL ES there, the renderer Shields have been running, as
 *  Impeller on a Shield can't be checked here (system-video-layer D6).
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
