package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Format
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.text.Cue
import androidx.media3.common.text.CueGroup
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.LoadingInfo
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioCapabilities
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.ClippingMediaSource
import androidx.media3.exoplayer.source.ForwardingTimeline
import androidx.media3.exoplayer.source.MediaPeriod
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.rtsp.RtspMediaSource
import androidx.media3.exoplayer.source.SampleStream
import androidx.media3.exoplayer.source.TrackGroupArray
import androidx.media3.exoplayer.source.WrappingMediaSource
import androidx.media3.exoplayer.trackselection.ExoTrackSelection
import androidx.media3.exoplayer.upstream.Allocator
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoFrameMetadataListener
import androidx.media3.exoplayer.video.VideoRendererEventListener
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import okhttp3.OkHttpClient
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/** ExoPlayer behind the Dart `ExoTunerPlayer` (lib/playback/exo_tuner_player.dart):
 *  one player per Dart player, decoding with MediaCodec straight into a Flutter
 *  texture's Surface. Its configuration never depends on the playback mode
 *  (direct-play spec). Methods on `nightingale_tv/player`; each player's events
 *  on `nightingale_tv/player/<id>`. */
@UnstableApi
class ExoTunerHost(
    private val context: Context,
    private val textures: TextureRegistry,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val players = mutableMapOf<Long, Instance>()

    /** Keep-alive connections, shared by every player (android-playback,
     *  "Buffering on Android"). */
    private val http = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "create") {
            val player = Instance(call.argument<Boolean>("leveling") ?: false)
            players[player.id] = player
            result.success(player.id)
            return
        }
        if (call.method == "capabilities") {
            result.success(DeviceCapabilities.query(context))
            return
        }
        val player = players[(call.argument<Number>("id"))?.toLong() ?: -1]
        if (player == null) {
            // Disposed meanwhile: nothing to do.
            result.success(null)
            return
        }
        try {
            when (call.method) {
                "open" -> player.open(
                    url = call.argument<String>("url")!!,
                    headers = call.argument<Map<String, String>>("headers") ?: emptyMap(),
                    startMs = call.argument<Number>("startMs")?.toLong(),
                    endMs = call.argument<Number>("endMs")?.toLong(),
                    exact = call.argument<Boolean>("exact") ?: true,
                    live = call.argument<Boolean>("live") ?: false,
                )
                "enqueue" -> player.enqueue(
                    url = call.argument<String>("url")!!,
                    headers = call.argument<Map<String, String>>("headers") ?: emptyMap(),
                    startMs = call.argument<Number>("startMs")?.toLong(),
                    endMs = call.argument<Number>("endMs")?.toLong(),
                )
                "advance" -> {
                    result.success(player.advance())
                    return
                }
                "clearQueue" -> player.clearQueue()
                "frameGap" -> {
                    result.success(player.frameGapMs(call.argument<Number>("windowMs")?.toLong() ?: 3000L))
                    return
                }
                "stop" -> player.stop()
                "captions" -> player.setCaptions(call.argument<Boolean>("on") ?: false)
                "setLeveling" -> player.setLeveling(call.argument<Boolean>("on") ?: false)
                "stats" -> {
                    result.success(player.stats())
                    return
                }
                "dispose" -> {
                    players.remove(player.id)
                    player.dispose()
                }
                else -> {
                    result.notImplemented()
                    return
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("player", e.message ?: e.toString(), null)
        }
    }

    /** When the activity goes: every player with it. */
    fun disposeAll() {
        players.values.forEach { it.dispose() }
        players.clear()
    }

    /** [leveling]: volume leveling (volume-leveling spec) at creation; see
     *  [setLeveling]. */
    private inner class Instance(leveling: Boolean) :
        Player.Listener, AnalyticsListener, TextureRegistry.SurfaceProducer.Callback, EventChannel.StreamHandler {

        private val producer = textures.createSurfaceProducer().apply { setSize(1920, 1080) }
        val id: Long = producer.id()

        private val main = Handler(Looper.getMainLooper())
        private val events = EventChannel(messenger, "nightingale_tv/player/$id")
        private var sink: EventChannel.EventSink? = null

        /** PNG-encodes image subtitles off the main thread. */
        private val encoder = Executors.newSingleThreadExecutor()

        /** Bytes read from the server (through the app's playback proxy), for
         *  the load rate. Counted on the loader's thread. */
        private val bytesLoaded = AtomicLong()
        private val transfers = object : TransferListener {
            override fun onTransferInitializing(source: DataSource, dataSpec: DataSpec, isNetwork: Boolean) {}
            override fun onTransferStart(source: DataSource, dataSpec: DataSpec, isNetwork: Boolean) {}
            override fun onBytesTransferred(source: DataSource, dataSpec: DataSpec, isNetwork: Boolean, bytes: Int) {
                bytesLoaded.addAndGet(bytes.toLong())
            }
            override fun onTransferEnd(source: DataSource, dataSpec: DataSpec, isNetwork: Boolean) {}
        }

        /** Volume leveling's processor while leveling is on (design D3). */
        private var leveler: LevelingAudioProcessor? = if (leveling) LevelingAudioProcessor() else null

        /** Built in init, after everything [attach] uses. */
        private lateinit var player: ExoPlayer

        private fun buildPlayer(): ExoPlayer = ExoPlayer.Builder(context, Renderers(context, leveler))
            .setLoadControl(
                // Design D7: up to 60 s ahead, never over 100 MB (4K on 1–2 GB
                // boxes), playing once 2.5 s is in.
                DefaultLoadControl.Builder()
                    .setBufferDurationsMs(30_000, 60_000, 2_500, 5_000)
                    .setTargetBufferBytes(100 * 1024 * 1024)
                    .setPrioritizeTimeOverSizeThresholds(false)
                    .build()
            )
            .setLooper(Looper.getMainLooper())
            .build()
            .also { attach(it) }

        private var captions = false

        /** This open's state, for events and the diagnostics. */
        private var completed = false
        private var hadPicture = false
        private var rebufferSince = 0L
        private var videoDecoder = "-"
        private var audioDecoder = "-"

        /** The playlist holds the next segment after the item playing
         *  (segment-handover spec), and whether the player moved on to the
         *  one queued last. */
        private var queued = false
        private var moved = false

        /** Queued while nothing played (a station ID card showed): it's the
         *  only item, loaded and paused on its first picture. */
        private var startsPaused = false

        /** When the last frames were due on screen (System.nanoTime), for the
         *  gap at a hand-over. Written on the playback thread. */
        private val frameTimes = LongArray(512)
        private var frameCount = 0
        private val frames = VideoFrameMetadataListener { _, releaseTimeNs, _, _ ->
            synchronized(frameTimes) {
                frameTimes[frameCount % frameTimes.size] = releaseTimeNs
                frameCount++
            }
        }

        /** Position ticks while playing (as mpv's position stream). */
        private val ticker = object : Runnable {
            override fun run() {
                send(mapOf("e" to "position", "ms" to player.currentPosition))
                if (player.isPlaying) main.postDelayed(this, 200)
            }
        }

        /** The leveling processor's counters every 5 s while leveling is on
         *  (design D6), for the diagnostics' LEVEL lines. */
        private val levelTicker = object : Runnable {
            override fun run() {
                val leveler = leveler ?: return
                leveler.takeStats()?.let { send(mapOf("e" to "level") + it) }
                main.postDelayed(this, 5_000)
            }
        }

        init {
            events.setStreamHandler(this)
            producer.setCallback(this)
            player = buildPlayer()
            if (leveler != null) main.postDelayed(levelTicker, 5_000)
        }

        /** Wires a new ExoPlayer to the texture and to this instance. */
        private fun attach(player: ExoPlayer) {
            player.setVideoSurface(producer.surface)
            player.addListener(this)
            player.addAnalyticsListener(this)
            player.setVideoFrameMetadataListener(frames)
            player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, !captions)
                .build()
        }

        /** Volume leveling on or off (design D4): ExoPlayer is built again
         *  with the matching audio output, on the same texture. What played
         *  stops; the tuner re-tunes. */
        fun setLeveling(on: Boolean) {
            if (on == (leveler != null)) return
            stop()
            main.removeCallbacks(levelTicker)
            player.removeListener(this)
            player.removeAnalyticsListener(this)
            player.release()
            leveler = if (on) LevelingAudioProcessor() else null
            completed = false
            hadPicture = false
            rebufferSince = 0L
            videoDecoder = "-"
            audioDecoder = "-"
            player = buildPlayer()
            log("info exo: player rebuilt with volume leveling ${if (on) "on (pcm-only)" else "off"}")
            if (on) main.postDelayed(levelTicker, 5_000)
        }

        // ---- Methods ----------------------------------------------------------

        /** [url], read through OkHttp with [headers], clipped at [endMs]. */
        private fun source(url: String, headers: Map<String, String>, endMs: Long?): MediaSource {
            val data = OkHttpDataSource.Factory(http)
                .setUserAgent("Nightingale TV")
                .setDefaultRequestProperties(headers)
                .setTransferListener(transfers)
            val extractors = DefaultExtractorsFactory()
                // Jellyfin's MPEG-TS conversions, and .ts/.m2ts files.
                .setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES)
            // A playlist (Plex's transcodes) plays as HLS; anything else is
            // one file or stream.
            val hls = Uri.parse(url).path?.endsWith(".m3u8") == true
            var source: MediaSource = if (hls) {
                HlsMediaSource.Factory(data)
                    .setExtractorFactory(
                        DefaultHlsExtractorFactory(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES, true)
                    )
                    .setAllowChunklessPreparation(true)
                    .createMediaSource(MediaItem.fromUri(url))
            } else {
                ProgressiveMediaSource.Factory(data, extractors)
                    .createMediaSource(MediaItem.fromUri(url))
            }
            if (endMs != null && endMs > 0L) {
                source = ClippingMediaSource.Builder(source)
                    .setEndPositionMs(endMs)
                    .build()
            }
            return source
        }

        /** A Live TV source's stream (live-playback D9): no clipping and no
         *  start (it plays from the live point), HLS, RTSP or one endless
         *  stream by its address, opened with the entry's own headers. A user
         *  agent goes to OkHttp's own setting (as a header too, it would be
         *  sent twice). Interlaced video is the device decoder's to handle,
         *  as in other Android TV apps. */
        private fun liveSource(url: String, headers: Map<String, String>): MediaSource {
            val uri = Uri.parse(url)
            if (uri.scheme.equals("rtsp", ignoreCase = true)) {
                return RtspMediaSource.Factory().createMediaSource(MediaItem.fromUri(url))
            }
            val agent = headers.entries.firstOrNull { it.key.equals("User-Agent", ignoreCase = true) }
            val data = OkHttpDataSource.Factory(http)
                .setUserAgent(agent?.value ?: "Nightingale TV")
                .setDefaultRequestProperties(headers.filterKeys { !it.equals("User-Agent", ignoreCase = true) })
                .setTransferListener(transfers)
            val hls = uri.path?.endsWith(".m3u8", ignoreCase = true) == true ||
                uri.query?.contains("m3u8", ignoreCase = true) == true
            return if (hls) {
                HlsMediaSource.Factory(data)
                    .setExtractorFactory(
                        DefaultHlsExtractorFactory(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES, true)
                    )
                    .setAllowChunklessPreparation(true)
                    .createMediaSource(MediaItem.Builder().setUri(url).setMimeType(MimeTypes.APPLICATION_M3U8).build())
            } else {
                ProgressiveMediaSource.Factory(
                    data,
                    DefaultExtractorsFactory()
                        .setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES)
                        // Broadcast captions (CEA-608 in the video), even
                        // when the stream doesn't declare them, as HLS does.
                        .setTsSubtitleFormats(
                            listOf(Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_CEA608).setAccessibilityChannel(1).build())
                        ),
                ).createMediaSource(MediaItem.fromUri(url))
            }
        }

        fun open(url: String, headers: Map<String, String>, startMs: Long?, endMs: Long?, exact: Boolean, live: Boolean = false) {
            undecodable = false
            completed = false
            hadPicture = false
            rebufferSince = 0L
            queued = false
            moved = false
            startsPaused = false
            if (live) {
                player.setSeekParameters(SeekParameters.DEFAULT)
                player.setMediaSource(liveSource(url, headers))
                player.prepare()
                player.playWhenReady = true
                return
            }
            var source = source(url, headers, endMs)
            // Design D5: a keyframe start, not a clipping start, so the
            // position stays on the file's own timeline. Outside the clipping,
            // which never starts a period before the position asked for.
            if (!exact && (startMs ?: 0L) > 0L) source = KeyframeStartSource(source)
            player.setSeekParameters(if (exact) SeekParameters.EXACT else SeekParameters.PREVIOUS_SYNC)
            player.setMediaSource(source, startMs ?: 0L)
            player.prepare()
            player.playWhenReady = true
        }

        /** The next segment, after the item playing: ExoPlayer loads it once
         *  that item is loaded to its clipped end, and plays on into it. It
         *  starts exactly at [startMs] on its file's own timeline (its window's
         *  default position, not a clipping start). */
        fun enqueue(url: String, headers: Map<String, String>, startMs: Long?, endMs: Long?) {
            clearQueue()
            val source = StartAtSource(source(url, headers, endMs), (startMs ?: 0L) * 1000)
            if (player.mediaItemCount == 0) {
                completed = false
                hadPicture = false
                rebufferSince = 0L
                player.setSeekParameters(SeekParameters.EXACT)
                player.setMediaSource(source)
                player.playWhenReady = false
                player.prepare()
                queued = true
                startsPaused = true
                moved = false
                return
            }
            player.addMediaSource(source)
            // A hand-over by advance() is a seek: to the exact start.
            player.setSeekParameters(SeekParameters.EXACT)
            queued = true
            moved = false
        }

        /** Moves on to the queued item now. */
        fun advance(): Boolean {
            if (moved) return true
            if (startsPaused) {
                startsPaused = false
                queued = false
                moved = true
                player.playWhenReady = true
                send(mapOf("e" to "advanced"))
                return true
            }
            if (!queued || !player.hasNextMediaItem()) return false
            player.seekToNextMediaItem()
            return true
        }

        fun clearQueue() {
            if (startsPaused) {
                startsPaused = false
                queued = false
                player.stop()
                player.clearMediaItems()
                return
            }
            queued = false
            val next = player.currentMediaItemIndex + 1
            if (player.mediaItemCount > next) player.removeMediaItems(next, player.mediaItemCount)
        }

        /** The longest time between two frames due on screen in the last
         *  [windowMs], counting the last one up to now. */
        fun frameGapMs(windowMs: Long): Int? {
            val now = System.nanoTime()
            val from = now - windowMs * 1_000_000
            synchronized(frameTimes) {
                if (frameCount == 0) return null
                val count = minOf(frameCount, frameTimes.size)
                var gap = 0L
                var before = -1L
                for (i in frameCount - count until frameCount) {
                    val t = frameTimes[i % frameTimes.size]
                    if (before >= 0 && t >= from && t - before > gap) gap = t - before
                    before = t
                }
                if (now - before > gap) gap = now - before
                return (gap / 1_000_000).toInt()
            }
        }

        fun stop() {
            queued = false
            moved = false
            startsPaused = false
            main.removeCallbacks(ticker)
            player.stop()
            player.clearMediaItems()
            send(mapOf("e" to "cues", "text" to emptyList<String>(), "images" to emptyList<Any>()))
        }

        fun setCaptions(on: Boolean) {
            captions = on
            val params = player.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, !on)
            if (!on) params.clearOverridesOfType(C.TRACK_TYPE_TEXT)
            player.trackSelectionParameters = params.build()
            if (on) selectSubtitles(player.currentTracks)
        }

        /** Captions on: a subtitle track even when none is marked default
         *  (as mpv's "auto"): the default one, else one in the device's
         *  language, else the first. */
        private fun selectSubtitles(tracks: Tracks) {
            if (!captions) return
            val text = tracks.groups.filter { it.type == C.TRACK_TYPE_TEXT && it.isSupported }
            if (text.isEmpty() || text.any { it.isSelected }) return
            val language = Locale.getDefault().language
            val pick = text.firstOrNull { (it.getTrackFormat(0).selectionFlags and C.SELECTION_FLAG_DEFAULT) != 0 }
                ?: text.firstOrNull { it.getTrackFormat(0).language?.startsWith(language) == true }
                ?: text.first()
            player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                .addOverride(TrackSelectionOverride(pick.mediaTrackGroup, 0))
                .build()
        }

        /** What the diagnostics and the tuner's sampler read. */
        fun stats(): Map<String, Any?> {
            val video = player.videoFormat
            val audio = player.audioFormat
            val counters = player.videoDecoderCounters
            val bitrate = listOf(video, audio).sumOf { f ->
                val b = f?.averageBitrate?.takeIf { it > 0 } ?: f?.bitrate?.takeIf { it > 0 } ?: 0
                b.toLong()
            }
            return mapOf(
                "positionMs" to player.currentPosition,
                "bufferedMs" to player.bufferedPosition,
                "durationMs" to player.duration.takeIf { it != C.TIME_UNSET },
                "state" to when (player.playbackState) {
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY -> "ready"
                    else -> "ended"
                },
                "playing" to player.isPlaying,
                "started" to hadPicture,
                "bytesLoaded" to bytesLoaded.get(),
                "rendered" to (counters?.renderedOutputBufferCount ?: 0),
                "dropped" to (counters?.droppedBufferCount ?: 0),
                "decoderDropped" to (counters?.droppedInputBufferCount ?: 0),
                "skipped" to (counters?.skippedOutputBufferCount ?: 0),
                "bitrate" to bitrate.takeIf { video != null && it > 0 },
                "container" to (video?.containerMimeType ?: audio?.containerMimeType),
                "videoCodec" to video?.sampleMimeType,
                "codecs" to video?.codecs,
                "width" to video?.width,
                "height" to video?.height,
                "fps" to video?.frameRate,
                "colorTransfer" to video?.colorInfo?.colorTransfer,
                "videoDecoder" to videoDecoder,
                "audioCodec" to audio?.sampleMimeType,
                "audioChannels" to audio?.channelCount,
                "audioDecoder" to audioDecoder,
            )
        }

        fun dispose() {
            main.removeCallbacks(ticker)
            main.removeCallbacks(levelTicker)
            events.setStreamHandler(null)
            sink = null
            player.removeListener(this)
            player.removeAnalyticsListener(this)
            player.release()
            producer.release()
            encoder.shutdownNow()
        }

        // ---- Events -----------------------------------------------------------

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
        }

        override fun onCancel(arguments: Any?) {
            sink = null
        }

        private fun send(event: Map<String, Any?>) {
            sink?.success(event)
        }

        private fun log(line: String) = send(mapOf("e" to "log", "line" to line))

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            send(mapOf("e" to "playing", "v" to isPlaying))
            main.removeCallbacks(ticker)
            if (isPlaying) main.post(ticker)
        }

        override fun onPlaybackStateChanged(state: Int) {
            send(mapOf("e" to "buffering", "v" to (state == Player.STATE_BUFFERING)))
            val now = System.currentTimeMillis()
            when (state) {
                Player.STATE_READY -> {
                    if (rebufferSince != 0L) {
                        log("info exo: rebuffer ended after ${now - rebufferSince} ms at ${player.currentPosition} ms")
                        rebufferSince = 0L
                    }
                    hadPicture = true
                }
                Player.STATE_BUFFERING -> if (hadPicture && rebufferSince == 0L) {
                    rebufferSince = now
                    log("info exo: rebuffer started at ${player.currentPosition} ms (buffered ${player.bufferedPosition - player.currentPosition} ms)")
                }
                Player.STATE_ENDED -> if (!completed) {
                    completed = true
                    send(mapOf("e" to "position", "ms" to player.currentPosition))
                    send(mapOf("e" to "completed", "v" to true))
                }
            }
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            if (!queued) return
            if (reason != Player.MEDIA_ITEM_TRANSITION_REASON_AUTO && reason != Player.MEDIA_ITEM_TRANSITION_REASON_SEEK) return
            queued = false
            moved = true
            // Only the item playing stays in the playlist.
            main.post {
                val index = player.currentMediaItemIndex
                if (index > 0) player.removeMediaItems(0, index)
            }
            send(mapOf("e" to "position", "ms" to player.currentPosition))
            send(mapOf("e" to "advanced"))
        }

        /** This open's video couldn't be decoded, and that was said. */
        private var undecodable = false

        override fun onTracksChanged(tracks: Tracks) {
            selectSubtitles(tracks)
            send(mapOf("e" to "tracks"))
            val text = tracks.groups.filter { it.type == C.TRACK_TYPE_TEXT }
            if (text.isNotEmpty()) {
                log("info exo: text tracks " + text.joinToString { g ->
                    "${g.getTrackFormat(0).sampleMimeType}${if (g.isSupported) "" else " (unsupported)"}${if (g.isSelected) " selected" else ""}"
                })
            }
            // Video that no decoder here takes plays nothing and raises no
            // error: it's said, so the tuner can (a library item converts, a
            // live channel shows "can't play this channel's video").
            val video = tracks.groups.filter { it.type == C.TRACK_TYPE_VIDEO }
            if (!undecodable && video.isNotEmpty() && video.none { it.isSupported }) {
                undecodable = true
                val mime = video.first().getTrackFormat(0).sampleMimeType ?: "video"
                log("error exo: no decoder for $mime")
                send(mapOf("e" to "error", "message" to "VIDEO_UNSUPPORTED: no decoder for $mime"))
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            val message = error.cause?.message?.let { "${error.errorCodeName}: $it" } ?: error.errorCodeName
            // The queued item failed to load (ExoPlayer says so once the item
            // playing is read to its end): it's dropped and opens at the
            // hand-over as usual, and the item playing plays on.
            if (startsPaused) {
                log("error exo: next segment: $message (dropped from the queue)")
                clearQueue()
                return
            }
            val failed = (error as? ExoPlaybackException)?.mediaPeriodId?.periodUid
            val index = failed?.let { player.currentTimeline.getIndexOfPeriod(it) } ?: C.INDEX_UNSET
            if (queued && index != C.INDEX_UNSET && index > player.currentPeriodIndex) {
                log("error exo: next segment: $message (dropped from the queue)")
                clearQueue()
                player.prepare()
                return
            }
            log("error exo: $message")
            send(mapOf("e" to "error", "message" to message))
        }

        /** The texture's size: the video's, so a picture of any size fills
         *  it (a 720p channel after a 1080p one would otherwise take the
         *  corner of a 1080p texture, over the old picture). */
        private var textureSize = Pair(1920, 1080)

        override fun onVideoSizeChanged(videoSize: VideoSize) {
            if (videoSize.width <= 0 || videoSize.height <= 0) return
            val size = Pair(videoSize.width, videoSize.height)
            if (size != textureSize) {
                textureSize = size
                producer.setSize(size.first, size.second)
                // The decoder keeps the buffers it has unless its output is
                // detached and attached again (to the producer's Surface,
                // which resizing can also replace).
                player.clearVideoSurface()
                player.setVideoSurface(producer.surface)
            }
            send(
                mapOf(
                    "e" to "size",
                    "width" to videoSize.width,
                    "height" to videoSize.height,
                    "ratio" to videoSize.pixelWidthHeightRatio.toDouble(),
                )
            )
        }

        override fun onCues(cueGroup: CueGroup) {
            val text = mutableListOf<String>()
            val bitmaps = mutableListOf<Cue>()
            for (cue in cueGroup.cues) {
                if (cue.bitmap != null) bitmaps.add(cue) else cue.text?.toString()?.trim()?.let { if (it.isNotEmpty()) text.add(it) }
            }
            if (bitmaps.isEmpty()) {
                send(mapOf("e" to "cues", "text" to text, "images" to emptyList<Any>()))
                return
            }
            encoder.execute {
                val images = bitmaps.map { cue -> image(cue) }
                main.post { send(mapOf("e" to "cues", "text" to text, "images" to images)) }
            }
        }

        /** An image subtitle as PNG bytes, with where it goes as fractions of
         *  the picture: left, top, width and height (height null: keep the
         *  bitmap's aspect). */
        private fun image(cue: Cue): Map<String, Any?> {
            val bitmap = cue.bitmap!!
            val png = ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
            val width = cue.size.takeIf { it != Cue.DIMEN_UNSET } ?: 1f
            val height = cue.bitmapHeight.takeIf { it != Cue.DIMEN_UNSET }
            var left = cue.position.takeIf { it != Cue.DIMEN_UNSET } ?: 0.5f
            if (cue.positionAnchor == Cue.ANCHOR_TYPE_MIDDLE) left -= width / 2
            if (cue.positionAnchor == Cue.ANCHOR_TYPE_END) left -= width
            var top = if (cue.lineType == Cue.LINE_TYPE_FRACTION && cue.line != Cue.DIMEN_UNSET) cue.line else 0.85f
            val h = height ?: 0f
            if (cue.lineAnchor == Cue.ANCHOR_TYPE_MIDDLE) top -= h / 2
            if (cue.lineAnchor == Cue.ANCHOR_TYPE_END) top -= h
            return mapOf(
                "png" to png,
                "left" to left.toDouble(),
                "top" to top.toDouble(),
                "width" to width.toDouble(),
                "height" to height?.toDouble(),
                "aspect" to bitmap.width.toDouble() / bitmap.height.coerceAtLeast(1),
            )
        }

        // ---- Diagnostics (design D9) -------------------------------------------

        override fun onVideoDecoderInitialized(
            eventTime: AnalyticsListener.EventTime, decoderName: String,
            initializedTimestampMs: Long, initializationDurationMs: Long,
        ) {
            videoDecoder = "$decoderName (${if (DeviceCapabilities.isHardware(decoderName)) "hardware" else "software"})"
            log("info exo: video decoder $videoDecoder in $initializationDurationMs ms")
        }

        override fun onAudioDecoderInitialized(
            eventTime: AnalyticsListener.EventTime, decoderName: String,
            initializedTimestampMs: Long, initializationDurationMs: Long,
        ) {
            audioDecoder = decoderName
            log("info exo: audio decoder $decoderName in $initializationDurationMs ms")
        }

        override fun onDroppedVideoFrames(eventTime: AnalyticsListener.EventTime, droppedFrames: Int, elapsedMs: Long) {
            log("warn exo: $droppedFrames video frames dropped in $elapsedMs ms")
        }

        override fun onRenderedFirstFrame(eventTime: AnalyticsListener.EventTime, output: Any, renderTimeMs: Long) {
            log("info exo: first frame at ${eventTime.currentPlaybackPositionMs} ms")
        }

        override fun onVideoCodecError(eventTime: AnalyticsListener.EventTime, videoCodecError: Exception) {
            log("error exo: video codec: ${videoCodecError.message}")
        }

        override fun onAudioSinkError(eventTime: AnalyticsListener.EventTime, audioSinkError: Exception) {
            log("error exo: audio sink: ${audioSinkError.message}")
        }

        // ---- The texture's Surface ------------------------------------------------

        override fun onSurfaceAvailable() {
            player.setVideoSurface(producer.surface)
        }

        override fun onSurfaceCleanup() {
            player.clearVideoSurface()
        }
    }
}

