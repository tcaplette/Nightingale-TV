import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../server/languages.dart';
import 'exo_tuner_player.dart';
import 'playback_diagnostics.dart';
import 'caption_size.dart';
import 'caption_style.dart';
import 'subtitles.dart';

/// Volume leveling (volume-leveling spec, design D1) as an FFmpeg filter
/// graph: a slow RMS compressor with linked channels (threshold -40 dBFS,
/// 4:1, soft knee 2.8, 200 ms attack, 2000 ms release, +12 dB make-up),
/// then a peak limiter at -1 dBFS (5 ms look-ahead, 50 ms release) with its
/// auto-level off, since auto-level raises the output. Neither looks ahead
/// further, so the first audio isn't held back. Android's
/// LevelingAudioProcessor.kt runs the same algorithm with the same values;
/// test/volume_leveling_test.dart runs this graph through ffmpeg.
const volumeLevelingChain = 'acompressor=detection=rms:link=average:threshold=0.01:ratio=4:knee=2.8'
    ':attack=200:release=2000:makeup=3.981,'
    'alimiter=limit=0.89:attack=5:release=50:level=disabled';

/// [volumeLevelingChain] as mpv's `af` property.
const volumeLevelingAf = 'lavfi=[$volumeLevelingChain]';

/// mpv's names for the subtitle codecs that are pictures, not text.
const imageSubtitleCodecs = {'hdmv_pgs_subtitle', 'pgssub', 'dvd_subtitle', 'dvb_subtitle'};

/// What the [Tuner] needs from a video player: mpv on Linux
/// ([MediaKitTunerPlayer]), ExoPlayer on Android ([ExoTunerPlayer]); tests
/// use a fake.
abstract class TunerPlayer implements PlayerReadings {
  /// The platform's player. By the real OS, not PlatformInfo's test
  /// override: ExoPlayer is native code, which only exists in the Android
  /// app.
  /// [leveling]: volume leveling's state at start-up, which ExoPlayer is
  /// built with.
  static TunerPlayer create({bool leveling = false}) =>
      Platform.isAndroid ? ExoTunerPlayer(leveling: leveling) : MediaKitTunerPlayer();

  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<Duration> get positionStream;
  Stream<void> get tracksStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;

  /// The player's log messages, as "level prefix: text" (diagnostics).
  Stream<String> get logStream;

  bool get playing;
  bool get buffering;

  /// Position in the media opened last (0-based, on the media's own
  /// timeline, like mpv's playback time).
  Duration get position;

  /// Opens [url], from [start], stopping at [end]. [exact]: start exactly at
  /// [start]; else at the keyframe before it, which shows a picture sooner.
  /// [live]: an endless live stream (live-playback D9): no start or end,
  /// played from the live point, interlaced video deinterlaced on desktop.
  /// [subtitles]: what it shows as subtitles (see [setSubtitles]).
  Future<void> open(Uri url,
      {required Map<String, String> headers,
      Duration? start,
      Duration? end,
      bool exact = true,
      bool live = false,
      SubtitleChoice? subtitles});
  Future<void> stop();

  /// Holds the picture and silences the sound (timeshift); [resume] goes on
  /// from the same frame.
  Future<void> pause();
  Future<void> resume();

  /// Moves within the item playing, exactly, to [position] on its media's
  /// own timeline, staying paused if it is. The item's end still stops it.
  Future<void> seek(Duration position);

  /// What the item playing shows as subtitles (subtitles spec): a track
  /// inside it, a text track loaded beside it, a live stream's own
  /// captions, or none (null). Setting the choice it has changes nothing.
  Future<void> setSubtitles(SubtitleChoice? choice);
  Future<void> dispose();

  /// The video, fitted in the space by [fit] with black around it, with the
  /// captions over it and never cropped.
  Widget buildVideo({BoxFit fit = BoxFit.contain});

  /// Seconds of media read ahead of the playback position (null when it
  /// can't be read): for prefetch and index-fill timing.
  Future<double?> bufferedSeconds();

  /// The open file's average bitrate in bits per second (size × 8 ÷
  /// duration), or null when it isn't known.
  Future<int?> averageBitrate();

  // ---- The next segment (segment-handover spec) -------------------------------

