import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'playback_diagnostics.dart';
import 'caption_size.dart';
import 'caption_style.dart';
import 'device_effects.dart';
import 'subtitles.dart';
import 'tuner_player.dart';
import 'video_hole.dart';
import 'video_look.dart';

/// ExoPlayer on Android (android/app/src/main/kotlin/…/ExoTunerHost.kt):
/// MediaCodec decodes straight to a system layer below Flutter's, in hardware
/// only, and [buildVideo] is the hole it shows through. Like [MediaKitTunerPlayer], its configuration is the same
/// whatever the playback mode; only seek precision is chosen per open.
class ExoTunerPlayer implements TunerPlayer {
  /// [leveling]: volume leveling's state, which the player is built with.
  ExoTunerPlayer({this._leveling = false}) {
    _ready = _create();
  }

  static const _channel = MethodChannel('nightingale_tv/player');

  late final Future<int?> _ready;

  /// The player's id on the Kotlin side, once there is one.
  int? get id => _id;
  int? _id;
  StreamSubscription<Object?>? _events;
  bool _disposed = false;

  /// Whether the layer has a picture: from the first frame until its surface
  /// goes (the app in the background).
  final hasPicture = ValueNotifier(false);

  /// The video's display size (pixel aspect applied), once known.
  final videoSize = ValueNotifier<Size?>(null);

  /// The subtitles on screen now (captions on).
  final cues = ValueNotifier<ExoCues>(ExoCues.none);

