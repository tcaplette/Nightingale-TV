import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';

class _FakeProcess implements Process {
  _FakeProcess(String stderr, int code) {
    _stderr.add(utf8.encode(stderr));
    // Exits once its output is read, unless stopped.
    scheduleMicrotask(() async {
      await _stderr.close();
      await _resumed.future;
      _exit.complete(code);
    });
    _resumed.complete();
  }

  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();
  var _resumed = Completer<void>();
  final signals = <ProcessSignal>[];

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (signal == ProcessSignal.sigstop && _resumed.isCompleted) _resumed = Completer<void>();
    if (signal == ProcessSignal.sigcont && !_resumed.isCompleted) _resumed.complete();
    return true;
  }

  @override
  int get pid => 4242;

  @override
  IOSink get stdin => throw UnimplementedError();
}

const _detections = '[blackdetect @ 0x1] black_start:16.908575 black_end:17.117117 black_duration:0.208542\n'
    '[silencedetect @ 0x2] silence_start: 47.391896\n'
    '[silencedetect @ 0x2] silence_end: 48.620771 | silence_duration: 1.228875\n'
    '[blackdetect @ 0x1] black_start:47.06373 black_end:48.231565 black_duration:1.167835\n';

void main() {
  final input = Uri.parse('http://127.0.0.1:40123/0123456789abcdef0123456789abcdef/reel');

  test('runs ffmpeg niced, with two threads, and nothing secret in its arguments', () async {
    final calls = <List<String>>[];
    final runner = FfmpegRunner(start: (exe, args) async {
      calls.add([exe, ...args]);
      return _FakeProcess(_detections, 0);
    });
    final d = await runner.scan(input,
        from: const Duration(minutes: 10), length: const Duration(minutes: 2), runtime: const Duration(minutes: 122));
    final args = calls.single;
    expect(args.take(4), ['nice', '-n', '10', 'ffmpeg']);
    expect(args, containsAllInOrder(['-threads', '2', '-ss', '600.000', '-t', '120.000', '-i', input.toString()]));
    expect(args, containsAllInOrder(['-vf', 'scale=160:-2,blackdetect=d=0.1:pix_th=0.10']));
    expect(args, containsAllInOrder(['-af', 'silencedetect=n=-45dB:d=0.15', '-f', 'null', '-']));
    for (final a in args) {
      expect(a.toLowerCase(), isNot(anyOf(contains('token'), contains('api_key'), contains('authorization'))));
      expect(a, isNot(contains('jf.example')));
    }
    // Times come back as positions in the whole video.
    expect(d.blacks.first.start, const Duration(minutes: 10, seconds: 16, microseconds: 908575));
    expect(d.silences.single.end, const Duration(minutes: 10, seconds: 48, microseconds: 620771));
  });

  test('a full scan has no -ss or -t', () async {
    final calls = <List<String>>[];
    final runner = FfmpegRunner(start: (exe, args) async {
      calls.add(args);
      return _FakeProcess('', 0);
    });
    await runner.scan(input, runtime: const Duration(minutes: 5));
    expect(calls.single, isNot(contains('-ss')));
    expect(calls.single, isNot(contains('-t')));
  });

  test('a failure on a file without audio is retried once without -af', () async {
    const noAudio = 'Input #0, mov,mp4, from \'x\':\n'
        '  Stream #0:0[0x1](und): Video: h264 (High), yuv420p, 1280x720\n'
        'Filter silencedetect has an unconnected output\n';
    final calls = <List<String>>[];
    final runner = FfmpegRunner(start: (exe, args) async {
      calls.add(args);
      return calls.length == 1 ? _FakeProcess(noAudio, 1) : _FakeProcess(_detections, 0);
    });
    final d = await runner.scan(input, runtime: const Duration(minutes: 5));
    expect(calls, hasLength(2));
    expect(calls[0], contains('-af'));
    expect(calls[1], isNot(contains('-af')));
    expect(d.blacks, hasLength(2));
  });

  test('other failures are reported, not retried', () async {
    const failed = 'Input #0, mov,mp4, from \'x\':\n'
        '  Stream #0:0: Video: h264\n  Stream #0:1: Audio: aac\n'
        'http://127.0.0.1:40123/x/reel: Server returned 404 Not Found\n';
    var calls = 0;
    final runner = FfmpegRunner(start: (exe, args) async {
      calls++;
      return _FakeProcess(failed, 1);
    });
    await expectLater(runner.scan(input, runtime: const Duration(minutes: 5)),
        throwsA(isA<FfmpegException>().having((e) => e.message, 'message', contains('404'))));
    expect(calls, 1);
  });

  test('pausing stops the process and resuming continues it', () async {
    late _FakeProcess process;
    final runner = FfmpegRunner(start: (exe, args) async => process = _FakeProcess(_detections, 0));
    runner.pause();
    final scan = runner.scan(input, runtime: const Duration(minutes: 5));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(process.signals, [ProcessSignal.sigstop], reason: 'starts paused while the TV is tuning');
    var finished = false;
    unawaited(scan.then((_) => finished = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(finished, isFalse);
    runner.resume();
    await scan;
    expect(process.signals, [ProcessSignal.sigstop, ProcessSignal.sigcont]);
  });

  test('checks once whether ffmpeg is installed', () async {
    var checks = 0;
    final missing = FfmpegRunner(run: (exe, args) async {
      checks++;
      throw const ProcessException('ffmpeg', [], 'No such file or directory', 2);
    });
    expect(await missing.available(), isFalse);
    expect(await missing.available(), isFalse);
    expect(checks, 1);
    final installed = FfmpegRunner(run: (exe, args) async => ProcessResult(1, 0, 'ffmpeg version 8.0', ''));
    expect(await installed.available(), isTrue);
  });
}
