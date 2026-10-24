import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/analysis/media_analyzer.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/analysis_queue.dart';
import 'package:nightingale_tv/profiles/household.dart';

import 'fixtures.dart';

void main() {
  group('queue', () {
    late AnalysisQueue queue;
    late Map<String, ValueNotifier<AnalyzerState>> idle;

    /// Who may analyze right now.
    List<String> allowed() => [for (final id in idle.keys) if (queue.allowedFor(id).value) id];

    setUp(() {
      queue = AnalysisQueue();
      idle = {for (final id in ['a', 'b']) id: ValueNotifier(AnalyzerState.starting)};
      // As an AppState does: losing the turn stops its analyzer.
      for (final id in idle.keys) {
        queue.allowedFor(id).addListener(() {
          if (!queue.allowedFor(id).value) idle[id]!.value = AnalyzerState.starting;
        });
      }
    });
    tearDown(() => queue.dispose());

    test("A runs to completion first, then B's, never both at once", () {
      fakeAsync((async) {
        queue.setProfiles(['a', 'b'], (id) => idle[id]);
        expect(allowed(), ['a']);
        // B has work too, but waits while A works.
        idle['a']!.value = AnalyzerState.working;
        async.elapse(const Duration(minutes: 30));
        expect(allowed(), ['a']);
        idle['a']!.value = AnalyzerState.idle;
        expect(allowed(), ['b']);
        idle['b']!.value = AnalyzerState.working;
        idle['b']!.value = AnalyzerState.idle;
        async.flushMicrotasks();
        expect(allowed(), ['a'], reason: 'B finished: back to A, to look for news');
        idle['a']!.value = AnalyzerState.idle;
        async.flushMicrotasks();
        expect(allowed(), ['b']);
        idle['b']!.value = AnalyzerState.idle;
        async.flushMicrotasks();
        expect(allowed(), isEmpty, reason: 'a round with nothing to do: resting');
      });
    });

    test('a round with nothing to do rests, then asks around again', () {
      fakeAsync((async) {
        idle['a']!.value = AnalyzerState.idle;
        idle['b']!.value = AnalyzerState.idle;
        queue.setProfiles(['a', 'b'], (id) => idle[id]);
        async.flushMicrotasks();
        expect(allowed(), isEmpty, reason: 'resting');
        expect(queue.turn, isNull);
        async.elapse(AnalysisQueue.rest);
        // A library refresh gave B work meanwhile.
        idle['b']!.value = AnalyzerState.working;
        async.flushMicrotasks();
        expect(allowed(), ['a'], reason: 'A is asked first again');
        idle['a']!.value = AnalyzerState.starting;
        idle['a']!.value = AnalyzerState.idle;
        expect(allowed(), ['b'], reason: 'and B gets its turn');
      });
    });

    test('an unexported profile loses its turn', () {
      queue.setProfiles(['a', 'b'], (id) => idle[id]);
      expect(allowed(), ['a']);
      queue.setProfiles(['b'], (id) => idle[id]);
      expect(allowed(), ['b']);
    });

    test("a busy holder's idle doesn't pass on another's turn", () {
      queue.setProfiles(['a', 'b'], (id) => idle[id]);
      idle['b']!.value = AnalyzerState.idle;
      idle['b']!.value = AnalyzerState.working;
      expect(allowed(), ['a']);
    });
  });

  group('household', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_queue'));
    tearDown(() async => dir.delete(recursive: true));

    test('exported profiles take turns; a stream holds analysis off without moving the turn', () async {
      final household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
      await household.start();
      final a = household.profiles.single;
      final b = household.newProfile()..name = 'B';
      await household.saveProfile(b);
      for (final p in [a, b]) {
        await (await signedInApp((await household.storageFor(p)).root, fakeLibrary())).close();
      }
      await household.setExportedProfiles({a.id, b.id});
      final appA = household.appFor(a.id)!, appB = household.appFor(b.id)!;
      expect(appA.analysisAllowed, isNotNull);
      final queue = household.analysisQueue!;
      expect(queue.turn, a.id);
      expect([appA.analysisAllowed!.value, appB.analysisAllowed!.value], [true, false]);

      household.exportStreaming.value = true;
      expect(appA.analysisBusy.value && appB.analysisBusy.value, isTrue);
      household.exportStreaming.value = false;
      expect(appA.analysisBusy.value || appB.analysisBusy.value, isFalse);

      // Without analysis (runAnalysis: false) both are idle once loaded:
      // the turn goes round and the queue rests.
      for (var i = 0; i < 100 && queue.turn != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(queue.turn, isNull);
      expect(appA.analysisAllowed!.value || appB.analysisAllowed!.value, isFalse);
      await household.setExportedProfiles({});
      queue.dispose();
    });

    test('the TV has no queue', () async {
      final household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      expect(household.analysisQueue, isNull);
      expect(household.app!.analysisAllowed, isNull);
      household.leave();
      await pumpEventQueue();
    });
  });
}