/** MediaCodec renderers. Video decodes in hardware only (android-playback):
 *  what no hardware decoder takes is converted by Jellyfin, except H.264, the
 *  conversion target, which a device with no hardware H.264 decoder decodes
 *  in software rather than not at all. HDR streams ask the decoder for SDR
 *  output (Android 13+), since the Flutter texture is SDR. With [leveler]
 *  (volume leveling on), the audio goes through it. */
@UnstableApi
private class Renderers(context: Context, private val leveler: LevelingAudioProcessor?) : DefaultRenderersFactory(context) {
    init {
        setEnableDecoderFallback(true)
        setMediaCodecSelector { mimeType, secure, tunneling ->
            val all = MediaCodecUtil.getDecoderInfos(mimeType, secure, tunneling)
            if (!MimeTypes.isVideo(mimeType)) return@setMediaCodecSelector all
            val hardware = all.filter { DeviceCapabilities.isHardware(it) }
            if (hardware.isEmpty() && mimeType == MimeTypes.VIDEO_H264) all else hardware
        }
    }

    /** Leveling off: the default audio output, unchanged (passthrough to
     *  HDMI where the output takes it). Leveling on (design D3/D4): PCM only,
     *  through the leveler. A builder with no Context keeps the capabilities
     *  it's given; with one, it follows the output's and passes AC-3/E-AC-3
     *  through undecoded, which no processor can touch. */
    override fun buildAudioSink(context: Context, enableFloatOutput: Boolean, enableAudioTrackPlaybackParams: Boolean): AudioSink? {
        val leveler = leveler ?: return super.buildAudioSink(context, enableFloatOutput, enableAudioTrackPlaybackParams)
        @Suppress("DEPRECATION")
        return DefaultAudioSink.Builder()
            .setAudioCapabilities(AudioCapabilities.DEFAULT_AUDIO_CAPABILITIES)
            .setAudioProcessors(arrayOf(leveler))
            .setEnableFloatOutput(enableFloatOutput)
            .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
            .build()
    }

