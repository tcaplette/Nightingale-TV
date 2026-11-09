package com.coffeehauslabs.nightingale_tv

import com.coffeehauslabs.nightingale_tv.AvStartAligner.Decision
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AvStartAlignerTest {
    private val base = 1_000_000_000_000L

    private fun started(): AvStartAligner = AvStartAligner().apply {
        videoEnabled(true)
        audioEnabled(true)
        videoReset()
        audioReset()
    }

    // ---- Video starts after the audio: the audio before it is dropped ----

    @Test
    fun lateVideoDropsTheAudioBeforeIt() {
        val a = started()
        a.videoSample(base + 879_000)
        a.audioSample(base)
        var t = base
        var skipped = 0
        while (a.audio(t, 0) == Decision.SKIP) {
            skipped++
            t += 21_333
        }
        // Buffers ending before the first picture are dropped; the one at it plays.
        assertEquals(41, skipped)
        assertEquals(Decision.PLAY, a.audio(t + 21_333, 0))
        assertEquals(879_000L, a.takeAudioDropped())
        assertNull(a.takeAudioDropped())
        // The video starts at its first frame: nothing to skip.
        assertEquals(Decision.PLAY, a.video(base + 879_000, 0))
        assertNull(a.takeVideoSkipped())
    }

    // ---- Audio starts after the video: the video before it is skipped ----

    @Test
    fun lateAudioSkipsTheVideoBeforeIt() {
        val a = started()
        a.videoSample(base)
        a.audioSample(base + 1_170_000)
        var t = base
        var skipped = 0
        while (a.video(t, 0) == Decision.SKIP) {
            skipped++
            t += 41_708
        }
        assertEquals(28, skipped)
        assertEquals(true, t >= base + 1_170_000 - 15_000)
        assertEquals(1_170_000L, a.takeVideoSkipped())
        assertEquals(Decision.PLAY, a.audio(base + 1_170_000, 0))
        assertNull(a.takeAudioDropped())
    }

    @Test
    fun videoHoldsUntilTheFirstAudioIsKnownThenGivesUp() {
        val a = started()
        a.videoSample(base)
        assertEquals(Decision.HOLD, a.video(base, 1_000))
        assertEquals(Decision.HOLD, a.video(base, 2_999))
        assertEquals(Decision.PLAY, a.video(base, 3_000))
    }

    // ---- Neither ----

    @Test
    fun audioOnlyPlaysEverything() {
        val a = AvStartAligner()
        a.videoEnabled(false)
        a.audioEnabled(true)
        a.audioReset()
        a.audioSample(base)
        assertEquals(Decision.PLAY, a.audio(base, 0))
        assertNull(a.takeAudioDropped())
        assertEquals(0L, a.pendingSkipUs(0))
    }

    @Test
    fun videoOnlyPlaysEverything() {
        val a = AvStartAligner()
        a.videoEnabled(true)
        a.audioEnabled(false)
        a.videoReset()
        a.videoSample(base)
        assertEquals(Decision.PLAY, a.video(base, 0))
        assertEquals(0L, a.pendingSkipUs(0))
    }

    @Test
    fun unknownVideoHoldsTheAudioThenPlaysAfterTheGiveUp() {
        val a = started()
        a.audioSample(base)
        assertEquals(Decision.HOLD, a.audio(base, 1_000))
        assertEquals(Decision.HOLD, a.audio(base, 2_999))
        assertEquals(Decision.PLAY, a.audio(base, 3_000))
        // Video known later doesn't drop audio that already plays.
        a.videoSample(base + 500_000)
        assertEquals(Decision.PLAY, a.audio(base + 21_333, 3_010))
    }

    @Test
    fun startsWithinOneBufferSkipNothing() {
        val a = started()
        a.videoSample(base + 10_000)
        a.audioSample(base)
        assertEquals(Decision.PLAY, a.audio(base, 0))
        assertEquals(Decision.PLAY, a.video(base + 10_000, 0))
        assertNull(a.takeAudioDropped())
        assertNull(a.takeVideoSkipped())
    }

    @Test
    fun aResetAlignsAgain() {
        val a = started()
        a.videoSample(base)
        a.audioSample(base)
        assertEquals(Decision.PLAY, a.audio(base, 0))
        // A seek: both renderers reset; the video's new first sample is later.
        a.videoReset()
        a.audioReset()
        a.audioSample(base + 5_000_000)
        assertEquals(Decision.HOLD, a.audio(base + 5_000_000, 10))
        a.videoSample(base + 6_000_000)
        assertEquals(Decision.SKIP, a.audio(base + 5_000_000, 20))
        assertEquals(Decision.PLAY, a.audio(base + 6_000_000, 30))
    }

    @Test
    fun onlyTheFirstSampleCounts() {
        val a = started()
        a.videoSample(base + 100_000)
        a.videoSample(base + 140_000)
        a.audioSample(base)
        assertEquals(Decision.SKIP, a.audio(base + 50_000, 0))
        assertEquals(Decision.PLAY, a.audio(base + 100_000, 0))
    }

    // ---- The start's buffer ----

    @Test
    fun theStartBufferCountsFromTheLaterStart() {
        val a = started()
        assertEquals(0L, a.pendingSkipUs(0))
        a.videoSample(base + 2_473_000, base)
        a.audioSample(base, base)
        assertEquals(2_473_000L, a.pendingSkipUs(0))
        assertEquals(473_000L, a.pendingSkipUs(2_000_000))
        // Aligned while the player still buffers: the start stays ahead of the
        // position until playback reaches it.
        assertEquals(Decision.SKIP, a.audio(base, 0))
        assertEquals(Decision.PLAY, a.audio(base + 2_473_000, 0))
        assertEquals(Decision.PLAY, a.video(base + 2_473_000, 0))
        assertEquals(2_473_000L, a.pendingSkipUs(0))
        assertEquals(0L, a.pendingSkipUs(2_473_000))
    }

    @Test
    fun theStartBufferCountsFromLateAudioToo() {
        val a = started()
        a.videoSample(base, base)
        a.audioSample(base + 1_170_000, base)
        assertEquals(Decision.SKIP, a.video(base, 0))
        assertEquals(1_170_000L, a.pendingSkipUs(0))
    }

    @Test
    fun nothingPendingWhenNothingWasDropped() {
        val a = started()
        a.videoSample(base + 10_000, base)
        a.audioSample(base, base)
        assertEquals(Decision.PLAY, a.audio(base, 0))
        assertEquals(Decision.PLAY, a.video(base + 10_000, 0))
        assertEquals(0L, a.pendingSkipUs(0))
    }
}
