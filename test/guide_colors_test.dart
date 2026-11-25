import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';

void main() {
  late Directory dir;
  late AppState app;
  late Tuner tuner;
  final now = DateTime(2026, 11, 3, 20, 10);
  final library = fakeLibrary(shows: const {'Alpha': 40, 'Beta': 40}, movies: 6);

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('guide_colors');
      app = await signedInApp(dir, library);
      app.client = FakeClient([]);
    });
    tuner = Tuner(app, player: FakePlayer([]))
      ..prefetch = false
      ..preload = false;
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: AppScope(
        app: app,
        tuner: tuner,
        child: TvCanvas(child: RepaintBoundary(key: const ValueKey('guide'), child: GuideView(onWatch: (_) {}, onClose: () {}, onMenu: () {}, clock: () => now))),
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

  Future<List<int>> pixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('guide')));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }))!;
  }

  Finder cellsOf(Color c) => find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == c);

  testWidgets('one server, or the setting off: the guide is drawn exactly as before; two: in colour, with a key', (tester) async {
    await show(tester);
    final purple = ServerColor.byName('purple')!;
    final one = await pixels(tester);
    expect(app.guideColorsOn, isFalse);
    expect(find.byType(GuideColorKey), findsNothing);
    expect(cellsOf(purple.cell), findsNothing);

    final second = FakeServer('Basement', items: fakeItems(), url: 'https://b.example', serverId: 'b');
    await tester.runAsync(() => app.addServer(second.session, second.client, refresh: false));
    await tester.pump();
    expect(app.guideColorsOn, isTrue);
    // The main server's programs are its colour, in both shades.
    expect(cellsOf(purple.cell), findsWidgets);
    expect(cellsOf(purple.alternate), findsWidgets);
    expect(find.byType(GuideColorKey), findsOneWidget);
    expect(find.textContaining('From '), findsOneWidget, reason: "the info panel names the highlighted program's server");
    expect(await pixels(tester), isNot(one));

    await tester.runAsync(() => app.setGuideServerColors(false));
    await tester.pump();
    expect(await pixels(tester), one, reason: 'the setting off looks as with one server');
    expect(find.textContaining('From '), findsNothing);
  });

  testWidgets('the colour follows the copy that plays, and a chosen colour', (tester) async {
    await show(tester);
    final second = FakeServer('Basement', items: fakeItems(), url: 'https://b.example', serverId: 'b');
    await tester.runAsync(() => app.addServer(second.session, second.client, refresh: false));
    await tester.runAsync(() => app.moveServer('s2', -1));
    final ch = app.channels.first;
    // A title on both servers, Basement first in Play from.
    final entry = MediaEntry(
        id: 's2~x', kind: MediaKind.movie, title: 'Mirror', runtime: const Duration(minutes: 90), alternates: const [MediaCopy(id: 'x')]);
    final p = ScheduledProgram(item: entry, start: now, end: now.add(const Duration(minutes: 90)));
    expect(app.colorOf(ch, p)!.name, 'green', reason: 'a second Jellyfin server takes the next free colour');
    await tester.runAsync(() async => app.markUnreachable('s2'));
    expect(app.colorOf(ch, p)!.name, 'purple', reason: 'its first server down, the copy that will play is the main one');
    await tester.runAsync(() => app.setServerColor('main', 'wine'));
    expect(app.colorOf(ch, p)!.name, 'wine');
    final saved = await tester.runAsync(() => app.storage.readJson('settings.json'));
    expect((saved! as Map)['serverColors'], {'main': 'wine'});
  });

  test('fitting the key ends where capped names come out a hair over the line', () {
    // Found by simulation: capped at the room left, these sum to 1 ulp over
    // 466.28…, which kept the old loop shortening them forever.
    final widths = [256.54811832494806, 247.7780124114125, 157.44425496894496, 180.09841830065153];
    const max = 466.28217525428397;
    final f = GuideColorKey.fit(widths, max, (left) => 22.37);
    expect(f.shown, 3);
    expect(f.cap, greaterThanOrEqualTo(90));
    expect(3 * (22 + 8 + 24) + 3 * f.cap + 22.37, closeTo(max, 1e-9));
    // Everything fits: nothing capped, nothing left out.
    expect(GuideColorKey.fit([100, 120], 400, (_) => 20), (shown: 2, cap: double.infinity));
    // No room for even a few letters each: the last ones go, "+N" counted.
    expect(GuideColorKey.fit([300, 300, 300], 200, (_) => 20).shown, 1);
    expect(GuideColorKey.fit([300, 300, 300], 60, (_) => 20).shown, 0);
  });

  testWidgets('the key always finishes fitting its line: every width, names shortened or left out', (tester) async {
    // Shortening caps each name at the room left, which can come out a hair
    // over the line in floating point; fitting must still end (a phone froze
    // with three sources, 2026-11-23).
    final entries = [
      (color: ServerColor.byName('purple')!, name: 'Home-Media-Server'),
      (color: ServerColor.byName('olive')!, name: 'guest on 10.0.2.2'),
      (color: ServerColor.byName('slate')!, name: 'media on 10.0.2.2'),
    ];
    for (final size in [16.7, 21.3, 22.0]) {
      for (var w = 120.0; w <= 900; w += 0.37) {
        await tester.pumpWidget(MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          home: Align(alignment: Alignment.topLeft, child: SizedBox(width: w, child: GuideColorKey(entries: entries, fontSize: size))),
        ));
      }
    }
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('scrolling the guide is no slower in colour', (tester) async {
    await show(tester);
    Future<int> scroll() async {
      final w = Stopwatch()..start();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(i < 15 ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      return w.elapsedMicroseconds;
    }

    await scroll();
    final plain = [for (var i = 0; i < 5; i++) await scroll()]..sort();
    final second = FakeServer('Basement', items: fakeItems(), url: 'https://b.example', serverId: 'b');
    await tester.runAsync(() => app.addServer(second.session, second.client, refresh: false));
    await tester.pump();
    await scroll();
    final colored = [for (var i = 0; i < 5; i++) await scroll()]..sort();
    // ignore: avoid_print
    print('guide scroll, 30 moves: ${plain[2] ~/ 1000} ms plain, ${colored[2] ~/ 1000} ms in colour');
    expect(colored[2], lessThan(plain[2] * 1.25 + 20000));
  });
}
