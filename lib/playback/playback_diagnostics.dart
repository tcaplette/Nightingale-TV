import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import 'tune_timeline.dart';

/// Logs what playback is doing once a second, to catch choppy video: mpv's
/// own drop and timing counters, Flutter's frame timings, and the tuner's
/// events (what opened, direct or transcode, status changes).
///
/// On only with NIGHTINGALE_TV_DEBUG_PLAYBACK=1, so it never adds work to
/// normal playback: in the environment, or on Android (where an app gets no
/// environment variables) built in with
/// `--dart-define=NIGHTINGALE_TV_DEBUG_PLAYBACK=1`. On Android every line
/// also goes to logcat (`adb logcat -s flutter`), since a release build's
/// files are out of adb's reach.
///
/// Each line is tab-separated; tags: OK/CHOPPY (per-second sample), FREEZE
/// (picture stopped while playing), MPV (mpv log message), EVENT (what the
/// tuner did), OPEN, STREAM, FIRST (the picture moves after an open, with
/// how long that took), ERROR (an uncaught Dart or Flutter error), MARK (a
/// step of the app's launch), HTTP (one of the app's own requests), TUNE
/// (one open from "tune" to its first picture, stage by stage, see
/// [TuneTimeline]), LAUNCH (from the process starting to the first
/// picture), HANDOVER (one segment to the next on a channel: preloaded or
/// opened, moved on by the player or the tuner, and the longest time between
/// two pictures around it).
///
/// `+t` is the time since main() started (since the class was first used).
/// Frames lost so far in the open media, as running totals: dropped by the
/// output, dropped by the decoder, shown late, and shown at the wrong time.
typedef FrameCounts = ({int dropped, int decoderDropped, int delayed, int mistimed});

/// What the diagnostics read from the player, in the player's own terms
/// (mpv's properties, or ExoPlayer's counters).
abstract interface class PlayerReadings {
  /// Seconds into the open media (null when unknown).
  Future<double?> debugPosition();

  /// See [FrameCounts].
  Future<FrameCounts> debugFrames();

  /// The per-second line's player fields after the frame counters, as
  /// "name=value", in order (buffered seconds, load rate…).
  Future<List<String>> debugLive();

  /// "name=value" fields that say why the picture may have stopped (FREEZE).
  Future<List<String>> debugStall();

  /// The STREAM line (format, codec, size, decoder…), once the player knows
  /// the stream; null until then.
  Future<String?> debugStream();

  /// The longest time between two pictures shown in the last [window]
  /// (counting a picture still on screen up to now), for HANDOVER; null
  /// when the player can't tell.
  Future<Duration?> debugFrameGap(Duration window);
}

class PlaybackDiagnostics {
  PlaybackDiagnostics._(this._sink, this._player, this._analyzer, this.path);

  static bool get enabled =>
      (Platform.environment['NIGHTINGALE_TV_DEBUG_PLAYBACK'] == '1' || _builtIn == '1') &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  static const _builtIn = String.fromEnvironment('NIGHTINGALE_TV_DEBUG_PLAYBACK');

  /// The diagnostics clock: started by the first [mark] (main() makes it).
  static final _clock = Stopwatch()..start();

  /// Lines written before the log was opened (launch marks, early
  /// requests), written out when it opens.
  static final _early = <String>[];

  /// The launch's steps, for the LAUNCH line: (name, at).
  static final _launch = <(String, Duration)>[];
  static bool _launchLogged = false;

  /// How long the process had been running when main() started (engine
  /// start-up), from /proc; null where it can't be read.
  static Duration? _processAgeAtMain;

  /// A step of the app's launch (main, storage, library loaded, TV screen,
  /// first tune…). The first one also notes how long the process ran
  /// before main().
  static void mark(String step) {
    if (!enabled) return;
    if (_launch.isEmpty) _processAgeAtMain = _processAge();
    final at = _clock.elapsed;
    if (_launch.length < 64) _launch.add((step, at));
    _log('MARK', step);
  }

  /// A line about the device or set-up, under [tag] (DEVICE, DECODER).
  static void note(String tag, String message) {
    if (enabled) _log(tag, message);
  }

  /// Writes to the open log, or keeps the line until it opens.
  static void _log(String tag, String message) {
    final d = active;
    if (d != null) {
      d._write(tag, message);
    } else if (_early.length < 500) {
      _early.add(_line(tag, message));
      _echo(tag, message);
    }
  }

