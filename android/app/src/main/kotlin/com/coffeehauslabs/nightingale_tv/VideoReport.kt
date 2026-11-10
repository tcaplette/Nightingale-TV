package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** The device side of a video report (video-report, design D4, D7, D9):
 *  the device, display, GPU and renderer, the app's own log, and a capture of
 *  the screen. Nothing here sends anything; Dart builds the report. */
object VideoReport {
    /** The engine's own line naming the Impeller backend it runs. */
    private val backendLine = Regex("""Using the Impeller rendering backend \(([^)]*)\)""")

    /** The engine's own line saying Impeller was turned off: it runs Skia
     *  on OpenGL ES (RendererChoice). */
    private val skiaLine = Regex("""Impeller opt-out deprecated""")

    /** The backend the engine reported, once found in the log (the line is
     *  written once, at start-up, and can leave the log's ring later). */
    @Volatile private var backend: String? = null

    /** That line itself, as the log has it, for the report's log. */
    @Volatile private var backendLogLine: String? = null

    /** The OpenGL ES strings: the same for the whole run. */
    @Volatile private var gl: Map<String, Any?>? = null

    /** The four extensions the video import needs (design D7). */
    private val glExtensions = listOf("GL_OES_EGL_image_external", "GL_OES_EGL_image_external_essl3")
    private val eglExtensions = listOf("EGL_ANDROID_image_native_buffer", "EGL_ANDROID_get_native_client_buffer")

    /** Whether this is a debuggable build (a debug or profile build). */
    fun debuggable(activity: Activity) = (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Looks for the engine's backend line a few seconds after start-up,
     *  while it's surely still in the log. */
    fun watchForBackend() {
        val thread = HandlerThread("ntv-backend").apply { start() }
        Handler(thread.looper).postDelayed({
            backendInUse()
            thread.quitSafely()
        }, 5_000)
    }

    /** "OpenGLES", "Vulkan"… as the engine wrote it, "Skia OpenGLES" when
     *  the engine says Impeller was opted out, or null when neither line is
     *  in the log (the log unreadable). */
    fun backendInUse(): String? {
        backend?.let { return it }
        val text = runLogcat(listOf("-d", "-v", "threadtime", "--pid=${Process.myPid()}", "-s", "flutter:I"), 512 * 1024)
            ?: return null
        val lines = text.lines()
        backendLogLine = lines.lastOrNull { backendLine.containsMatchIn(it) }
            ?: lines.lastOrNull { skiaLine.containsMatchIn(it) }
        return parseBackend(text)?.also { backend = it }
    }

    /** The backend named by the engine's line in [log], the last one if
     *  there are several; "Skia OpenGLES" when there's no such line but the
     *  engine's Impeller opt-out line is there (design D3). */
    fun parseBackend(log: String): String? =
        backendLine.findAll(log).lastOrNull()?.groupValues?.get(1)
            ?: if (skiaLine.containsMatchIn(log)) SKIA_BACKEND else null

    /** The backend tag when Flutter runs Skia. */
    const val SKIA_BACKEND = "Skia OpenGLES"

    /** Flutter's own rule for the video buffer kind (FlutterRenderer
     *  .createSurfaceProducer): an ImageReader from API 29, except Huawei
     *  devices up to API 29; a SurfaceTexture otherwise. */
    fun producerKind(sdk: Int = Build.VERSION.SDK_INT, manufacturer: String = Build.MANUFACTURER): String =
        if (sdk >= 29 && !(sdk <= 29 && manufacturer.equals("HUAWEI", ignoreCase = true))) "image_reader" else "surface_texture"

    /** The device, display, GPU and renderer (design D7). */
    fun facts(activity: Activity, rendererAsked: String): Map<String, Any?> = mapOf(
        "build" to mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "board" to Build.BOARD,
            "sdk" to Build.VERSION.SDK_INT,
        ),
        "display" to display(activity),
        "gl" to glStrings(),
        "vulkan" to vulkan(activity.packageManager),
        "renderer_asked" to rendererAsked,
        "backend" to (backendInUse() ?: "unknown"),
        "producer" to producerKind(),
    )

