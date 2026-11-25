package com.coffeehauslabs.nightingale_tv

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** YouTube's embedded player (youtube-playback D8): one system WebView over
 *  the Flutter view, at the frame Flutter gives in its pixels. It never takes
 *  key focus, so the D-pad, number and media keys stay with the app; touches
 *  and an air mouse's clicks reach it (YouTube's Skip ad, logo and links).
 *  Driven over `ntv/youtube_view`, as on Linux. */
class YouTubeWebView(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "ntv/youtube_view").also { it.setMethodCallHandler(this) }
    private val content: ViewGroup = activity.findViewById(android.R.id.content)
    private val main = Handler(Looper.getMainLooper())
    private var web: WebView? = null
    private var visible = false

    private fun send(method: String, args: Any?) = main.post { channel.invokeMethod(method, args) }

    /** Null when the device has no working System WebView. */
    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun create(): WebView? {
        val view = try {
            WebView(activity)
        } catch (e: Exception) {
            // No System WebView installed, or it's disabled.
            Log.w(TAG, "No WebView: ${e.javaClass.simpleName}")
            return null
        }
        view.apply {
            isFocusable = false
            isFocusableInTouchMode = false
            descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            setBackgroundColor(Color.BLACK)
            settings.javaScriptEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.domStorageEnabled = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.setSupportZoom(false)
            // The page's 640-pixel viewport, scaled to the frame.
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            settings.setSupportMultipleWindows(false)
            settings.javaScriptCanOpenWindowsAutomatically = false
            addJavascriptInterface(Bridge(), "NtvAndroid")
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                // Links the player opens go to the browser, never into its frame.
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    if (!request.isForMainFrame) return false
                    send("openUrl", request.url.toString())
                    return true
                }

                override fun onPageFinished(view: WebView, url: String?) {
                    fitWidth = 0
                    if (visible) fit(view)
                }

                override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                    if (web === view) {
                        content.removeView(view)
                        web = null
                    }
                    view.destroy()
                    send("crashed", if (detail.didCrash()) 1 else 0)
                    return true
                }
            }
            visibility = View.GONE
        }
        content.addView(view, FrameLayout.LayoutParams(1, 1, Gravity.TOP or Gravity.LEFT))
        applyFrame(view)
        return view
    }

    /** Where the app shows the player, in the Flutter view's pixels; kept
     *  for a view made later. */
    private var frame = intArrayOf(0, 0, 0, 0)

    private fun applyFrame(view: WebView) {
        if (!visible) {
            view.visibility = View.GONE
            return
        }
        val (x, y, w, h) = frame
        view.layoutParams = FrameLayout.LayoutParams(w, h, Gravity.TOP or Gravity.LEFT).apply {
            leftMargin = x
            topMargin = y
        }
        view.layout(x, y, x + w, y + h)
        view.visibility = View.VISIBLE
        view.onResume()
        fit(view)
    }

    /** The frame's width the page was last fitted to. */
    private var fitWidth = 0

    /** The WebView fits the page's 640-pixel viewport to the frame only when
     *  the page loads; a frame of another width later (a turned phone, the
     *  guide's preview) has the page fitted to it again. */
    private fun fit(view: WebView) {
        val w = frame[2]
        if (w <= 0 || w == fitWidth) return
        fitWidth = w
        val width = w / activity.resources.displayMetrics.density
        view.evaluateJavascript("window.ntvFit && ntvFit($width)", null)
    }

    inner class Bridge {
        @JavascriptInterface
        fun post(text: String) = send("message", text)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val view = web ?: create()?.also { web = it }
                if (view == null) {
                    result.success("noWebView")
                    return
                }
                view.loadDataWithBaseURL(call.argument<String>("baseUrl"), call.argument<String>("html")!!,
                    "text/html", "utf-8", null)
                result.success(null)
            }
            "recreate" -> {
                web?.let { content.removeView(it); it.destroy() }
                web = null
                fitWidth = 0
                result.success(null)
            }
            "frame" -> {
                val x = (call.argument<Number>("x") ?: 0).toInt()
                val y = (call.argument<Number>("y") ?: 0).toInt()
                val w = (call.argument<Number>("w") ?: 0).toInt()
                val h = (call.argument<Number>("h") ?: 0).toInt()
                frame = intArrayOf(x, y, w, h)
                visible = call.argument<Boolean>("visible") == true && w > 0 && h > 0
                web?.let { applyFrame(it) }
                result.success(null)
            }
            "run" -> {
                web?.evaluateJavascript(call.argument<String>("js")!!, null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** In the background no sound may go on: the page is stopped and the
     *  WebView's timers paused (Flutter stops the video first). */
    fun onPause() {
        web?.evaluateJavascript("ntvStop()", null)
        web?.onPause()
    }

    fun dispose() {
        web?.let { content.removeView(it); it.destroy() }
        web = null
    }

    companion object {
        private const val TAG = "YouTubeWebView"
    }
}