    override fun buildVideoRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        eventHandler: Handler,
        eventListener: VideoRendererEventListener,
        allowedVideoJoiningTimeMs: Long,
        out: ArrayList<Renderer>,
    ) {
        out.add(
            SdrVideoRenderer(
                MediaCodecVideoRenderer.Builder(context)
                    .setMediaCodecSelector(mediaCodecSelector)
                    .setAllowedJoiningTimeMs(allowedVideoJoiningTimeMs)
                    .setEnableDecoderFallback(enableDecoderFallback)
                    .setEventHandler(eventHandler)
                    .setEventListener(eventListener)
                    .setMaxDroppedFramesToNotify(MAX_DROPPED_VIDEO_FRAME_COUNT_TO_NOTIFY)
            )
        )
    }
}

@UnstableApi
private class SdrVideoRenderer(builder: Builder) : MediaCodecVideoRenderer(builder) {
    /** A decoder reused across a change of resolution keeps its old output
     *  size and crops the new picture inside it, and the Flutter texture
     *  ignores that crop (a 720p channel after a 1080p one showed in a
     *  corner, or zoomed). A new resolution gets a new decoder. */
    override fun canReuseCodec(
        codecInfo: MediaCodecInfo, oldFormat: Format, newFormat: Format, isNewFormatTheSameSource: Boolean,
    ): DecoderReuseEvaluation {
        if (oldFormat.width != newFormat.width || oldFormat.height != newFormat.height) {
            return DecoderReuseEvaluation(
                codecInfo.name, oldFormat, newFormat,
                DecoderReuseEvaluation.REUSE_RESULT_NO,
                DecoderReuseEvaluation.DISCARD_REASON_VIDEO_RESOLUTION_CHANGED,
            )
        }
        return super.canReuseCodec(codecInfo, oldFormat, newFormat, isNewFormatTheSameSource)
    }

