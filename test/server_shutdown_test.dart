import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_exit.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';

void main() {
  tearDown(exitHooks.clear);

  test('SIGTERM stops the stream processes, writes state files and exits 0', () async {
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_shutdown');
    addTearDown(() => dir.delete(recursive: true));
    final household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    await household.start();

    // A stand-in for an export stream's ffmpeg, stopped by the export's
    // exit hook.
    final ffmpeg = await Process.start('sleep', ['60']);
    exitHooks.add(() async {
      ffmpeg.kill(ProcessSignal.sigterm);
      await ffmpeg.exitCode;
    });
    // A state write still pending when the signal comes.
    unawaited(household.root.writeJson('marker.json', {'written': true}));

    final signals = StreamController<ProcessSignal>();
    final exited = Completer<int>();
    final sub = watchServerSignals(household.closeAll, signals: signals.stream, exitWith: exited.complete);
    addTearDown(sub.cancel);
    final watch = Stopwatch()..start();
    signals.add(ProcessSignal.sigterm);
    signals.add(ProcessSignal.sigint);
    expect(await exited.future, 0);
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    expect(Process.killPid(ffmpeg.pid, ProcessSignal.sigcont), isFalse, reason: 'no process left');
    expect(await household.root.readJson('marker.json'), {'written': true});
  });

  test('a shutdown that hangs exits 1 at the deadline', () {
    fakeAsync((async) {
      exitHooks.add(() => Completer<void>().future);
      final codes = <int>[];
      final signals = StreamController<ProcessSignal>();
      watchServerSignals(() => Completer<void>().future, signals: signals.stream, exitWith: codes.add);
      signals.add(ProcessSignal.sigterm);
      async.elapse(const Duration(seconds: 8));
      expect(codes, isEmpty);
      async.elapse(const Duration(seconds: 2));
      expect(codes, [1]);
    });
  });
}
