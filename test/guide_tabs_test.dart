import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;
  late Tuner tuner;

  // Comedies, two TV-Y kids' shows (a Kids Zone channel), movies and songs.
  final library = fakeLibrary(
    shows: const {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: const {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Kids'],
      'Delta': ['Kids'],
    },
    ratings: const {'Alpha': 'TV-14', 'Beta': 'TV-PG', 'Gamma': 'TV-Y', 'Delta': 'TV-Y'},
    movies: 6,
    songs: fakeMusic(200),
  );

  Future<void> show(WidgetTester tester,
      {String? savedTab, int? maxRatingRank, void Function(AppState app)? setUp}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_guide_tabs');
      app = await signedInApp(dir, library, maxRatingRank: maxRatingRank);
      app.client = FakeClient([]);
      // One favorite.
      await app.updateChannel(app.channels[1], favorite: true);
      if (savedTab != null) await app.setGuideTab(savedTab);
      setUp?.call(app);
    });
    tuner = Tuner(app, player: FakePlayer([]))
      ..prefetch = false
      ..preload = false;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: AppScope(
        app: app,
        tuner: tuner,
        child: TvCanvas(child: GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {})),
      ),
    ));
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        // Saves started in the test's fake time can't be waited for here.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The channel names in the grid, top to bottom (a music channel's
  /// guide cells carry its name too).
  List<String> grid(WidgetTester tester) {
    final names = {for (final c in app.channels) c.name};
    return {
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (names.contains(t.data)) t.data!,
    }.toList();
  }

  testWidgets('the tabs: All, Favorites, Movies, Music, Kids', (tester) async {
    await show(tester);
    expect([for (final t in app.guideTabs()) t.name], ['All', 'Favorites', 'Movies', 'Music', 'Kids']);
    expect(app.guideTabs().last.channels.map((c) => c.name), ['Kids Zone']);
    for (final name in ['ALL', 'FAVORITES', 'MOVIES', 'MUSIC', 'KIDS']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.textContaining('▲ Tabs'), findsOneWidget);
  });

  testWidgets('D-pad: Up to the tabs, Right selects Favorites, Movies, then Music; Down to the grid', (tester) async {
    await show(tester);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, GuideTabs.favorites);
    expect(grid(tester), [app.channels[1].name]);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, GuideTabs.movies);
    expect(grid(tester), everyElement(contains('Movie')));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, GuideTabs.music);
    expect(grid(tester), ['Music Radio']);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, GuideTabs.kids);
    // Right at the last tab stays put.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(app.settings.guideTab, GuideTabs.kids);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(app.settings.guideTab, GuideTabs.music);
    // Up again reaches the Menu button; Down comes back to the tabs, then the grid.
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(app.settings.guideTab, GuideTabs.movies, reason: 'back on the tab row');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(app.settings.guideTab, GuideTabs.movies, reason: 'Left in the grid moves in time, not tabs');
  });

  testWidgets('a mouse click and a tap select tabs', (tester) async {
    await show(tester);
    await tester.tap(find.text('MOVIES'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(app.settings.guideTab, GuideTabs.movies);
    expect(grid(tester), everyElement(contains('Movie')));
    await tester.tap(find.text('KIDS'), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(grid(tester), ['Kids Zone']);
  });

  testWidgets('the guide opens on the remembered tab', (tester) async {
    await show(tester, savedTab: GuideTabs.movies);
    expect(grid(tester), everyElement(contains('Movie')));
  });

  testWidgets('a remembered tab that is now hidden opens on All', (tester) async {
    await show(tester, savedTab: GuideTabs.music, setUp: (app) => app.settings.hiddenTabs = {GuideTabs.music});
    expect(grid(tester).first, app.channels.first.name);
    expect(find.text('MUSIC'), findsNothing);
  });

  testWidgets('Channel Up goes through every channel, whatever the tab', (tester) async {
    await show(tester, savedTab: GuideTabs.music);
    final radio = app.channels.firstWhere((c) => c.isMusic);
    final before = app.channels.lastWhere((c) => c.number < radio.number);
    await tester.runAsync(() async {
      await tuner.tune(before);
      await tuner.channelUp();
    });
    expect(tuner.channel!.id, radio.id);
    await tester.runAsync(() => tuner.channelDown());
    expect(tuner.channel!.id, before.id, reason: 'not a Music channel, but next in number');
    await tester.runAsync(tuner.stop);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('a kid profile has no Kids tab', (tester) async {
    await show(tester, maxRatingRank: 2);
    expect(app.channels.any((c) => c.name == 'Kids Zone'), isTrue);
    expect(app.guideTabs().map((t) => t.id), isNot(contains(GuideTabs.kids)));
    expect(find.text('KIDS'), findsNothing);
  });
}
