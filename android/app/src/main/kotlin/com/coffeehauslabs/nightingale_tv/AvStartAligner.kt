package com.coffeehauslabs.nightingale_tv

/** Starts picture and sound together (video-size-surface-swap, design D4).
 *  After a playback start (an open or a seek), a stream whose video and audio
 *  begin at different times starts at the later of the two: the audio before
 *  the first video sample is dropped (as mpv's `initial-audio-sync` does), or
 *  the video before the first audio sample is skipped unshown. Either way the
 *  picture never stands still while the sound plays, and the picture never
 *  jumps ahead once the sound starts.
 *
 *  Times are renderer timestamps (µs), the same for audio and video. Called
 *  only from the playback thread. */
class AvStartAligner(private val giveUpMs: Long = 2_000) {

    enum class Decision { SKIP, HOLD, PLAY }

    /** A buffer that starts less than this before the start is kept (an AAC
     *  frame is 21–23 ms; a video frame at 50 fps is 20 ms). */
    private val toleranceUs = 15_000L

    private class Track {
        var enabled = false
        var firstUs: Long? = null
        var firstPeriodUs: Long? = null
        var aligning = false
        var holdingSinceMs: Long? = null
        var firstSkippedUs: Long? = null
        var skippedUs = 0L
        var report: Long? = null

        fun reset() {
            firstUs = null
            firstPeriodUs = null
            aligning = true
            holdingSinceMs = null
            firstSkippedUs = null
            skippedUs = 0L
            report = null
        }
    }

    private val video = Track()
    private val audio = Track()

    fun videoEnabled(enabled: Boolean) = enable(video, enabled)
    fun audioEnabled(enabled: Boolean) = enable(audio, enabled)

    private fun enable(track: Track, enabled: Boolean) {
        track.enabled = enabled
        if (!enabled) {
            track.firstUs = null
            track.firstPeriodUs = null
            track.aligning = false
        }
    }

    /** A renderer's position reset (open or seek): its next sample is its
     *  first, and its next buffers are aligned. */
    fun videoReset() = video.reset()
    fun audioReset() = audio.reset()

    /** A sample queued to a decoder at renderer time [timeUs], whose stream
     *  starts its period at renderer time [offsetUs]; only the first after a
     *  reset counts. */
    fun videoSample(timeUs: Long, offsetUs: Long = 0) = sample(video, timeUs, offsetUs)
    fun audioSample(timeUs: Long, offsetUs: Long = 0) = sample(audio, timeUs, offsetUs)

    private fun sample(track: Track, timeUs: Long, offsetUs: Long) {
        if (track.firstUs != null) return
        track.firstUs = timeUs
        track.firstPeriodUs = timeUs - offsetUs
    }

    /** What to do with a decoded buffer at [timeUs], at wall time [nowMs].
     *  After a track's first PLAY, all its buffers play until its next reset. */
    fun audio(timeUs: Long, nowMs: Long): Decision = decide(audio, video, timeUs, nowMs)
    fun video(timeUs: Long, nowMs: Long): Decision = decide(video, audio, timeUs, nowMs)

    private fun decide(self: Track, other: Track, timeUs: Long, nowMs: Long): Decision {
        if (!self.aligning) return Decision.PLAY
        if (self.firstUs == null) self.firstUs = timeUs
        if (!other.enabled) return stop(self)
        val otherFirst = other.firstUs
        if (otherFirst == null) {
            val since = self.holdingSinceMs ?: nowMs.also { self.holdingSinceMs = it }
            return if (nowMs - since >= giveUpMs) stop(self) else Decision.HOLD
        }
        val start = maxOf(self.firstUs!!, otherFirst)
        if (timeUs < start - toleranceUs) {
            if (self.firstSkippedUs == null) self.firstSkippedUs = timeUs
            self.skippedUs = start - self.firstSkippedUs!!
            return Decision.SKIP
        }
        return stop(self)
    }

    private fun stop(track: Track): Decision {
        track.aligning = false
        track.holdingSinceMs = null
        if (track.skippedUs > 0) track.report = track.skippedUs
        return Decision.PLAY
    }

    /** The audio (or video) dropped by the alignment that just ended, once,
     *  for one diagnostics line. */
    fun takeAudioDropped(): Long? = audio.report.also { audio.report = null }
    fun takeVideoSkipped(): Long? = video.report.also { video.report = null }

    /** How far ahead of [positionUs] (period time) the start is, while a
     *  track is being or was aligned: the start's buffer only counts from
     *  there, or playback would start and then run dry. The renderers align
     *  while the player is still buffering, so this lasts until the position
     *  reaches the start, not just while aligning. */
    fun pendingSkipUs(positionUs: Long): Long {
        if (!video.enabled || !audio.enabled) return 0
        val active = video.aligning || audio.aligning || video.skippedUs > 0 || audio.skippedUs > 0
        if (!active) return 0
        val start = listOfNotNull(video.firstPeriodUs, audio.firstPeriodUs).maxOrNull() ?: return 0
        return (start - positionUs).coerceAtLeast(0)
    }
}
