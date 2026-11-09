package com.coffeehauslabs.nightingale_tv

/** Which renderer Flutter starts with (android-playback, "NVIDIA Shield draws
 *  video through OpenGL ES"). Impeller's Vulkan backend converts the video's
 *  YUV hardware buffers to RGB wrongly on Tegra drivers, so every channel's
 *  colours are off on a Shield while the menus look right. On NVIDIA devices
 *  Impeller runs on OpenGL ES instead, where the driver converts the frames
 *  itself as an external texture. Every other device starts as before. */
object RendererChoice {
    /** The engine argument that puts Impeller on OpenGL ES. */
    const val OPENGLES_ARGUMENT = "--impeller-backend=opengles"

    /** The launch intent extra that makes any device count as a Shield, in a
     *  debuggable build only, so the switch can be tested on an emulator. */
    const val DEBUG_EXTRA = "ntv_treat_as_shield"

    /** Why OpenGL ES is asked for ("nvidia" or "debug override"), or null for
     *  the default renderer. */
    fun reason(manufacturer: String?, debuggable: Boolean, overrideAsked: Boolean): String? = when {
        manufacturer.equals("NVIDIA", ignoreCase = true) -> "nvidia"
        debuggable && overrideAsked -> "debug override"
        else -> null
    }

    /** The engine arguments for [reason]: none for the default renderer. */
    fun engineArguments(reason: String?): Array<String> =
        if (reason == null) emptyArray() else arrayOf(OPENGLES_ARGUMENT)

    /** The diagnostics wording: "impeller opengles (nvidia)" or "default". */
    fun describe(reason: String?): String = if (reason == null) "default" else "impeller opengles ($reason)"
}
