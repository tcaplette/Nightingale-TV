package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.Effect
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import androidx.media3.effect.RgbMatrix

/** The CRT effects that change the video itself (system-video-layer D5), as
 *  lib/ui/widgets/crt_effects.dart works them out: the colour matrix, and
 *  shaders/crt.frag's curvature and glow. [picture] places the tube: the
 *  frame's centre and half size, in parts of the picture, and the glow's reach
 *  (4 device pixels) in the same parts. [overlay], with glow only, is what the
 *  glow is worked out over (empty for none): the frame's size in device
 *  pixels, how dark the scanlines are, their period and dark part, how dark the
 *  mask and the vignette are, the vignette's radius and start, and the corners'
 *  radius. */
class VideoLook(
    val matrix: FloatArray?,
    val curvature: Float,
    val glow: Float,
    val picture: FloatArray,
    val overlay: FloatArray,
) {
    companion object {
        const val OVERLAY_VALUES = 10

        /** From Dart: the 4×5 colour matrix (its offsets 0–255), curvature,
         *  glow, the six places and the overlay; null when nothing changes
         *  the video. */
        fun from(
            matrix: List<Double>?, curvature: Double, glow: Double, picture: List<Double>,
            overlay: List<Double> = emptyList(),
        ): VideoLook? {
            if (matrix == null && curvature <= 0 && glow <= 0) return null
            return VideoLook(
                matrix?.let { rgbMatrix(it) }, curvature.toFloat(), glow.toFloat(),
                FloatArray(6) { picture[it].toFloat() },
                if (overlay.size == OVERLAY_VALUES) FloatArray(OVERLAY_VALUES) { overlay[it].toFloat() } else FloatArray(0),
            )
        }

        /** Flutter's row-major 4×5 matrix as GL's column-major 4×4 over
         *  (r, g, b, 1), the offsets in 0–1. */
        fun rgbMatrix(m: List<Double>): FloatArray = floatArrayOf(
            m[0].toFloat(), m[5].toFloat(), m[10].toFloat(), 0f,
            m[1].toFloat(), m[6].toFloat(), m[11].toFloat(), 0f,
            m[2].toFloat(), m[7].toFloat(), m[12].toFloat(), 0f,
            (m[4] / 255).toFloat(), (m[9] / 255).toFloat(), (m[14] / 255).toFloat(), 1f,
        )
    }
}

/** The effects for a kind of look, read from [look] at every frame, so a
 *  changed value needs no new pipeline. With no look (the guide's preview of a
 *  channel that has one) they pass the picture through. The tube is drawn at
 *  [size], the layer's, so its lines fall on the screen's pixels, and
 *  [inPicture] is where those are in the picture (VideoLayer.inPicture). */
@UnstableApi
fun videoEffects(context: Context, kind: Int, size: Size?, inPicture: () -> FloatArray, look: () -> VideoLook?): List<Effect> = buildList {
    // For checking what a device whose pipeline fails does.
    if (VideoReport.debugFlag(context, "fail_effects")) add(FailingEffect)
    if (kind and 1 != 0) add(MatrixEffect(look))
    if (kind and 2 != 0) add(TubeEffect(size, inPicture, look))
}

@UnstableApi
private object FailingEffect : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        throw VideoFrameProcessingException("debug.nightingale_tv.fail_effects")
}

@UnstableApi
private class MatrixEffect(private val look: () -> VideoLook?) : RgbMatrix {
    override fun getMatrix(presentationTimeUs: Long, useHdr: Boolean): FloatArray =
        look()?.matrix ?: GlUtil.create4x4IdentityMatrix()
}

@UnstableApi
private class TubeEffect(private val size: Size?, private val inPicture: () -> FloatArray, private val look: () -> VideoLook?) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram = TubeProgram(size, inPicture, look)
}

/** shaders/crt.frag on the video alone, over the scanlines, mask, vignette and
 *  corners as `paintCrtOverlay` paints them: where it samples past the picture,
 *  or outside the tube, it's black. */
@UnstableApi
private class TubeProgram(private val size: Size?, private val inPicture: () -> FloatArray, private val look: () -> VideoLook?) : BaseGlShaderProgram(false, 1) {
    private val program = try {
        GlProgram(VERTEX, FRAGMENT).apply {
            setBufferAttribute(
                "aFramePosition", GlUtil.getNormalizedCoordinateBounds(), GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
            )
        }
    } catch (e: GlUtil.GlException) {
        throw VideoFrameProcessingException(e)
    }

