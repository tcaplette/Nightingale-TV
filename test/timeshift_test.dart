import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'media_files.dart';

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakeClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;

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
    dir = await Directory.systemTemp.createTemp('nightingale_tv_timeshift');
    app = await signedInApp(dir, library);
    log = [];
    client = FakeClient(log);
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();
  Future<void> debounced() => Future<void>.delayed(Tuner.seekDebounce + const Duration(milliseconds: 60));
  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)! as ChannelSchedule;
  Channel first() => app.channels.first;

  /// A program part at least [length] long, from the time on.
  ScheduledProgram longPart(Channel ch, {Duration length = const Duration(minutes: 5)}) {
    final s = scheduleOf(ch);
    var seg = s.playbackAt(now);
    for (var i = 0; i < 400; i++) {
      if (!seg.isBreak && seg.item != null && !seg.isCommercial && seg.duration >= length) return seg;
      seg = s.playbackAt(seg.end);
    }
    throw StateError('no part found');
  }

  /// Tunes [offset] into a long part, at the live point.
  Future<ScheduledProgram> tuneInto(Channel ch, {Duration offset = const Duration(minutes: 2)}) async {
    final part = longPart(ch);
    now = part.start.add(offset);
    await tuner.tune(ch);
    await settle();
    expect(tuner.status, TunerStatus.playing);
    return part;
  }

  group('pause and resume', () {
    test('a short pause holds the viewing time, and resumes the same open behind by the time paused', () async {
      final part = await tuneInto(first());
      final at = now;
      final opens = player.opens.length;
      await tuner.pause();
      expect(tuner.paused, isTrue);
      expect(player.paused, isTrue);
      now = now.add(const Duration(seconds: 45));
      expect(tuner.viewNow(), at, reason: 'stands still');
      expect(tuner.behind, const Duration(seconds: 45));
      await tuner.resume();
      await settle();
      expect(tuner.paused, isFalse);
      expect(player.paused, isFalse);
      expect(player.opens.length, opens, reason: 'the same stream goes on');
      expect(tuner.behind, const Duration(seconds: 45));
      expect(tuner.viewNow(), at);
      expect(tuner.segmentEndsAt, part.end, reason: 'on the viewing timeline');
    });

    test('a long pause reopens exactly where it was, with no channel number', () async {
      final part = await tuneInto(first());
      final at = now;
      await tuner.pause();
      now = now.add(const Duration(minutes: 20));
      final seen = <bool>[];
      tuner.addListener(() => seen.add(tuner.changingChannel));
      await tuner.resume();
      await settle();
      final open = player.opens.last;
      expect(open.start, part.positionAt(at));
      expect(open.exact, isTrue);
      expect(seen, isNot(contains(true)));
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.behind, const Duration(minutes: 20));
    });

    test('a paused transcode stops its job, and the resume starts a new one at that place', () async {
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
      final part = await tuneInto(first());
      final at = now;
      tuner.pausedJobStop = const Duration(milliseconds: 20);
      await tuner.pause();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(client.stopped, hasLength(1));
      expect(tuner.status, TunerStatus.playing, reason: 'the picture stays');
      now = now.add(const Duration(minutes: 1));
      final opens = player.opens.length;
      await tuner.resume();
      await settle();
      expect(player.opens.length, opens + 1);
      expect(player.opens.last.url.path, endsWith('/stream.ts'));
      expect(player.opens.last.url.queryParameters['StartTimeTicks'],
          '${part.positionAt(at).inMicroseconds * 10}');
    });

    test('a resume that fails reopens once before it counts', () async {
      await tuneInto(first());
      await tuner.pause();
      now = now.add(const Duration(seconds: 10));
      player.failResume = true;
      final opens = player.opens.length;
      await tuner.resume();
      await settle();
      expect(player.opens.length, opens + 1);
      expect(tuner.status, TunerStatus.playing);
    });

    test('a stream that errors after the resume reopens rather than failing', () async {
      await tuneInto(first());
      await tuner.pause();
      now = now.add(const Duration(seconds: 10));
      await tuner.resume();
      final opens = player.opens.length;
      player.failNow();
      await settle();
      expect(player.opens.length, opens + 1);
      expect(tuner.status, TunerStatus.playing);
    });

    test('a stream that gives up while paused only reopens at the resume', () async {
      await tuneInto(first());
      await tuner.pause();
      player.failNow();
      await settle();
      expect(tuner.status, TunerStatus.playing);
      final opens = player.opens.length;
      now = now.add(const Duration(seconds: 5));
      await tuner.resume();
      await settle();
      expect(player.opens.length, opens + 1);
    });

    test('only what is playing pauses', () async {
      player.onOpen = (_) => OpenResult.hangs;
      await tuner.tune(first());
      await settle();
      expect(tuner.status, TunerStatus.tuning);
      await tuner.pause();
      expect(tuner.paused, isFalse);
    });

    test('paused, the hand-over waits, and what was preloaded is dropped', () async {
      tuner.preload = true;
      final part = await tuneInto(first());
      now = part.end.subtract(const Duration(seconds: 10));
      await tuner.tune(first());
      await settle();
      await pumpEventQueue(times: 50);
      expect(player.queued, isNotNull);
      await tuner.pause();
      await settle();
      expect(player.queued, isNull);
      expect(tuner.preloadedSegment, isNull);
      await tuner.debugSegmentEnded();
      expect(tuner.segment!.start, part.start, reason: 'still the same part');
    });
  });

  group('seeking', () {
    test('three presses make one seek, 90 s later, shown at once', () async {
      final part = await tuneInto(first());
      await tuner.oneMinuteBehind();
      await debounced();
      await settle();
      expect(tuner.behind, const Duration(minutes: 1), reason: 'test set-up: a minute behind, in the part');
      player.seeks.clear();
      final from = tuner.viewNow();
      // Back further, then three forward.
      tuner.skip(const Duration(seconds: -10));
      tuner.skip(const Duration(seconds: 30));
      tuner.skip(const Duration(seconds: 30));
      expect(tuner.seekTarget, from.add(const Duration(seconds: 50)));
      expect(player.seeks, isEmpty);
      await debounced();
      await settle();
      expect(player.seeks, [part.positionAt(from.add(const Duration(seconds: 50)))]);
      expect(tuner.seekTarget, isNull);
    });

    test('inside the segment it seeks and re-arms; no new open', () async {
      final part = await tuneInto(first());
      final opens = player.opens.length;
      tuner.skip(const Duration(seconds: -10));
      await debounced();
      await settle();
      expect(player.opens.length, opens);
      expect(player.seeks, [part.positionAt(now.subtract(const Duration(seconds: 10)))]);
      expect(tuner.behind, const Duration(seconds: 10));
      expect(tuner.segmentEndsAt, part.end);
      expect(tuner.shifted, isTrue);
    });

    test('into another program it opens exactly, with no channel number', () async {
      final ch = first();
      final part = await tuneInto(ch, offset: const Duration(minutes: 2));
      final before = scheduleOf(ch).playbackAt(part.start.subtract(const Duration(seconds: 30)));
      final seen = <bool>[];
      tuner.addListener(() => seen.add(tuner.changingChannel));
      tuner.seekTo(part.start.subtract(const Duration(seconds: 30)));
      await debounced();
      await settle();
      expect(tuner.segment!.item!.id, before.item!.id);
      expect(player.opens.last.exact, isTrue);
      expect(seen, isNot(contains(true)));
    });

    test('forward stops at the live point, which is LIVE again', () async {
      final part = await tuneInto(first());
      tuner.skip(const Duration(seconds: -20));
      await debounced();
      await settle();
      expect(tuner.shifted, isTrue);
      tuner.skip(const Duration(seconds: 30));
      expect(tuner.seekTarget, now);
      await debounced();
      await settle();
      expect(tuner.shifted, isFalse);
      expect(tuner.behind, Duration.zero);
      expect(player.seeks.last, part.positionAt(now));
    });

    test('back stops at the start of the window', () async {
      await tuneInto(first());
      for (var i = 0; i < 300; i++) {
        tuner.skip(const Duration(seconds: -60));
      }
      expect(tuner.seekTarget, tuner.earliestView());
      await debounced();
      await settle();
    });

    test('a viewer earlier than the window is not moved forward by skipping back', () async {
      await tuneInto(first());
      await tuner.pause();
      now = now.add(const Duration(hours: 2));
      await tuner.resume();
      await settle();
      final view = tuner.viewNow();
      expect(view.isBefore(tuner.earliestView()), isTrue);
      tuner.skip(const Duration(seconds: -10));
      expect(tuner.seekTarget!.isAfter(view), isFalse);
      await debounced();
    });

    test('seeking while paused stays paused, and shows the new place at the resume', () async {
      final part = await tuneInto(first());
      await tuner.pause();
      final at = tuner.viewNow();
      tuner.skip(const Duration(seconds: -30));
      await debounced();
      await settle();
      expect(tuner.paused, isTrue);
      expect(tuner.viewNow(), at.subtract(const Duration(seconds: 30)));
      expect(player.seeks.last, part.positionAt(tuner.viewNow()));
      expect(player.paused, isTrue);
    });

    test('a seek into another segment while paused holds at its first picture', () async {
      final part = await tuneInto(first());
      await tuner.pause();
      tuner.seekTo(part.start.subtract(const Duration(seconds: 30)));
      await debounced();
      await settle();
      expect(tuner.paused, isTrue);
      expect(tuner.status, TunerStatus.playing);
      expect(player.paused, isTrue);
    });

    test('the held step is 60 s, either way', () {
      expect(transportStep(forward: true, heldFor: Duration.zero), const Duration(seconds: 30));
      expect(transportStep(forward: false, heldFor: const Duration(seconds: 1)), const Duration(seconds: -10));
      expect(transportStep(forward: true, heldFor: const Duration(seconds: 3)), const Duration(seconds: 60));
      expect(transportStep(forward: false, heldFor: const Duration(seconds: 3)), const Duration(seconds: -60));
    });
  });

  group('restart and go live', () {
    test('a program with no breaks restarts at its slot, however long ago', () async {
      final part = await tuneInto(first(), offset: const Duration(minutes: 4));
      await tuner.restart();
      await settle();
      expect(tuner.viewNow(), part.start);
      expect(player.seeks.last, part.itemFrom);
    });

    test('restart goes past the pre-roll, and from a break to the program it belongs to', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = first();
      final s = scheduleOf(ch);
      // A mid-roll: its program's first picture is behind it. (In a
      // pre-roll the first picture is still ahead of live.)
      bool midRoll(ScheduledProgram seg) =>
          seg.isBreak &&
          seg.isCommercial &&
          seg.program != null &&
          seg.start.isAfter(now) &&
          s.firstPictureOf(s.programAt(seg.start)).isBefore(seg.start);
      var seg = s.playbackAt(now);
      for (var i = 0; i < 400 && !midRoll(seg); i++) {
        seg = s.playbackAt(seg.end);
      }
      expect(seg.isBreak, isTrue);
      now = seg.start.add(const Duration(seconds: 2));
      await tuner.tune(ch);
      await settle();
      expect(tuner.inBreak, isTrue);
      final slot = s.programAt(now);
      final first_ = s.firstPictureOf(slot);
      await tuner.restart();
      await settle();
      expect(tuner.viewNow(), first_);
      expect(tuner.segment!.isBreak, isFalse, reason: 'the first picture of the show');
      expect(tuner.segment!.item!.id, slot.item!.id);
    });

    test('restart while paused plays', () async {
      final part = await tuneInto(first());
      await tuner.pause();
      await tuner.restart();
      await settle();
      expect(tuner.paused, isFalse);
      expect(player.paused, isFalse);
      expect(tuner.viewNow(), part.start);
    });

    test('Live returns to what is airing, and drops a pending seek', () async {
      await tuneInto(first());
      tuner.skip(const Duration(seconds: -60));
      await debounced();
      await settle();
      await tuner.goLive();
      await settle();
      expect(tuner.shifted, isFalse);
      expect(tuner.viewNow(), now);
      tuner.skip(const Duration(seconds: -60));
      await tuner.goLive();
      await debounced();
      expect(tuner.shifted, isFalse);
      expect(tuner.seekTarget, isNull);
    });
  });

  group('window, floor and limit', () {
    test('a short program can be rewound 30 minutes, into the one before it', () async {
      await tuneInto(first(), offset: const Duration(minutes: 5));
      expect(tuner.earliestView(), now.subtract(const Duration(minutes: 30)));
    });

    test('a schedule change keeps the viewer in the slot on air then', () async {
      final ch = first();
      final part = await tuneInto(ch, offset: const Duration(minutes: 5));
      app.debugScheduleChanged(ch.id, now.subtract(const Duration(minutes: 1)));
      expect(tuner.earliestView(), part.start, reason: 'restart still works, nothing before');
      app.debugScheduleChanged(ch.id, null);
    });

    test('a change after the viewer pinned the schedule does not limit them', () async {
      final ch = first();
      await tuneInto(ch, offset: const Duration(minutes: 5));
      tuner.skip(const Duration(seconds: -30));
      await debounced();
      now = now.add(const Duration(minutes: 1));
      app.debugScheduleChanged(ch.id, now);
      expect(tuner.earliestView(), now.subtract(const Duration(minutes: 30)));
      app.debugScheduleChanged(ch.id, null);
    });

    test('resuming a pause over 4 hours old goes live with a notice', () async {
      await tuneInto(first());
      final notices = <String>[];
      final sub = tuner.notices.listen(notices.add);
      await tuner.pause();
      now = now.add(const Duration(hours: 5));
      await tuner.resume();
      await settle();
      expect(tuner.shifted, isFalse);
      expect(tuner.paused, isFalse);
      expect(notices, [Tuner.backToLiveNotice]);
      await sub.cancel();
    });
  });

  group('what ends a shift', () {
    Future<void> behind(Channel ch) async {
      await tuneInto(ch);
      tuner.skip(const Duration(seconds: -60));
      await debounced();
      await settle();
      expect(tuner.shifted, isTrue);
    }

    test('tuning ends it, and coming back is at the live point', () async {
      final a = app.channels[0], b = app.channels[1];
      await behind(a);
      await tuner.tune(b);
      await settle();
      expect(tuner.shifted, isFalse);
      await tuner.tune(a);
      await settle();
      expect(tuner.shifted, isFalse);
      expect(tuner.viewNow(), now);
    });

    test('while behind the schedule is pinned; reschedule leaves it alone', () async {
      final ch = first();
      await behind(ch);
      final pinned = tuner.schedule;
      final opens = player.opens.length, seeks = player.seeks.length;
      await app.setGlobalPlan(BreakPlan.automatic, now: now);
      await tuner.reschedule();
      await settle();
      expect(identical(tuner.schedule, pinned), isTrue);
      expect(identical(app.scheduleFor(ch), pinned), isFalse, reason: 'the guide has the new one');
      expect(player.opens.length, opens);
      expect(player.seeks.length, seeks);
      await tuner.goLive();
      await settle();
      expect(identical(tuner.schedule, app.scheduleFor(ch)), isTrue, reason: 'going live shows the new schedule');
    });

    test('public retune ends it', () async {
      await behind(first());
      await tuner.retune();
      await settle();
      expect(tuner.shifted, isFalse);
    });

    test('rebuilding the Android player for leveling keeps it', () async {
      PlatformInfo.debugOverride = TargetPlatform.android;
      addTearDown(PlatformInfo.debugReset);
      await behind(first());
      final at = tuner.behind;
      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      await settle();
      expect(tuner.behind, at);
    });

    test('a shifted open that fails goes live and says so', () async {
      final part = await tuneInto(first());
      final notices = <String>[];
      final sub = tuner.notices.listen(notices.add);
      var failing = true;
      player.onOpen = (_) {
        if (failing) {
          failing = false;
          return OpenResult.errors;
        }
        return OpenResult.plays;
      };
      tuner.seekTo(part.start.subtract(const Duration(seconds: 30)));
      await debounced();
      await settle();
      expect(notices, [Tuner.couldntPlayNotice]);
      expect(tuner.shifted, isFalse);
      expect(tuner.status, TunerStatus.playing);
      await sub.cancel();
    });

    test('turning the setting off goes live', () async {
      await behind(first());
      await app.setPlayback(const PlaybackSettings(pauseAndRewind: false));
      await settle();
      expect(tuner.shifted, isFalse);
      expect(tuner.canTimeshift, isFalse);
      tuner.skip(const Duration(seconds: -10));
      expect(tuner.seekTarget, isNull);
    });
  });

  group('returning to the app', () {
    test('a viewer behind returns to the same place, paused if they were', () async {
      final ch = first();
      await tuneInto(ch);
      tuner.skip(const Duration(seconds: -60));
      await debounced();
      await settle();
      await tuner.pause();
      final place = tuner.place!;
      final at = tuner.viewNow();
      await tuner.stop();
      expect(tuner.shifted, isFalse);
      now = now.add(const Duration(minutes: 10));
      await tuner.tune(ch, at: place);
      await settle();
      expect(tuner.viewNow(), at);
      expect(tuner.paused, isTrue);
      expect(player.paused, isTrue);
      expect(player.opens.last.exact, isTrue);
    });

    test('a viewer at the live point has no place to return to', () async {
      await tuneInto(first());
      expect(tuner.place, isNull);
    });

    test('over 4 hours later they come back live', () async {
      final ch = first();
      await tuneInto(ch);
      await tuner.pause();
      final place = tuner.place!;
      await tuner.stop();
      now = now.add(const Duration(hours: 5));
      await tuner.tune(ch, at: place);
      await settle();
      expect(tuner.shifted, isFalse);
    });
  });

  group('reports', () {
    test('a pause says so at once, at the paused position, and rewinding never lowers reached', () async {
      final part = await tuneInto(first());
      client.reports.clear();
      await tuner.pause();
      await settle();
      final paused = client.reports.last;
      expect(paused.$1, 'progress');
      expect(paused.$2.isPaused, isTrue);
      expect(paused.$2.position, part.positionAt(tuner.viewNow()));
      now = now.add(const Duration(seconds: 5));
      await tuner.resume();
      await settle();
      expect(client.reports.last.$2.isPaused, isFalse);
    });

    test('rewinding across the viewing keeps how far it got', () async {
      final ch = first();
      final part = await tuneInto(ch, offset: const Duration(minutes: 4));
      player.position = part.positionAt(now);
      tuner.seekTo(part.start);
      await debounced();
      await settle();
      // A stop now reports position 0 or further: never a lowered "watched".
      await tuner.stop();
      final stopped = client.reports.where((r) => r.$1 == 'stopped').toList();
      expect(stopped.single.$2.position, Duration.zero, reason: 'a partial viewing reports 0, as surfing does');
    });
  });

  group('the viewing clock', () {
    test('handover, preload and a keyframe join work on the viewing timeline', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      tuner.preload = true;
      final ch = first();
      final s = scheduleOf(ch);
      // A part a break follows.
      var part = s.playbackAt(now);
      for (var i = 0; i < 400 && (part.isBreak || !s.playbackAt(part.end).isBreak || part.duration < const Duration(minutes: 3)); i++) {
        part = s.playbackAt(part.end);
      }
      now = part.start.add(const Duration(minutes: 1));
      player.keyframeEarly = const Duration(seconds: 3);
      await tuner.tune(ch);
      await settle();
      expect(tuner.segmentEndsAt, part.end.add(const Duration(seconds: 3)), reason: 'keyframe correction');
      // Now five minutes behind, and 20 s from the part's end on the viewing clock.
      final view = part.end.subtract(const Duration(seconds: 20));
      now = view.add(const Duration(minutes: 5));
      tuner.seekTo(view);
      await debounced();
      await settle();
      await pumpEventQueue(times: 50);
      expect(tuner.segmentEndsAt, part.end, reason: 'a seek drops the correction');
      expect(tuner.behind.inSeconds, closeTo(300, 1));
      expect(player.queued, isNotNull, reason: 'preloaded against the viewing time');
      final opens = player.opens.length;
      final next = s.playbackAt(part.end);
      now = next.start.add(tuner.behind);
      await tuner.debugSegmentEnded();
      await settle();
      expect(player.opens.length, opens, reason: 'a seamless hand-over');
      expect(tuner.segment!.start, next.start);
      expect(tuner.inBreak, isTrue);
    });

    test('a viewer who never touches the controls stays on the clock', () async {
      final part = await tuneInto(first());
      expect(tuner.viewNow(), now);
      expect(tuner.shifted, isFalse);
      expect(tuner.segmentEndsAt, part.end);
      expect(identical(tuner.schedule, app.scheduleFor(first())), isTrue);
    });

    test('live channels have no timeshift', () {
      expect(tuner.canTimeshift, isFalse, reason: 'nothing tuned');
    });
  });

  group('mpv, real files', () {
    late MediaKitTunerPlayer mpv;
    late File file;

    setUpAll(() async {
      MediaKit.ensureInitialized();
    });

    setUp(() async {
      file = (await testVideos()).faststart;
      mpv = MediaKitTunerPlayer(video: false);
    });

    tearDown(() => mpv.dispose());

    Future<void> until(bool Function() ok, String what) async {
      for (var i = 0; i < 200 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(ok(), isTrue, reason: what);
    }

    test('pause holds the position, a seek lands within 0.5 s, and the end clip still stops', () async {
      final done = Completer<void>();
      final sub = mpv.completedStream.listen((c) {
        if (c && !done.isCompleted) done.complete();
      });
      await mpv.open(file.uri, headers: const {}, start: const Duration(seconds: 2), end: const Duration(seconds: 12));
      await until(() => mpv.position >= const Duration(seconds: 3), 'plays');
      await mpv.pause();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final held = mpv.position;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(mpv.position, held, reason: 'pause holds');
      await mpv.seek(const Duration(seconds: 9));
      await until(() => (mpv.position - const Duration(seconds: 9)).abs() < const Duration(milliseconds: 500), 'lands');
      await mpv.resume();
      await done.future.timeout(const Duration(seconds: 15));
      expect(mpv.position, lessThan(const Duration(seconds: 12, milliseconds: 500)));
      await sub.cancel();
    }, timeout: const Timeout(Duration(minutes: 1)));
  }, skip: Platform.isLinux && Platform.environment.containsKey('NIGHTINGALE_NO_MPV'));
}

extension on Tuner {
  /// Skips one minute back.
  Future<void> oneMinuteBehind() async => skip(const Duration(seconds: -60));
}
