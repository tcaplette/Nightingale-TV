package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** The free flavor's store (play-unlock D2): no Google Play Billing, so every
 *  call answers that there's no store. The play flavor has the real one. */
@Suppress("UNUSED_PARAMETER")
class StoreBridge(activity: Activity) : MethodChannel.MethodCallHandler {
    var channel: MethodChannel? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.success(mapOf("available" to false))
    }

    fun end() {}
}