    override fun configure(inputWidth: Int, inputHeight: Int) = size ?: Size(inputWidth, inputHeight)

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            val v = look()
            val p = v?.picture ?: FloatArray(6)
            program.use()
            program.setSamplerTexIdUniform("uPicture", inputTexId, 0)
            val at = if (size == null) floatArrayOf(1f, 1f, 0f, 0f) else inPicture()
            program.setFloatsUniform("uScale", floatArrayOf(at[0], at[1]))
            program.setFloatsUniform("uShift", floatArrayOf(at[2], at[3]))
            program.setFloatUniform("uCurvature", v?.curvature ?: 0f)
            program.setFloatUniform("uGlow", v?.glow ?: 0f)
            program.setFloatsUniform("uCenter", floatArrayOf(p[0], p[1]))
            // No frame (no look): its shape doesn't matter, but never divide
            // by nothing.
            program.setFloatsUniform("uHalf", floatArrayOf(if (p[2] > 0f) p[2] else 1e6f, if (p[3] > 0f) p[3] else 1e6f))
            program.setFloatsUniform("uReach", floatArrayOf(p[4], p[5]))
            val o = v?.overlay?.takeIf { it.isNotEmpty() }
            program.setFloatUniform("uOverlay", if (o != null) 1f else 0f)
            program.setFloatsUniform("uFrame", if (o != null) floatArrayOf(o[0], o[1]) else floatArrayOf(1f, 1f))
            program.setFloatsUniform("uLines", if (o != null) floatArrayOf(o[2], o[3], o[4]) else floatArrayOf(0f, 1f, 0f))
            program.setFloatUniform("uMask", o?.get(5) ?: 0f)
            program.setFloatsUniform("uVignette", if (o != null) floatArrayOf(o[6], o[7], o[8]) else floatArrayOf(0f, 1f, 0f))
            program.setFloatUniform("uCorner", o?.get(9) ?: 0f)
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program.delete()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }
}

private const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vAt;
void main() {
  gl_Position = aFramePosition;
  vAt = aFramePosition.xy * 0.5 + 0.5;
}
"""

/** GL's picture is upside down against the frame's places, so y is turned
 *  over for them and back for sampling. */
private const val FRAGMENT = """
precision highp float;
uniform sampler2D uPicture;
uniform float uCurvature;
uniform float uGlow;
uniform vec2 uCenter;
uniform vec2 uHalf;
uniform vec2 uReach;
uniform vec2 uScale;
uniform vec2 uShift;
uniform float uOverlay;
uniform vec2 uFrame;
uniform vec3 uLines;
uniform float uMask;
uniform vec3 uVignette;
uniform float uCorner;
varying vec2 vAt;

vec3 at(vec2 p) {
  if (p.x < 0.0 || p.y < 0.0 || p.x > 1.0 || p.y > 1.0) return vec3(0.0);
  vec3 c = texture2D(uPicture, vec2(p.x, 1.0 - p.y)).rgb;
  if (uOverlay < 0.5) return c;
  // The frame's device pixel, whole.
  vec2 f = ((p - uCenter) / uHalf * 0.5 + 0.5) * uFrame;
  vec2 px = floor(f);
  if (mod(px.y, uLines.y) >= uLines.y - uLines.z) c *= 1.0 - uLines.x;
  if (uMask > 0.0) {
    float m = mod(px.x, 3.0);
    vec3 trace = m < 0.5 ? vec3(0.251, 0.0, 0.0) : (m < 1.5 ? vec3(0.0, 0.251, 0.0) : vec3(0.0, 0.0, 0.251));
    c = mix(c, trace, uMask);
  }
  if (uVignette.x > 0.0) {
    float t = clamp((distance(f, uFrame * 0.5) / uVignette.y - uVignette.z) / (1.0 - uVignette.z), 0.0, 1.0);
    c *= 1.0 - uVignette.x * t;
  }
  vec2 q = abs(f - uFrame * 0.5) - (uFrame * 0.5 - uCorner);
  if (q.x > 0.0 && q.y > 0.0) c *= clamp(uCorner - length(q) + 0.5, 0.0, 1.0);
  return c;
}

void main() {
  vec2 c = (vec2(vAt.x, 1.0 - vAt.y) * uScale + uShift - uCenter) / uHalf;
  c *= 1.0 + uCurvature * dot(c, c);
  if (abs(c.x) > 1.0 || abs(c.y) > 1.0) {
    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }
  vec2 p = uCenter + c * uHalf;
  vec3 color = at(p);
  if (uGlow > 0.0) {
    vec2 r = uReach;
    vec3 blur = at(p + vec2(r.x, 0.0)) + at(p - vec2(r.x, 0.0)) + at(p + vec2(0.0, r.y)) + at(p - vec2(0.0, r.y)) +
        at(p + r) + at(p - r) + at(p + vec2(r.x, -r.y)) + at(p + vec2(-r.x, r.y));
    color += max(blur / 8.0 - 0.4, 0.0) * uGlow;
  }
  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
"""
