package com.coffeehauslabs.nightingale_tv

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Volume leveling on Android (volume-leveling spec, design D3): the same
 *  compressor and limiter as Linux's `volumeLevelingChain`
 *  (lib/playback/tuner_player.dart), for ExoPlayer's audio output.
 *
 *  - **Compressor:** FFmpeg `acompressor`'s algorithm and formulas (RMS
 *    detection, channels linked by their average, soft knee, attack and
 *    release coefficients), with the same values.
 *  - **Limiter:** a peak limiter with a 5 ms look-ahead. The gain needed by
 *    each peak is held across the look-ahead and ramped into over it, so no
 *    output sample goes over the limit; it releases over 50 ms.
 *
 *  Takes 16-bit and float PCM at any channel count and rate, and puts out
 *  the same format and the same number of frames (the audio is 5 ms later).
 *  Other encodings pass through untouched. Counters for the diagnostics are
 *  read with [takeStats]. */
@UnstableApi
class LevelingAudioProcessor : BaseAudioProcessor() {

    companion object {
        // Design D1, as in volumeLevelingChain.
        const val THRESHOLD = 0.01 // -40 dBFS
        const val RATIO = 4.0
        const val KNEE = 2.8
        const val ATTACK_MS = 200.0
        const val RELEASE_MS = 2000.0
        const val MAKEUP = 3.981 // +12 dB
        const val LIMIT = 0.89 // -1 dBFS
        const val LIMITER_LOOKAHEAD_MS = 5.0
        const val LIMITER_RELEASE_MS = 50.0

        private const val DB_PER_NEPER = 8.685889638065035 // 20 / ln(10)
    }

    // acompressor's precomputed values (af_sidechaincompress.c,
    // compressor_config_output), for downward mode and RMS detection.
    private val thres = ln(THRESHOLD)
    private val kneeStart = ln(THRESHOLD / sqrt(KNEE))
    private val kneeStop = ln(THRESHOLD * sqrt(KNEE))
    private val adjKneeStart = (THRESHOLD / sqrt(KNEE)).let { it * it }
    private val compressedKneeStop = (kneeStop - thres) / RATIO + thres

    private var attackCoeff = 1.0
    private var releaseCoeff = 1.0
    private var limiterReleaseCoeff = 1.0

    /** The detector's envelope (mean square), kept across flushes, so a new
     *  segment starts at the level the last one left. */
    private var linSlope = 0.0

    // The limiter, sized at configure.
    private var channels = 0
    private var lookahead = 1
    private var delay = DoubleArray(0) // lookahead frames × channels
    private var held = DoubleArray(0) // the held gain of the last lookahead frames
    private var heldSum = 0.0
    private var pos = 0
    private var release = 1.0

    /** The sliding minimum of the needed gain over lookahead + 1 frames: a
     *  monotonic queue of (frame, gain) in a ring. */
    private var minFrames = LongArray(0)
    private var minGains = DoubleArray(0)
    private var minHead = 0
    private var minSize = 0
    private var frame = 0L

    // Diagnostics, since the last takeStats().
    private val statsLock = Any()
    private var statFrames = 0L
    private var statSquares = 0.0
    private var statReductionDb = 0.0
    private var statMaxReductionDb = 0.0
    private var statLimiterHits = 0L