    override fun getMediaCodecConfiguration(
        codecInfo: MediaCodecInfo, format: Format, crypto: android.media.MediaCrypto?, codecOperatingRate: Float,
    ): MediaCodecAdapter.Configuration {
        val configuration = super.getMediaCodecConfiguration(codecInfo, format, crypto, codecOperatingRate)
        val transfer = format.colorInfo?.colorTransfer
        if (Build.VERSION.SDK_INT >= 33 && (transfer == C.COLOR_TRANSFER_ST2084 || transfer == C.COLOR_TRANSFER_HLG)) {
            configuration.mediaFormat.setInteger(MediaFormat.KEY_COLOR_TRANSFER_REQUEST, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }
        return configuration
    }
}

/** Starts its window at [startUs] (its default position), so a playlist item
 *  plays from there, exactly, on its file's own timeline. */
@UnstableApi
private class StartAtSource(source: MediaSource, private val startUs: Long) : WrappingMediaSource(source) {
    override fun onChildSourceInfoRefreshed(newTimeline: Timeline) {
        refreshSourceInfo(object : ForwardingTimeline(newTimeline) {
            override fun getWindow(windowIndex: Int, window: Timeline.Window, defaultPositionProjectionUs: Long): Timeline.Window {
                super.getWindow(windowIndex, window, defaultPositionProjectionUs)
                if (window.durationUs == C.TIME_UNSET || startUs < window.durationUs) window.defaultPositionUs = startUs
                return window
            }
        })
    }
}

/** Starts the media at the keyframe before the requested position (design
 *  D5): ExoPlayer applies seek parameters to seeks but not to the position a
 *  player is prepared at, so the period moves its own first start there. */
@UnstableApi
private class KeyframeStartSource(source: MediaSource) : WrappingMediaSource(source) {
    override fun createPeriod(id: MediaSource.MediaPeriodId, allocator: Allocator, startPositionUs: Long): MediaPeriod =
        KeyframeStartPeriod(mediaSource.createPeriod(id, allocator, startPositionUs))

