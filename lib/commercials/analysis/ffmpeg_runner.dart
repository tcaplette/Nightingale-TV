import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'detections.dart';

/// Starts a process (replaceable in tests).
typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

/// Runs a process to completion (replaceable in tests).
typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

class FfmpegException implements Exception {
  FfmpegException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Finds black frames and silences in a stream.
abstract interface class SceneScanner {
  Future<bool> available();

  /// Scans [input] (all of it, or [length] from [from]).
  Future<Detections> scan(Uri input, {Duration? from, Duration? length, required Duration runtime});
  void pause();
  void resume();
  void cancel();
}

/// Runs ffmpeg's black-frame and silence detection over a stream, at low
/// CPU priority, one process at a time.
class FfmpegRunner implements SceneScanner {
  FfmpegRunner({ProcessStarter? start, ProcessRunner? run})
      : _start = start ?? Process.start,
        _run = run ?? Process.run;

  final ProcessStarter _start;
  final ProcessRunner _run;
  Future<bool>? _available;
  Process? _process;
  bool _paused = false;

  /// Whether ffmpeg is installed (checked once).
  @override
  Future<bool> available() => _available ??= () async {
        try {
          final r = await _run('ffmpeg', const ['-version']);
          return r.exitCode == 0;
        } on ProcessException {
          return false;
        }
      }();

  /// ffmpeg's arguments for scanning [input], optionally only [length] of it
  /// from [from]. The input is a loopback proxy URL, so no token is ever on
  /// the command line.
  static List<String> arguments(Uri input, {Duration? from, Duration? length, bool audio = true}) => [
        '-nostdin',
        '-hide_banner',
        '-nostats',
        '-threads',
        '2',
        if (from != null) ...['-ss', _seconds(from)],
        if (length != null) ...['-t', _seconds(length)],
        '-i',
        input.toString(),
        '-vf',
        'scale=160:-2,blackdetect=d=0.1:pix_th=0.10',
        if (audio) ...['-af', 'silencedetect=n=-45dB:d=0.15'],
        '-f',
        'null',
        '-',
      ];

  static String _seconds(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);

  /// Scans [input] (all of it, or [length] from [from]) and returns what it
  /// found, as positions in the whole video. [runtime] closes a silence
  /// still open at the end.
  @override
  Future<Detections> scan(Uri input, {Duration? from, Duration? length, required Duration runtime}) async {
    final end = length == null ? runtime : (from ?? Duration.zero) + length;
    var (code, stderr) = await _runFfmpeg(arguments(input, from: from, length: length));
    // Older ffmpeg builds fail on -af when the file has no audio at all.
    if (code != 0 && _hasNoAudio(stderr)) {
      (code, stderr) = await _runFfmpeg(arguments(input, from: from, length: length, audio: false));
    }
    if (code != 0) throw FfmpegException(_lastLines(stderr));
    return parseFfmpegDetections(stderr, offset: from ?? Duration.zero, end: end);
  }

  Future<(int, String)> _runFfmpeg(List<String> args) async {
    if (_process != null) throw StateError('ffmpeg is already running.');
    // nice runs ffmpeg in its place, so signals reach ffmpeg itself.
    final process = await _start('nice', ['-n', '10', 'ffmpeg', ...args]);
    _process = process;
    if (_paused) process.kill(ProcessSignal.sigstop);
    try {
      final stderr = StringBuffer();
      final done = Future.wait([
        process.stdout.drain<void>(),
        process.stderr.transform(const Utf8Decoder(allowMalformed: true)).forEach(stderr.write),
      ]);
      final code = await process.exitCode;
      await done;
      return (code, stderr.toString());
    } finally {
      _process = null;
    }
  }

  static final _streamLine = RegExp(r'^\s*Stream #\d+:\d+.*?: (Video|Audio):', multiLine: true);

  static bool _hasNoAudio(String stderr) {
    final streams = _streamLine.allMatches(stderr).map((m) => m[1]).toList();
    return streams.contains('Video') && !streams.contains('Audio');
  }

  static String _lastLines(String stderr) {
    final lines = stderr.trim().split('\n');
    return lines.length <= 3 ? stderr.trim() : lines.sublist(lines.length - 3).join('\n');
  }

  /// Freezes the running scan (e.g. while the TV tunes a channel).
  @override
  void pause() {
    if (_paused) return;
    _paused = true;
    _process?.kill(ProcessSignal.sigstop);
  }

  @override
  void resume() {
    if (!_paused) return;
    _paused = false;
    _process?.kill(ProcessSignal.sigcont);
  }

  /// Stops the running scan; it fails with [FfmpegException].
  @override
  void cancel() {
    final p = _process;
    if (p == null) return;
    if (_paused) p.kill(ProcessSignal.sigcont);
    p.kill(ProcessSignal.sigterm);
  }
}