  static String _line(String tag, String message) {
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    return '${DateTime.now().toIso8601String()}\t+${t}s\t$tag\t$message';
  }

  static void _echo(String tag, String message) {
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    // ignore: avoid_print
    if (Platform.isAndroid) print('PLAYDBG +${t}s $tag $message');
  }

  /// The process's age now, from /proc (Linux and Android).
  static Duration? _processAge() {
    try {
      final stat = File('/proc/self/stat').readAsStringSync();
      final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      // Field 22 (starttime), in ticks since boot; fields here start at 3.
      final startTicks = int.parse(fields[19]);
      final uptime = double.parse(File('/proc/uptime').readAsStringSync().split(' ').first);
      return Duration(milliseconds: (uptime * 1000 - startTicks * 10).round());
    } on Object {
      return null;
    }
  }

  /// Starts logging to `playback-debug.log` in [dir], reading [player].
  /// [analyzer] says what background analysis is doing; [playing] whether
  /// the tuner thinks a segment is playing now; [active] whether a channel is
  /// on at all (paused included). While none is (asleep, stopped), the
  /// samplers stand down, so the log doesn't load an idle app.
  static PlaybackDiagnostics? start(Directory dir, PlayerReadings player,
      Future<({String job, String budget, int proxyBytes})> Function() analyzer, bool Function() playing,
      {bool Function()? active}) {
    if (!enabled) return null;
    final path = '${dir.path}/playback-debug.log';
    final file = File(path);
    // Keep the last run's log as .1 once it gets big.
    if (file.existsSync() && file.lengthSync() > 20 * 1024 * 1024) file.renameSync('$path.1');
    final d = PlaybackDiagnostics._(file.openWrite(mode: FileMode.append), player, analyzer, path)..playing = playing;
    if (active != null) d._active = active;
    PlaybackDiagnostics.active = d;
    d._begin();
    return d;
  }

  /// The log being written, for events from outside the tuner (Live TV
  /// export streams), so a stutter can be lined up against them.
  static PlaybackDiagnostics? active;

  final IOSink _sink;
  final PlayerReadings _player;
  late final bool Function() playing;
  bool Function() _active = _always;
  static bool _always() => true;
  bool _idleLogged = false;
  Timer? _freezeTimer;
  bool _checkingFreeze = false;
  double? _freezePos;
  DateTime? _frozenSince;
  bool _freezeLogged = false;
  final Future<({String job, String budget, int proxyBytes})> Function() _analyzer;
  int _proxyBytes = 0;
  bool _streamLogged = false;
  bool _sampling = false;
  final String path;
  Timer? _timer;
  final _cpu = _CpuSampler();
  final _tcp = _TcpSampler();

  /// The open in progress (or the last one), from "tune" to its picture.
  TuneTimeline? _tune;

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

