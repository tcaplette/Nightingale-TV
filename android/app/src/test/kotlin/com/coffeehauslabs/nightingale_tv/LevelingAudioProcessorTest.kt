package com.coffeehauslabs.nightingale_tv

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.random.Random

/** The leveling processor on the spec's test signal (volume-leveling,
 *  "Leveling evens out loudness"), with the same limits as Linux's chain in
 *  test/volume_leveling_test.dart: pink noise at -36, -12, -54 and -24 LUFS
 *  (20, 20, 5 and 20 s), measured with EBU R128 short-term loudness. */
@UnstableApi
class LevelingAudioProcessorTest {

    private val sections = listOf(20 to -36.0, 20 to -12.0, 5 to -54.0, 20 to -24.0)

    @Test
    fun levelsTheTestSignal16Bit() = levels(C.ENCODING_PCM_16BIT)

    @Test
    fun levelsTheTestSignalFloat() = levels(C.ENCODING_PCM_FLOAT)

    private fun levels(encoding: Int) {
        val rate = 48_000
        val base = PinkNoise(2).let { noise ->
            val meter = Meter(2)
            repeat(10 * rate) { meter.add(noise.next()) }
            meter.integrated()
        }
        val noise = PinkNoise(2)
        val input = Meter(2)
        val output = Meter(2)
        val processor = LevelingAudioProcessor()
        assertEquals(AudioProcessor.AudioFormat(rate, 2, encoding), processor.configure(AudioProcessor.AudioFormat(rate, 2, encoding)))
        assertTrue(processor.isActive)
        processor.flush()

        var peak = 0.0
        var framesIn = 0L
        var framesOut = 0L
        for ((seconds, lufs) in sections) {
            val gain = 10.0.pow((lufs - base) / 20)
            var left = seconds * rate
            while (left > 0) {
                val n = minOf(1024, left)
                left -= n
                val frames = Array(n) { noise.next().map { it * gain }.toDoubleArray() }
                // What the decoder would give: 16-bit clips at full scale.
                val sent = frames.map { f -> f.map { s -> if (encoding == C.ENCODING_PCM_16BIT) s.coerceIn(-1.0, 32767 / 32768.0) else s }.toDoubleArray() }
                sent.forEach(input::add)
                processor.queueInput(encode(sent, encoding))
                framesIn += n
                for (f in decode(processor.output, encoding, 2)) {
                    output.add(f)
                    framesOut++
                    for (s in f) peak = max(peak, abs(s))
                }
            }
        }

        assertEquals("same number of frames out", framesIn, framesOut)
        assertEquals(-36.0, input.mean(10.0, 20.0), 0.5)
        assertEquals(-12.0, input.mean(30.0, 40.0), 0.5)
        assertEquals(-24.0, input.mean(55.0, 65.0), 0.5)

        val quiet = output.mean(10.0, 20.0)
        val loud = output.mean(30.0, 40.0)
        val medium = output.mean(55.0, 65.0)
        val spread = maxOf(quiet, loud, medium) - minOf(quiet, loud, medium)
        val onset = output.max(20.0, 23.0) - loud
        val raised = output.at(45.0) - input.at(45.0)
        val peakDb = 20 * log10(peak)
        println(
            "leveled (${if (encoding == C.ENCODING_PCM_FLOAT) "float" else "16-bit"}): quiet %.1f, loud %.1f, medium %.1f LUFS; spread %.1f LU, onset +%.1f LU, near-silence +%.1f dB, peak %.2f dBFS"
                .format(quiet, loud, medium, spread, onset, raised, peakDb)
        )
        assertTrue("steady loudness within 8 LU ($spread)", spread <= 8)
        assertTrue("onset no more than 3 LU over ($onset)", onset <= 3)
        assertTrue("near-silence raised no more than 12 dB ($raised)", raised <= 12)
        assertTrue("peaks at most 0.5 dB over -1 dBFS ($peakDb)", peakDb <= -0.5)

        val stats = processor.takeStats()!!
        assertEquals(framesIn, stats["frames"])
        assertTrue((stats["limiterHits"] as Long) >= 0)
        assertEquals(null, processor.takeStats())
    }

    @Test
    fun anyChannelCountAndRate() {
        for ((rate, channels) in listOf(44_100 to 6, 32_000 to 1, 96_000 to 8)) {
            val processor = LevelingAudioProcessor()
            val format = AudioProcessor.AudioFormat(rate, channels, C.ENCODING_PCM_FLOAT)
            assertEquals(format, processor.configure(format))
            processor.flush()
            val noise = PinkNoise(channels)
            var framesIn = 0
            var framesOut = 0
            var peak = 0.0
            repeat(rate / 1000) {
                framesIn += 1000
                // Loud: well over the limit before leveling.
                processor.queueInput(encode(Array(1000) { noise.next().map { it * 8 }.toDoubleArray() }.toList(), C.ENCODING_PCM_FLOAT))
                for (f in decode(processor.output, C.ENCODING_PCM_FLOAT, channels)) {
                    framesOut++
                    for (s in f) {
                        assertFalse(s.isNaN())
                        peak = max(peak, abs(s))
                    }
                }
            }
            assertEquals("$rate Hz × $channels", framesIn, framesOut)
            assertTrue("$rate Hz × $channels: peak $peak", peak <= LevelingAudioProcessor.LIMIT + 1e-6)
        }
    }