  /// Where [buildVideo] is on screen: the layer follows it.
  late final holes = VideoHoles((hole, picture) {
    final id = _id;
    if (id == null) return false;
    unawaited(_channel.invokeMethod<void>('place', {
      'id': id,
      'left': picture.left,
      'top': picture.top,
      'right': picture.right,
      'bottom': picture.bottom,
    }));
    _sendLook(hole);
    return true;
  });

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
    _id = id;
    // Before the first open, so a channel with effects starts with them.
    _sendLook(holes.current);
    holes.placeAgain();
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
      case 'firstFrame':
        hasPicture.value = true;
      case 'effectsFailed':
        PlaybackDiagnostics.note('RETRO', 'video effects failed: ${raw['message']}');
        DeviceEffects.instance.videoEffectsFailed();
      case 'effectsApplied':
        videoLookApplied.value = raw['v'] == true;
      case 'noPicture':
        hasPicture.value = false;
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
      bool live = false,
      SubtitleChoice? subtitles}) async {
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
      'subtitles': subtitlesArgument(subtitles),
    });
  }

  /// [choice] as ExoTunerHost takes it.
  @visibleForTesting
  static Map<String, Object?> subtitlesArgument(SubtitleChoice? choice) => switch (choice) {
        null => {'kind': 'off'},
        StreamCaptions() => {'kind': 'stream'},
        EmbeddedSubtitle(:final position, :final language) => {
            'kind': 'embedded',
            'position': position,
            'language': ?language,
          },
        SideLoadedSubtitle(:final uri, :final headers, :final format, :final language, :final label) => {
            'kind': 'side',
            'url': uri.toString(),
            'headers': headers,
            'mime': switch (format) {
              'vtt' => 'text/vtt',
              'ass' || 'ssa' => 'text/x-ssa',
              _ => 'application/x-subrip',
            },
            'language': ?language,
            'label': ?label,
          },
      };

  /// An item added to ExoPlayer's playlist after the one playing: it starts
  /// at [start] on the file's own timeline (no clipping start), and is
  /// clipped at [end].
  @override
  Future<void> enqueue(Uri url,
          {required Map<String, String> headers, Duration? start, Duration? end, SubtitleChoice? subtitles}) =>
      _call<void>('enqueue', {
        'url': url.toString(),
        'headers': headers,
        'startMs': start?.inMilliseconds,
        'endMs': end?.inMilliseconds,
        'subtitles': subtitlesArgument(subtitles),
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

  /// A track inside the stream is an override of ExoPlayer's text tracks;
  /// a text track loaded beside it re-prepares the item where it is, with
  /// the track added.
  @override
  Future<void> setSubtitles(SubtitleChoice? choice) async {
    if (choice == null) cues.value = ExoCues.none;
    await _call<void>('subtitles', {'subtitles': subtitlesArgument(choice)});
  }

  /// A change rebuilds ExoPlayer with the new audio output (design D4),
  /// on the same layer; what was playing stops, and the tuner re-tunes.
  @override
  Future<void> setVolumeLeveling(bool on) async {
    PlaybackDiagnostics.note('LEVEL', '${on ? 'on' : 'off'} exo ${on ? 'pcm-only' : 'passthrough'}');
    if (on == _leveling) return;
    _leveling = on;
    _isPlaying = false;
    cues.value = ExoCues.none;
    await _call<void>('setLeveling', {'on': on});
  }

  /// The cues are drawn in Flutter, so it's only their size that changes.
  @override
  Future<void> setCaptionSize(CaptionSize size) async => captionSize.value = size;

  /// ExoPlayer's volume; one ExoPlayer plays the item on screen and the one
  /// queued, so it covers both.
  @override
  Future<void> setVolume(double volume) => _call<void>('setVolume', {'volume': volume.clamp(0.0, 1.0)});

  /// ExoPlayer's playback speed, pitch kept (Sonic). Passthrough audio
  /// can't change speed; the party's follower sees that and seeks instead.
  @override
  Future<void> setSpeed(double speed) => _call<void>('setSpeed', {'speed': speed.clamp(0.9, 1.1)});

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    final id = await _ready;
    _disposed = true;
    await _events?.cancel();
    _id = null;
    hasPicture.value = false;
    if (id != null) await _channel.invokeMethod<void>('dispose', {'id': id});
  }

  @override
  bool get onVideoLayer => true;

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) => ListenableBuilder(
        listenable: Listenable.merge([videoSize, hasPicture]),
        builder: (context, _) =>
            VideoHole(video: videoSize.value, fit: fit, open: hasPicture.value, holes: holes),
      );

  @override
  final ValueNotifier<bool> videoLookApplied = ValueNotifier(true);

  VideoLook _look = VideoLook.none;
  bool _lookDrawn = true;

  @override
  void setVideoLook(VideoLook look, {bool drawn = true}) {
    if (look == _look && drawn == _lookDrawn) return;
    _look = look;
    _lookDrawn = drawn;
    _sendLook(holes.current);
  }

  /// The effects as drawn now, with the frame ([hole]'s box) and 4 device
  /// pixels, the glow's reach, in parts of the picture; the overlay in the
  /// frame's device pixels.
  void _sendLook(RenderVideoHole? hole) {
    final id = _id;
    if (id == null) return;
    final box = hole?.boxOnScreen, picture = hole?.pictureOnScreen;
    final look = _lookDrawn ? _look : VideoLook.none;
    final args = <String, Object?>{
      'id': id,
      // Which passes the channel needs, drawn here or not.
      'kind': (_look.matrix != null ? 1 : 0) + (_look.curvature > 0 || _look.glow > 0 ? 2 : 0),
      'matrix': look.matrix,
      'curvature': look.curvature,
      'glow': look.glow,
      'overlay': [
        if (look.overlay.on && box != null && picture != null) ...[
          box.width,
          box.height,
          look.overlay.scanlines,
          scanlinePeriod(box.height, look.overlay.lines).toDouble(),
          scanlineDark(scanlinePeriod(box.height, look.overlay.lines)).toDouble(),
          look.overlay.mask,
          look.overlay.vignette,
          box.longestSide * vignetteRadius,
          vignetteStart,
          box.shortestSide * tubeCorner,
        ],
      ],
      'picture': [
        if (box != null && picture != null) ...[
          (box.center.dx - picture.left) / picture.width,
          (box.center.dy - picture.top) / picture.height,
          box.width / 2 / picture.width,
          box.height / 2 / picture.height,
          4 / picture.width,
          4 / picture.height,
        ] else
          for (var i = 0; i < 6; i++) 0.0,
      ],
    };
    // Nothing in effect and nothing before: nothing to say.
    final said = '$args';
    if (said == _saidLook || (_saidLook == null && !_look.any)) return;
    if (!_look.any && _saidLook == 'off') return;
    _saidLook = _look.any ? said : 'off';
    unawaited(_channel.invokeMethod<void>('setEffects', args));
  }

  String? _saidLook;

  @override
  Widget buildCaptions() => _ExoCaptions(this);

  /// The size captions are drawn at.
  final captionSize = ValueNotifier(CaptionSize.medium);

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

