import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/blocks_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  testWidgets('Programming blocks: the premiere row first; its editor moves premieres to 9:00 PM on weeknights',
      (tester) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Directory dir;
    late AppState app;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_premiere_settings');
      app = await signedInApp(dir, fakeLibrary());
    });
    final tuner = Tuner(app, player: FakePlayer([]));
    await tester.pumpWidget(AppScope(
      app: app,
      tuner: tuner,
      child: MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        builder: (context, child) => TvCanvas(child: child!),
        home: const BlocksScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('New episode premieres'), findsOneWidget);
    expect(find.text('8:00 PM  ·  Every day  ·  On'), findsOneWidget);

    await tester.tap(find.text('New episode premieres'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('+'));
      await tester.pump();
    }
    expect(find.text('9:00 PM'), findsOneWidget);
    await tester.tap(find.text('Weekdays'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    // The settings file is written in real time, a step at a time.
    for (var i = 0; i < 20 && find.text('Save').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(app.settings.premieres, const PremiereSettings(startMinute: 21 * 60, days: {1, 2, 3, 4, 5}));
    expect(find.text('9:00 PM  ·  Weekdays  ·  On'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    tuner.dispose();
    await tester.runAsync(() async {
      await app.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await dir.delete(recursive: true);
    });
  });
}
