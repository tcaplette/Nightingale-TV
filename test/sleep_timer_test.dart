import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
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
  late List<bool> screenOn;
  late List<String> messages;

  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_sleep');
    app = await signedInApp(dir, library);
    // Breaks, so programs have post-rolls.
    await app.setGlobalPlan(BreakPlan.automatic);
    app.client = FakeClient([]);
    player = FakePlayer([]);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
    // The sleep timer's own timers run on fake time, in step with [now].
    fa = FakeAsync();
    screenOn = [];
    messages = [];
    sleep = fa.run((_) => SleepTimer(tuner, clock: () => now, keepScreenOn: (on) async => screenOn.add(on)));
    fa.run((_) => sleep.messages.listen(messages.add));
  });

  tearDown(() async {
    fa.run((_) => sleep.dispose());
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();
  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)! as ChannelSchedule;

  /// Moves the clock and the timer's fake time on together, a second at a
  /// time.
  void advance(Duration d) {
    var left = d;
    while (left > Duration.zero) {
      final step = left < const Duration(seconds: 1) ? left : const Duration(seconds: 1);
      now = now.add(step);
      fa.elapse(step);
      left -= step;
    }
    fa.flushMicrotasks();
  }

  void choose(SleepChoice c) {
    fa.run((_) => sleep.choose(c));
    fa.flushMicrotasks();
  }

  void cancel(String by) {
    fa.run((_) => sleep.cancel(by: by));
    fa.flushMicrotasks();
  }

  /// The end of [slot]'s last show part, worked out from its segments, and
  /// whether a post-roll follows it.
  ({DateTime end, bool postRoll}) lastPartOf(ChannelSchedule s, ScheduledProgram slot) {
    DateTime? end;
    var postRoll = false;
    for (var seg = s.playbackAt(slot.start); seg.start.isBefore(slot.end); seg = s.playbackAt(seg.end)) {
      if (!seg.isBreak && seg.item != null) {
        end = seg.end;
        postRoll = false;
      } else if (seg.role == BreakRole.post) {
        postRoll = true;
      }
    }
    return (end: end!, postRoll: postRoll);
  }

  /// Tunes [ch] [into] a slot that has a post-roll, at the live point.
  Future<ScheduledProgram> tuneIntoShow(Channel ch, {Duration into = const Duration(minutes: 3)}) async {
    final s = scheduleOf(ch);
    var slot = s.programAt(now);
    for (var i = 0; i < 50 && !lastPartOf(s, slot).postRoll; i++) {
      slot = s.next(slot);
    }
    expect(lastPartOf(s, slot).postRoll, isTrue, reason: 'a slot with a post-roll');
    now = slot.start.add(into);
    await tuner.tune(ch);
    await settle();
    return slot;
  }

  group('minute timers', () {
    test('fire on the wall clock whatever the tuner does, warning a minute ahead', () async {
      await tuneIntoShow(app.channels.first);
      final setAt = now;
      choose(const SleepChoice.after(15));
      expect(sleep.phase, SleepPhase.armed);
      expect(sleep.deadline, setAt.add(const Duration(minutes: 15)));
      expect(messages, ['Sleep in 15 min']);
      advance(const Duration(minutes: 7, seconds: 20));
      expect(sleep.minutesLeft, 8, reason: 'whole minutes, rounded up');
      // Pausing, and a channel change, don't move it.
      await tuner.pause();
      advance(const Duration(minutes: 2));
      await tuner.resume();
      await tuner.tune(app.channels[1]);
      await settle();
      expect(sleep.deadline, setAt.add(const Duration(minutes: 15)));
      advance(setAt.add(const Duration(minutes: 14)).difference(now) - const Duration(seconds: 1));
      expect(sleep.phase, SleepPhase.armed);
      advance(const Duration(seconds: 1));
      expect(sleep.phase, SleepPhase.warning);
      expect(sleep.secondsLeft, 60);
      advance(const Duration(seconds: 18));
      expect(sleep.secondsLeft, 42);
      advance(const Duration(seconds: 42));
      expect(sleep.phase, SleepPhase.fading);
    });

    test('the phases run in order; the end stops playback, restores the volume and lets the screen go', () async {
      final ch = app.channels.first;
      await tuneIntoShow(ch);
      final phases = <SleepPhase>[];
      sleep.addListener(() {
        if (phases.isEmpty || phases.last != sleep.phase) phases.add(sleep.phase);
      });
      choose(const SleepChoice.after(15));
      advance(const Duration(minutes: 15));
      expect(sleep.phase, SleepPhase.fading);
      expect(tuner.status, isNot(TunerStatus.idle), reason: 'still playing while it fades');
      advance(const Duration(seconds: 4));
      expect(player.volume, closeTo(0.6, 0.001), reason: 'down by a twentieth every half second');
      advance(const Duration(seconds: 6));
      await settle();
      fa.flushMicrotasks();
      await settle();
      expect(phases, [SleepPhase.armed, SleepPhase.warning, SleepPhase.fading, SleepPhase.asleep]);
      expect(sleep.phase, SleepPhase.asleep);
      expect(tuner.status, TunerStatus.idle);
      expect(tuner.channel, isNull, reason: 'nothing streams');
      expect(player.volume, 1, reason: 'the next tune is not silent');
      expect(player.volumes.where((v) => v < 1), hasLength(20));
      expect(screenOn, [false]);
      expect(sleep.sleptOn?.id, ch.id);
      expect(sleep.choice, SleepChoice.off);
      expect(app.analyzerBudgetNow.paused, isTrue, reason: 'no background reads while asleep');
    });

    test('a cancel during the fade restores full volume at once', () async {
      await tuneIntoShow(app.channels.first);
      choose(const SleepChoice.after(15));
      advance(const Duration(minutes: 15, seconds: 4));
      expect(sleep.phase, SleepPhase.fading);
      expect(player.volume, lessThan(1));
      cancel('key');
      expect(sleep.phase, SleepPhase.idle);
      expect(player.volume, 1);
      expect(messages.last, 'Sleep timer off');
      advance(const Duration(seconds: 20));
      expect(player.volume, 1, reason: 'no more steps');
      expect(tuner.status, isNot(TunerStatus.idle));
    });

    test('a cancel in the warning turns it off; nothing fires later', () async {
      await tuneIntoShow(app.channels.first);
      choose(const SleepChoice.after(15));
      advance(const Duration(minutes: 14, seconds: 18));
      expect(sleep.phase, SleepPhase.warning);
      cancel('pointer move');
      expect(sleep.phase, SleepPhase.idle);
      expect(sleep.choice, SleepChoice.off);
      advance(const Duration(minutes: 2));
      expect(sleep.phase, SleepPhase.idle);
      expect(player.volumes.where((v) => v < 1), isEmpty);
    });

    test('choosing Off turns it off', () async {
      await tuneIntoShow(app.channels.first);
      choose(const SleepChoice.after(30));
      choose(SleepChoice.off);
      expect(sleep.phase, SleepPhase.idle);
      expect(sleep.deadline, isNull);
      expect(messages, ['Sleep in 30 min', 'Sleep timer off']);
    });
  });

  group('end of this program', () {
    test('fires at the last show part\'s end, before the post-roll', () async {
      final ch = app.channels.first;
      final slot = await tuneIntoShow(ch);
      final end = lastPartOf(scheduleOf(ch), slot).end;
      expect(end.isBefore(slot.end), isTrue);
      expect(sleep.programEnd(), end);
      choose(SleepChoice.programEnd);
      expect(messages, ['Sleep at end of program']);
      expect(sleep.deadline, end);
      advance(end.subtract(const Duration(seconds: 61)).difference(now));
      expect(sleep.phase, SleepPhase.armed);
      advance(const Duration(seconds: 1));
      expect(sleep.phase, SleepPhase.warning, reason: 'a minute before the end');
      advance(const Duration(seconds: 60));
      expect(sleep.phase, SleepPhase.fading, reason: 'at the end');
    });

    test('chosen in a program\'s last minute, it\'s the next program\'s end, with a full warning', () async {
      final ch = app.channels.first;
      final s = scheduleOf(ch);
      final slot = await tuneIntoShow(ch);
      final end = lastPartOf(s, slot).end;
      now = end.subtract(const Duration(seconds: 30));
      final next = s.next(slot);
      final nextEnd = lastPartOf(s, next).end;
      expect(sleep.programEnd(choosing: true), nextEnd);
      choose(SleepChoice.programEnd);
      expect(sleep.deadline, nextEnd);
      advance(const Duration(minutes: 2));
      expect(sleep.phase, SleepPhase.armed, reason: 'the program that ended doesn\'t count');
      expect(sleep.deadline, nextEnd, reason: 'following keeps to the next program');
    });

    test('pausing and rewinding move it later', () async {
      final ch = app.channels.first;
      final slot = await tuneIntoShow(ch);
      final end = lastPartOf(scheduleOf(ch), slot).end;
      choose(SleepChoice.programEnd);
      await tuner.pause();
      advance(const Duration(minutes: 5));
      expect(sleep.deadline, end.add(const Duration(minutes: 5)));
      await tuner.resume();
      await settle();
      advance(const Duration(seconds: 2));
      expect(sleep.deadline, end.add(const Duration(minutes: 5)));
      tuner.skip(const Duration(minutes: -1));
      await Future<void>.delayed(Tuner.seekDebounce + const Duration(milliseconds: 60));
      await settle();
      advance(const Duration(seconds: 1));
      expect(sleep.deadline, end.add(const Duration(minutes: 6)));
    });

    test('a channel change moves it to the end of what\'s on there', () async {
      await tuneIntoShow(app.channels.first);
      choose(SleepChoice.programEnd);
      final other = app.channels[1];
      final s = scheduleOf(other);
      await tuner.tune(other);
      await settle();
      advance(const Duration(seconds: 1));
      var slot = s.programAt(now);
      var expected = lastPartOf(s, slot).end;
      if (!expected.isAfter(now)) {
        slot = s.next(slot);
        expected = lastPartOf(s, slot).end;
      }
      expect(sleep.deadline, expected);
    });

    test('off the air it waits, then fires a minute after a program with an end is on', () async {
      final empty = await app.createCustomChannel('Empty', const ChannelSource(seriesKeys: ['alpha|2000']));
      empty.playlist = const [];
      await app.updateChannel(empty);
      await tuneIntoShow(app.channels.first);
      choose(SleepChoice.programEnd);
      await tuner.tune(app.channelById(empty.id)!);
      await settle();
      expect(tuner.status, TunerStatus.offAir);
      advance(const Duration(seconds: 1));
      expect(sleep.deadline, isNull);
      expect(sleep.programEnd(), isNull);
      advance(const Duration(minutes: 30));
      expect(sleep.phase, SleepPhase.armed, reason: 'waits');
      await tuner.tune(app.channels.first);
      await settle();
      final back = now;
      advance(const Duration(seconds: 1));
      expect(sleep.deadline!.difference(back).inSeconds, inInclusiveRange(60, 61));
      expect(sleep.phase, SleepPhase.warning);
    });

    test('with no end for 4 hours it fires anyway', () async {
      final empty = await app.createCustomChannel('Empty', const ChannelSource(seriesKeys: ['alpha|2000']));
      empty.playlist = const [];
      await app.updateChannel(empty);
      await tuneIntoShow(app.channels.first);
      choose(SleepChoice.programEnd);
      await tuner.tune(app.channelById(empty.id)!);
      await settle();
      advance(const Duration(hours: 4) - const Duration(seconds: 2));
      expect(sleep.phase, SleepPhase.armed);
      advance(const Duration(seconds: 3));
      expect(sleep.phase, SleepPhase.warning);
      advance(const Duration(seconds: 60));
      expect(sleep.phase, SleepPhase.fading);
    });
  });

  group('waking and hiding', () {
    Future<void> fallAsleep() async {
      await tuneIntoShow(app.channels.first);
      choose(const SleepChoice.after(15));
      advance(const Duration(minutes: 15, seconds: 10));
      await settle();
      fa.flushMicrotasks();
      await settle();
      expect(sleep.phase, SleepPhase.asleep);
    }

    test('wake() holds the screen on again and says to tune the channel slept on', () async {
      await fallAsleep();
      var woke = 0;
      sleep.woke.addListener(() => woke++);
      fa.run((_) => sleep.wake(by: 'key Enter'));
      fa.flushMicrotasks();
      expect(sleep.phase, SleepPhase.idle);
      expect(screenOn, [false, true]);
      expect(woke, 1);
      expect(app.asleep, isFalse);
      expect(sleep.sleptOn?.id, app.channels.first.id);
      expect(sleep.choice, SleepChoice.off);
    });

    test('Android hiding the app turns an armed timer off, with no toast', () async {
      await tuneIntoShow(app.channels.first);
      choose(const SleepChoice.after(15));
      cancel('hidden');
      expect(sleep.phase, SleepPhase.idle);
      expect(messages, ['Sleep in 15 min']);
      advance(const Duration(minutes: 20));
      expect(sleep.phase, SleepPhase.idle);
    });

    test('hiding while asleep ends the sleep without tuning', () async {
      await fallAsleep();
      var woke = 0;
      sleep.woke.addListener(() => woke++);
      cancel('hidden');
      expect(sleep.phase, SleepPhase.idle);
      expect(screenOn, [false, true]);
      expect(woke, 0);
      expect(app.asleep, isFalse);
    });
  });
}