/// The captions over the video: image subtitles on the picture, and text
/// captions over it all (as media_kit_video's `Video` shows them on Linux).
/// They fit the whole space, so cropping the picture never crops them.
class _ExoCaptions extends StatelessWidget {
  const _ExoCaptions(this.player);

  final ExoTunerPlayer player;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<Size?>(
          valueListenable: player.videoSize,
          builder: (context, size, _) => size == null
              ? const SizedBox.shrink()
              : FittedBox(child: SizedBox.fromSize(size: size, child: ExoImageCues(player.cues, player.captionSize, size))),
        ),
        _TextCues(player.cues, player.captionSize),
      ],
    );
  }
}

/// Where image cues go at [factor] of their authored size, in the picture
/// ([size]): each grows about its own bottom centre and stays inside the
/// picture, with its shape kept. Cues that were apart stay apart, the upper
/// moving up (a two-line DVB caption can be one cue per line).
@visibleForTesting
List<Rect> placeImageCues(List<ExoImageCue> cues, Size size, double factor) {
  Rect inside(Rect r) => Rect.fromLTWH(r.left.clamp(0, max(0.0, size.width - r.width)).toDouble(),
      r.top.clamp(0, max(0.0, size.height - r.height)).toDouble(), r.width, r.height);
  final authored = [
    for (final c in cues)
      Rect.fromLTWH(c.left * size.width, c.top * size.height, c.width * size.width,
          c.height == null ? c.width * size.width / c.aspect : c.height! * size.height),
  ];
  final placed = [
    for (final r in authored)
      () {
        final f = min(factor, min(size.width / r.width, size.height / r.height));
        final w = r.width * f, h = r.height * f;
        return inside(Rect.fromLTWH(r.center.dx - w / 2, r.bottom - h, w, h));
      }(),
  ];
  final lowestFirst = [for (var i = 0; i < cues.length; i++) i]..sort((a, b) => authored[b].bottom.compareTo(authored[a].bottom));
  for (var k = 1; k < lowestFirst.length; k++) {
    final i = lowestFirst[k];
    for (final j in lowestFirst.take(k)) {
      if (!authored[i].overlaps(authored[j]) && placed[i].overlaps(placed[j])) {
        placed[i] = inside(placed[i].shift(Offset(0, placed[j].top - placed[i].bottom)));
      }
    }
  }
  return placed;
}

/// Image captions on the picture, at the size in force.
@visibleForTesting
class ExoImageCues extends StatelessWidget {
  const ExoImageCues(this.cues, this.captionSize, this.size, {super.key});

  final ValueListenable<ExoCues> cues;
  final ValueListenable<CaptionSize> captionSize;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cues, captionSize]),
      builder: (context, _) {
        final images = cues.value.images;
        final rects = placeImageCues(images, size, captionSize.value.ratio);
        return Stack(
          children: [
            for (var n = 0; n < images.length; n++)
              Positioned.fromRect(
                rect: rects[n],
                child: Image.memory(images[n].png, fit: BoxFit.fill, gaplessPlayback: true),
              ),
          ],
        );
      },
    );
  }
}

/// Text captions, in the captions' one style.
class _TextCues extends StatelessWidget {
  const _TextCues(this.cues, this.captionSize);

  final ValueListenable<ExoCues> cues;
  final ValueListenable<CaptionSize> captionSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cues, captionSize]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: captionPadding,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              [
                for (final line in cues.value.text)
                  if (line.trim().isNotEmpty) line.trim(),
              ].join('\n'),
              style: captionTextStyle(captionSize.value),
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(captionBoxScale(constraints.biggest)),
            ),
          ),
        ),
      ),
    );
  }
}
