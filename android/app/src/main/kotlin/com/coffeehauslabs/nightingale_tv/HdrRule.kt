package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi

/** When a stream shows as HDR (system-video-layer D7): the display lists its
 *  format. Otherwise the decoder is asked for SDR, where Android can (13+). */
@UnstableApi
object HdrRule {
    private const val HDR10 = 2
    private const val HLG = 3
    private const val HDR10_PLUS = 4

    /** Whether a stream of [colorTransfer] (a `C.COLOR_TRANSFER_*`) is HDR. */
    fun isHdr(colorTransfer: Int?) = colorTransfer == C.COLOR_TRANSFER_ST2084 || colorTransfer == C.COLOR_TRANSFER_HLG

    /** Whether a display of [types] (its HDR types) shows [colorTransfer]. */
    fun shows(colorTransfer: Int?, types: List<Int>) = when (colorTransfer) {
        C.COLOR_TRANSFER_ST2084 -> HDR10 in types || HDR10_PLUS in types
        C.COLOR_TRANSFER_HLG -> HLG in types
        else -> false
    }

    /** Whether the decoder is asked for SDR output. */
    fun asksForSdr(colorTransfer: Int?, types: List<Int>, sdk: Int) =
        sdk >= 33 && isHdr(colorTransfer) && !shows(colorTransfer, types)

    /** The HDR types of the display the app is on, as they are now; with
     *  `debug.nightingale_tv.hdr_display` in a debuggable build, all of them. */
    @Suppress("DEPRECATION")
    fun displayTypes(context: Context): List<Int> {
        if (VideoReport.debugFlag(context, "hdr_display")) return listOf(HDR10, HLG, HDR10_PLUS)
        val display = context.getSystemService(DisplayManager::class.java)?.getDisplay(Display.DEFAULT_DISPLAY)
            ?: return emptyList()
        val types = if (Build.VERSION.SDK_INT >= 34) display.mode.supportedHdrTypes else display.hdrCapabilities?.supportedHdrTypes
        return types?.toList() ?: emptyList()
    }
}