    @Suppress("DEPRECATION")
    private fun display(activity: Activity): Map<String, Any?> {
        val d = try {
            if (Build.VERSION.SDK_INT >= 30) activity.display else activity.windowManager.defaultDisplay
        } catch (e: Exception) {
            null
        } ?: return mapOf("error" to "no display")
        fun mode(m: android.view.Display.Mode) = "${m.physicalWidth}x${m.physicalHeight}@${"%.2f".format(java.util.Locale.ROOT, m.refreshRate)}"
        val metrics = activity.resources.displayMetrics
        return mapOf(
            "mode" to mode(d.mode),
            "modes" to d.supportedModes.map { mode(it) },
            "hdr_types" to (d.hdrCapabilities?.supportedHdrTypes?.map { hdrName(it) } ?: emptyList<String>()),
            "wide_color" to (if (Build.VERSION.SDK_INT >= 26) d.isWideColorGamut else null),
            "density_dpi" to metrics.densityDpi,
            "density" to metrics.density.toDouble(),
        )
    }

    private fun hdrName(type: Int) = when (type) {
        1 -> "DolbyVision"
        2 -> "HDR10"
        3 -> "HLG"
        4 -> "HDR10+"
        else -> "type$type"
    }

    /** The Vulkan hardware level and version features (design D7). */
    private fun vulkan(pm: PackageManager): Map<String, Any?> {
        val features = pm.systemAvailableFeatures
        val level = features.firstOrNull { it.name == PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL }?.version
        val version = features.firstOrNull { it.name == PackageManager.FEATURE_VULKAN_HARDWARE_VERSION }?.version
        return mapOf(
            "level" to level,
            "version" to version?.let { "${it ushr 22}.${(it ushr 12) and 0x3ff}.${it and 0xfff}" },
        )
    }

    /** GL vendor, renderer, version and the four extensions, from a
     *  throwaway 1×1 pbuffer context on a thread of its own. */
    private fun glStrings(): Map<String, Any?> {
        gl?.let { return it }
        var result: Map<String, Any?> = mapOf("error" to "timeout")
        val done = CountDownLatch(1)
        Thread({
            result = try {
                readGl()
            } catch (e: Throwable) {
                mapOf("error" to (e.message ?: e.toString()))
            }
            done.countDown()
        }, "ntv-gl-probe").start()
        done.await(3, TimeUnit.SECONDS)
        if (result["error"] == null) gl = result
        return result
    }

    private fun readGl(): Map<String, Any?> {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return mapOf("error" to "eglInitialize")
        try {
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            val attributes = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_NONE,
            )
            if (!EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) || count[0] == 0) {
                return mapOf("error" to "no EGL config")
            }
            val config = configs[0]
            val context = EGL14.eglCreateContext(
                display, config, EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            val surface = EGL14.eglCreatePbufferSurface(display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
            try {
                if (!EGL14.eglMakeCurrent(display, surface, surface, context)) return mapOf("error" to "eglMakeCurrent")
                val ext = (GLES20.glGetString(GLES20.GL_EXTENSIONS) ?: "").split(' ').toSet()
                val eglExt = (EGL14.eglQueryString(display, EGL14.EGL_EXTENSIONS) ?: "").split(' ').toSet()
                return mapOf(
                    "vendor" to GLES20.glGetString(GLES20.GL_VENDOR),
                    "renderer" to GLES20.glGetString(GLES20.GL_RENDERER),
                    "version" to GLES20.glGetString(GLES20.GL_VERSION),
                    "egl_version" to "${version[0]}.${version[1]}",
                    "extensions" to (glExtensions.associateWith { it in ext } + eglExtensions.associateWith { it in eglExt }),
                )
            } finally {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                EGL14.eglDestroySurface(display, surface)
                EGL14.eglDestroyContext(display, context)
            }
        } finally {
            EGL14.eglTerminate(display)
        }
    }

