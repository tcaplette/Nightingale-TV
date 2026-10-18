import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/reel_cutter.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  final library = fakeLibrary(
    shows: {'Alpha': 30, 'Beta': 30, 'Gamma': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_ads'));
  tearDown(() => dir.delete(recursive: true));

  group('upgrading from before break plans', () {
    test('breaks on with two libraries become one pool and the old-behavior plan', () async {
      final app = await signedInApp(dir, library,
          settings: {
            'installId': 'nightingaletv-abc',
            'commercialsEnabled': true,
            'commercialLibraryIds': ['libA', 'libB'],
          },
          editChannels: (channels) => channels.first['commercials'] = false);
      expect(app.settings.commercialPlan, BreakPlan.legacy);
      final pool = app.settings.commercialPools.single;
      expect(pool.name, 'Commercials');
      expect([for (final r in pool.roots) r.itemId], ['libA', 'libB']);
      expect(pool.roots.every((r) => r.isWholeLibrary), isTrue);
      expect(app.allChannels.first.commercialPlan, BreakPlan.off, reason: '"Always off" becomes Off');
      expect(app.allChannels[1].commercialPlan, isNull, reason: 'the rest follow the main setting');

      // Saved in the new format, with the old keys kept for a downgrade.
      final saved = await app.storage.readJson('settings.json') as Map<String, Object?>;
      expect(saved['commercialPlan'], BreakPlan.legacy.toJson());
      expect(saved['commercialsEnabled'], isTrue);
      expect(saved['commercialLibraryIds'], ['libA', 'libB']);
      expect(app.allChannels.first.toJson()['commercials'], isFalse);

      // Loading again gives the same pool (the same id every time).
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.commercialPools.single.id, pool.id);
      expect(again.settings.commercialPlan, BreakPlan.legacy);
    });

    test('"Always on" becomes a channel plan of the old behavior', () async {
      final app = await signedInApp(dir, library,
          settings: {'installId': 'nightingaletv-abc', 'commercialsEnabled': false, 'commercialLibraryIds': []},
          editChannels: (channels) => channels.first['commercials'] = true);
      expect(app.settings.commercialPlan, BreakPlan.off);
      expect(app.settings.commercialPools, isEmpty);
      expect(app.allChannels.first.commercialPlan, BreakPlan.legacy);
    });

    test('a fresh install has breaks off and no pools', () async {
      final app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 30}));
      expect(app.settings.commercialPlan, BreakPlan.off);
      expect(app.settings.commercialPools, isEmpty);
      expect(app.allChannels.every((c) => c.commercialPlan == null), isTrue);
    });
  });

  group('pools', () {
    test('new pools get the next free name and survive a restart', () async {
      final app = await signedInApp(dir, library);
      final second = await app.createPool();
      expect(app.settings.commercialPools.map((p) => p.name), ['Commercials', 'Commercials 2']);
      await app.renamePool(second, '  Bumpers ');
      expect(second.name, 'Bumpers');
      await app.renamePool(second, '   ');
      expect(second.name, 'Bumpers', reason: 'a blank name is ignored');
      final third = await app.createPool();
      expect(third.name, 'Commercials 2');
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.commercialPools.map((p) => p.name), ['Commercials', 'Bumpers', 'Commercials 2']);
    });

    test('deleting a pool a plan uses switches that role to all pools', () async {
      final app = await signedInApp(dir, library);
      final bumpers = await app.createPool();
      final roles = const CustomRoles(midInterval: Duration(minutes: 10), preRoll: Duration(seconds: 15))
          .withPool(BreakRole.mid, bumpers.id)
          .withPool(BreakRole.pre, fakePoolId);
      await app.setGlobalPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
      final ch = app.allChannels.first;
      await app.setChannelPlan(ch, BreakPlan(mode: BreakMode.custom, roles: roles));
      await app.deletePool(bumpers);
      expect(app.settings.commercialPools.map((p) => p.id), [fakePoolId]);
      expect(app.settings.commercialPlan.roles.midPool, isNull);
      expect(app.settings.commercialPlan.roles.prePool, fakePoolId, reason: 'other roles keep their pool');
      expect(ch.commercialPlan!.roles.midPool, isNull);
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.commercialPlan.roles.midPool, isNull);
      expect(again.allChannels.first.commercialPlan!.roles.midPool, isNull);
    });

    test('changing a pool\'s folders re-scans the library', () async {
      final app = await signedInApp(dir, library);
      final pool = app.settings.commercialPools.single;
      var scans = 0;
      app.addListener(() {
        if (app.refreshing) scans++;
      });
      await app.setPoolRoots(pool, const [PoolRoot(itemId: 'f1', libraryId: 'lib', label: 'Lib › Ads')]);
      for (var i = 0; i < 40 && (app.refreshing || scans == 0); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(scans, greaterThan(0));
      // The test server can't be reached; the cached lineup stays on.
      expect(app.phase, AppPhase.ready);
      expect(app.syncError, isNotNull);
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.commercialPools.single.roots.single.label, 'Lib › Ads');
    });
  });

  group('plans', () {
    bool onBoundary(DateTime t, int minutes) =>
        t.minute % minutes == 0 && t.second == 0 && t.millisecond == 0 && t.microsecond == 0;

    test('breaks are off by default', () async {
      final app = await signedInApp(dir, library);
      expect(app.settings.commercialPlan, BreakPlan.off);
      expect(app.channels.every((c) => !app.breaksFor(c)), isTrue);
    });

    test('Off to Automatic keeps the episode on air and puts later slots on :00 and :30', () async {
      // Whatever the time, the episode on air stays on air.
      final app = await signedInApp(dir, library);
      final now = DateTime.now();
      final before = {for (final ch in app.channels) ch.id: app.scheduleFor(ch)!.playbackAt(now)};
      await app.setGlobalPlan(BreakPlan.automatic);
      for (final ch in app.channels) {
        expect(app.breaksFor(ch), isTrue);
        final schedule = app.scheduleFor(ch)!;
        final was = before[ch.id]!;
        final slot = schedule.programAt(now);
        expect(slot.item!.id, was.item!.id, reason: '${ch.name}: the same episode stays on air');
        // Lined up on the clock: the nearest boundary (at most 15 minutes
        // away), or the other one when the nearest would take the episode
        // off the air.
        final shift = slot.layoutStart.difference(now.subtract(was.positionAt(now))).abs();
        expect(shift, lessThan(const Duration(minutes: 30)));
        for (final p in schedule.programsBetween(slot.end, now.add(const Duration(hours: 4)))) {
          expect(onBoundary(p.start, 30), isTrue, reason: '${ch.name} ${p.title} starts ${p.start}');
        }
      }
      final reloaded = AppState(app.storage);
      await reloaded.start();
      expect(reloaded.settings.commercialPlan, BreakPlan.automatic);
      expect(onBoundary(reloaded.allChannels.first.anchor, 30), isTrue);
    });

    test('with no tail, the anchor stays put', () async {
      final app = await signedInApp(dir, library);
      final ch = app.channels.first;
      final now = DateTime.now();
      final before = app.scheduleFor(ch)!.playbackAt(now);
      const noTail = BreakPlan(mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 10)));
      await app.setGlobalPlan(noTail);
      final after = app.scheduleFor(ch)!.playbackAt(now);
      if (!after.isBreak) {
        expect(after.item!.id, before.item!.id);
        expect((after.positionAt(now) - before.positionAt(now)).abs(), lessThan(const Duration(seconds: 1)),
            reason: 'nothing to line up on, so the show keeps its exact position');
      }
    });

    test('turning breaks off keeps the show on air where it was', () async {
      final app = await signedInApp(dir, library);
      await app.setGlobalPlan(BreakPlan.legacy);
      final ch = app.channels.first;
      final now = DateTime.now();
      final before = app.scheduleFor(ch)!.playbackAt(now);
      await app.setGlobalPlan(BreakPlan.off);
      final after = app.scheduleFor(ch)!.playbackAt(now);
      // During a break there's no show position to keep.
      if (!before.isBreak) {
        expect(after.item!.id, before.item!.id);
        expect((after.positionAt(now) - before.positionAt(now)).abs(), lessThan(const Duration(seconds: 1)));
      }
    });

    test('a channel can have its own plan', () async {
      final app = await signedInApp(dir, library);
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      await app.setChannelPlan(ch, BreakPlan.off);
      expect(app.breaksFor(ch), isFalse);
      expect(app.breaksFor(app.channels[1]), isTrue);
      expect(app.settings.commercialPlan, BreakPlan.automatic, reason: 'the main plan is unchanged');
      const custom = BreakPlan(mode: BreakMode.custom, roles: CustomRoles(midInterval: Duration(minutes: 8)));
      await app.setChannelPlan(ch, custom);
      expect(app.planFor(ch), custom);
      expect(app.planFor(app.channels[1]), BreakPlan.automatic);
      await app.setChannelPlan(ch, null);
      expect(app.planFor(ch), BreakPlan.automatic);
      final reloaded = AppState(app.storage);
      await reloaded.start();
      expect(reloaded.allChannels.first.commercialPlan, isNull);
    });

    test('without clips, a plan airs as Off', () async {
      final noAds = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 30, 'Beta': 30}));
      await noAds.setGlobalPlan(BreakPlan.automatic);
      expect(noAds.channels.every((c) => !noAds.breaksFor(c)), isTrue);
      expect(noAds.configuredPlanFor(noAds.channels.first), BreakPlan.automatic);
    });

    test('a plan whose pools have no clips airs as Off', () async {
      final app = await signedInApp(dir, library);
      final empty = await app.createPool();
      final plan = BreakPlan(
          mode: BreakMode.custom,
          roles: const CustomRoles(midInterval: Duration(minutes: 10)).withPool(BreakRole.mid, empty.id));
      await app.setGlobalPlan(plan);
      expect(app.breaksFor(app.channels.first), isFalse);
      expect(app.hasClipsFor(plan), isFalse);
    });

    test('the first clips arriving rebase the channels without the episode jumping', () async {
      // The only commercial is a 2-hour reel, not analyzed yet.
      final reelOnly = fakeLibrary(
        shows: {'Alpha': 30, 'Beta': 30},
        genres: {
          'Alpha': ['Comedy'],
          'Beta': ['Comedy'],
        },
        commercials: const [Duration(hours: 2)],
      );
      final app = await signedInApp(dir, reelOnly, serverId: 'srv-test');
      await app.setGlobalPlan(BreakPlan.automatic);
      expect(app.breaksFor(app.channels.first), isFalse, reason: 'no clips yet');
      final now = DateTime.now();
      final before = {for (final ch in app.channels) ch.id: app.scheduleFor(ch)!.playbackAt(now)};

      final reel = app.library.commercials.single;
      app.analysisCache!.recordReel(
          reel, ReelCuts(CutSource.detection, [for (var i = 0; i < 20; i++) Span(Duration(seconds: i * 30), Duration(seconds: i * 30 + 29))]),
          at: now);
      expect(app.catalog.clipsFor(null), hasLength(20));
      for (final ch in app.channels) {
        expect(app.breaksFor(ch), isTrue);
        final slot = app.scheduleFor(ch)!.programAt(now);
        expect(slot.item!.id, before[ch.id]!.item!.id, reason: '${ch.name}: still the same episode');
        expect(onBoundary(slot.end, 30), isTrue);
      }
      // Saved (right away, with the rebased lineup), so a restart shows the
      // same thing.
      await app.analysisCache!.flush();
      final reloaded = AppState(app.storage, runAnalysis: false);
      await reloaded.start();
      expect(reloaded.breaksFor(reloaded.channels.first), isTrue);
      expect(reloaded.scheduleFor(reloaded.channels.first)!.programAt(now).start,
          app.scheduleFor(app.channels.first)!.programAt(now).start);
      await reloaded.close();
      await app.close();
    });

    test('breaks airing now keep their clips when new ones arrive', () async {
      final app = await signedInApp(dir, library, serverId: 'srv-test');
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final now = DateTime.now();
      ScheduledProgram? breakNow;
      for (var t = now; t.isBefore(now.add(const Duration(hours: 1))); t = t.add(const Duration(seconds: 20))) {
        final p = app.scheduleFor(ch)!.playbackAt(t);
        if (p.isCommercial && p.start.isAfter(now)) {
          breakNow = p;
          break;
        }
      }
      expect(breakNow, isNotNull);
      expect(app.catalog.version, greaterThan(0));
      expect(app.scheduleFor(ch)!.playbackAt(breakNow!.start).item!.id, breakNow.item!.id);
      await app.close();
    });
  });

  test('lining up on the clock never takes the program on air off it, at any time', () async {
    // Every minute of an hour, as if the plan changed then.
    final app = await signedInApp(dir, library);
    final ch = app.channels.first;
    final start = DateTime(2026, 10, 17, 18);
    for (var m = 0; m < 60; m++) {
      final now = start.add(Duration(minutes: m, seconds: 17));
      ch.anchor = start.subtract(const Duration(minutes: 3));
      final off = app.scheduleFor(ch)!;
      final was = off.programAt(now).item!.id;
      await app.setChannelPlan(ch, BreakPlan.automatic, now: now);
      final on = app.scheduleFor(ch)!.programAt(now);
      expect(on.item!.id, was, reason: 'at 18:${m.toString().padLeft(2, '0')}');
      expect(ch.anchor.minute % 30, 0);
      await app.setChannelPlan(ch, null, now: now);
    }
  });
}