  void _begin() {
    _write('START', 'pid=$pid cores=${Platform.numberOfProcessors} os=${Platform.operatingSystem}');
    for (final line in _early) {
      _sink.writeln(line);
    }
    _early.clear();
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
    if (!_active()) {
      _frozenSince = null;
      _freezeLogged = false;
      _freezePos = null;
      return;
    }
    _checkingFreeze = true;
    try {
      final pos = await _safe(_player.debugPosition, null);
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
        _freezeLogged = false;
      } else if (_freezePos != null && _frozenSince == null) {
        _frozenSince = now;
      } else if (_frozenSince != null && !_freezeLogged && now.difference(_frozenSince!) > const Duration(milliseconds: 500)) {
        _freezeLogged = true;
        final state = (await _safe(_player.debugStall, const <String>[])).join(' ');
        _write('FREEZE', 'started at pos=$pos playing=$_playing $state');
      }
      _freezePos = pos;
    } finally {
      _checkingFreeze = false;
    }
  }

  /// An mpv log message.
  void mpvLog(String line) {
    _write('MPV', line);
    _tune?.mpvLine(line, _clock.elapsed);
  }

  // ---- Tune timelines ---------------------------------------------------------

  /// The tuner starts opening something: [trigger] says why (launch,
  /// channel, segment, retune, resume, fallback), [what] names it. An
  /// open still in progress is superseded.
  void tuneStarted(String trigger, String what) {
    _endTune('superseded');
    _tune = TuneTimeline(trigger, what, _clock.elapsed);
  }

  /// The tuner awaited [name] (a report, a decision) before opening.
  void tuneWaited(String name, Duration took) => _tune?.waited(name, took);

  /// The player's open call returned.
  void openReturned() => _tune?.openReturned ??= _clock.elapsed;

  /// The open ended with its picture moving.
  void firstPicture() {
    final tune = _tune;
    _endTune('picture');
    if (!_launchLogged && tune != null && tune.trigger == 'launch' && tune.outcome == 'picture') {
      _launchLogged = true;
      _logLaunch(tune);
    }
  }

  /// The open failed (or stopped) before its picture.
  void tuneFailed(String why) => _endTune('failed: $why');

  /// Whether this open goes through the playback proxy.
  void tuneProxy(bool on) => _tune?.proxy = on;

  /// The playback proxy sent a request upstream for mpv.
  void proxyUpstream({required bool warm, required Object? from, required Object? ms}) {
    _tune?.upstreamRequest(warm);
    _write('PROXY', 'upstream ${warm ? 'warm' : 'cold'} from=$from headers=${ms}ms');
  }

  /// The index cache served (or learned) part of the open.
  void proxyCache(String what, Object? detail) {
    _tune?.cache(what);
    _write('PROXY', 'cache $what ${detail ?? ''}');
  }

  /// A background index fill finished (or stopped).
  void cacheFill(String summary) => _write('CACHE', summary);

  void _endTune(String how) {
    final tune = _tune;
    if (tune == null || tune.done) return;
    tune.finish(how, _clock.elapsed);
    _write('TUNE', tune.summary());
  }

  /// From the process starting to the first picture, with each launch step.
  void _logLaunch(TuneTimeline first) {
    String s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final age = _processAgeAtMain;
    final steps = [for (final (name, at) in _launch) '$name +${s(at)}'];
    final total = age == null ? null : age + first.picture!;
    _write(
        'LAUNCH',
        [
          'process-to-picture=${total == null ? '-' : s(total)}',
          'before-main=${age == null ? '-' : s(age)}',
          'main-to-picture=${s(first.picture!)}',
          'tune-to-picture=${s(first.total!)}',
          'steps: ${steps.join(', ')}',
        ].join(' | '));
  }

  /// One of the app's HTTP requests finished (see [DiagnosticHttpClient]).
  static void httpRequest(String method, String path, int? status, Duration headers, Duration took, int bytes,
      {Object? error}) {
    if (!enabled) return;
    final d = active;
    // It overlaps the open in progress.
    final tune = d?._tune;
    if (tune != null && !tune.done) tune.appRequest('$method $path', took, bytes);
    _log('HTTP',
        '$method $path status=${status ?? '-'} headers=${headers.inMilliseconds}ms took=${took.inMilliseconds}ms bytes=$bytes${error == null ? '' : ' error=$error'}');
  }

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

  /// A break notice's cut came (break-notices D7).
  void notice(String what) => _write('NOTICE', what);

  /// A new segment opened: [kind] is direct or transcode.
  void opened(String kind, Uri url, {Duration? start, Duration? end}) {
    _tune
      ?..kind = kind
      ..openCalled ??= _clock.elapsed;
    _playing = '$kind ${url.path}';
    _streamLogged = false;
    _openedAt = _clock.elapsed;
    _firstLogged = false;
    // The next reading is the new file's, not a jump from the last one.
    _freezePos = null;
    _write('OPEN', '$kind path=${url.path} start=$start end=$end');
  }

  /// A preloaded segment took over without an open (segment-handover spec).
  void handedOver(String kind, Uri url, {Duration? start, Duration? end}) {
    _playing = '$kind ${url.path}';
    _streamLogged = false;
    _openedAt = _clock.elapsed;
    _firstLogged = false;
    _freezePos = null;
    _write('OPEN', '$kind (preloaded) path=${url.path} start=$start end=$end');
  }

  /// One segment handed over to the next: [preloaded] or opened, by the
  /// player or the tuner ([trigger]), with the longest time between two
  /// pictures around it ([gap]; null when there's no picture or the player
  /// can't tell), and from the hand-over to the next one's picture
  /// ([after]): a stall in the segment before shows in [gap] only.
  void handover(String from, String to,
          {required bool preloaded, required String trigger, Duration? gap, Duration? after}) =>
      _write('HANDOVER',
          'from=$from to=$to preloaded=${preloaded ? 'yes' : 'no'} trigger=$trigger gap=${gap == null ? '-' : '${gap.inMilliseconds}ms'} after=${after == null ? '-' : '${after.inMilliseconds}ms'}');

  /// [read]'s answer, or [fallback] if the player couldn't answer.
  Future<T> _safe<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } on Object {
      return fallback;
    }
  }

  Future<void> _sample() async {
    if (_sampling) return;
    if (!_active()) {
      if (!_idleLogged) {
        _idleLogged = true;
        _write('IDLE', 'no channel on; sampling stops until the next tune');
      }
      return;
    }
    _idleLogged = false;
    _sampling = true;
    try {
      await _sampleOnce();
    } finally {
      _sampling = false;
    }
  }

  Future<void> _sampleOnce() async {
    final frames = await _safe(_player.debugFrames, (dropped: 0, decoderDropped: 0, delayed: 0, mistimed: 0));
    final drops = frames.dropped, decoderDrops = frames.decoderDropped;
    final delayed = frames.delayed, mistimed = frames.mistimed;
    final pos = await _safe(_player.debugPosition, null);
    // Stream details once the player knows them.
    if (!_streamLogged) {
      final stream = await _safe(_player.debugStream, null);
      if (stream != null) {
        _streamLogged = true;
        _write('STREAM', stream);
      }
    }
    final analysis = await _analyzer();
    final dProxy = analysis.proxyBytes - _proxyBytes;
    _proxyBytes = analysis.proxyBytes;
    final tune = _tune;
    if (tune != null && !tune.done) tune.analyzerBytes += dProxy < 0 ? analysis.proxyBytes : dProxy;
    final live = await _safe(_player.debugLive, const <String>[]);
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
        ...live,
        _cpu.sample(),
        await _tcp.sample(),
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

  /// A sample under way when the log closes finishes after it: what it
  /// would write is dropped.
  bool _closed = false;

  void _write(String tag, String message) {
    if (_closed) return;
    _sink.writeln(_line(tag, message));
    _echo(tag, message);
  }

  Future<void> close() async {
    if (_closed) return;
    if (identical(active, this)) active = null;
    _timer?.cancel();
    _freezeTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _endTune('app closed');
    _write('STOP', '');
    _closed = true;
    await _sink.flush();
    await _sink.close();
  }
}