    /** The last 400 lines of the app's own log (design D9), at most 64 KB
     *  (the newest kept), or null when it can't be read. */
    fun logcat(): String? {
        backendInUse()
        val tail = runLogcat(listOf("-d", "-v", "threadtime", "-t", "400", "--pid=${Process.myPid()}"), 64 * 1024 - 512)
            ?: return null
        return withBackendLine(tail, backendLogLine)
    }

    /** [tail] with the engine's backend [line] first: it's written once, at
     *  start-up, and the last 400 lines rarely reach back to it. */
    fun withBackendLine(tail: String, line: String?): String =
        if (line == null || tail.contains(line)) tail else "$line\n$tail"

    /** `logcat` with [args], its output's last [cap] bytes; null on any
     *  failure. An app reads its own process's log without a permission. */
    private fun runLogcat(args: List<String>, cap: Int): String? = try {
        val process = ProcessBuilder(listOf("logcat") + args).redirectErrorStream(true).start()
        val bytes = process.inputStream.use { it.readBytes() }
        process.waitFor(3, TimeUnit.SECONDS)
        if (process.exitValue() != 0 && bytes.isEmpty()) null else capTail(String(bytes, Charsets.UTF_8), cap)
    } catch (e: Exception) {
        null
    }

    /** [text]'s last [cap] bytes, cut at a line start. */
    fun capTail(text: String, cap: Int): String {
        val bytes = text.toByteArray(Charsets.UTF_8)
        if (bytes.size <= cap) return text
        val tail = String(bytes, bytes.size - cap, cap, Charsets.UTF_8)
        val nl = tail.indexOf('\n')
        return if (nl >= 0) tail.substring(nl + 1) else tail
    }

    /** The screen as shown: a [PixelCopy] of Flutter's SurfaceView into a
     *  1920×1080 bitmap, as RGBA bytes (design D4). Calls [done] on the main
     *  thread with the bytes and the surface's own size, or the reason it
     *  couldn't. */
    fun captureScreen(activity: Activity, done: (Map<String, Any?>) -> Unit) {
        val view = findSurfaceView(activity.window.decorView)
        if (view == null) {
            done(mapOf("error" to "no SurfaceView"))
            return
        }
        if (view.width <= 0 || view.height <= 0) {
            done(mapOf("error" to "surface not laid out"))
            return
        }
        val bitmap = Bitmap.createBitmap(CAPTURE_WIDTH, CAPTURE_HEIGHT, Bitmap.Config.ARGB_8888)
        val main = Handler(Looper.getMainLooper())
        try {
            PixelCopy.request(view, bitmap, { status ->
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    done(mapOf("error" to "PixelCopy status $status"))
                    return@request
                }
                // ARGB_8888 is laid out R, G, B, A in memory.
                val buffer = ByteBuffer.allocate(bitmap.byteCount)
                bitmap.copyPixelsToBuffer(buffer)
                bitmap.recycle()
                done(
                    mapOf(
                        "rgba" to buffer.array(),
                        "width" to CAPTURE_WIDTH,
                        "height" to CAPTURE_HEIGHT,
                        "surface_width" to view.width,
                        "surface_height" to view.height,
                    )
                )
            }, main)
        } catch (e: Exception) {
            bitmap.recycle()
            done(mapOf("error" to (e.message ?: e.toString())))
        }
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) findSurfaceView(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    /** The debug fault (design D13): `debug.nightingale_tv.video_fault`, in a
     *  debuggable build only; empty otherwise. */
    fun fault(activity: Activity): String = if (!debuggable(activity)) "" else systemProperty("debug.nightingale_tv.video_fault")

    fun systemProperty(name: String): String = try {
        Class.forName("android.os.SystemProperties").getMethod("get", String::class.java).invoke(null, name) as String
    } catch (e: Exception) {
        ""
    }

    const val CAPTURE_WIDTH = 1920
    const val CAPTURE_HEIGHT = 1080
}