  /// Queues the segment after the one playing: [url] from exactly [start],
  /// stopping at [end], showing [subtitles]. The player buffers it while
  /// the item playing plays on, and moves on to it at that item's end. It
  /// replaces anything queued before; [open] and [stop] drop it.
  Future<void> enqueue(Uri url,
      {required Map<String, String> headers, Duration? start, Duration? end, SubtitleChoice? subtitles});

  /// Moves on to the queued item now (the schedule's hand-over came first).
  /// True when the player is on it, moved now or by itself since it was
  /// queued; false when nothing is queued (cleared, or it failed to load).
  Future<bool> advance();

  /// Drops the queued item, if there is one.
  Future<void> clearQueue();

  /// Volume leveling (volume-leveling spec) on or off, for what's playing
  /// and everything opened after. mpv applies it at once; ExoPlayer is
  /// rebuilt, and the tuner then re-tunes.
  Future<void> setVolumeLeveling(bool on);

  /// Draws captions at [size], on what's showing and whatever plays next.
  Future<void> setCaptionSize(CaptionSize size);

  /// The output volume, 0–1 (the sleep timer's fade), for what's playing,
  /// what's queued and everything opened after. The tuner sets it back to 1
  /// at every tune.
  Future<void> setVolume(double volume);

  /// The player moved on to the queued item, by itself at the end of the
  /// item playing or by [advance].
  Stream<void> get advanced;
}

/// mpv through media_kit. Its configuration is the same whatever the
/// playback mode (direct-play spec): nothing here reads settings. Only seek
/// precision is chosen per open, by the kind of open (see [open]).
///
/// The next segment loads in a second mpv (a deck), paused on its first
/// picture, and takes over the screen at the hand-over (segment-handover
/// spec, design D5). mpv's own playlist can't do this: it reads ahead to the
/// next file only once the file playing has been read to its end, which a
/// program part ending at a break never is, and it would read the next file
/// from its start rather than the clip's.
class MediaKitTunerPlayer implements TunerPlayer {
  /// [verboseLog]: mpv's verbose log on [logStream] (diagnostics builds,
  /// and the startup latency test, which times mpv's steps from it).
  ///
  /// [video]: false makes decks without a video output, for tests, which
  /// can't attach one.
  MediaKitTunerPlayer({bool? verboseLog, @visibleForTesting this._video = true})
      : _configuration = (verboseLog ?? PlaybackDiagnostics.enabled) ? _diagnosticConfiguration : configuration {
    _onAir = _newDeck();
    _decks.value = [_onAir];
  }

  static const configuration = PlayerConfiguration(title: 'Nightingale TV');

  /// [configuration], with mpv's verbose log (network, decoder choice,
  /// errors) for the playback diagnostics log. Diagnostics builds only.
  static const _diagnosticConfiguration = PlayerConfiguration(title: 'Nightingale TV', logLevel: MPVLogLevel.v);

  final PlayerConfiguration _configuration;
  final bool _video;

  /// The deck on screen.
  late _Deck _onAir;

  /// The deck the next segment loads in, made at the first [enqueue].
  _Deck? _spare;

  /// The decks in paint order, the one on screen last (on top).
  final _decks = ValueNotifier<List<_Deck>>(const []);

  /// [_spare] holds the next segment.
  bool _queued = false;

  /// The player moved on to the item queued last.
  bool _moved = false;

  /// Stops the deck that went off screen, once the new one is painted.
  Timer? _stopOffAir;

  /// Volume leveling is on (design D2): on every deck, including decks made
  /// later.
  bool _leveling = false;

  /// mpv couldn't build the leveling filters: playing without them until
  /// the setting changes again.
  bool _levelingRefused = false;

  /// [setVolume]'s volume, 0–1: on every deck, including decks made later.
  double _volume = 1;

  final _captionSize = ValueNotifier(CaptionSize.medium);

  /// The `af` set while leveling is on (tests replace it).
  @visibleForTesting
  String levelingAf = volumeLevelingAf;

  /// What mpv says when it can't build the audio filters (0.34: "Audio
  /// filter initialized failed!"). It turns the audio track off then.
  static final _filterFailure = RegExp('audio filter init', caseSensitive: false);

  /// The mpv on screen.
  Player get player => _onAir.player;
  VideoController get video => _onAir.video;

  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _tracks = StreamController<void>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _log = StreamController<String>.broadcast();
  final _advanced = StreamController<void>.broadcast();