/// This process's TCP connections (Linux), from `ss`: for each, the bytes
/// waiting in the receive queue that the app hasn't read yet (recvQ), the
/// bytes received per second since the last sample, the receive window the
/// kernel has grown to (rcvSpace), the receive buffer limit (rb), the round
/// trip (rtt, rcvRtt) and ms since data last arrived (lastRcv). A full recvQ
/// means the reader is behind; an empty one means it's waiting for data.
class _TcpSampler {
  final _received = <String, int>{};
  int? _hostBytes;
  final _clock = Stopwatch()..start();
  Duration _last = Duration.zero;

  Future<String> sample() async {
    if (!Platform.isLinux) return 'tcp=-';
    try {
      final result = await Process.run('ss', ['-tinmpH', 'state', 'established']);
      final now = _clock.elapsed;
      final seconds = (now - _last).inMicroseconds / 1e6;
      _last = now;
      final records = <String>[];
      for (final line in (result.stdout as String).split('\n')) {
        if (line.isEmpty) continue;
        if (line.startsWith(' ') || line.startsWith('\t')) {
          if (records.isNotEmpty) records[records.length - 1] += ' $line';
        } else {
          records.add(line);
        }
      }
      final out = <String>[];
      final seen = <String>{};
      for (final r in records.where((r) => r.contains('pid=$pid,'))) {
        final cols = r.trim().split(RegExp(r'\s+'));
        if (cols.length < 4) continue;
        final key = '${cols[2]}>${cols[3]}';
        seen.add(key);
        String? f(String name) => RegExp('(?:^|\\s)$name:([^\\s]+)').firstMatch(r)?.group(1);
        final bytes = int.tryParse(f('bytes_received') ?? '') ?? 0;
        final before = _received[key];
        _received[key] = bytes;
        final rate = before == null || seconds <= 0 ? '-' : ((bytes - before) / seconds).round().toString();
        final rb = RegExp(r'skmem:\([^)]*\brb(\d+)').firstMatch(r)?.group(1) ?? '-';
        out.add('${cols[3]} recvQ=${cols[0]} rate=$rate rcvSpace=${f('rcv_space') ?? '-'} '
            'rb=$rb rtt=${f('rtt')?.split('/').first ?? '-'} rcvRtt=${f('rcv_rtt') ?? '-'} '
            'lastRcv=${f('lastrcv') ?? '-'}');
      }
      _received.removeWhere((k, _) => !seen.contains(k));
      // Everything this machine received per second, on all interfaces but
      // loopback: compared with the app's own sockets above, what else on
      // the machine shares the link.
      var hostBytes = 0;
      for (final line in File('/proc/net/dev').readAsLinesSync().skip(2)) {
        final parts = line.trim().split(RegExp(r'[:\s]+'));
        if (parts.length > 1 && parts[0] != 'lo') hostBytes += int.tryParse(parts[1]) ?? 0;
      }
      final hostBefore = _hostBytes;
      _hostBytes = hostBytes;
      final hostRate = hostBefore == null || seconds <= 0 ? '-' : ((hostBytes - hostBefore) / seconds).round().toString();
      return 'hostRx=$hostRate tcp=[${out.join('; ')}]';
    } on Object catch (e) {
      return 'tcp=ERR($e)';
    }
  }
}

