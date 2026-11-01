import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'playback_diagnostics.dart';
import 'tuner_player.dart';

/// ExoPlayer on Android (android/app/src/main/kotlin/…/ExoTunerHost.kt):
/// MediaCodec decodes straight into the Surface of a Flutter texture, in
/// hardware only. Like [MediaKitTunerPlayer], its configuration is the same
/// whatever the playback mode; only seek precision is chosen per open.
class ExoTunerPlayer implements TunerPlayer {
  /// [leveling]: volume leveling's state, which the player is built with.
  ExoTunerPlayer({this._leveling = false}) {
    _ready = _create();
  }

  static const _channel = MethodChannel('nightingale_tv/player');

  late final Future<int?> _ready;
  StreamSubscription<Object?>? _events;
  bool _disposed = false;

  /// The Flutter texture showing the video, once there is one.
  final textureId = ValueNotifier<int?>(null);

  /// The video's display size (pixel aspect applied), once known.
  final videoSize = ValueNotifier<Size?>(null);

  /// The subtitles on screen now (captions on).
  final cues = ValueNotifier<ExoCues>(ExoCues.none);

  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _tracks = StreamController<void>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _log = StreamController<String>.broadcast();
  final _advanced = StreamController<void>.broadcast();

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _at = Duration.zero;

  /// Volume leveling: the audio goes through ExoTunerHost's leveling
  /// processor, decoded to PCM (no passthrough).
  bool _leveling;

  Future<int?> _create() async {
    final int? id;
    try {
      id = await _channel.invokeMethod<int>('create', {'leveling': _leveling});
    } on PlatformException catch (e) {
      debugPrint('Android player: ${e.message}');
      return null;
    }
    if (id == null) return null;
    if (_disposed) {
      await _channel.invokeMethod<void>('dispose', {'id': id});
      return null;
    }
    _events = EventChannel('nightingale_tv/player/$id').receiveBroadcastStream().listen(_onEvent);
    textureId.value = id;
    return id;
  }

  Future<T?> _call<T>(String method, [Map<String, Object?> args = const {}]) async {
    final id = await _ready;
    if (id == null || _disposed) return null;
    return _channel.invokeMethod<T>(method, {'id': id, ...args});
  }

  void _onEvent(Object? raw) {
    if (raw is! Map) return;
    switch (raw['e']) {
      case 'playing':
        _isPlaying = raw['v'] == true;
        _playing.add(_isPlaying);
      case 'buffering':
        _isBuffering = raw['v'] == true;
        _buffering.add(_isBuffering);
      case 'position':
        _at = Duration(milliseconds: (raw['ms'] as num).toInt());
        _position.add(_at);
      case 'tracks':
        _tracks.add(null);
      case 'completed':
        _completed.add(raw['v'] == true);
      case 'error':
        _error.add('${raw['message']}');
      case 'size':
        final w = (raw['width'] as num).toDouble(), h = (raw['height'] as num).toDouble();
        final ratio = (raw['ratio'] as num?)?.toDouble() ?? 1;
        videoSize.value = Size(w * (ratio > 0 ? ratio : 1), h);
      case 'cues':
        cues.value = ExoCues.fromEvent(raw);
      case 'log':
        _log.add('${raw['line']}');
      case 'advanced':
        _advanced.add(null);
      case 'level':
        PlaybackDiagnostics.note('LEVEL', levelLine(raw));
    }
  }