  /// When the picture on screen last moved (microseconds on [_ticks]), for
  /// [debugFrameGap]: mpv's position changes once per frame.
  final _tickTimes = ListQueue<int>();
  final _ticks = Stopwatch()..start();
  Duration? _lastTick;

  _Deck _newDeck() {
    final deck = _Deck(Player(configuration: _configuration), video: _video);
    // The audio output keeps running (silent) while a deck is paused, so a
    // deck taking over doesn't wait for it to start: picture waits for
    // audio, and starting PulseAudio took up to 350 ms.
    unawaited(deck.setOption('audio-stream-silence', 'yes'));
    if (_leveling) unawaited(_applyLeveling(deck));
    if (_volume != 1) unawaited(deck.player.setVolume(_volume * 100));
    final s = deck.player.stream;
    bool onAir() => identical(deck, _onAir);
    deck.subscriptions.addAll([
      s.playing.listen((v) {
        if (onAir()) _playing.add(v);
      }),
      s.buffering.listen((v) {
        if (onAir()) _buffering.add(v);
      }),
      s.position.listen((v) {
        if (!onAir()) return;
        _noteTick(v);
        _position.add(v);
      }),
      // mpv picks subtitle tracks by itself on every new file (those flagged
      // default): the choice goes back on once its tracks are listed.
      s.tracks.listen((_) {
        unawaited(_applySubtitles(deck));
        if (onAir()) _tracks.add(null);
      }),
      s.completed.listen((done) {
        if (!onAir()) return;
        // At the item's end (mpv holds its last picture): on to the next
        // segment if one is queued.
        if (done && _queued) {
          _moveOn();
          return;
        }
        _completed.add(done);
      }),
      s.error.listen((message) {
        if (_filterFailure.hasMatch(message) && deck.af.isNotEmpty) {
          unawaited(_refuseLeveling(deck, message));
          return;
        }
        if (onAir()) {
          _error.add(message);
        } else if (_queued && identical(deck, _spare)) {
          // The next segment failed to load: it opens at the hand-over as
          // usual.
          _log.add('error next: $message (dropped from the queue)');
          _queued = false;
          unawaited(deck.player.stop());
        }
      }),
      s.log.listen((l) => _log.add('${l.level} ${onAir() ? '' : 'next '}${l.prefix}: ${l.text}')),
    ]);
    return deck;
  }

  void _noteTick(Duration position) {
    if (position == _lastTick) return;
    _lastTick = position;
    final now = _ticks.elapsedMicroseconds;
    _tickTimes.add(now);
    while (_tickTimes.length > 1 && now - _tickTimes.first > 10 * Duration.microsecondsPerSecond) {
      _tickTimes.removeFirst();
    }
  }

  /// The queued deck goes on screen and plays; the one before stops.
  void _moveOn() {
    final next = _spare!, old = _onAir;
    _onAir = next;
    _spare = old;
    _queued = false;
    _moved = true;
    _lastTick = null;
    _decks.value = [old, next];
    unawaited(next.player.play());
    // Its last picture stays under the new deck until that one is painted.
    unawaited(old.player.pause());
    _stopOffAir?.cancel();
    _stopOffAir = Timer(const Duration(milliseconds: 300), () => unawaited(old.player.stop()));
    _advanced.add(null);
  }

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get bufferingStream => _buffering.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<void> get tracksStream => _tracks.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Stream<String> get errorStream => _error.stream;
  @override
  Stream<String> get logStream => _log.stream;
  @override
  Stream<void> get advanced => _advanced.stream;

  @override
  bool get playing => _onAir.player.state.playing;
  @override
  bool get buffering => _onAir.player.state.buffering;
  @override
  Duration get position => _onAir.player.state.position;

  @override
  Future<void> open(Uri url,
      {required Map<String, String> headers,
      Duration? start,
      Duration? end,
      bool exact = true,
      bool live = false,
      SubtitleChoice? subtitles}) async {
    await _dropQueue();
    _moved = false;
    _lastTick = null;
    await _onAir.setExact(exact);
    final fields = await _onAir.setLive(live, headers);
    _onAir.newFile(subtitles);
    await _onAir.player.open(Media(url.toString(), httpHeaders: fields, start: live ? null : start, end: live ? null : end));
  }

  @override
  Future<void> stop() async {
    await _dropQueue();
    _moved = false;
    await _onAir.player.stop();
  }