    override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT && inputAudioFormat.encoding != C.ENCODING_PCM_FLOAT) {
            return AudioProcessor.AudioFormat.NOT_SET
        }
        return inputAudioFormat
    }

    override fun onFlush() {
        val format = inputAudioFormat
        if (format.channelCount <= 0) return
        val rate = format.sampleRate.toDouble()
        attackCoeff = min(1.0, 1.0 / (ATTACK_MS * rate / 4000.0))
        releaseCoeff = min(1.0, 1.0 / (RELEASE_MS * rate / 4000.0))
        limiterReleaseCoeff = 1.0 - exp(-1000.0 / (LIMITER_RELEASE_MS * rate))
        channels = format.channelCount
        lookahead = max(1, (LIMITER_LOOKAHEAD_MS * rate / 1000.0).roundToInt())
        delay = DoubleArray(lookahead * channels)
        held = DoubleArray(lookahead) { 1.0 }
        heldSum = lookahead.toDouble()
        pos = 0
        release = 1.0
        minFrames = LongArray(lookahead + 2)
        minGains = DoubleArray(lookahead + 2)
        minHead = 0
        minSize = 0
        frame = 0L
    }

    override fun onReset() {
        linSlope = 0.0
        delay = DoubleArray(0)
        held = DoubleArray(0)
        synchronized(statsLock) {
            statFrames = 0L
            statSquares = 0.0
            statReductionDb = 0.0
            statMaxReductionDb = 0.0
            statLimiterHits = 0L
        }
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val input = inputBuffer.order(ByteOrder.nativeOrder())
        val start = input.position()
        val size = input.remaining()
        val float = inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT
        val bytesPerSample = if (float) 4 else 2
        val frames = size / (bytesPerSample * channels)
        val output = replaceOutputBuffer(size).order(ByteOrder.nativeOrder())
        val sample = DoubleArray(channels)

        var squares = 0.0
        var reductionDb = 0.0
        var maxReductionDb = 0.0
        var limiterHits = 0L

        for (f in 0 until frames) {
            val at = start + f * channels * bytesPerSample
            // The compressor's detector: the channels' average, squared.
            var level = 0.0
            for (c in 0 until channels) {
                val i = at + c * bytesPerSample
                val x = if (float) input.getFloat(i).toDouble() else input.getShort(i) / 32768.0
                sample[c] = x
                level += abs(x)
                squares += x * x / channels
            }
            level /= channels
            level *= level
            linSlope += (level - linSlope) * (if (level > linSlope) attackCoeff else releaseCoeff)

            var gain = MAKEUP
            if (linSlope > 0.0 && linSlope > adjKneeStart) {
                val logGain = compressedLogGain(linSlope)
                gain *= exp(logGain)
                val reduction = -logGain * DB_PER_NEPER
                reductionDb += reduction
                if (reduction > maxReductionDb) maxReductionDb = reduction
            }

            // The limiter: the gain this frame needs, released slowly...
            var peak = 0.0
            for (c in 0 until channels) {
                sample[c] *= gain
                peak = max(peak, abs(sample[c]))
            }
            val needed = if (peak > LIMIT) LIMIT / peak else 1.0
            if (needed < 1.0) limiterHits++
            release = min(needed, release + (1.0 - release) * limiterReleaseCoeff)
            // ...held over the look-ahead...
            while (minSize > 0 && minGains[(minHead + minSize - 1) % minGains.size] >= release) minSize--
            minFrames[(minHead + minSize) % minFrames.size] = frame
            minGains[(minHead + minSize) % minGains.size] = release
            minSize++
            while (minFrames[minHead] < frame - lookahead) {
                minHead = (minHead + 1) % minFrames.size
                minSize--
            }
            // ...and ramped into over it, in time for the delayed sample.
            heldSum += minGains[minHead] - held[pos]
            held[pos] = minGains[minHead]
            val limiterGain = heldSum / lookahead

            for (c in 0 until channels) {
                val y = delay[pos * channels + c] * limiterGain
                delay[pos * channels + c] = sample[c]
                if (float) {
                    output.putFloat(y.toFloat())
                } else {
                    output.putShort((y * 32768.0).roundToInt().coerceIn(-32768, 32767).toShort())
                }
            }
            pos++
            if (pos == lookahead) {
                pos = 0
                // Against the running sum drifting.
                heldSum = held.sum()
            }
            frame++
        }

        input.position(input.limit())
        output.flip()
        synchronized(statsLock) {
            statFrames += frames
            statSquares += squares
            statReductionDb += reductionDb
            statMaxReductionDb = max(statMaxReductionDb, maxReductionDb)
            statLimiterHits += limiterHits
        }
    }

    /** acompressor's output_gain() as a natural log, in downward mode with
     *  RMS detection: the gain below 1 for this envelope, before make-up. */
    private fun compressedLogGain(linSlope: Double): Double {
        val slope = ln(linSlope) * 0.5
        var gain = (slope - thres) / RATIO + thres
        if (KNEE > 1.0 && slope < kneeStop) {
            gain = hermite(slope, kneeStart, kneeStop, kneeStart, compressedKneeStop, 1.0, 1.0 / RATIO)
        }
        return gain - slope
    }

    /** acompressor's hermite_interpolation(). */
    private fun hermite(x: Double, x0: Double, x1: Double, p0: Double, p1: Double, m0: Double, m1: Double): Double {
        val width = x1 - x0
        val t = (x - x0) / width
        val w0 = m0 * width
        val w1 = m1 * width
        val t2 = t * t
        val t3 = t2 * t
        val ct2 = -3 * p0 - 2 * w0 + 3 * p1 - w1
        val ct3 = 2 * p0 + w0 - 2 * p1 + w1
        return ct3 * t3 + ct2 * t2 + w0 * t + p0
    }

    /** What happened since the last call, for a LEVEL line: the input's RMS
     *  (dBFS), the compressor's average and largest gain reduction (dB), and
     *  how many frames the limiter turned down. Null when no audio went
     *  through. */
    fun takeStats(): Map<String, Any>? = synchronized(statsLock) {
        if (statFrames == 0L) return null
        val rms = sqrt(statSquares / statFrames)
        val stats = mapOf<String, Any>(
            "frames" to statFrames,
            "inRmsDb" to (if (rms > 0) 20 * log10(rms) else -120.0),
            "reductionDb" to statReductionDb / statFrames,
            "maxReductionDb" to statMaxReductionDb,
            "gainDb" to 20 * log10(MAKEUP) - statReductionDb / statFrames,
            "limiterHits" to statLimiterHits,
        )
        statFrames = 0L
        statSquares = 0.0
        statReductionDb = 0.0
        statMaxReductionDb = 0.0
        statLimiterHits = 0L
        stats
    }
}
