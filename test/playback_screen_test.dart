import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/playback_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;
  late Tuner tuner;

  Future<void> show(WidgetTester tester, PlaybackSettings playback) async {
    tester.view.physicalSize = const Size(1920, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_playback_screen');
      app = await signedInApp(dir, fakeLibrary());
      await app.setPlayback(playback);
    });
    tuner = Tuner(app, player: FakePlayer([]));
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: AppScope(app: app, tuner: tuner, child: const PlaybackScreen()),
    ));
    await tester.pumpAndSettle();
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        await dir.delete(recursive: true);
      });
    });
  }

  List<String> choices(WidgetTester tester) => [
        for (final t in tester.widgetList<TvToggle>(find.byType(TvToggle)))
          if (t.radio) t.label,
      ];

  testWidgets('Original comes first, then the caps down to 4 Mbps; no Auto', (tester) async {
    await show(tester, PlaybackSettings.off.copyWith(transcodeIfNeeded: true));
    expect(choices(tester), [
      'Original (no limit)',
      '40 Mbps · 4K',
      '20 Mbps · 1080p high',
      '12 Mbps · 1080p',
      '8 Mbps · 1080p',
      '4 Mbps · 720p',
    ]);
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, 'Original (no limit)')).on, isTrue);
    expect(find.textContaining('Auto'), findsNothing);
    expect(find.text(PlaybackScreen.toggleHelp), findsOneWidget);
    expect(find.text(PlaybackScreen.bitrateHelp), findsOneWidget);
  });

  testWidgets('a cap shows no connection measurement or "Now" line', (tester) async {
    await show(tester, const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, '4 Mbps · 720p')).on, isTrue);
    expect(find.textContaining('Now:'), findsNothing);
    expect(find.textContaining('connection about'), findsNothing);
    expect(find.text('Measuring…'), findsNothing);
  });

  testWidgets('with the toggle off, the caps are shown but not selectable', (tester) async {
    await show(tester, PlaybackSettings.off);
    expect(choices(tester), hasLength(6));
    for (final t in tester.widgetList<TvToggle>(find.byType(TvToggle))) {
      if (t.radio) expect(t.onPressed, isNull, reason: t.label);
    }
  });

  testWidgets('picking a cap saves it', (tester) async {
    await show(tester, const PlaybackSettings(transcodeIfNeeded: true));
    await tester.tap(find.text('8 Mbps · 1080p'));
    await tester.pumpAndSettle();
    expect(app.settings.playback, const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
  });
}
