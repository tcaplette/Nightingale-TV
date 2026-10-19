import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Logs what playback is doing once a second, to catch choppy video: mpv's
/// own drop and timing counters, Flutter's frame timings, and the tuner's
/// events (what opened, direct or transcode, status changes).
///
/// On only with NIGHTINGALE_TV_DEBUG_PLAYBACK=1, so it never adds work to
/// normal playback. Each line is tab-separated; tags: OK/CHOPPY (per-second
/// sample), FREEZE (picture stopped while playing), MPV (mpv log message),
/// EVENT (what the tuner did), OPEN, STREAM, FIRST (the picture moves after
/// an open, with how long that took), ERROR (an uncaught Dart or Flutter
/// error).
class PlaybackDiagnostics {
  PlaybackDiagnostics._(this._sink, this._read, this._analyzer, this.path);

  static bool get enabled =>
      Platform.environment['NIGHTINGALE_TV_DEBUG_PLAYBACK'] == '1' && !Platform.environment.containsKey('FLUTTER_TEST');

  /// Starts logging to `playback-debug.log` in [dir]. [read] reads an mpv
  /// property ("" when there's none).
  /// [analyzer] says what background analysis is doing; [playing] whether
  /// the tuner thinks a segment is playing now.
  static PlaybackDiagnostics? start(Directory dir, Future<String> Function(String property) read,
      Future<({String job, String budget, int proxyBytes})> Function() analyzer, bool Function() playing) {
    if (!enabled) return null;
    final path = '${dir.path}/playback-debug.log';
    final file = File(path);
    // Keep the last run's log as .1 once it gets big.
    if (file.existsSync() && file.lengthSync() > 20 * 1024 * 1024) file.renameSync('$path.1');
    final d = PlaybackDiagnostics._(file.openWrite(mode: FileMode.append), read, analyzer, path)..playing = playing;
    d._begin();
    return active = d;
  }

  /// The log being written, for events from outside the tuner (Live TV
  /// export streams), so a stutter can be lined up against them.
  static PlaybackDiagnostics? active;

  final IOSink _sink;
  final Future<String> Function(String) _read;
  late final bool Function() playing;
  Timer? _freezeTimer;
  bool _checkingFreeze = false;
  double? _freezePos;
  DateTime? _frozenSince;
  final Future<({String job, String budget, int proxyBytes})> Function() _analyzer;
  int _proxyBytes = 0;
  bool _streamLogged = false;
  bool _sampling = false;
  final String path;
  Timer? _timer;
  final _clock = Stopwatch()..start();

  /// What's playing, set by the tuner on every open.
  String _playing = '-';

  /// When the last open happened, until its picture first moves.
  Duration? _openedAt;
  bool _firstLogged = true;

  // Counters at the last sample, for per-second deltas.
  int _drops = 0, _decoderDrops = 0, _delayed = 0, _mistimed = 0;
  double? _lastPos;

  // Flutter frames since the last sample.
  int _frames = 0, _slowFrames = 0;
  Duration _worstBuild = Duration.zero, _worstRaster = Duration.zero;

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