    @Test
    fun otherEncodingsPassThroughUntouched() {
        // An inactive processor is skipped by the audio sink: the decoder's
        // samples reach the output as they are.
        for (encoding in listOf(C.ENCODING_PCM_24BIT, C.ENCODING_PCM_32BIT, C.ENCODING_AC3)) {
            val processor = LevelingAudioProcessor()
            assertEquals(AudioProcessor.AudioFormat.NOT_SET, processor.configure(AudioProcessor.AudioFormat(48_000, 2, encoding)))
            assertFalse(processor.isActive)
            processor.flush()
        }
    }

    // ---- The test signal and the meter ------------------------------------------

    /** Pink noise (Paul Kellet's filter), independent per channel. */
    private class PinkNoise(private val channels: Int) {
        private val random = Random(7)
        private val b = Array(channels) { DoubleArray(7) }

        fun next(): DoubleArray = DoubleArray(channels) { c ->
            val white = random.nextDouble() * 2 - 1
            val s = b[c]
            s[0] = 0.99886 * s[0] + white * 0.0555179
            s[1] = 0.99332 * s[1] + white * 0.0750759
            s[2] = 0.96900 * s[2] + white * 0.1538520
            s[3] = 0.86650 * s[3] + white * 0.3104856
            s[4] = 0.55000 * s[4] + white * 0.5329522
            s[5] = -0.7616 * s[5] - white * 0.0168980
            val pink = s[0] + s[1] + s[2] + s[3] + s[4] + s[5] + s[6] + white * 0.5362
            s[6] = white * 0.115926
            pink * 0.11
        }
    }

    /** ITU-R BS.1770 loudness at 48 kHz: K-weighting, then the short-term
     *  loudness (3 s) every 100 ms, as ffmpeg's ebur128 logs it. */
    private class Meter(private val channels: Int) {
        private val shelf = Array(channels) { Biquad(1.53512485958697, -2.69169618940638, 1.19839281085285, -1.69065929318241, 0.73248077421585) }
        private val highPass = Array(channels) { Biquad(1.0, -2.0, 1.0, -1.99004745483398, 0.99007225036621) }
        private val blocks = mutableListOf<Double>()
        private var block = 0.0
        private var inBlock = 0
        private var total = 0.0
        private var frames = 0L

        /** Short-term loudness at the end of each 100 ms. */
        val shortTerm = mutableListOf<Double>()

        fun add(frame: DoubleArray) {
            var power = 0.0
            for (c in 0 until channels) {
                val y = highPass[c].run(shelf[c].run(frame[c]))
                power += y * y
            }
            block += power
            total += power
            frames++
            if (++inBlock == 4800) {
                blocks.add(block / 4800)
                block = 0.0
                inBlock = 0
                val window = blocks.takeLast(30)
                shortTerm.add(lufs(window.sum() / 30))
            }
        }

        fun integrated() = lufs(total / frames)
        private fun lufs(power: Double) = -0.691 + 10 * log10(power)

        private fun range(from: Double, to: Double) =
            shortTerm.filterIndexed { i, _ -> (i + 1) / 10.0 > from + 1e-6 && (i + 1) / 10.0 <= to + 1e-6 }

        fun mean(from: Double, to: Double) = range(from, to).average()
        fun max(from: Double, to: Double) = range(from, to).max()
        fun at(t: Double) = shortTerm[(t * 10).roundToInt() - 1]
    }

    private class Biquad(val b0: Double, val b1: Double, val b2: Double, val a1: Double, val a2: Double) {
        private var x1 = 0.0
        private var x2 = 0.0
        private var y1 = 0.0
        private var y2 = 0.0

        fun run(x: Double): Double {
            val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }

    private fun encode(frames: List<DoubleArray>, encoding: Int): ByteBuffer {
        val channels = frames.first().size
        val bytes = if (encoding == C.ENCODING_PCM_FLOAT) 4 else 2
        val buffer = ByteBuffer.allocateDirect(frames.size * channels * bytes).order(ByteOrder.nativeOrder())
        for (f in frames) for (s in f) {
            if (encoding == C.ENCODING_PCM_FLOAT) buffer.putFloat(s.toFloat())
            else buffer.putShort((s * 32768).roundToInt().coerceIn(-32768, 32767).toShort())
        }
        buffer.flip()
        return buffer
    }

    private fun decode(buffer: ByteBuffer, encoding: Int, channels: Int): List<DoubleArray> {
        val b = buffer.order(ByteOrder.nativeOrder())
        val out = mutableListOf<DoubleArray>()
        while (b.hasRemaining()) {
            out.add(DoubleArray(channels) { if (encoding == C.ENCODING_PCM_FLOAT) b.float.toDouble() else b.short / 32768.0 })
        }
        return out
    }
}
