import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
import 'package:nightingale_tv/playback/still_watching.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;
  late FakeAsync fa;
  late SleepTimer sleep;
  late StillWatching still;
  Duration? after = const Duration(hours: 4);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_still');
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 20, 'Beta': 20}));
    app.client = FakeClient([]);
    player = FakePlayer([]);
    now = DateTime.now();
    after = const Duration(hours: 4);
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
    fa = FakeAsync();
    sleep = fa.run((_) => SleepTimer(tuner, clock: () => now, keepScreenOn: (on) async {}));
    still = StillWatching(tuner, sleep,
        clock: () => now, after: () => after, timer: (d, cb) => fa.run((_) => Timer(d, cb)));
  });

  tearDown(() async {
    still.dispose();
    fa.run((_) => sleep.dispose());
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  /// Moves the clock and fake time on together, in steps of [step].
  void advance(Duration d, {Duration step = const Duration(seconds: 1)}) {
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      now = now.add(s);
      fa.elapse(s);
      left -= s;
    }
    fa.flushMicrotasks();
  }

  Future<void> tune([int i = 0]) async {
    await tuner.tune(app.channels[i]);
    await pumpEventQueue();
    fa.flushMicrotasks();
  }

  const minute = Duration(minutes: 1);

  test('nothing counts until a channel plays', () async {
    expect(still.phase, StillWatchingPhase.off);
    advance(const Duration(hours: 5), step: minute);
    expect(still.phase, StillWatchingPhase.off);
    await tune();
    expect(still.phase, StillWatchingPhase.watching);
  });

  test('asks at the set time with no input, not before', () async {
    await tune();
    advance(const Duration(hours: 4) - minute, step: minute);
    expect(still.prompting, isFalse);
    advance(minute);
    expect(still.prompting, isTrue);
    expect(still.secondsLeft, 60);
    advance(const Duration(seconds: 18));
    expect(still.secondsLeft, 42);
  });

  test('every input starts the count again', () async {
    await tune();
    advance(const Duration(hours: 3), step: minute);
    still.input('pointer move');
    advance(const Duration(hours: 3), step: minute);
    expect(still.prompting, isFalse, reason: '3 h since the last input');
    advance(const Duration(hours: 1), step: minute);
    expect(still.prompting, isTrue);
  });

  test('a tune starts the count again', () async {
    await tune();
    advance(const Duration(hours: 3), step: minute);
    await tune();
    advance(const Duration(hours: 3), step: minute);
    expect(still.prompting, isFalse);
    advance(const Duration(hours: 1), step: minute);
    expect(still.prompting, isTrue);
  });

  test('input on the prompt closes it, playing on; the next comes a full time later', () async {
    await tune();
    advance(const Duration(hours: 4), step: minute);
    expect(still.prompting, isTrue);
    still.input('key Select');
    expect(still.phase, StillWatchingPhase.watching);
    advance(const Duration(minutes: 2));
    expect(sleep.phase, SleepPhase.idle, reason: 'no sleep after an answer');
    expect(tuner.channel, isNotNull);
    advance(const Duration(hours: 4) - const Duration(minutes: 3), step: minute);
    expect(still.prompting, isFalse);
    advance(const Duration(minutes: 1));
    expect(still.prompting, isTrue);
  });

  test('no answer in 60 s: the sound fades and the app sleeps', () async {
    await tune();
    advance(const Duration(hours: 4), step: minute);
    advance(const Duration(seconds: 59));
    expect(still.prompting, isTrue);
    expect(sleep.phase, SleepPhase.idle);
    advance(const Duration(seconds: 1));
    expect(still.prompting, isFalse);
    expect(sleep.phase, SleepPhase.fading);
    advance(const Duration(seconds: 10));
    await pumpEventQueue();
    fa.flushMicrotasks();
    expect(sleep.phase, SleepPhase.asleep);
    expect(tuner.channel, isNull);
    expect(still.phase, StillWatchingPhase.off);
  });

  test('waking tunes again, and the prompt waits the full time from then', () async {
    await tune();
    advance(const Duration(hours: 4, minutes: 1, seconds: 10), step: const Duration(seconds: 10));
    await pumpEventQueue();
    expect(sleep.phase, SleepPhase.asleep);
    advance(const Duration(hours: 2), step: minute);
    fa.run((_) => sleep.wake(by: 'key Select'));
    fa.flushMicrotasks();
    await pumpEventQueue();
    await tune();
    expect(still.phase, StillWatchingPhase.watching);
    advance(const Duration(hours: 4) - minute, step: minute);
    expect(still.prompting, isFalse);
    advance(minute);
    expect(still.prompting, isTrue);
  });

  test('paused in timeshift still counts', () async {
    await tune();
    await tuner.pause();
    fa.flushMicrotasks();
    expect(tuner.paused, isTrue);
    advance(const Duration(hours: 4), step: minute);
    expect(still.prompting, isTrue);
  });

  test('a sleep timer set means no prompt; the timer puts the app to sleep', () async {
    await tune();
    fa.run((_) => sleep.choose(const SleepChoice.after(120)));
    fa.flushMicrotasks();
    expect(still.phase, StillWatchingPhase.off);
    advance(const Duration(minutes: 120, seconds: 10));
    await pumpEventQueue();
    fa.flushMicrotasks();
    expect(sleep.phase, SleepPhase.asleep);
    advance(const Duration(hours: 3), step: minute);
    expect(still.prompting, isFalse);
  });

  test('Off never asks', () async {
    after = null;
    await tune();
    advance(const Duration(hours: 10), step: minute);
    expect(still.prompting, isFalse);
    expect(sleep.phase, SleepPhase.idle);
  });

  test('the profile\'s setting is read by default: 4 hours', () {
    final s = StillWatching(tuner, sleep);
    addTearDown(s.dispose);
    expect(app.settings.playback.stillWatchingAfter, const Duration(hours: 4));
  });

  test('outside a diagnostics build there is no shortened time', () {
    expect(StillWatching.debugOverride, isNull);
    final s = StillWatching(tuner, sleep);
    addTearDown(s.dispose);
    expect(s.phase, StillWatchingPhase.off);
  });
}