  @override
  Future<void> pause() => _onAir.player.pause();

  @override
  Future<void> resume() => _onAir.player.play();

  @override
  Future<void> seek(Duration position) async {
    // A keyframe join left seeks imprecise.
    await _onAir.setOption('hr-seek', 'yes');
    await _onAir.player.seek(position);
  }

  /// Stops the spare deck, whatever it holds.
  Future<void> _dropQueue() async {
    _stopOffAir?.cancel();
    _stopOffAir = null;
    _queued = false;
    await _spare?.player.stop();
  }

  @override
  Future<void> enqueue(Uri url,
      {required Map<String, String> headers, Duration? start, Duration? end, SubtitleChoice? subtitles}) async {
    _stopOffAir?.cancel();
    _stopOffAir = null;
    var spare = _spare;
    if (spare == null) {
      spare = _spare = _newDeck();
      _decks.value = [spare, _onAir];
    }
    _queued = true;
    _moved = false;
    await spare.setExact(true);
    spare.newFile(subtitles);
    // Paused: it loads and shows its first picture, under the deck on air.
    await spare.player.open(Media(url.toString(), httpHeaders: headers, start: start, end: end), play: false);
  }

  @override
  Future<bool> advance() async {
    if (_moved) return true;
    if (!_queued) return false;
    _moveOn();
    return true;
  }

  @override
  Future<void> clearQueue() => _dropQueue();

  /// Sets `af` on both decks; a deck made later gets it in [_newDeck].
  @override
  Future<void> setVolumeLeveling(bool on) async {
    _leveling = on;
    _levelingRefused = false;
    PlaybackDiagnostics.note('LEVEL', '${on ? 'on' : 'off'} mpv af=$_af');
    for (final deck in [_onAir, ?_spare]) {
      await _applyLeveling(deck);
    }
  }

  /// The size in force: the text style at once, and each deck's image
  /// tracks (a deck made later gets it as its tracks arrive).
  @override
  Future<void> setCaptionSize(CaptionSize size) async {
    if (_captionSize.value == size) return;
    _captionSize.value = size;
    for (final deck in [_onAir, ?_spare]) {
      await _applySubtitles(deck);
    }
  }

