package com.coffeehauslabs.nightingale_tv

import android.app.UiModeManager
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Like a TV: the screen never dims, locks or starts the screensaver
        // while the app is in front (and only then, so no wakelock).
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onDestroy() {
        val leaving = !isChangingConfigurations
        players?.disposeAll()
        super.onDestroy()
        // The engine goes with the activity, so the process ends too
        // (quitting with Back, or the system closing the app): the next
        // launch starts clean, with no players left from this engine.
        if (leaving) Process.killProcess(Process.myPid())
    }

    private var players: ExoTunerHost? = null

    private val deviceImages = DeviceImages(this)

    private val backupFiles = BackupFiles(this)

    // Lazy: its sensor listener needs the activity attached.
    private val fullScreen by lazy { FullScreenOrientation(this) }

    override fun onResume() {
        super.onResume()
        fullScreen.onResume()
    }

    override fun onPause() {
        fullScreen.onPause()
        super.onPause()
    }

    @Deprecated("Flutter's embedding still delivers results here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!backupFiles.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!deviceImages.onPermissionResult(requestCode, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceName" -> result.success(deviceName())
                    "isTelevision" -> result.success(
                        (getSystemService(UI_MODE_SERVICE) as UiModeManager).currentModeType ==
                            Configuration.UI_MODE_TYPE_TELEVISION
                    )
                    else -> result.notImplemented()
                }
            }
        // Pictures on the device, for icons where there's no document picker.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/images")
            .setMethodCallHandler(deviceImages)
        // Saving backup files with the document picker, where there is one.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/files")
            .setMethodCallHandler(backupFiles)
        // Full screen from the portrait watch screen (phones and tablets).
        fullScreen.channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/orientation")
            .also { it.setMethodCallHandler(fullScreen) }
        // The players (lib/playback/exo_tuner_player.dart).
        val host = ExoTunerHost(applicationContext, flutterEngine.renderer, flutterEngine.dartExecutor.binaryMessenger)
        players = host
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/player").setMethodCallHandler(host)
    }

    /** The name Jellyfin shows: the one set in Android's settings, or the
     *  maker and model ("NVIDIA SHIELD Android TV"). */
    private fun deviceName(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            val named = Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
            if (!named.isNullOrBlank()) return named.trim()
        }
        val model = Build.MODEL.trim()
        if (model.startsWith(Build.MANUFACTURER, ignoreCase = true)) return model
        return "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} $model"
    }
}
