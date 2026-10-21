package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.content.pm.ActivityInfo
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.OrientationEventListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Full screen from the portrait watch screen (lib/platform/orientation.dart).
 *
 * - `enterFullScreen` turns the app sideways, either way up, even with
 *   auto-rotate off.
 * - `exitFullScreen` turns it upright, and lets go once the phone is held
 *   upright, so a phone still held sideways doesn't flip straight back.
 * - With auto-rotate on, turning the phone from sideways back to upright in
 *   full screen leaves it, and tells Dart (`fullScreenEnded`).
 *
 * Phones and tablets only; TVs never call it.
 */
class FullScreenOrientation(private val activity: Activity) : MethodChannel.MethodCallHandler {
    var channel: MethodChannel? = null

    private var fullScreen = false

    /** Upright after full screen, until the phone is held upright. */
    private var holdingUpright = false

    /** The phone was held sideways during this full screen. */
    private var seenSideways = false

    /** How the phone was last held. Kept while not listening, as the
     *  listener keeps it too: it only reports changes from it. */
    private var degrees = OrientationEventListener.ORIENTATION_UNKNOWN
    private var upright = false
    private var resumed = true

    private val handler = Handler(Looper.getMainLooper())

    private val listener = object : OrientationEventListener(activity) {
        override fun onOrientationChanged(degrees: Int) {
            if (degrees == ORIENTATION_UNKNOWN) return
            this@FullScreenOrientation.degrees = degrees
            val nowUpright = degrees <= UPRIGHT_TOLERANCE || degrees >= 360 - UPRIGHT_TOLERANCE
            if (sideways(degrees)) seenSideways = true
            if (nowUpright == upright) return
            upright = nowUpright
            handler.removeCallbacks(heldUpright)
            if (upright) handler.postDelayed(heldUpright, HOLD_MS)
        }
    }

    /** Held within 30° of upright for half a second. */
    private val heldUpright = Runnable {
        if (holdingUpright) {
            release()
        } else if (fullScreen && seenSideways && autoRotate()) {
            exit()
            channel?.invokeMethod("fullScreenEnded", null)
        }
        updateListening()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enterFullScreen" -> {
                fullScreen = true
                holdingUpright = false
                handler.removeCallbacks(unlessSideways)
                seenSideways = sideways(degrees)
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                updateListening()
                result.success(null)
            }
            "exitFullScreen" -> {
                exit()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun exit() {
        fullScreen = false
        seenSideways = false
        if (listener.canDetectOrientation()) {
            holdingUpright = true
            activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            // The listener only reports changes: already upright, the
            // half-second starts now.
            handler.removeCallbacks(heldUpright)
            if (upright) handler.postDelayed(heldUpright, HOLD_MS)
            // A phone lying still may report nothing at all: unless it's
            // known to be sideways, let go after a second.
            handler.removeCallbacks(unlessSideways)
            handler.postDelayed(unlessSideways, FALLBACK_MS)
        } else {
            // No sensor to tell when it's upright, and so no auto-rotate.
            holdingUpright = false
            activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        updateListening()
    }

    private val unlessSideways = Runnable {
        if (holdingUpright && !sideways(degrees)) release()
        updateListening()
    }

    /** Follows the user's auto-rotate setting again. */
    private fun release() {
        holdingUpright = false
        handler.removeCallbacks(unlessSideways)
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    }

    fun onResume() {
        resumed = true
        updateListening()
        if (holdingUpright) handler.postDelayed(unlessSideways, FALLBACK_MS)
    }

    fun onPause() {
        resumed = false
        updateListening()
    }

    private fun updateListening() {
        if (resumed && (fullScreen || holdingUpright)) {
            listener.enable()
        } else {
            listener.disable()
            handler.removeCallbacks(heldUpright)
            handler.removeCallbacks(unlessSideways)
        }
    }

    private fun sideways(degrees: Int) = degrees in 60..120 || degrees in 240..300

    private fun autoRotate(): Boolean =
        Settings.System.getInt(activity.contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1

    private companion object {
        const val UPRIGHT_TOLERANCE = 30
        const val HOLD_MS = 500L
        const val FALLBACK_MS = 1000L
    }
}
