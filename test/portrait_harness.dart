import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/platform/orientation.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/sleep_timer.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/sleep_overlay.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'backup_fixtures.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

/// Phone portrait sizes (dp) the portrait layout is checked at.
const narrowPhone = Size(360, 740);
const pixel8 = Size(412, 915);
const tabletUpright = Size(800, 1280);

/// Runs as [platform] (an Android phone, unless [television]) until the
/// test ends.
void runAs(TargetPlatform platform, {bool television = false}) {
  PlatformInfo.debugOverride = platform;
  PlatformInfo.debugTelevision = television;
  addTearDown(() {
    PlatformInfo.debugReset();
    FullScreen.instance.debugReset();
  });
}

/// Makes the test window [size] dp (one pixel per dp).
void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A signed-in household of one ("Mom"), its tuner on a fake player, shown
/// the way main() shows it: scopes above the app, the canvas in its builder.
class PortraitHarness {
  PortraitHarness._(this.household, this.tuner, this._dir, this.sleep, this.screenOn);

  final Household household;
  final Tuner tuner;
  final Directory _dir;

  /// The sleep timer, when asked for, on the tuner's clock.
  final SleepTimer? sleep;

  /// What the sleep timer asked of Android's screen-on flag.
  final List<bool> screenOn;

  AppState get app => household.app!;

  /// [clock] is the tuner's (the real time by default). [sleep]: with a
  /// sleep timer, on the same clock.
  static Future<PortraitHarness> start(WidgetTester tester,
      {LibraryIndex? library, DateTime Function()? clock, bool sleep = false}) async {
    late Directory dir;
    late Household h;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_portrait');
      await writeHousehold(dir, [Profile(id: 'mom0000000000001', name: 'Mom')],
          library ?? portraitLibrary());
      h = await openHousehold(dir);
      await h.select(h.profiles.first);
      h.app!.client = FakeClient([]);
    });
    final tuner = Tuner(h.app!, player: FakePlayer([]), clock: clock)
      ..prefetch = false
      ..preload = false;
    final screenOn = <bool>[];
    final timer =
        sleep ? SleepTimer(tuner, clock: clock, keepScreenOn: (on) async => screenOn.add(on)) : null;
    final harness = PortraitHarness._(h, tuner, dir, timer, screenOn);
    addTearDown(() => harness._dispose(tester));
    return harness;
  }

  /// Shows [home] (null: nothing yet) in the app.
  Future<void> show(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(HouseholdScope(
      household: household,
      child: AppScope(
        app: app,
        tuner: tuner,
        sleep: sleep,
        child: MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          builder: (context, child) => TvCanvas(child: SleepOverlay(child: child!)),
          home: home,
        ),
      ),
    ));
    await tester.pump();
  }

  /// Stops playback and lets its timers go, at the end of a test's body.
  Future<void> end(WidgetTester tester) async {
    // No sleep timer left counting.
    if (sleep?.armed ?? false) sleep!.choose(SleepChoice.off);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(tuner.stop);
    await tester.pump(const Duration(minutes: 10));
  }

  Future<void> _dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    sleep?.dispose();
    tuner.dispose();
    await tester.runAsync(() async {
      final app = household.app;
      household.leave();
      household.backups!.dispose();
      // Writes still under way finish before the folder goes.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Bounded: a save waiting on the test's fake clock never finishes.
      await app?.storage.flush().timeout(const Duration(seconds: 2), onTimeout: () {});
      await _dir.delete(recursive: true);
    });
  }
}

/// Shows with names as long as real libraries have, in several genres, with
/// movies and music: channels in several tabs, a music channel among them.
LibraryIndex portraitLibrary() => fakeLibrary(
      shows: const {
        'The Adventures of Brisco County, Jr.': 12,
        'Star Trek: Deep Space Nine': 12,
        'Alpha': 20,
        'Beta': 20,
        'Gamma': 20,
        'Delta': 20,
      },
      genres: const {
        'The Adventures of Brisco County, Jr.': ['Western'],
        'Star Trek: Deep Space Nine': ['Science Fiction'],
        'Alpha': ['Comedy'],
        'Beta': ['Comedy'],
        'Gamma': ['Kids'],
        'Delta': ['Kids'],
      },
      ratings: const {'Gamma': 'TV-Y', 'Delta': 'TV-Y'},
      movies: 6,
      songs: fakeMusic(200),
    );
