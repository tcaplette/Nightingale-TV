package com.coffeehauslabs.nightingale_tv

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.accessibility.CaptioningManager
import android.view.KeyEvent
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
        // Android 12+: the splash goes at once, not with its fade, since the
        // launch screen under it shows the same bird in the same place.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
        // A setup handed over by the other Nightingale TV app (not again
        // when the activity is recreated).
        if (savedInstanceState == null) installSwitching.onIntent(intent)
        // Android's default focus highlight would outline the whole picture
        // once a key is pressed (phones, tablets and boxes with a keyboard,
        // remote or air mouse); the app draws its own focus.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            findViewById<View>(FLUTTER_VIEW_ID)?.defaultFocusHighlightEnabled = false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        installSwitching.onIntent(intent)
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

    /** The video report's self-test (video-report D5), with the engine's
     *  texture registry. */
    private var selfTest: VideoSelfTest? = null

    private val deviceImages = DeviceImages(this)

    private val backupFiles = BackupFiles(this)

    private val installSwitching = InstallSwitching(this)

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

    /** Why this engine runs Impeller on OpenGL ES, or null for the default
     *  renderer (RendererChoice). */
    private var rendererReason: String? = null

    /** On an NVIDIA device (or a debug build told to act as one), an engine
     *  with Impeller on OpenGL ES; otherwise null, so FlutterActivity builds
     *  its usual engine. The engine registers the plugins itself, and
     *  configureFlutterEngine runs as on the default path. */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val reason = RendererChoice.reason(
            Build.MANUFACTURER,
            debuggable,
            intent?.getBooleanExtra(RendererChoice.DEBUG_EXTRA, false) == true,
        )
        rendererReason = reason
        // In logcat in every build (release builds keep Dart's prints out).
        Log.i("NightingaleTV", "renderer: ${RendererChoice.describe(reason)}")
        if (reason == null) return null
        return FlutterEngine(context, RendererChoice.engineArguments(reason))
    }

    /** An engine made in provideFlutterEngine goes with the activity, as the
     *  default one does (FlutterActivity keeps a supplied engine otherwise). */
    override fun shouldDestroyEngineWithHost(): Boolean = rendererReason != null || super.shouldDestroyEngineWithHost()

    private var platformChannel: MethodChannel? = null

    /** An on-screen keyboard holds the D-pad while it's up, and its own caret
     *  keys go straight to Flutter, past here. So a Left or Right here came
     *  from the remote and the keyboard is closed, even one that reports no
     *  inset (text-entry). Sent first: it arrives ahead of the key itself. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_DPAD_LEFT || event.keyCode == KeyEvent.KEYCODE_DPAD_RIGHT)
        ) {
            platformChannel?.invokeMethod("dpadArrow", null)
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/platform")
            .also { platformChannel = it }
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceName" -> result.success(deviceName())
                    "isTelevision" -> result.success(
                        (getSystemService(UI_MODE_SERVICE) as UiModeManager).currentModeType ==
                            Configuration.UI_MODE_TYPE_TELEVISION
                    )
                    // The browser, e.g. for plex.tv/link on a phone.
                    "openUrl" -> result.success(
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(call.arguments as String)))
                            true
                        } catch (e: Exception) {
                            false
                        }
                    )
                    // The sleep timer (sleep-timer spec): asleep, the device's
                    // own screensaver and sleep take over; awake, held on again.
                    "keepScreenOn" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    // The system caption size, a viewer's starting caption size.
                    "captionFontScale" -> result.success(
                        (getSystemService(CAPTIONING_SERVICE) as? CaptioningManager)?.fontScale?.toDouble()
                    )
                    // The renderer asked for at start-up, for the diagnostics.
                    "renderer" -> result.success(RendererChoice.describe(rendererReason))
                    // Android's API level (error reports pick their SDK by it).
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    // The household's names, taken out of Java/Kotlin crash
                    // reports (error-reporting D4).
                    "reportNames" -> {
                        io.sentry.flutter.NightingaleScrub.names =
                            (call.arguments as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                        result.success(null)
                    }
                    // The error reporting check's forced error: a debug.*
                    // property, which only adb (or root) can set.
                    "forcedError" -> result.success(
                        try {
                            Class.forName("android.os.SystemProperties")
                                .getMethod("get", String::class.java)
                                .invoke(null, "debug.nightingale_tv.force_error") as String
                        } catch (e: Exception) {
                            ""
                        }
                    )
                    else -> if (!videoReportCall(call, result)) result.notImplemented()
                }
            }
        // Pictures on the device, for icons where there's no document picker.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/images")
            .setMethodCallHandler(deviceImages)
        // Saving backup files with the document picker, where there is one.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/files")
            .setMethodCallHandler(backupFiles)
        // The official app and the own build: which this is, and moving a
        // setup between them.
        installSwitching.channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/install")
            .also { it.setMethodCallHandler(installSwitching) }
        // Full screen from the portrait watch screen (phones and tablets).
        fullScreen.channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/orientation")
            .also { it.setMethodCallHandler(fullScreen) }
        // The video report (lib/reporting/video_report.dart).
        selfTest = VideoSelfTest(applicationContext, flutterEngine.renderer)
        VideoReport.watchForBackend()
        // The players (lib/playback/exo_tuner_player.dart).
        val host = ExoTunerHost(applicationContext, flutterEngine.renderer, flutterEngine.dartExecutor.binaryMessenger)
        players = host
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nightingale_tv/player").setMethodCallHandler(host)
    }

    /** The video report's methods on `nightingale_tv/platform` (video-report
     *  D4, D5, D7, D9, D13); false when [call] isn't one. Anything that
     *  blocks runs off the main thread. */
    private fun videoReportCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result): Boolean {
        val test = selfTest ?: return false
        fun card() = VideoSelfTest.cards[call.argument<String>("card")]
            ?: throw IllegalArgumentException("no card ${call.argument<String>("card")}")
        fun decoder() = call.argument<String>("decoder")!!
        when (call.method) {
            "videoFacts" -> test.background({ VideoReport.facts(this, RendererChoice.describe(rendererReason)) }) { result.success(it) }
            "videoLogcat" -> test.background({ VideoReport.logcat() }) { result.success(it) }
            "videoCapture" -> VideoReport.captureScreen(this) { result.success(it) }
            "videoFault" -> result.success(VideoReport.fault(this))
            "selfTestDecoder" -> test.background({ test.decoder(card()) }) { result.success(it) }
            "selfTestCpu" -> test.background({ test.cpu(card(), decoder()) }) { result.success(it) }
            "selfTestProbe" -> test.background({ test.probe(card(), decoder()) }) { result.success(it) }
            "selfTestTexture" -> {
                val gl = call.argument<Boolean>("gl") == true
                if (gl) {
                    // Only where the engine runs Impeller on OpenGL ES.
                    test.background({ VideoSelfTest.surfaceTextureSkip(VideoReport.backendInUse()) }) { skip ->
                        if (skip != null) result.success(mapOf("skipped" to skip))
                        else test.texture(card(), decoder(), true) { result.success(it) }
                    }
                } else {
                    test.texture(card(), decoder(), false) { result.success(it) }
                }
            }
            "selfTestRelease" -> {
                test.release(call.argument<Number>("id")!!.toLong())
                result.success(null)
            }
            else -> return false
        }
        return true
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
