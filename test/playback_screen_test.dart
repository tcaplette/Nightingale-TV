import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
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
  late FakePlayer player;

  Future<void> show(WidgetTester tester, PlaybackSettings playback) async {
    tester.view.physicalSize = const Size(1920, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_playback_screen');
      app = await signedInApp(dir, fakeLibrary());
      await app.setPlayback(playback);
    });
    player = FakePlayer([]);
    tuner = Tuner(app, player: player);
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

  /// The label of the toggle that has focus.
  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorWidgetOfExactType<TvToggle>()?.label;
  }

  testWidgets('volume leveling: shown under AUDIO, off by default, with help text', (tester) async {
    await show(tester, PlaybackSettings.off);
    expect(find.text('AUDIO'), findsOneWidget);
    final toggle = tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.levelingLabel));
    expect(toggle.on, isFalse);
    expect(toggle.radio, isFalse);
    expect(find.text(PlaybackScreen.levelingHelp), findsOneWidget, reason: 'no passthrough sentence off Android');
    expect(find.textContaining(PlaybackScreen.levelingAndroidHelp), findsNothing);
  });

  testWidgets('volume leveling: the help text mentions passthrough on Android', (tester) async {
    PlatformInfo.debugOverride = TargetPlatform.android;
    addTearDown(PlatformInfo.debugReset);
    await show(tester, PlaybackSettings.off);
    expect(find.text('${PlaybackScreen.levelingHelp} ${PlaybackScreen.levelingAndroidHelp}'), findsOneWidget);
  });

  for (final transcode in [false, true]) {
    testWidgets('volume leveling: the D-pad reaches it and OK saves it (converting ${transcode ? 'on' : 'off'})',
        (tester) async {
      await show(tester, PlaybackSettings.off.copyWith(transcodeIfNeeded: transcode));
      expect(focusedLabel(), PlaybackScreen.toggleLabel);
      // Past the caps when they're selectable; straight to it when they aren't.
      for (var i = 0; i < 10 && focusedLabel() != PlaybackScreen.levelingLabel; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focusedLabel(), PlaybackScreen.levelingLabel, reason: 'transcode $transcode');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(app.settings.playback.volumeLeveling, isTrue);
      expect(app.settings.playback.transcodeIfNeeded, transcode, reason: 'nothing else changes');
      expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.levelingLabel)).on, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(app.settings.playback.volumeLeveling, isFalse);
    });
  }

  testWidgets('volume leveling: a tap saves it', (tester) async {
    await show(tester, PlaybackSettings.off);
    await tester.tap(find.text(PlaybackScreen.levelingLabel));
    await tester.pumpAndSettle();
    expect(app.settings.playback, const PlaybackSettings(volumeLeveling: true));
  });

  testWidgets('break notices: shown under COMMERCIALS, on by default, with help text', (tester) async {
    await show(tester, PlaybackSettings.off);
    expect(find.text('COMMERCIALS'), findsOneWidget);
    final toggle = tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.noticesLabel));
    expect(toggle.on, isTrue);
    expect(toggle.radio, isFalse);
    expect(find.text(PlaybackScreen.noticesHelp), findsOneWidget);
  });

  for (final transcode in [false, true]) {
    testWidgets('break notices: the D-pad reaches it and OK saves it, with no re-tune or decisions cleared '
        '(converting ${transcode ? 'on' : 'off'})', (tester) async {
      await show(tester, PlaybackSettings.off.copyWith(transcodeIfNeeded: transcode));
      app.saveDecision('src1', null, null, directStream: true);
      expect(focusedLabel(), PlaybackScreen.toggleLabel);
      for (var i = 0; i < 12 && focusedLabel() != PlaybackScreen.noticesLabel; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focusedLabel(), PlaybackScreen.noticesLabel, reason: 'transcode $transcode');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(app.settings.playback, PlaybackSettings(transcodeIfNeeded: transcode, breakNotices: false));
      expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.noticesLabel)).on, isFalse);
      expect(app.savedDecision('src1', null), isNotNull, reason: 'notices change no playback');
      expect(player.opens, isEmpty, reason: 'no re-tune');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(app.settings.playback.breakNotices, isTrue);
      expect(app.savedDecision('src1', null), isNotNull);
      final saved = await tester.runAsync(() => app.storage.readJson('settings.json'));
      expect(((saved as Map)['playback'] as Map)['breakNotices'], true);
    });
  }

  testWidgets('break notices: a tap saves it', (tester) async {
    await show(tester, PlaybackSettings.off);
    await tester.tap(find.text(PlaybackScreen.noticesLabel));
    await tester.pumpAndSettle();
    expect(app.settings.playback, const PlaybackSettings(breakNotices: false));
    // Other settings still clear decisions.
    app.saveDecision('src1', null, null);
    await tester.tap(find.text(PlaybackScreen.levelingLabel));
    await tester.pumpAndSettle();
    expect(app.savedDecision('src1', null), isNull);
  });

  testWidgets('on-screen clock: shown after break notices, off by default, with help text', (tester) async {
    await show(tester, PlaybackSettings.off);
    expect(find.text('CLOCK'), findsOneWidget);
    final toggle = tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.clockLabel));
    expect(toggle.on, isFalse);
    expect(toggle.radio, isFalse);
    expect(find.text(PlaybackScreen.clockHelp), findsOneWidget);
    expect(tester.getTopLeft(find.text(PlaybackScreen.clockLabel)).dy,
        greaterThan(tester.getTopLeft(find.text(PlaybackScreen.noticesLabel)).dy));
    expect(tester.getTopLeft(find.text(PlaybackScreen.clockLabel)).dy,
        lessThan(tester.getTopLeft(find.text(PlaybackScreen.rewindLabel)).dy));
  });

  for (final transcode in [false, true]) {
    testWidgets('on-screen clock: the D-pad reaches it and OK saves it, with no re-tune or decisions cleared '
        '(converting ${transcode ? 'on' : 'off'})', (tester) async {
      await show(tester, PlaybackSettings.off.copyWith(transcodeIfNeeded: transcode));
      app.saveDecision('src1', null, null, directStream: true);
      for (var i = 0; i < 14 && focusedLabel() != PlaybackScreen.clockLabel; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focusedLabel(), PlaybackScreen.clockLabel, reason: 'transcode $transcode');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(app.settings.playback, PlaybackSettings(transcodeIfNeeded: transcode, onScreenClock: true));
      expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.clockLabel)).on, isTrue);
      expect(app.savedDecision('src1', null), isNotNull, reason: 'the clock changes no playback');
      expect(player.opens, isEmpty, reason: 'no re-tune');
      Object? saved;
      for (var i = 0; i < 50 && saved == null; i++) {
        await tester.pump();
        final json = await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return app.storage.readJson('settings.json');
        });
        if (((json as Map?)?['playback'] as Map?)?['onScreenClock'] == true) saved = json;
      }
      expect(saved, isNotNull, reason: 'saved to settings.json');
    });
  }

  testWidgets('on-screen clock: a tap saves it', (tester) async {
    await show(tester, PlaybackSettings.off);
    await tester.tap(find.text(PlaybackScreen.clockLabel));
    await tester.pumpAndSettle();
    expect(app.settings.playback, const PlaybackSettings(onScreenClock: true));
  });

  testWidgets('picking a cap saves it', (tester) async {
    await show(tester, const PlaybackSettings(transcodeIfNeeded: true));
    await tester.tap(find.text('8 Mbps · 1080p'));
    await tester.pumpAndSettle();
    expect(app.settings.playback, const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
  });

  testWidgets('the Pause and rewind toggle is on by default, and turning it off while behind goes live', (tester) async {
    await show(tester, PlaybackSettings.off);
    await tester.runAsync(() async {
      await tuner.tune(app.channels.first);
      await pumpEventQueue();
      await tuner.pause();
    });
    expect(tuner.shifted, isTrue);
    expect(tester.widget<TvToggle>(find.widgetWithText(TvToggle, PlaybackScreen.rewindLabel)).on, isTrue);
    await tester.tap(find.text(PlaybackScreen.rewindLabel));
    await tester.pump();
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(app.settings.playback.pauseAndRewind, isFalse);
    expect(tuner.shifted, isFalse);
    await tester.runAsync(tuner.stop);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 10));
  });
}