  /// mpv's software volume, after the leveling filters, so leveling is
  /// unaffected.
  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    for (final deck in [_onAir, ?_spare]) {
      await deck.player.setVolume(_volume * 100);
    }
  }

  String get _af => _leveling && !_levelingRefused ? levelingAf : '';

  Future<void> _applyLeveling(_Deck deck) async {
    final af = _af;
    if (deck.af == af) return;
    deck.af = af;
    try {
      await deck.setOption('af', af);
    } on Object catch (e) {
      await _refuseLeveling(deck, '$e');
    }
  }

  /// mpv refused the filters: every deck plays on without them, with the
  /// audio track back on where mpv turned it off.
  Future<void> _refuseLeveling(_Deck failed, String message) async {
    if (!_levelingRefused) {
      _levelingRefused = true;
      debugPrint('Volume leveling: mpv refused the audio filters ($message); playing without leveling');
      PlaybackDiagnostics.note('LEVEL', 'refused mpv af=$levelingAf: $message');
    }
    for (final deck in [_onAir, ?_spare]) {
      await _applyLeveling(deck);
    }
    try {
      // mpv says so before it turns the track off. Its selection is still
      // "auto", so it's set to "no" first for "auto" to be a change.
      for (var i = 0; i < 40; i++) {
        if (await failed.property('aid') == 'no') {
          await failed.setOption('aid', 'no');
          await failed.setOption('aid', 'auto');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } on Object catch (e) {
      debugPrint('Volume leveling: audio not restored: $e');
    }
  }

  /// The decks' mpvs, the one on screen first (tests).
  @visibleForTesting
  List<Player> get debugDecks => [_onAir.player, ?_spare?.player];

  @override
  Future<void> setSubtitles(SubtitleChoice? choice) async {
    _onAir.subtitles = choice;
    await _applySubtitles(_onAir);
  }

  /// Gets the text of a side-loaded track (tests replace it).
  @visibleForTesting
  static Future<String> Function(Uri uri, Map<String, String> headers) fetchSubtitle = _fetchSubtitle;

  static Future<String> _fetchSubtitle(Uri uri, Map<String, String> headers) async {
    // Diagnostics builds log it with the servers' other requests.
    final client = PlaybackDiagnostics.enabled ? DiagnosticHttpClient(http.Client()) : http.Client();
    try {
      final response = await client.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) throw HttpException('subtitles: HTTP ${response.statusCode}', uri: uri);
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }

  /// The texts fetched last, by URL: setting a track again (a re-open, a
  /// hand-over) doesn't fetch it again.
  final _subtitleTexts = <Uri, String>{};

  Future<String> _subtitleText(SideLoadedSubtitle s) async {
    final cached = _subtitleTexts.remove(s.uri);
    final text = cached ?? await fetchSubtitle(s.uri, s.headers);
    _subtitleTexts[s.uri] = text;
    while (_subtitleTexts.length > 4) {
      _subtitleTexts.remove(_subtitleTexts.keys.first);
    }
    return text;
  }

  /// Puts [deck]'s choice on, one change at a time.
  Future<void> _applySubtitles(_Deck deck) {
    final work = deck.subtitleWork.then((_) => _applySubtitlesNow(deck)).catchError((Object e) {
      _log.add('warn subtitles: ${deck.subtitles} not shown: $e');
    });
    deck.subtitleWork = work;
    return work;
  }

  /// Puts [deck]'s choice on, then says who draws it.
  Future<void> _applySubtitlesNow(_Deck deck) async {
    await _selectSubtitles(deck);
    await _drawSubtitles(deck);
  }

  /// mpv's own subtitle output is for image tracks, which it alone can draw
  /// (scaled against Medium, their authored size). Flutter draws text
  /// tracks, so mpv's output is off for those: nothing is drawn twice.
  Future<void> _drawSubtitles(_Deck deck) async {
    final image = imageSubtitleCodecs.contains((await deck.subtitleTracks()).where((t) => t.selected).firstOrNull?.codec);
    await deck.setOption('sub-visibility', image ? 'yes' : 'no');
    if (image) await deck.setOption('sub-scale', '${_captionSize.value.ratio}');
  }

  Future<void> _selectSubtitles(_Deck deck) async {
    final want = deck.subtitles;
    final player = deck.player;
    final sid = await deck.property('sid');
    switch (want) {
      case null:
        if (sid != 'no' && sid != '') await player.setSubtitleTrack(SubtitleTrack.no());
      case StreamCaptions():
        if (player.state.track.subtitle != SubtitleTrack.auto()) await player.setSubtitleTrack(SubtitleTrack.auto());
      case EmbeddedSubtitle(:final position, :final language):
        final tracks = await deck.subtitleTracks();
        final inFile = [for (final t in tracks) if (!t.external) t];
        // Listed in the file's order; a list that disagrees with the
        // server's on the language is matched by language instead.
        var pick = position < inFile.length ? inFile[position] : null;
        if (language != null && pick != null && pick.language != null && pick.language != language) {
          pick = inFile.where((t) => t.language == language).firstOrNull ?? pick;
        }
        // Not listed yet: the tracks' arrival puts it on.
        if (pick == null) return;
        if (sid != '${pick.id}') await player.setSubtitleTrack(SubtitleTrack('${pick.id}', null, null));
      case final SideLoadedSubtitle side:
        if (deck.sideLoaded == side && deck.sideLoadedId != null) {
          if (sid != deck.sideLoadedId) await player.setSubtitleTrack(SubtitleTrack(deck.sideLoadedId!, null, null));
          return;
        }
        // Only a loaded file takes a subtitle file: its tracks' arrival
        // puts it on.
        if ((await deck.subtitleTracks(any: true)).isEmpty) return;
        final text = await _subtitleText(side);
        if (deck.subtitles != side) return;
        deck.sideLoaded = side;
        await player.setSubtitleTrack(SubtitleTrack.data(text, title: side.label, language: side.language));
        deck.sideLoadedId = await deck.property('sid');
    }
  }

  @override
  Future<void> dispose() async {
    _stopOffAir?.cancel();
    for (final deck in [_onAir, ?_spare]) {
      for (final s in deck.subscriptions) {
        await s.cancel();
      }
      await deck.player.dispose();
    }
    for (final c in [_playing, _buffering, _position, _tracks, _completed, _error, _log, _advanced]) {
      await c.close();
    }
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) => ValueListenableBuilder<List<_Deck>>(
        valueListenable: _decks,
        builder: (context, decks, _) => Stack(
          fit: StackFit.expand,
          children: [
            for (final deck in decks)
              ValueListenableBuilder<CaptionSize>(
                valueListenable: _captionSize,
                builder: (context, size, _) => Video(
                  key: ValueKey(deck),
                  controller: deck.video,
                  controls: NoVideoControls,
                  fill: Colors.black,
                  fit: fit,
                  subtitleViewConfiguration: SubtitleViewConfiguration(style: captionTextStyle(size), padding: captionPadding),
                ),
              ),
          ],
        ),
      );

  @override
  Future<Duration?> debugFrameGap(Duration window) async {
    final now = _ticks.elapsedMicroseconds;
    final from = now - window.inMicroseconds;
    var gap = 0;
    int? before;
    for (final t in _tickTimes) {
      if (before != null && t >= from && t - before > gap) gap = t - before;
      before = t;
    }
    if (before == null) return null;
    // A picture still on screen.
    if (now - before > gap) gap = now - before;
    return Duration(microseconds: gap);
  }

  /// An mpv property of the deck on screen ("" when there's none).
  Future<String> _property(String name) => _onAir.property(name);

  /// [_property], or "ERR(…)" when mpv can't answer (diagnostics).
  Future<String> _safe(String name) async {
    try {
      return await _property(name);
    } on Object catch (e) {
      return 'ERR($e)';
    }
  }

  /// Read from mpv's properties; mpv's configuration doesn't change for it.
  @override
  Future<double?> bufferedSeconds() async {
    try {
      return double.tryParse(await _property('demuxer-cache-duration'));
    } on Object {
      return null;
    }
  }

  @override
  Future<int?> averageBitrate() async {
    try {
      final size = double.tryParse(await _property('file-size'));
      final duration = double.tryParse(await _property('duration'));
      if (size == null || duration == null || duration <= 0) return null;
      return (size * 8 / duration).round();
    } on Object {
      return null;
    }
  }

  // ---- Diagnostics: mpv's own properties ----------------------------------

  @override
  Future<double?> debugPosition() async => double.tryParse(await _safe('time-pos'));

  @override
  Future<FrameCounts> debugFrames() async {
    Future<int> count(String p) async => int.tryParse(await _safe(p)) ?? 0;
    return (
      dropped: await count('frame-drop-count'),
      decoderDropped: await count('decoder-frame-drop-count'),
      delayed: await count('vo-delayed-frame-count'),
      mistimed: await count('mistimed-frame-count'),
    );
  }

  @override
  Future<List<String>> debugLive() async => [
        'vfFps=${await _safe('estimated-vf-fps')}',
        'displayFps=${await _safe('estimated-display-fps')}',
        'vsyncJitter=${await _safe('vsync-jitter')}',
        'avsync=${await _safe('avsync')}',
        'avsyncChange=${await _safe('total-avsync-change')}',
        'cache=${await _safe('demuxer-cache-duration')}s',
        'pausedForCache=${await _safe('paused-for-cache')}',
        'cacheSpeed=${await _safe('cache-speed')}',
        await _cacheState(),
        'videoBitrate=${await _safe('video-bitrate')}',
      ];

  @override
  Future<List<String>> debugStall() async => [
        for (final p in const [
          'paused-for-cache',
          'core-idle',
          'pause',
          'demuxer-cache-duration',
          'cache-speed',
          'demuxer-cache-idle',
          'eof-reached',
          'seeking',
        ])
          '$p=${await _safe(p)}',
        await _cacheState(),
      ];

  /// mpv properties that don't change within a file, logged once per open.
  static const _streamProps = [
    'file-format',
    'video-codec',
    'video-params/w',
    'video-params/h',
    'video-params/pixelformat',
    'video-params/colormatrix',
    'video-frame-info/interlaced',
    'container-fps',
    'hwdec-current',
    'current-vo',
    'video-sync',
    'display-fps',
    'deinterlace',
    'vf',
  ];

  /// Once mpv knows the video codec.
  @override
  Future<String?> debugStream() async {
    if ((await _safe('video-codec')).isEmpty) return null;
    // The file's average bitrate: what the connection has to keep up with.
    final size = double.tryParse(await _safe('file-size'));
    final duration = double.tryParse(await _safe('duration'));
    final mbps = size != null && duration != null && duration > 0 ? (size * 8 / duration / 1e6).toStringAsFixed(2) : '-';
    return [for (final p in _streamProps) '$p=${await _safe(p)}', 'fileMbps=$mbps'].join(' ');
  }

  /// Whether data is reaching mpv, from its demuxer cache: the input rate
  /// (bytes/s), bytes read ahead, whether the reader is starved (underrun),
  /// and whether the demuxer has stopped reading (idle).
  Future<String> _cacheState() async {
    final state = await _safe('demuxer-cache-state');
    String field(String key) => RegExp('"$key":\\s*([^,}\\]]+)').firstMatch(state)?.group(1) ?? '-';
    return 'inputRate=${field('raw-input-rate')} aheadBytes=${field('fw-bytes')} '
        'underrun=${field('underrun')} demuxIdle=${field('idle')}';
  }
}

/// One mpv and its video.
class _Deck {
  _Deck(this.player, {bool video = true}) {
    if (video) this.video = VideoController(player);
  }

  final Player player;
  late final VideoController video;
  final subscriptions = <StreamSubscription<Object?>>[];

  /// The `af` property as last set ("" for none).
  String af = '';

  /// What the file opened last shows as subtitles, and the subtitle file
  /// loaded beside it (with its mpv track id).
  SubtitleChoice? subtitles;
  SideLoadedSubtitle? sideLoaded;
  String? sideLoadedId;
  Future<void> subtitleWork = Future.value();

  /// A new file opens, showing [choice].
  void newFile(SubtitleChoice? choice) {
    subtitles = choice;
    sideLoaded = null;
    sideLoadedId = null;
  }

  /// The subtitle tracks mpv lists for the file (only those of a track type
  /// `sub`; with [any], tracks of every type).
  Future<List<({int id, bool external, String? language, String? codec, bool selected})>> subtitleTracks({bool any = false}) async {
    final raw = await property('track-list');
    if (raw.isEmpty) return const [];
    final Object? list;
    try {
      list = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (list is! List) return const [];
    return [
      for (final t in list.whereType<Map<String, Object?>>())
        if ((any || t['type'] == 'sub') && t['id'] is num)
          (
            id: (t['id'] as num).toInt(),
            external: t['external'] == true,
            language: normalizeLanguage(t['lang'] as String?),
            codec: t['codec'] as String?,
            selected: t['selected'] == true,
          ),
    ];
  }

  /// [exact]: mpv's own default (precise for a start position); else
  /// keyframes.
  Future<void> setExact(bool exact) async {
    final native = player.platform;
    if (native is NativePlayer) await native.setProperty('hr-seek', exact ? 'default' : 'no');
  }

  Future<void> setOption(String name, String value) async {
    final native = player.platform;
    if (native is NativePlayer) await native.setProperty(name, value);
  }

  /// The live options as set ([setLive]).
  bool live = false;

  /// mpv's own user agent, read before the first live open changed it.
  String? _userAgent;

  /// Sets mpv up for a live open, or back for a file (live-playback D9):
  /// deinterlacing (libmpv 0.34 has no "auto": its yadif deinterlaces
  /// interlaced frames and passes progressive ones), the cache on with a
  /// short readahead, and the stream's user agent and referrer through
  /// mpv's own options. Returns the other headers, for the open.
  Future<Map<String, String>> setLive(bool on, Map<String, String> headers) async {
    final rest = {...headers};
    String? take(String name) {
      final key = rest.keys.where((k) => k.toLowerCase() == name).firstOrNull;
      return key == null ? null : rest.remove(key);
    }

    final agent = on ? take('user-agent') : null;
    final referrer = on ? take('referer') : null;
    if (!on && !live) return rest;
    if (on && _userAgent == null) _userAgent = await property('user-agent');
    live = on;
    await setOption('deinterlace', on ? 'yes' : 'no');
    await setOption('cache', on ? 'yes' : 'auto');
    await setOption('demuxer-readahead-secs', on ? '5' : '1');
    await setOption('user-agent', agent ?? _userAgent ?? '');
    await setOption('referrer', referrer ?? '');
    return rest;
  }

  /// An mpv property ("" when there's none).
  Future<String> property(String name) async {
    final native = player.platform;
    return native is NativePlayer ? native.getProperty(name, waitForInitialization: false) : '';
  }
}