  void _begin() {
    _write('START', 'pid=$pid');
    // Errors nothing else catches, which release builds otherwise drop.
    final flutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      _write('ERROR', 'flutter: ${details.exceptionAsString()}'.replaceAll('\n', ' | '));
      flutterError?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final dartError = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _write('ERROR', 'dart: $error | ${stack.toString().split('\n').take(4).join(' | ')}');
      return dartError?.call(error, stack) ?? false;
    };
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    _freezeTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _checkFreeze());
  }

  /// A FREEZE line when the position stops moving for over 0.5 s while the
  /// tuner says it's playing, and one when it moves again.
  Future<void> _checkFreeze() async {
    if (_checkingFreeze) return;
    _checkingFreeze = true;
    try {
      final pos = double.tryParse(await _safe('time-pos'));
      final now = DateTime.now();
      final moved = pos != null && _freezePos != null && (pos - _freezePos!).abs() > 0.01;
      final openedAt = _openedAt;
      if (moved && !_firstLogged && openedAt != null) {
        _firstLogged = true;
        _write('FIRST', 'picture moving ${(_clock.elapsed - openedAt).inMilliseconds} ms after open, pos=$pos playing=$_playing');
      }
      if (!playing() || pos == null || moved) {
        final since = _frozenSince;
        if (since != null && now.difference(since) > const Duration(milliseconds: 500)) {
          _write('FREEZE', 'ended after ${now.difference(since).inMilliseconds} ms at pos=$pos playing=$_playing');
        }
        _frozenSince = null;
      } else if (_freezePos != null && _frozenSince == null) {
        _frozenSince = now;
      } else if (_frozenSince != null && now.difference(_frozenSince!) > const Duration(milliseconds: 500) &&
          now.difference(_frozenSince!) < const Duration(milliseconds: 760)) {
        final state = [
          for (final p in const ['paused-for-cache', 'core-idle', 'pause', 'demuxer-cache-duration', 'cache-speed', 'eof-reached', 'seeking'])
            '$p=${await _safe(p)}',
        ].join(' ');
        _write('FREEZE', 'started at pos=$pos playing=$_playing $state');
      }
      _freezePos = pos;
    } finally {
      _checkingFreeze = false;
    }
  }

  /// An mpv log message.
  void mpvLog(String line) => _write('MPV', line);

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      if (t.totalSpan > const Duration(microseconds: 16667)) _slowFrames++;
      if (t.buildDuration > _worstBuild) _worstBuild = t.buildDuration;
      if (t.rasterDuration > _worstRaster) _worstRaster = t.rasterDuration;
    }
  }

  /// A tuner event: an open, a status change, an error.
  void event(String what) => _write('EVENT', what);

  /// A new segment opened: [kind] is direct or transcode.
  void opened(String kind, Uri url, {Duration? start, Duration? end}) {
    _playing = '$kind ${url.path}';
    _streamLogged = false;
    _openedAt = _clock.elapsed;
    _firstLogged = false;
    // The next reading is the new file's, not a jump from the last one.
    _freezePos = null;
    _write('OPEN', '$kind path=${url.path} start=$start end=$end');
  }

  Future<String> _safe(String property) async {
    try {
      return await _read(property);
    } on Object catch (e) {
      return 'ERR($e)';
    }
  }

  Future<int> _int(String p) async => int.tryParse(await _safe(p)) ?? 0;

  Future<void> _sample() async {
    if (_sampling) return;
    _sampling = true;
    try {
      await _sampleOnce();
    } finally {
      _sampling = false;
    }
  }

  Future<void> _sampleOnce() async {
    final drops = await _int('frame-drop-count');
    final decoderDrops = await _int('decoder-frame-drop-count');
    final delayed = await _int('vo-delayed-frame-count');
    final mistimed = await _int('mistimed-frame-count');
    final pos = double.tryParse(await _safe('time-pos'));
    // Stream details once mpv knows them (the first sample with a codec).
    if (!_streamLogged && (await _safe('video-codec')).isNotEmpty) {
      _streamLogged = true;
      _write('STREAM', [for (final p in _streamProps) '$p=${await _safe(p)}'].join(' '));
    }
    final analysis = await _analyzer();
    final dProxy = analysis.proxyBytes - _proxyBytes;
    _proxyBytes = analysis.proxyBytes;
    final live = {
      for (final p in const [
        'estimated-vf-fps',
        'estimated-display-fps',
        'vsync-jitter',
        'avsync',
        'total-avsync-change',
        'demuxer-cache-duration',
        'paused-for-cache',
        'cache-speed',
        'video-bitrate',
      ])
        p: await _safe(p),
    };
    final dDrops = drops - _drops, dDecoder = decoderDrops - _decoderDrops;
    final dDelayed = delayed - _delayed, dMistimed = mistimed - _mistimed;
    final advanced = pos != null && _lastPos != null ? pos - _lastPos! : null;
    _drops = drops;
    _decoderDrops = decoderDrops;
    _delayed = delayed;
    _mistimed = mistimed;
    _lastPos = pos;

    final choppy = dDrops > 0 || dDecoder > 0 || dDelayed > 0 || dMistimed > 0 || _slowFrames > 2;
    _write(
      choppy ? 'CHOPPY' : 'OK',
      [
        'playing=$_playing',
        'pos=${pos?.toStringAsFixed(2)}',
        'advanced=${advanced?.toStringAsFixed(2)}',
        'drops+$dDrops($drops)',
        'decoderDrops+$dDecoder($decoderDrops)',
        'voDelayed+$dDelayed($delayed)',
        'mistimed+$dMistimed($mistimed)',
        'vfFps=${live['estimated-vf-fps']}',
        'displayFps=${live['estimated-display-fps']}',
        'vsyncJitter=${live['vsync-jitter']}',
        'avsync=${live['avsync']}',
        'avsyncChange=${live['total-avsync-change']}',
        'cache=${live['demuxer-cache-duration']}s',
        'pausedForCache=${live['paused-for-cache']}',
        'cacheSpeed=${live['cache-speed']}',
        'videoBitrate=${live['video-bitrate']}',
        'analyzer="${analysis.job}"',
        'analyzerBudget=${analysis.budget}',
        'analyzerBytesPerSec=${dProxy < 0 ? analysis.proxyBytes : dProxy}',
        'uiFrames=$_frames',
        'uiSlow=$_slowFrames',
        'uiWorstBuild=${_worstBuild.inMicroseconds / 1000}ms',
        'uiWorstRaster=${_worstRaster.inMicroseconds / 1000}ms',
      ].join(' '),
    );
    _frames = _slowFrames = 0;
    _worstBuild = _worstRaster = Duration.zero;
  }

  void _write(String tag, String message) {
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    _sink.writeln('${DateTime.now().toIso8601String()}\t+${t}s\t$tag\t$message');
  }

  Future<void> close() async {
    if (identical(active, this)) active = null;
    _timer?.cancel();
    _freezeTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _write('STOP', '');
    await _sink.flush();
    await _sink.close();
  }
}