  /// The leveling processor's counters over the last 5 s (design D6), as a
  /// LEVEL line.
  @visibleForTesting
  static String levelLine(Map<Object?, Object?> e) {
    String db(Object? v, {bool sign = false}) {
      final d = (v as num?)?.toDouble() ?? 0;
      return '${sign && d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}dB';
    }

    return 'on exo in=${db(e['inRmsDb'])} reduction=${db(e['reductionDb'])} (max ${db(e['maxReductionDb'])}) '
        'gain=${db(e['gainDb'], sign: true)} limiterHits=${e['limiterHits']} frames=${e['frames']}';
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
  bool get playing => _isPlaying;
  @override
  bool get buffering => _isBuffering;
  @override
  Duration get position => _at;

  @override
  Future<void> open(Uri url,
      {required Map<String, String> headers,
      Duration? start,
      Duration? end,
      bool exact = true,
      bool live = false}) async {
    _at = live ? Duration.zero : start ?? Duration.zero;
    _isPlaying = false;
    cues.value = ExoCues.none;
    final id = await _ready;
    if (id == null) throw StateError('The Android player did not start.');
    await _call<void>('open', {
      'url': url.toString(),
      'headers': headers,
      'startMs': live ? null : start?.inMilliseconds,
      'endMs': live ? null : end?.inMilliseconds,
      'exact': exact,
      'live': live,
    });
  }

  /// An item added to ExoPlayer's playlist after the one playing: it starts
  /// at [start] on the file's own timeline (no clipping start), and is
  /// clipped at [end].
  @override
  Future<void> enqueue(Uri url, {required Map<String, String> headers, Duration? start, Duration? end}) =>
      _call<void>('enqueue', {
        'url': url.toString(),
        'headers': headers,
        'startMs': start?.inMilliseconds,
        'endMs': end?.inMilliseconds,
      });

  @override
  Future<bool> advance() async => await _call<bool>('advance') ?? false;

  @override
  Future<void> clearQueue() => _call<void>('clearQueue');

  @override
  Future<void> stop() async {
    _isPlaying = false;
    cues.value = ExoCues.none;
    await _call<void>('stop');
  }

  @override
  Future<void> pause() => _call<void>('pause');

  @override
  Future<void> resume() => _call<void>('resume');

  @override
  Future<void> seek(Duration position) async {
    _at = position;
    await _call<void>('seek', {'ms': position.inMilliseconds});
  }

  @override
  Future<void> showCaptions(bool on) async {
    if (!on) cues.value = ExoCues.none;
    await _call<void>('captions', {'on': on});
  }

  /// A change rebuilds ExoPlayer with the new audio output (design D4),
  /// on the same texture; what was playing stops, and the tuner re-tunes.
  @override
  Future<void> setVolumeLeveling(bool on) async {
    PlaybackDiagnostics.note('LEVEL', '${on ? 'on' : 'off'} exo ${on ? 'pcm-only' : 'passthrough'}');
    if (on == _leveling) return;
    _leveling = on;
    _isPlaying = false;
    cues.value = ExoCues.none;
    await _call<void>('setLeveling', {'on': on});
  }

  /// ExoPlayer's volume; one ExoPlayer plays the item on screen and the one
  /// queued, so it covers both.
  @override
  Future<void> setVolume(double volume) => _call<void>('setVolume', {'volume': volume.clamp(0.0, 1.0)});

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    final id = await _ready;
    _disposed = true;
    await _events?.cancel();
    textureId.value = null;
    if (id != null) await _channel.invokeMethod<void>('dispose', {'id': id});
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) => _ExoVideo(this, fit);

  // ---- Readings -------------------------------------------------------------