    override fun releasePeriod(mediaPeriod: MediaPeriod) {
        mediaSource.releasePeriod((mediaPeriod as KeyframeStartPeriod).inner)
    }
}

@UnstableApi
private class KeyframeStartPeriod(val inner: MediaPeriod) : MediaPeriod, MediaPeriod.Callback {
    private var callback: MediaPeriod.Callback? = null
    private var started = false

    override fun prepare(callback: MediaPeriod.Callback, positionUs: Long) {
        this.callback = callback
        inner.prepare(this, positionUs)
    }

    override fun onPrepared(mediaPeriod: MediaPeriod) {
        callback?.onPrepared(this)
    }

    override fun onContinueLoadingRequested(source: MediaPeriod) {
        callback?.onContinueLoadingRequested(this)
    }

    override fun maybeThrowPrepareError() = inner.maybeThrowPrepareError()
    override fun getTrackGroups(): TrackGroupArray = inner.trackGroups

    override fun selectTracks(
        selections: Array<out ExoTrackSelection?>, mayRetainStreamFlags: BooleanArray,
        streams: Array<SampleStream?>, streamResetFlags: BooleanArray, positionUs: Long,
    ): Long {
        var position = positionUs
        if (!started) {
            started = true
            if (position > 0) position = inner.getAdjustedSeekPositionUs(position, SeekParameters.PREVIOUS_SYNC)
        }
        return inner.selectTracks(selections, mayRetainStreamFlags, streams, streamResetFlags, position)
    }

    override fun discardBuffer(positionUs: Long, toKeyframe: Boolean) = inner.discardBuffer(positionUs, toKeyframe)
    override fun readDiscontinuity(): Long = inner.readDiscontinuity()
    override fun seekToUs(positionUs: Long): Long = inner.seekToUs(positionUs)
    override fun getAdjustedSeekPositionUs(positionUs: Long, seekParameters: SeekParameters): Long =
        inner.getAdjustedSeekPositionUs(positionUs, seekParameters)
    override fun getBufferedPositionUs(): Long = inner.bufferedPositionUs
    override fun getNextLoadPositionUs(): Long = inner.nextLoadPositionUs
    override fun continueLoading(loadingInfo: LoadingInfo): Boolean = inner.continueLoading(loadingInfo)
    override fun isLoading(): Boolean = inner.isLoading
    override fun reevaluateBuffer(positionUs: Long) = inner.reevaluateBuffer(positionUs)
    override fun setEndPositionUs(endPositionUs: Long): Long = inner.setEndPositionUs(endPositionUs)
    override fun setUsesStreamPrerollFlags() = inner.setUsesStreamPrerollFlags()
}
