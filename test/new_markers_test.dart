import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/new_tag.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  final channel = Channel(
    id: 'c',
    number: 12,
    name: 'Laugh Track',
    icon: const ChannelIcon.builtin('tv'),
    source: const ChannelSource(),
    order: PlaybackOrder.cyclic,
    playlist: const [],
    anchor: DateTime(2026),
  );
  const episode = MediaEntry(
      id: 'e5',
      kind: MediaKind.episode,
      title: 'The Return',
      runtime: Duration(minutes: 22),
      seriesName: 'Alpha',
      season: 2,
      episode: 5);
  const song = MediaEntry(
      id: 's1',
      kind: MediaKind.song,
      title: 'Take On Me',
      runtime: Duration(minutes: 4),
      artist: 'a-ha',
      album: 'Hunting High and Low',
      year: 1985);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: TvCanvas(child: Stack(children: [child])),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the banner marks a premiere NEW', (tester) async {
    final now = DateTime.now();
    final p = ScheduledProgram(
        item: episode,
        start: now,
        end: now.add(const Duration(minutes: 30)),
        blockTitle: PremierePlan.title,
        isPremiere: true);
    await pump(tester, Positioned(left: 0, right: 0, bottom: 0, child: ChannelBanner(channel: channel, program: p, next: null)));
    expect(find.byType(NewTag), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining('NEW EPISODES'), findsOneWidget);
  });

  testWidgets('no NEW for a rerun', (tester) async {
    final now = DateTime.now();
    final p = ScheduledProgram(item: episode, start: now, end: now.add(const Duration(minutes: 30)));
    await pump(tester, Positioned(left: 0, right: 0, bottom: 0, child: ChannelBanner(channel: channel, program: p, next: null)));
    expect(find.byType(NewTag), findsNothing);
  });

  testWidgets('the banner shows a song as "Artist – Song" and "Album · Year"', (tester) async {
    final now = DateTime.now();
    final p = ScheduledProgram(item: song, start: now, end: now.add(const Duration(minutes: 4)));
    await pump(tester, Positioned(left: 0, right: 0, bottom: 0, child: ChannelBanner(channel: channel, program: p, next: null)));
    expect(find.text('a-ha – Take On Me'), findsOneWidget);
    expect(find.textContaining('Hunting High and Low · 1985'), findsOneWidget);
  });

  testWidgets('the Up next card names the premiere with a NEW tag', (tester) async {
    final now = DateTime.now();
    final end = now.add(const Duration(seconds: 50));
    final show = ScheduledProgram(item: episode, start: end.subtract(const Duration(minutes: 22)), end: end);
    final next = ScheduledProgram(
        item: episode, start: end, end: end.add(const Duration(minutes: 22)), blockTitle: PremierePlan.title, isPremiere: true);
    await pump(
        tester,
        Positioned(
            right: 90,
            bottom: 70,
            child: UpNextCard(program: show, segment: show, next: next, lastPart: true, hidden: false)));
    expect(find.byType(NewTag), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity, 1);
    expect(find.text('Starting with Alpha'), findsOneWidget, reason: 'it starts the New Episodes slot');
    await tester.pumpWidget(const SizedBox());
  });

  group('in the guide', () {
    late Directory dir;
    late AppState app;
    late Tuner tuner;

    Future<void> openGuide(WidgetTester tester) async {
      tester.view.physicalSize = TvCanvas.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      // Episodes added two days ago; a premiere slot that started this quarter hour.
      final items = fakeItems(shows: const {'Alpha': 12, 'Beta': 12}, movies: 0);
      final added = now.subtract(const Duration(days: 2)).toUtc().toIso8601String();
      final library = LibraryIndex.fromJellyfinItems(
        seriesItems: items.series,
        episodeItems: [for (final e in items.episodes) {...e, 'DateCreated': added}],
        movieItems: const [],
        songItems: fakeMusic(200),
        fetchedAt: DateTime(2026),
      ).withAvailability(null, now);
      final start = now.hour * 60 + now.minute ~/ 15 * 15;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('nightingale_tv_new_markers');
        app = await signedInApp(dir, library,
            settings: (AppSettings.fresh()..premieres = PremiereSettings(startMinute: start)).toJson());
      });
      tuner = Tuner(app, player: FakePlayer([]));
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
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await dir.delete(recursive: true);
        });
      });
    }

    testWidgets("a premiere is NEW in its cell and in the info panel", (tester) async {
      await openGuide(tester);
      final home = app.premierePlan!.homeOf['alpha']!;
      final row = app.channels.indexWhere((c) => c.id == home);
      expect(app.scheduleFor(app.channels[row])!.programAt(DateTime.now()).isPremiere, isTrue);
      expect(find.byType(NewTag), findsWidgets);
      for (var i = 0; i < row; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(tester.widgetList<NewTag>(find.byType(NewTag)).any((t) => t.size == 32), isTrue, reason: 'info panel');
    });

    testWidgets('a music channel: hour-long cells named after it, and "Now playing" in the info panel', (tester) async {
      await openGuide(tester);
      await tester.tap(find.text('MUSIC'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      final radio = app.channels.firstWhere((c) => c.isMusic);
      final cells = app.scheduleFor(radio)!.guideProgramsBetween(DateTime.now(), DateTime.now().add(const Duration(hours: 1)));
      expect(cells.first.title, 'Music Radio');
      expect(cells.first.end.difference(cells.first.start), const Duration(hours: 1));
      expect(cells.first.start.minute, 0);
      expect(find.textContaining('Now playing: song artist'), findsOneWidget);
      expect(find.textContaining('Up next: '), findsOneWidget);
      // The description line has room for at least two lines (25 pt).
      expect(tester.getSize(find.textContaining('Up next: ')).height, greaterThanOrEqualTo(55));
    });
  });
}