/// This process's CPU use since the last sample, in all and for its busiest
/// threads (by name: mpv's decoder, demuxer and output threads among them),
/// from /proc, so a stall can be told apart from the device running out of
/// CPU. 100% is one core.
class _CpuSampler {
  final _threads = <int, int>{};
  int? _process;
  final _clock = Stopwatch()..start();
  Duration _last = Duration.zero;

  /// Linux and Android count CPU time in hundredths of a second.
  static const _ticksPerSecond = 100;

  String sample() {
    try {
      final now = _clock.elapsed;
      final seconds = (now - _last).inMicroseconds / 1e6;
      _last = now;
      final busy = <(String, double)>[];
      final seen = <int>{};
      for (final task in Directory('/proc/self/task').listSync()) {
        final tid = int.tryParse(task.path.split('/').last);
        final t = tid == null ? null : _read('${task.path}/stat');
        if (tid == null || t == null) continue;
        seen.add(tid);
        final before = _threads[tid];
        _threads[tid] = t.ticks;
        if (before != null && seconds > 0) busy.add((t.name, (t.ticks - before) / _ticksPerSecond / seconds * 100));
      }
      _threads.removeWhere((tid, _) => !seen.contains(tid));
      final process = _read('/proc/self/stat')?.ticks;
      final before = _process;
      _process = process;
      if (before == null || process == null || seconds <= 0) return 'cpu=-';
      busy.sort((a, b) => b.$2.compareTo(a.$2));
      final top = [for (final t in busy.take(5)) if (t.$2 >= 1) '${t.$1}:${t.$2.round()}%'].join(',');
      return 'cpu=${((process - before) / _ticksPerSecond / seconds * 100).round()}% threads=$top';
    } on Object catch (e) {
      return 'cpu=ERR($e)';
    }
  }

  /// A /proc stat file's name (spaces made underscores) and user+system time.
  static ({String name, int ticks})? _read(String path) {
    try {
      final stat = File(path).readAsStringSync();
      final open = stat.indexOf('('), close = stat.lastIndexOf(')');
      final fields = stat.substring(close + 2).split(' ');
      return (name: stat.substring(open + 1, close).replaceAll(' ', '_'), ticks: int.parse(fields[11]) + int.parse(fields[12]));
    } on Object {
      return null;
    }
  }
}

/// Logs each of the app's HTTP requests (path, status, time to headers,
/// time to the last byte, bytes received) to the diagnostics log: the app's
/// own traffic, to line up against an open. Diagnostics builds only.
class DiagnosticHttpClient extends http.BaseClient {
  DiagnosticHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final clock = Stopwatch()..start();
    final method = request.method, path = request.url.path;
    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } on Object catch (e) {
      PlaybackDiagnostics.httpRequest(method, path, null, clock.elapsed, clock.elapsed, 0, error: e);
      rethrow;
    }
    final headers = clock.elapsed;
    var bytes = 0;
    var logged = false;
    void log([Object? error]) {
      if (logged) return;
      logged = true;
      PlaybackDiagnostics.httpRequest(method, path, response.statusCode, headers, clock.elapsed, bytes, error: error);
    }

    final body = response.stream.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        bytes += chunk.length;
        sink.add(chunk);
      },
      handleError: (e, st, sink) {
        log(e);
        sink.addError(e, st);
      },
      handleDone: (sink) {
        log();
        sink.close();
      },
    ));
    return http.StreamedResponse(body, response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase);
  }

  @override
  void close() => _inner.close();
}
