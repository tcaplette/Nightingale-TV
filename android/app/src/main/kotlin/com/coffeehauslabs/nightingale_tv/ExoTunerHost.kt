package com.coffeehauslabs.nightingale_tv

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Surface
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
import androidx.media3.exoplayer.LoadControl
import androidx.media3.exoplayer.LoadingInfo
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.SeekParameters
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.audio.AudioCapabilities
import androidx.media3.exoplayer.audio.AudioRendererEventListener
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.MediaCodecAudioRenderer
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.ClippingMediaSource
import androidx.media3.exoplayer.source.ForwardingTimeline
import androidx.media3.exoplayer.source.MediaPeriod
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
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
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.text.DefaultSubtitleParserFactory
import androidx.media3.extractor.text.SubtitleExtractor
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
                    subs = Subs.from(call.argument<Map<String, Any?>>("subtitles")),
                )
                "enqueue" -> player.enqueue(
                    url = call.argument<String>("url")!!,
                    headers = call.argument<Map<String, String>>("headers") ?: emptyMap(),
                    startMs = call.argument<Number>("startMs")?.toLong(),
                    endMs = call.argument<Number>("endMs")?.toLong(),
                    subs = Subs.from(call.argument<Map<String, Any?>>("subtitles")),
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
                "pause" -> player.pause()
                "resume" -> player.resume()
                "seek" -> player.seek(call.argument<Number>("ms")?.toLong() ?: 0L)
                "subtitles" -> player.setSubtitles(Subs.from(call.argument<Map<String, Any?>>("subtitles")))
                "setLeveling" -> player.setLeveling(call.argument<Boolean>("on") ?: false)
                "setVolume" -> player.setVolume(call.argument<Number>("volume")?.toFloat() ?: 1f)
                "stats" -> {
                    result.success(player.stats())
                    return
                }
                // The stream and decoder for a video report (video-report D8).
                "videoReport" -> {
                    result.success(player.videoReport())
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
        Player.Listener, AnalyticsListener, TextureRegistry.SurfaceProducer.Callback, EventChannel.StreamHandler,
        RenderHost {

        private val producer = textures.createSurfaceProducer().apply { setSize(1920, 1080) }
        val id: Long = producer.id()

        /** The texture's size: the video's, so a picture of any size fills
         *  it (the Flutter texture shows the whole buffer and ignores the
         *  decoder's crop). Written only by [prepareSurface], on the playback
         *  thread (video-size-surface-swap, design D2). */
        @Volatile private var textureSize = Pair(1920, 1080)

        /** The producer's Surface the player was last given, and whether
         *  Flutter has it (false between [onSurfaceCleanup] and
         *  [onSurfaceAvailable]). */
        @Volatile private var surface: Surface? = null
        @Volatile private var surfaceLive = true
        @Volatile private var disposed = false

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

        private fun buildPlayer(): ExoPlayer {
            // Picture and sound start together (video-size-surface-swap D4):
            // shared by this ExoPlayer's renderers and its load control.
            val aligner = AvStartAligner()
            return ExoPlayer.Builder(context, Renderers(context, leveler, this, aligner))
                .setLoadControl(
                    AlignedLoadControl(
                        // Design D7: up to 60 s ahead, never over 100 MB (4K on
                        // 1–2 GB boxes), playing once 2.5 s is in.
                        DefaultLoadControl.Builder()
                            .setBufferDurationsMs(30_000, 60_000, 2_500, 5_000)
                            .setTargetBufferBytes(100 * 1024 * 1024)
                            .setPrioritizeTimeOverSizeThresholds(false)
                            .build(),
                        aligner,
                        this,
                    )
                )
                .setLooper(Looper.getMainLooper())
                .build()
                .also { attach(it) }
        }

        /** The subtitles the item playing shows (subtitles spec), and the
         *  queued item's, which take over with it. */
        private var subs: Subs = Subs.Off
        private var queuedSubs: Subs = Subs.Off

        /** The item playing and the one queued, as opened, to re-prepare the
         *  item playing with a side-loaded track added. */
        private var current: Item? = null
        private var queuedItem: Item? = null

        /** The sleep timer's fade (sleep-timer spec), 0–1. One ExoPlayer plays
         *  the item on screen and the next one queued, so it covers both;
         *  kept across a rebuild. */
        private var volume = 1f

        /** This open's state, for events and the diagnostics. */
        private var completed = false
        private var hadPicture = false
        private var rebufferSince = 0L
        private var videoDecoder = "-"
        private var audioDecoder = "-"

        /** For a video report (video-report D8): the video decoder's name,
         *  its output format as it last reported it (every key, written on
         *  the playback thread), and the last size ExoPlayer reported. */
        @Volatile private var videoDecoderName: String? = null
        @Volatile private var decoderOutput: Map<String, String>? = null
        @Volatile private var lastVideoSize: Map<String, Any?>? = null

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
            player.setVideoSurface(producer.surface.also { surface = it })
            player.addListener(this)
            player.addAnalyticsListener(this)
            player.setVideoFrameMetadataListener(frames)
            player.volume = volume
            player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, subs == Subs.Off)
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

        /** [url], read through OkHttp with [headers], clipped at [endMs], with
         *  [subs]'s text track beside it when it's side-loaded. */
        private fun source(url: String, headers: Map<String, String>, endMs: Long?, subs: Subs = Subs.Off): MediaSource {
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
            if (subs is Subs.Side) source = MergingMediaSource(source, sideLoaded(subs))
            if (endMs != null && endMs > 0L) {
                source = ClippingMediaSource.Builder(source)
                    .setEndPositionMs(endMs)
                    .build()
            }
            return source
        }

        /** A text track loaded beside the stream, through OkHttp with the
         *  server's headers, parsed into cues as it loads (as ExoPlayer's own
         *  side-loaded subtitles are). */
        private fun sideLoaded(side: Subs.Side): MediaSource {
            val data = OkHttpDataSource.Factory(http)
                .setUserAgent("Nightingale TV")
                .setDefaultRequestProperties(side.headers)
            val format = Format.Builder()
                .setId(SIDE_LOADED_ID)
                .setSampleMimeType(side.mime)
                .setLanguage(side.language)
                .setLabel(side.label)
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build()
            val parsers = DefaultSubtitleParserFactory()
            val extractors = ExtractorsFactory { arrayOf<Extractor>(SubtitleExtractor(parsers.create(format), format)) }
            return ProgressiveMediaSource.Factory(data, extractors).createMediaSource(MediaItem.fromUri(side.url))
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

        fun open(
            url: String,
            headers: Map<String, String>,
            startMs: Long?,
            endMs: Long?,
            exact: Boolean,
            live: Boolean = false,
            subs: Subs = Subs.Off,
        ) {
            undecodable = false
            completed = false
            hadPicture = false
            rebufferSince = 0L
            queued = false
            moved = false
            startsPaused = false
            queuedItem = null
            current = Item(url, headers, endMs, subs, live)
            useSubtitles(subs)
            if (live) {
                player.setSeekParameters(SeekParameters.DEFAULT)
                player.setMediaSource(liveSource(url, headers))
                player.prepare()
                player.playWhenReady = true
                return
            }
            var source = source(url, headers, endMs, subs)
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
        fun enqueue(url: String, headers: Map<String, String>, startMs: Long?, endMs: Long?, subs: Subs = Subs.Off) {
            clearQueue()
            val source = StartAtSource(source(url, headers, endMs, subs), (startMs ?: 0L) * 1000)
            queuedItem = Item(url, headers, endMs, subs, false, startMs)
            queuedSubs = subs
            if (player.mediaItemCount == 0) {
                current = queuedItem
                useSubtitles(subs)
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
            queuedItem = null
            if (startsPaused) {
                startsPaused = false
                queued = false
                current = null
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
            current = null
            queuedItem = null
            main.removeCallbacks(ticker)
            player.stop()
            player.clearMediaItems()
            send(mapOf("e" to "cues", "text" to emptyList<String>(), "images" to emptyList<Any>()))
        }

        fun pause() {
            player.playWhenReady = false
        }

        fun setVolume(v: Float) {
            volume = v.coerceIn(0f, 1f)
            player.volume = volume
        }

        fun resume() {
            player.playWhenReady = true
        }

        /** Exactly to [ms] on the file's own timeline (a keyframe open left
         *  its seek parameters on the keyframes), inside the clipped end.
         *  Ticks stop while paused, so the new position is said here. */
        fun seek(ms: Long) {
            completed = false
            player.setSeekParameters(SeekParameters.EXACT)
            val duration = player.duration
            player.seekTo(if (duration != C.TIME_UNSET) ms.coerceAtMost((duration - 1).coerceAtLeast(0L)) else ms)
            send(mapOf("e" to "position", "ms" to player.currentPosition))
        }

        /** What the item playing shows as subtitles. A side-loaded track it
         *  wasn't opened with re-prepares it where it is, with the track
         *  added (and what's queued after it). */
        fun setSubtitles(next: Subs) {
            val item = current
            if (next is Subs.Side && item != null && !item.live && item.subs != next) {
                val position = player.currentPosition
                val playing = player.playWhenReady
                val updated = item.copy(subs = next)
                current = updated
                useSubtitles(next)
                player.setSeekParameters(SeekParameters.EXACT)
                player.setMediaSource(source(updated.url, updated.headers, updated.endMs, next), position)
                queuedItem?.let { q ->
                    player.addMediaSource(StartAtSource(source(q.url, q.headers, q.endMs, q.subs), (q.startMs ?: 0L) * 1000))
                }
                player.prepare()
                player.playWhenReady = playing
                log("info exo: re-prepared at ${position} ms with a side-loaded ${next.mime} track")
                return
            }
            if (item != null) current = item.copy(subs = next)
            useSubtitles(next)
        }

        /** Text tracks on or off for [next], and its track picked. */
        private fun useSubtitles(next: Subs) {
            subs = next
            val params = player.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, next == Subs.Off)
            if (next == Subs.Off) params.clearOverridesOfType(C.TRACK_TYPE_TEXT)
            player.trackSelectionParameters = params.build()
            if (next != Subs.Off) selectSubtitles(player.currentTracks)
        }

        /** The text track [subs] names: the side-loaded one; the one at its
         *  position among the stream's own (by language when the stream
         *  lists them differently); for a live stream's own captions (as
         *  mpv's "auto"), the default one, else one in the device's
         *  language, else the first. */
        private fun selectSubtitles(tracks: Tracks) {
            val wanted = subs
            if (wanted == Subs.Off) return
            val text = tracks.groups.filter { it.type == C.TRACK_TYPE_TEXT && it.isSupported }
            if (text.isEmpty()) return
            fun sideLoaded(g: Tracks.Group) = g.getTrackFormat(0).id?.endsWith(SIDE_LOADED_ID) == true
            val own = text.filter { !sideLoaded(it) }
            val pick = when (wanted) {
                is Subs.Side -> text.firstOrNull { sideLoaded(it) }
                is Subs.Embedded -> {
                    val at = own.getOrNull(wanted.position)
                    val lang = wanted.language
                    if (at != null && lang != null && !sameLanguage(at.getTrackFormat(0).language, lang)) {
                        own.firstOrNull { sameLanguage(it.getTrackFormat(0).language, lang) } ?: at
                    } else {
                        at
                    }
                }
                Subs.Stream -> {
                    if (text.any { it.isSelected }) return
                    val language = Locale.getDefault().language
                    text.firstOrNull { (it.getTrackFormat(0).selectionFlags and C.SELECTION_FLAG_DEFAULT) != 0 }
                        ?: text.firstOrNull { it.getTrackFormat(0).language?.startsWith(language) == true }
                        ?: text.first()
                }
                Subs.Off -> null
            } ?: return
            if (pick.isSelected && text.count { it.isSelected } == 1) return
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

        /** The item on screen's stream and decoder (video-report D8). */
        fun videoReport(): Map<String, Any?> {
            val format = player.videoFormat
            val name = videoDecoderName
            return mapOf(
                "input" to format?.let { describeFormat(it) },
                "decoder" to name,
                "decoder_hardware" to name?.let { DeviceCapabilities.isHardware(it) },
                "decoder_output" to decoderOutput,
                "decoder_caps" to if (name != null && format?.sampleMimeType != null) decoderCaps(name, format.sampleMimeType!!) else null,
                "texture_size" to "${textureSize.first}x${textureSize.second}",
                "video_size" to lastVideoSize,
            )
        }

        fun dispose() {
            disposed = true
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
            // The queued item's subtitles go on with it.
            current = queuedItem
            queuedItem = null
            useSubtitles(queuedSubs)
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

        /** Only the size, for the picture's aspect. The texture was already
         *  sized for it when its decoder was configured ([prepareSurface]);
         *  the decoder's output is never moved while it runs
         *  (video-size-surface-swap). */
        override fun onVideoSizeChanged(videoSize: VideoSize) {
            if (videoSize.width <= 0 || videoSize.height <= 0) return
            lastVideoSize = mapOf(
                "width" to videoSize.width,
                "height" to videoSize.height,
                "pixel_ratio" to videoSize.pixelWidthHeightRatio.toDouble(),
            )
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
            videoDecoderName = decoderName
            decoderOutput = null
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

        /** Back from the background: Flutter made the texture again, at the
         *  size last set. */
        override fun onSurfaceAvailable() {
            surfaceLive = true
            player.setVideoSurface(producer.surface.also { surface = it })
        }

        override fun onSurfaceCleanup() {
            surfaceLive = false
            surface = null
            player.clearVideoSurface()
        }

        /** Called on the playback thread as a decoder for [width]×[height]
         *  is configured, before it decodes anything (design D1/D2). When the
         *  size differs from the texture's, the texture is resized, and the
         *  Surface returned when that replaced it (an ImageReader producer,
         *  API 29+; a SurfaceTexture keeps its Surface): the renderer
         *  configures the new decoder on it. ExoPlayer's own record of the
         *  output follows on the main thread, with the latest Surface, which
         *  the renderer already has. */
        override fun note(line: String) {
            main.post { log(line) }
        }

        override fun outputFormat(format: android.media.MediaFormat?) {
            decoderOutput = format?.let { mediaFormatEntries(it) }
        }

        override fun prepareSurface(width: Int, height: Int): Surface? {
            if (width <= 0 || height <= 0) return null
            val size = Pair(width, height)
            if (size == textureSize) return null
            textureSize = size
            producer.setSize(width, height)
            // In the background: the texture comes back at this size and
            // onSurfaceAvailable attaches it.
            if (!surfaceLive) return null
            val next = producer.surface
            if (next === surface) {
                main.post { log("info exo: texture ${width}x${height}, same surface") }
                return null
            }
            surface = next
            main.post {
                log("info exo: texture ${width}x${height}, new surface before the decoder starts")
                val latest = surface
                if (!disposed && surfaceLive && latest != null) player.setVideoSurface(latest)
            }
            return next
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
private class Renderers(
    context: Context,
    private val leveler: LevelingAudioProcessor?,
    private val sizer: RenderHost,
    private val aligner: AvStartAligner,
) : DefaultRenderersFactory(context) {
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

    /** The default audio renderer, swapped for one built with the same
     *  arguments that drops the audio before the first picture. */
    override fun buildAudioRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        audioSink: AudioSink,
        eventHandler: Handler,
        eventListener: AudioRendererEventListener,
        out: ArrayList<Renderer>,
    ) {
        super.buildAudioRenderers(
            context, extensionRendererMode, mediaCodecSelector, enableDecoderFallback, audioSink, eventHandler, eventListener, out,
        )
        val index = out.indexOfFirst { it is MediaCodecAudioRenderer }
        if (index < 0) return
        out[index] = AlignedAudioRenderer(
            context, codecAdapterFactory, mediaCodecSelector, enableDecoderFallback, eventHandler, eventListener, audioSink,
            aligner, sizer,
        )
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
                sizer,
                aligner,
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

/** What the renderers need from their player: [prepareSurface] sizes the
 *  Flutter texture for a decoder about to be configured (see
 *  `Instance.prepareSurface`; the Surface to configure it on when the resize
 *  replaced it, else null), and [note] writes a diagnostics line. */
private interface RenderHost {
    /** A diagnostics line. */
    fun note(line: String)

    /** The video decoder's output format, as it reported it (video-report
     *  D8); on the playback thread. */
    fun outputFormat(format: android.media.MediaFormat?) {}

    fun prepareSurface(width: Int, height: Int): Surface?
}

@UnstableApi
private class SdrVideoRenderer(
    private val sizer: RenderHost,
    private val aligner: AvStartAligner,
    builder: Builder,
) : MediaCodecVideoRenderer(builder) {
    // What the audio renderer aligns to (design D4): whether there's video,
    // and the first sample queued after each playback start.
    override fun onEnabled(joining: Boolean, mayRenderStartOfStream: Boolean) {
        super.onEnabled(joining, mayRenderStartOfStream)
        aligner.videoEnabled(true)
    }

    override fun onDisabled() {
        aligner.videoEnabled(false)
        super.onDisabled()
    }

    override fun onPositionReset(positionUs: Long, joining: Boolean, sampleStreamIsResetToKeyFrame: Boolean) {
        super.onPositionReset(positionUs, joining, sampleStreamIsResetToKeyFrame)
        aligner.videoReset()
    }

    override fun onQueueInputBuffer(buffer: androidx.media3.decoder.DecoderInputBuffer) {
        super.onQueueInputBuffer(buffer)
        if (!buffer.isEndOfStream) aligner.videoSample(buffer.timeUs, outputStreamOffsetUs)
    }

    /** Frames before the first sound are skipped unshown (design D4), so the
     *  first picture is the one the sound starts with: otherwise it would
     *  stand still while they're dropped as late. */
    override fun processOutputBuffer(
        positionUs: Long, elapsedRealtimeUs: Long, codec: MediaCodecAdapter?, buffer: java.nio.ByteBuffer?,
        bufferIndex: Int, bufferFlags: Int, sampleCount: Int, bufferPresentationTimeUs: Long,
        isDecodeOnlyBuffer: Boolean, isLastBuffer: Boolean, format: Format,
    ): Boolean {
        if (!isDecodeOnlyBuffer && !isLastBuffer) {
            when (aligner.video(bufferPresentationTimeUs, SystemClock.elapsedRealtime())) {
                AvStartAligner.Decision.SKIP -> {
                    codec?.let { skipOutputBuffer(it, bufferIndex, bufferPresentationTimeUs) }
                    return true
                }
                AvStartAligner.Decision.HOLD -> return false
                AvStartAligner.Decision.PLAY -> aligner.takeVideoSkipped()?.let {
                    sizer.note("info exo: video before the first sound skipped: ${it / 1000} ms")
                }
            }
        }
        return super.processOutputBuffer(
            positionUs, elapsedRealtimeUs, codec, buffer, bufferIndex, bufferFlags, sampleCount,
            bufferPresentationTimeUs, isDecodeOnlyBuffer, isLastBuffer, format,
        )
    }

    override fun onOutputFormatChanged(format: Format, mediaFormat: MediaFormat?) {
        super.onOutputFormatChanged(format, mediaFormat)
        sizer.outputFormat(mediaFormat)
    }

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
        // No decoder exists here (the old one was released, see
        // canReuseCodec), so this only sets the display surface the new one
        // is configured on: nothing running is re-targeted.
        sizer.prepareSurface(format.width, format.height)?.let { handleMessage(Renderer.MSG_SET_VIDEO_OUTPUT, it) }
        val configuration = super.getMediaCodecConfiguration(codecInfo, format, crypto, codecOperatingRate)
        val transfer = format.colorInfo?.colorTransfer
        if (Build.VERSION.SDK_INT >= 33 && (transfer == C.COLOR_TRANSFER_ST2084 || transfer == C.COLOR_TRANSFER_HLG)) {
            configuration.mediaFormat.setInteger(MediaFormat.KEY_COLOR_TRANSFER_REQUEST, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }
        return configuration
    }
}

/** [inner], except that while the audio before the first picture is about to
 *  be dropped (design D4), the start's buffer counts only from the first
 *  picture: playback starts with 2.5 s in past it, not past the audio that
 *  never plays. */
@UnstableApi
private class AlignedLoadControl(
    private val inner: LoadControl,
    private val aligner: AvStartAligner,
    private val host: RenderHost,
) : LoadControl {
    override fun shouldStartPlayback(parameters: LoadControl.Parameters): Boolean {
        val skip = aligner.pendingSkipUs(parameters.playbackPositionUs)
        if (skip == 0L) return inner.shouldStartPlayback(parameters)
        val past = (parameters.bufferedDurationUs - skip).coerceAtLeast(0)
        val start = inner.shouldStartPlayback(
            LoadControl.Parameters(
                parameters.playerId, parameters.timeline, parameters.mediaPeriodId, parameters.playbackPositionUs,
                past, parameters.playbackSpeed, parameters.playWhenReady, parameters.rebuffering,
                parameters.targetLiveOffsetUs, parameters.lastRebufferRealtimeMs,
            )
        )
        if (start) host.note("info exo: playback starts with ${past / 1000} ms buffered past the first picture")
        return start
    }

    override fun onPrepared(playerId: PlayerId) = inner.onPrepared(playerId)
    override fun onTracksSelected(
        parameters: LoadControl.Parameters, trackGroups: TrackGroupArray, trackSelections: Array<out ExoTrackSelection?>,
    ) = inner.onTracksSelected(parameters, trackGroups, trackSelections)
    override fun onStopped(playerId: PlayerId) = inner.onStopped(playerId)
    override fun onReleased(playerId: PlayerId) = inner.onReleased(playerId)
    override fun getAllocator(playerId: PlayerId): Allocator = inner.getAllocator(playerId)
    override fun getBackBufferDurationUs(playerId: PlayerId): Long = inner.getBackBufferDurationUs(playerId)
    override fun retainBackBufferFromKeyframe(playerId: PlayerId): Boolean = inner.retainBackBufferFromKeyframe(playerId)
    override fun shouldContinueLoading(parameters: LoadControl.Parameters): Boolean = inner.shouldContinueLoading(parameters)
    override fun shouldContinuePreloading(
        playerId: PlayerId, timeline: Timeline, mediaPeriodId: MediaSource.MediaPeriodId, bufferedDurationUs: Long,
    ): Boolean = inner.shouldContinuePreloading(playerId, timeline, mediaPeriodId, bufferedDurationUs)
}

/** The default MediaCodec audio renderer, except that after a playback start
 *  (an open or a seek) it drops the decoded audio that comes before the
 *  first video sample, so picture and sound start together (design D4). A
 *  dropped buffer is released unplayed; the audio output's clock then starts
 *  at the first buffer kept. */
@UnstableApi
private class AlignedAudioRenderer(
    context: Context,
    codecAdapterFactory: MediaCodecAdapter.Factory,
    mediaCodecSelector: MediaCodecSelector,
    enableDecoderFallback: Boolean,
    eventHandler: Handler,
    eventListener: AudioRendererEventListener,
    audioSink: AudioSink,
    private val aligner: AvStartAligner,
    private val host: RenderHost,
) : MediaCodecAudioRenderer(
    context, codecAdapterFactory, mediaCodecSelector, enableDecoderFallback, eventHandler, eventListener, audioSink,
) {
    override fun onEnabled(joining: Boolean, mayRenderStartOfStream: Boolean) {
        super.onEnabled(joining, mayRenderStartOfStream)
        aligner.audioEnabled(true)
    }

    override fun onDisabled() {
        aligner.audioEnabled(false)
        super.onDisabled()
    }

    override fun onPositionReset(positionUs: Long, joining: Boolean, sampleStreamIsResetToKeyFrame: Boolean) {
        super.onPositionReset(positionUs, joining, sampleStreamIsResetToKeyFrame)
        aligner.audioReset()
    }

    override fun onQueueInputBuffer(buffer: androidx.media3.decoder.DecoderInputBuffer) {
        super.onQueueInputBuffer(buffer)
        if (!buffer.isEndOfStream) aligner.audioSample(buffer.timeUs, outputStreamOffsetUs)
    }

    override fun processOutputBuffer(
        positionUs: Long, elapsedRealtimeUs: Long, codec: MediaCodecAdapter?, buffer: java.nio.ByteBuffer?,
        bufferIndex: Int, bufferFlags: Int, sampleCount: Int, bufferPresentationTimeUs: Long,
        isDecodeOnlyBuffer: Boolean, isLastBuffer: Boolean, format: Format,
    ): Boolean {
        if (!isDecodeOnlyBuffer && !isLastBuffer) {
            when (aligner.audio(bufferPresentationTimeUs, SystemClock.elapsedRealtime())) {
                AvStartAligner.Decision.SKIP -> {
                    codec?.releaseOutputBuffer(bufferIndex, false)
                    decoderCounters.skippedOutputBufferCount += sampleCount
                    return true
                }
                AvStartAligner.Decision.HOLD -> return false
                AvStartAligner.Decision.PLAY -> aligner.takeAudioDropped()?.let {
                    host.note("info exo: audio before the first picture dropped: ${it / 1000} ms")
                }
            }
        }
        return super.processOutputBuffer(
            positionUs, elapsedRealtimeUs, codec, buffer, bufferIndex, bufferFlags, sampleCount,
            bufferPresentationTimeUs, isDecodeOnlyBuffer, isLastBuffer, format,
        )
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

/** The id of a side-loaded text track's format (ExoPlayer prefixes it with
 *  the merged source's index). */
private const val SIDE_LOADED_ID = "nightingale-side-loaded"

/** ISO 639 codes of either length (`en`, `eng`, `en-US`) for one language. */
private fun sameLanguage(a: String?, b: String): Boolean {
    if (a == null) return false
    fun three(code: String): String {
        val base = code.lowercase(Locale.ROOT).split('-', '_').first()
        if (base.length != 2) return base
        return try {
            Locale(base).isO3Language
        } catch (_: Exception) {
            base
        }
    }
    val x = three(a)
    val y = three(b)
    if (x == y) return true
    // 639-2/B and /T codes of the same language (ger/deu, fre/fra…).
    val pairs = mapOf(
        "ger" to "deu", "fre" to "fra", "dut" to "nld", "chi" to "zho", "cze" to "ces", "gre" to "ell",
        "per" to "fas", "rum" to "ron", "slo" to "slk", "alb" to "sqi", "arm" to "hye", "baq" to "eus",
        "bur" to "mya", "geo" to "kat", "ice" to "isl", "mac" to "mkd", "mao" to "mri", "may" to "msa",
        "tib" to "bod", "wel" to "cym",
    )
    return pairs[x] == y || pairs[y] == x
}

/** One item as opened, to build it again. */
private data class Item(
    val url: String,
    val headers: Map<String, String>,
    val endMs: Long?,
    val subs: Subs,
    val live: Boolean,
    val startMs: Long? = null,
)

/** What an item shows as subtitles (the Dart `SubtitleChoice`). */
private sealed class Subs {
    object Off : Subs()
    /** A live stream's own captions. */
    object Stream : Subs()
    data class Embedded(val position: Int, val language: String?) : Subs()
    data class Side(val url: String, val headers: Map<String, String>, val mime: String, val language: String?, val label: String?) : Subs()

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun from(m: Map<String, Any?>?): Subs = when (m?.get("kind")) {
            "stream" -> Stream
            "embedded" -> Embedded((m["position"] as? Number)?.toInt() ?: 0, m["language"] as? String)
            "side" -> Side(
                url = m["url"] as String,
                headers = (m["headers"] as? Map<String, String>) ?: emptyMap(),
                mime = (m["mime"] as? String) ?: MimeTypes.APPLICATION_SUBRIP,
                language = m["language"] as? String,
                label = m["label"] as? String,
            )
            else -> Off
        }
    }
}

/** A stream's video format, for a video report (video-report D8). */
@UnstableApi
internal fun describeFormat(f: Format): Map<String, Any?> = mapOf(
    "mime" to f.sampleMimeType,
    "codecs" to f.codecs,
    "width" to f.width,
    "height" to f.height,
    "frame_rate" to f.frameRate.toDouble(),
    "pixel_ratio" to f.pixelWidthHeightRatio.toDouble(),
    "color_space" to f.colorInfo?.colorSpace?.let { colorSpaceName(it) },
    "color_range" to f.colorInfo?.colorRange?.let { if (it == C.COLOR_RANGE_FULL) "full" else if (it == C.COLOR_RANGE_LIMITED) "limited" else "$it" },
    "color_transfer" to f.colorInfo?.colorTransfer?.let { colorTransferName(it) },
    "bit_depth" to f.colorInfo?.lumaBitdepth?.takeIf { it != Format.NO_VALUE },
    "hdr_static_info" to (f.colorInfo?.hdrStaticInfo != null),
)

private fun colorSpaceName(v: Int) = when (v) {
    C.COLOR_SPACE_BT709 -> "bt709"
    C.COLOR_SPACE_BT601 -> "bt601"
    C.COLOR_SPACE_BT2020 -> "bt2020"
    else -> "$v"
}

private fun colorTransferName(v: Int) = when (v) {
    C.COLOR_TRANSFER_SDR -> "sdr"
    C.COLOR_TRANSFER_ST2084 -> "pq"
    C.COLOR_TRANSFER_HLG -> "hlg"
    C.COLOR_TRANSFER_LINEAR -> "linear"
    C.COLOR_TRANSFER_SRGB -> "srgb"
    C.COLOR_TRANSFER_GAMMA_2_2 -> "gamma2.2"
    else -> "$v"
}

/** Every key of a decoder's [MediaFormat], its value as a string. */
internal fun mediaFormatEntries(format: MediaFormat): Map<String, String> {
    if (Build.VERSION.SDK_INT < 29) return mapOf("format" to format.toString())
    return format.keys.sorted().associateWith { key ->
        try {
            when (format.getValueTypeForKey(key)) {
                MediaFormat.TYPE_INTEGER -> format.getInteger(key).toString()
                MediaFormat.TYPE_LONG -> format.getLong(key).toString()
                MediaFormat.TYPE_FLOAT -> format.getFloat(key).toString()
                MediaFormat.TYPE_STRING -> format.getString(key) ?: ""
                MediaFormat.TYPE_BYTE_BUFFER -> "<${format.getByteBuffer(key)?.remaining() ?: 0} bytes>"
                else -> "?"
            }
        } catch (e: Exception) {
            "?"
        }
    }
}

/** The colour formats and profile levels decoder [name] lists for [mime]. */
internal fun decoderCaps(name: String, mime: String): Map<String, Any?> = try {
    val info = android.media.MediaCodecList(android.media.MediaCodecList.ALL_CODECS).codecInfos.firstOrNull { it.name == name }
    val caps = info?.getCapabilitiesForType(mime)
    if (caps == null) {
        mapOf("error" to "not listed")
    } else {
        mapOf(
            "color_formats" to caps.colorFormats.map { "0x" + Integer.toHexString(it) },
            "profile_levels" to caps.profileLevels.map { "${it.profile}/${it.level}" },
            "max_instances" to caps.maxSupportedInstances,
        )
    }
} catch (e: Exception) {
    mapOf("error" to (e.message ?: e.toString()))
}
