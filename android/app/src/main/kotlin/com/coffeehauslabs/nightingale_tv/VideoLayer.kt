package com.coffeehauslabs.nightingale_tv

import android.app.Activity
import android.graphics.Rect
import android.view.Gravity
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import kotlin.math.ceil
import kotlin.math.floor

/** The system layer a player's video shows on (system-video-layer D1): a
 *  [SurfaceView] below the transparent Flutter view. Android shows on it only
 *  the part of each decoded buffer the decoder marks as the picture, with the
 *  stream's own colours and dynamic range. Flutter leaves a hole over it and
 *  says where the picture goes ([place]); it takes no focus and no touches.
 *
 *  [onSurface] hears of the surface coming (true) and going (false). */
class VideoLayer(activity: Activity, private val onSurface: (Boolean) -> Unit) : SurfaceHolder.Callback {
    val view = SurfaceView(activity).apply {
        isFocusable = false
        isFocusableInTouchMode = false
        isClickable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    /** Where the layer is, in the content's pixels; null until placed (it
     *  fills the content, so its surface exists before the first picture). */
    var bounds: Rect? = null
        private set

    /** The layer's whole pixels in parts of the picture it shows, as scale
     *  and offset in each direction: the picture can start and end between
     *  two pixels. Read on the effects' thread. */
    @Volatile var inPicture = floatArrayOf(1f, 1f, 0f, 0f)
        private set

    private val content: ViewGroup = activity.findViewById(android.R.id.content)

    init {
        view.holder.addCallback(this)
        content.addView(
            view, 0,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
    }

    /** Puts the layer at the picture's whole rectangle, in the Flutter view's
     *  pixels. A cropped picture's is larger than the screen: the system
     *  clips it, and Flutter covers the rest. */
    fun place(left: Double, top: Double, right: Double, bottom: Double) {
        val next = boundsFor(left, top, right, bottom) ?: return
        inPicture = floatArrayOf(
            (next.width() / (right - left)).toFloat(), (next.height() / (bottom - top)).toFloat(),
            ((next.left - left) / (right - left)).toFloat(), ((next.top - top) / (bottom - top)).toFloat(),
        )
        if (next == bounds) return
        bounds = next
        view.layoutParams = FrameLayout.LayoutParams(next.width(), next.height(), Gravity.TOP or Gravity.LEFT).apply {
            leftMargin = next.left
            topMargin = next.top
        }
        // Now, not at the next layout pass: the surface moves a frame sooner,
        // closer to the Flutter frame that moved the hole.
        view.layout(next.left, next.top, next.right, next.bottom)
    }

    fun remove() {
        view.holder.removeCallback(this)
        content.removeView(view)
    }

    override fun surfaceCreated(holder: SurfaceHolder) = onSurface(true)

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

    override fun surfaceDestroyed(holder: SurfaceHolder) = onSurface(false)

    companion object {
        /** The whole pixels covering a rectangle, so no edge of the hole
         *  shows past the layer; null for an empty one. A hair over a whole
         *  pixel (the interface is scaled) doesn't take another. */
        fun edges(left: Double, top: Double, right: Double, bottom: Double): IntArray? {
            if (!(right - left > 0.5 && bottom - top > 0.5)) return null
            return intArrayOf(
                floor(left + HAIR).toInt(), floor(top + HAIR).toInt(),
                ceil(right - HAIR).toInt(), ceil(bottom - HAIR).toInt(),
            )
        }

        private fun boundsFor(left: Double, top: Double, right: Double, bottom: Double): Rect? =
            edges(left, top, right, bottom)?.let { Rect(it[0], it[1], it[2], it[3]) }

        private const val HAIR = 0.02
    }
}