  /// One reading of the player, shared by the calls made within 100 ms of
  /// each other (the diagnostics read several fields per sample).
  Future<Map<Object?, Object?>>? _stats;
  DateTime _statsAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<Object?, Object?>> _read() {
    final now = DateTime.now();
    final cached = _stats;
    if (cached != null && now.difference(_statsAt) < const Duration(milliseconds: 100)) return cached;
    _statsAt = now;
    return _stats = _call<Map<Object?, Object?>>('stats').then((m) => m ?? const {});
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  @override
  Future<double?> bufferedSeconds() async {
    try {
      final s = await _read();
      final position = s['positionMs'], buffered = s['bufferedMs'];
      if (position is! num || buffered is! num) return null;
      return max(0, buffered - position) / 1000;
    } on Object {
      return null;
    }
  }

  @override
  Future<int?> averageBitrate() async {
    try {
      return ((await _read())['bitrate'] as num?)?.toInt();
    } on Object {
      return null;
    }
  }

  // ---- Diagnostics (design D9) ------------------------------------------------

  /// From the release times of the frames ExoPlayer rendered.
  @override
  Future<Duration?> debugFrameGap(Duration window) async {
    final ms = await _call<int>('frameGap', {'windowMs': window.inMilliseconds});
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// Counters at the last [debugLive], for per-second rates.
  int _lastRendered = 0, _lastBytes = 0;
  DateTime? _lastLive;

  @override
  Future<double?> debugPosition() async {
    final s = await _read();
    // Until the open first plays, its position is where it was asked to
    // start, then where the keyframe is: neither is the picture moving.
    final ms = s['positionMs'];
    return s['started'] == true && ms is num ? ms / 1000 : null;
  }

  @override
  Future<FrameCounts> debugFrames() async {
    final s = await _read();
    return (dropped: _int(s['dropped']), decoderDropped: _int(s['decoderDropped']), delayed: 0, mistimed: 0);
  }

  @override
  Future<List<String>> debugLive() async {
    final s = await _read();
    final now = DateTime.now();
    final rendered = _int(s['rendered']), bytes = _int(s['bytesLoaded']);
    final last = _lastLive;
    final seconds = last == null ? 0 : now.difference(last).inMicroseconds / 1e6;
    // Counters start again with each open.
    final dRendered = rendered >= _lastRendered ? rendered - _lastRendered : rendered;
    _lastLive = now;
    _lastRendered = rendered;
    final dBytes = bytes - _lastBytes;
    _lastBytes = bytes;
    final buffered = await bufferedSeconds();
    return [
      'vfFps=${seconds > 0 ? (dRendered / seconds).toStringAsFixed(2) : '-'}',
      'cache=${buffered?.toStringAsFixed(2) ?? '-'}s',
      'state=${s['state']}',
      'loadRate=${seconds > 0 ? (dBytes / seconds).round() : '-'}',
      'bytesLoaded=$bytes',
      'videoBitrate=${s['bitrate'] ?? '-'}',
      'skipped=${s['skipped']}',
    ];
  }

  @override
  Future<List<String>> debugStall() async {
    final s = await _read();
    return [
      'state=${s['state']}',
      'playing=${s['playing']}',
      'cache=${(await bufferedSeconds())?.toStringAsFixed(2) ?? '-'}s',
      'bytesLoaded=${s['bytesLoaded']}',
    ];
  }

  /// Once the video decoder is chosen.
  @override
  Future<String?> debugStream() async {
    final s = await _read();
    if (s['videoCodec'] == null || s['videoDecoder'] == '-') return null;
    final bitrate = s['bitrate'];
    return [
      'container=${s['container']}',
      'video-codec=${s['videoCodec']}',
      'codecs=${s['codecs']}',
      'video-params/w=${s['width']}',
      'video-params/h=${s['height']}',
      'container-fps=${s['fps']}',
      'color-transfer=${s['colorTransfer']}',
      'decoder=${s['videoDecoder']}',
      'audio-codec=${s['audioCodec']}',
      'audio-channels=${s['audioChannels']}',
      'audio-decoder=${s['audioDecoder']}',
      'fileMbps=${bitrate is num ? (bitrate / 1e6).toStringAsFixed(2) : '-'}',
    ].join(' ');
  }
}

/// The subtitles on screen: text lines, and images (PGS, VobSub).
class ExoCues {
  const ExoCues(this.text, this.images);

  static const none = ExoCues([], []);

  factory ExoCues.fromEvent(Map<Object?, Object?> e) => ExoCues(
        [for (final t in e['text'] as List? ?? const []) '$t'],
        [
          for (final i in (e['images'] as List? ?? const []).cast<Map<Object?, Object?>>())
            ExoImageCue(
              png: i['png'] as Uint8List,
              left: (i['left'] as num).toDouble(),
              top: (i['top'] as num).toDouble(),
              width: (i['width'] as num).toDouble(),
              height: (i['height'] as num?)?.toDouble(),
              aspect: (i['aspect'] as num).toDouble(),
            ),
        ],
      );

  final List<String> text;
  final List<ExoImageCue> images;
}

/// An image subtitle, placed in fractions of the picture.
class ExoImageCue {
  const ExoImageCue(
      {required this.png, required this.left, required this.top, required this.width, this.height, required this.aspect});

  final Uint8List png;
  final double left, top, width;

  /// Null: from [width] and the image's [aspect].
  final double? height;
  final double aspect;
}

/// The texture fitted in the space by [fit] with black around it, image
/// subtitles on the picture, and text captions over it all (as
/// media_kit_video's `Video` shows them on Linux). The subtitles fit the whole
/// space, so cropping the picture never crops them.
class _ExoVideo extends StatelessWidget {
  const _ExoVideo(this.player, this.fit);

  final ExoTunerPlayer player;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<int?>(
            valueListenable: player.textureId,
            builder: (context, id, _) => id == null
                ? const SizedBox.shrink()
                : ValueListenableBuilder<Size?>(
                    valueListenable: player.videoSize,
                    builder: (context, size, _) => size == null
                        ? const SizedBox.shrink()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: fit,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox.fromSize(size: size, child: Texture(textureId: id)),
                              ),
                              FittedBox(child: SizedBox.fromSize(size: size, child: _ImageCues(player.cues, size))),
                            ],
                          ),
                  ),
          ),
          _TextCues(player.cues),
        ],
      ),
    );
  }
}

class _ImageCues extends StatelessWidget {
  const _ImageCues(this.cues, this.size);

  final ValueListenable<ExoCues> cues;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ExoCues>(
      valueListenable: cues,
      builder: (context, c, _) => Stack(
        children: [
          for (final i in c.images)
            Positioned(
              left: i.left * size.width,
              top: i.top * size.height,
              width: i.width * size.width,
              height: i.height == null ? i.width * size.width / i.aspect : i.height! * size.height,
              child: Image.memory(i.png, fit: BoxFit.fill, gaplessPlayback: true),
            ),
        ],
      ),
    );
  }
}

/// Text captions, styled and scaled as media_kit_video's `SubtitleView`
/// defaults (the Linux captions).
class _TextCues extends StatelessWidget {
  const _TextCues(this.cues);

  final ValueListenable<ExoCues> cues;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ExoCues>(
      valueListenable: cues,
      builder: (context, c, _) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = sqrt((constraints.maxWidth * constraints.maxHeight / (1920 * 1080)).clamp(0.0, 1.0));
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                [
                  for (final line in c.text)
                    if (line.trim().isNotEmpty) line.trim(),
                ].join('\n'),
                style: const TextStyle(
                  height: 1.4,
                  fontSize: 32,
                  letterSpacing: 0,
                  wordSpacing: 0,
                  color: Color(0xffffffff),
                  fontWeight: FontWeight.normal,
                  backgroundColor: Color(0xaa000000),
                ),
                textAlign: TextAlign.center,
                textScaler: TextScaler.linear(scale),
              ),
            ),
          );
        },
      ),
    );
  }
}
