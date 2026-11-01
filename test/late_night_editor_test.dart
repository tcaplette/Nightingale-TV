import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/blocks_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

/// The TV's late-night shortcut and minimum-rating toggles
/// (late-night-drift 3.3).
void main() {
  const shows = {'Kiddo': 4, 'Edgy': 5, 'Grown': 6};
  const ratings = {'Kiddo': 'TV-G', 'Edgy': 'TV-14', 'Grown': 'TV-MA'};

  /// Shows [home] on the TV canvas for an app on [library]; [prepare] runs
  /// on the app first. Returns the app.
  Future<AppState> show(WidgetTester tester, Widget Function() home,
      {int? maxRatingRank, Future<void> Function(AppState app)? prepare}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Directory dir;
    late AppState app;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_late_night_editor');
      app = await signedInApp(dir, fakeLibrary(shows: shows, ratings: ratings), maxRatingRank: maxRatingRank);
      await prepare?.call(app);
    });
    final tuner = Tuner(app, player: FakePlayer([]));
    await tester.pumpWidget(AppScope(
      app: app,
      tuner: tuner,
      child: MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        builder: (context, child) => TvCanvas(child: child!),
        home: home(),
      ),
    ));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir.delete(recursive: true);
      });
    });
    return app;
  }

  /// Scrolls the editor's form until [target] is built, then onto the screen.
  Future<void> revealFinder(WidgetTester tester, Finder target) async {
    // The form is the left-hand column; the summary is on the right.
    final form = Offset(TvCanvas.size.width * 0.3, TvCanvas.size.height / 2);
    for (final step in const [-300.0, 300.0]) {
      for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
        await tester.dragFrom(form, Offset(0, step));
        await tester.pumpAndSettle();
      }
    }
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String text) => revealFinder(tester, find.text(text));

  Future<void> tap(WidgetTester tester, String text) async {
    if (find.byType(BlockEditorScreen).evaluate().isNotEmpty) await reveal(tester, text);
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<bool> radioOn(WidgetTester tester, String label) async {
    await reveal(tester, label);
    return tester.widget<TvToggle>(find.widgetWithText(TvToggle, label)).on;
  }

  /// Picks the channel [name] in the channel picker.
  Future<void> pickChannel(WidgetTester tester, String name) async {
    await revealFinder(tester, find.byIcon(Icons.tv));
    await tester.tap(find.byIcon(Icons.tv).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(name), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('the shortcut opens a filled-in editor that saves an ordinary rated block', (tester) async {
    final app = await show(tester, () => const BlocksScreen(), prepare: (app) async {
      await app.createCustomChannel('Mixed', const ChannelSource(seriesKeys: ['kiddo|2000', 'grown|2000']),
          order: PlaybackOrder.weighted);
    });
    final mixed = app.channels.firstWhere((c) => c.name == 'Mixed');
    await tap(tester, 'New late-night block');
    expect(find.text('NEW LATE-NIGHT BLOCK'), findsOneWidget);
    expect(find.text('LATE NIGHT'), findsOneWidget, reason: 'the summary shows the title');
    expect(find.text('Every day  ·  11:00 PM – 4:00 AM  ·  TV-MA / R and up'), findsOneWidget);
    expect(await radioOn(tester, 'TV-MA / R and up'), isTrue);

    // Following the channel: its source and order, with the minimum.
    await pickChannel(tester, 'Mixed');
    expect(await radioOn(tester, PlaybackOrder.weighted.label), isTrue);
    await tap(tester, 'Save');
    for (var i = 0; i < 20 && find.text('Save').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final block = app.blocks.single;
    expect((block.title, block.channelId, block.order), ('Late Night', mixed.id, PlaybackOrder.weighted));
    expect(block.source.seriesKeys, ['kiddo|2000', 'grown|2000']);
    expect(block.source.ratingFloor, RatingFloor.mature);
    expect(block.playlist.toSet(), {for (var i = 1; i <= 6; i++) 'Grown-e$i'});
  });

  testWidgets('a chosen order stops the editor following the channel', (tester) async {
    final app = await show(tester, () => const BlockEditorScreen(lateNight: true), prepare: (app) async {
      await app.createCustomChannel('Mixed', const ChannelSource(seriesKeys: ['grown|2000']), order: PlaybackOrder.weighted);
    });
    expect(app.channels, isNotEmpty);
    await tap(tester, PlaybackOrder.random.label);
    await pickChannel(tester, 'Mixed');
    expect(await radioOn(tester, PlaybackOrder.random.label), isTrue, reason: "the user's order stays");
  });

  testWidgets('the minimum toggles: any rating plays everything; lineups hide them', (tester) async {
    final app = await show(tester, () => const BlockEditorScreen(lateNight: true), prepare: (app) async {
      await app.createCustomChannel('Mixed', const ChannelSource(seriesKeys: ['kiddo|2000', 'edgy|2000', 'grown|2000']));
    });
    await pickChannel(tester, 'Mixed');
    expect(find.textContaining('1 show'), findsOneWidget);
    await tap(tester, 'TV-14 / PG-13 and up');
    expect(find.textContaining('2 shows'), findsOneWidget);
    await tap(tester, 'Any rating');
    expect(find.textContaining('3 shows'), findsOneWidget);
    expect(find.text('Every day  ·  11:00 PM – 4:00 AM'), findsOneWidget);
    await tap(tester, 'NC-17 / 18 and up');
    expect(find.text('Nothing yet. Choose shows or movies.'), findsOneWidget);
    await tap(tester, 'Save');
    expect(find.text('Nothing in this mix is rated NC-17 or higher. Choose a lower rating or other shows.'), findsOneWidget);
    expect(app.blocks, isEmpty);
    await tap(tester, 'A lineup');
    expect(find.text('Minimum rating'), findsNothing);
  });

  testWidgets('kid profiles get no shortcut and no toggles', (tester) async {
    await show(tester, () => const BlocksScreen(), maxRatingRank: KidRating.older.maxRank);
    expect(find.text('New late-night block'), findsNothing);
    await tap(tester, 'New programming block');
    expect(find.text('Minimum rating'), findsNothing);
    expect(find.text('Any rating'), findsNothing);
  });
}
