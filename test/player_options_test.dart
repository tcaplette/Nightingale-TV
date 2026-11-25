import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/remote/key_dispatch.dart';
import 'package:nightingale_tv/ui/format.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'language_arb_support.dart';
import 'portrait_harness.dart';

/// The player options, Captions and Quality, and the quality picker on the
/// landscape TV screen (player-options, with the subtitles, dpad-buttons,
/// timeshift and youtube-playback deltas).
void main() {
  late PortraitHarness h;

  Tuner tuner() => h.tuner;
  FakePlayer player() => h.tuner.media as FakePlayer;
  final bar = find.byType(TransportBar);
  final options = find.byType(PlayerOptions);
  final dialog = find.byType(Dialog);
  final guide = find.byType(GuideView);
  final captionsButton = find.byKey(const ValueKey('option-captions'));
  final qualityButton = find.byKey(const ValueKey('option-quality'));

  /// The TV screen playing the first generated channel. [timeshift] off: no
  /// transport bar.
  Future<void> start(WidgetTester tester,
      {TargetPlatform platform = TargetPlatform.linux, bool timeshift = true, PlaybackSettings? playback}) async {
    runAs(platform, television: true);
    setWindow(tester, const Size(1920, 1080));
    h = await PortraitHarness.start(tester);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    final settings = (playback ?? PlaybackSettings.off).copyWith(pauseAndRewind: timeshift);
    await tester.runAsync(() => h.app.setPlayback(settings));
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tuner().status, TunerStatus.playing);
    await tester.pump(const Duration(seconds: 6));
    expect(options, findsNothing);
  }

  /// The TV screen on a phone held sideways (touch-sized buttons), in
  /// [language], with the app's real fonts.
  Future<void> startSideways(WidgetTester tester, String language, {required bool timeshift}) async {
    tester.platformDispatcher.localesTestValue = [localeOf(language)];
    activeLanguage = language;
    addTearDown(() {
      tester.platformDispatcher.clearLocalesTestValue();
      activeLanguage = 'en';
    });
    runAs(TargetPlatform.android);
    setWindow(tester, const Size(915, 412));
    h = await PortraitHarness.start(tester);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    // The longest cap word.
    await tester.runAsync(() => h.app.setPlayback(
        PlaybackSettings.off.copyWith(pauseAndRewind: timeshift, transcodeIfNeeded: true, bitrate: PlaybackSettings.presets[1])));
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 6));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> keys(WidgetTester tester, List<LogicalKeyboardKey> ks) async {
    for (final k in ks) {
      await key(tester, k);
    }
  }

  /// Lets a pick's save and re-open run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  /// Waits for [f] to show, within 5 s (a busy machine takes longer).
  Future<void> until(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 50 && f.evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  Future<TestGesture> mouse(WidgetTester tester) async {
    final m = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await m.addPointer(location: const Offset(900, 500));
    addTearDown(m.removePointer);
    await m.moveTo(const Offset(910, 510));
    await tester.pump(const Duration(milliseconds: 300));
    return m;
  }

  /// What the D-pad or pointer has highlighted on the options, wherever
  /// they are.
  PlayerOption? optionLit(WidgetTester tester) => tester.widget<PlayerOptions>(options).focused;
  TransportFocus? barLit(WidgetTester tester) => tester.widget<TransportBar>(bar).focused;
  List<String> rowLit(WidgetTester tester) => [
        for (final b in tester.widgetList<TvPointerButton>(find.byType(TvPointerButton)))
          if (b.highlighted) b.label,
      ];

  bool quickPickerOpen() => find.descendant(of: dialog, matching: find.text('4 Mbps · 720p')).evaluate().isNotEmpty;
  bool captionsPickerOpen() => find.descendant(of: dialog, matching: find.text('Captions')).evaluate().isNotEmpty;

  /// Pretends [ch] is on (a live or YouTube channel): the screen reads it
  /// from the tuner at its next build.
  void pretendOn(Channel ch) => tuner().channel = ch;

  final youTube = Channel.youTube(
    ref: const YouTubeRef(serverKey: 's2', channelId: 'UCcooking'),
    number: 501,
    name: 'Cooking',
    icon: const ChannelIcon.builtin('tv'),
    playlist: const ['s2~v1'],
    anchor: DateTime(2026, 11, 23),
  );
  final live = Channel.live(
      ref: const LiveRef(sourceId: 'src', key: 'k1'), number: 900, name: 'Live One', icon: const ChannelIcon.builtin('tv'));

  const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown;
  const left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;
  const ok = LogicalKeyboardKey.select;

  group('where they show', () {
    testWidgets('a generated channel with the bar: Left opens it, with the options at the right end of the row below the seek bar and the clock above its right end',
        (tester) async {
      await start(tester);
      await key(tester, left);
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: options), findsOneWidget);
      final seek = tester.getRect(find.byKey(const ValueKey('transport-seek')));
      final captions = tester.getRect(captionsButton), quality = tester.getRect(qualityButton);
      expect(captions.top, greaterThan(seek.bottom), reason: 'the row below the seek bar');
      expect(quality.left, greaterThan(captions.left), reason: 'Captions, then Quality');
      expect(captions.left, greaterThan(tester.getRect(find.bySemanticsLabel('Live')).right));
      expect(quality.right, closeTo(1920 - 90, 2), reason: 'at the right end');
      expect(find.descendant(of: qualityButton, matching: find.text('Original')), findsOneWidget);
      final clock = tester.getRect(find.descendant(of: bar, matching: find.text(formatTime(DateTime.now()))));
      expect(clock.bottom, lessThanOrEqualTo(seek.top + 1), reason: 'above the seek bar');
      expect(clock.right, greaterThan(seek.right), reason: 'at its right end');
      expect(tester.takeException(), isNull);
      await h.end(tester);
    });

    testWidgets('without the bar: Right shows them at the bottom right just above the banner, with no seek bar',
        (tester) async {
      await start(tester, timeshift: false);
      await key(tester, right);
      expect(bar, findsNothing);
      expect(options, findsOneWidget);
      final banner = tester.getRect(find.byType(ChannelBanner));
      final quality = tester.getRect(qualityButton);
      expect(quality.bottom, lessThanOrEqualTo(banner.top), reason: 'above the banner');
      expect(banner.top - quality.bottom, lessThan(20), reason: 'just above it');
      expect(quality.right, closeTo(1920 - 90, 2));
      expect(find.byType(TvPointerButton), findsWidgets, reason: 'with the top row');
      await h.end(tester);
    });

    testWidgets('a live channel: Right shows them above the banner, and the D-pad reaches them', (tester) async {
      await start(tester);
      pretendOn(live);
      await key(tester, right);
      expect(bar, findsNothing, reason: 'live channels have no bar');
      expect(options, findsOneWidget);
      expect(find.descendant(of: qualityButton, matching: find.text('Original')), findsOneWidget);
      await key(tester, down);
      expect(optionLit(tester), PlayerOption.captions);
      await key(tester, right);
      expect(optionLit(tester), PlayerOption.quality);
      await h.end(tester);
    });

    testWidgets('a surf shows the banner without them', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await key(tester, up);
      expect(tuner().channel!.id, isNot(was));
      expect(tester.getTopLeft(find.byType(ChannelBanner)).dy, lessThan(1080), reason: 'the banner is up');
      expect(options, findsNothing);
      await h.end(tester);
    });

    testWidgets('the air mouse shows them with the banner and the row; a click on Quality opens the picker',
        (tester) async {
      await start(tester, timeshift: false);
      final m = await mouse(tester);
      expect(options, findsOneWidget);
      expect(find.widgetWithText(TvPointerButton, 'Guide'), findsOneWidget);
      await m.moveTo(tester.getCenter(qualityButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(dialog, findsNothing, reason: 'hover never presses');
      await tester.tap(qualityButton, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(quickPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('touch: a tap shows the bar, and a tap on Captions opens the captions picker', (tester) async {
      await start(tester, platform: TargetPlatform.android);
      await tester.tapAt(const Offset(960, 400), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.descendant(of: bar, matching: options), findsOneWidget);
      await tester.tap(captionsButton, kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 400));
      expect(captionsPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('Captions shows its state: crossed out while off, filled while on', (tester) async {
      await start(tester);
      await key(tester, left);
      expect(find.descendant(of: captionsButton, matching: find.byIcon(Icons.closed_caption_disabled)), findsOneWidget);
      expect(find.bySemanticsLabel('Captions'), findsOneWidget);
      await tester.runAsync(() => tuner().toggleCaptions());
      await tester.pump();
      expect(find.descendant(of: captionsButton, matching: find.byIcon(Icons.closed_caption)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Captions: ')), findsOneWidget);
      await h.end(tester);
    });
  });

  group('the D-pad with the bar', () {
    testWidgets('Left, Down, Right, Right, Right, OK: Restart, Live, Captions and Quality in turn, then the quality picker',
        (tester) async {
      await start(tester);
      await key(tester, left);
      expect(barLit(tester), TransportFocus.seekBar);
      await key(tester, down);
      expect(barLit(tester), TransportFocus.restart);
      await key(tester, right);
      expect(barLit(tester), TransportFocus.live);
      await key(tester, right);
      expect(barLit(tester), TransportFocus.captions, reason: 'Right from Live');
      expect(optionLit(tester), PlayerOption.captions);
      await key(tester, right);
      expect(barLit(tester), TransportFocus.quality);
      await key(tester, right);
      expect(barLit(tester), TransportFocus.quality, reason: 'stops at the end');
      await key(tester, ok);
      expect(quickPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('Left, Down, Right, Right, OK opens the captions picker; Up goes back to the seek bar', (tester) async {
      await start(tester);
      await keys(tester, [left, down, right, right]);
      expect(barLit(tester), TransportFocus.captions);
      await key(tester, up);
      expect(barLit(tester), TransportFocus.seekBar);
      await keys(tester, [down, right, right, ok]);
      expect(captionsPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('Left from Captions goes back to Live and stops at Restart', (tester) async {
      await start(tester);
      await keys(tester, [left, down, right, right, left]);
      expect(barLit(tester), TransportFocus.live);
      await keys(tester, [left, left]);
      expect(barLit(tester), TransportFocus.restart);
      await h.end(tester);
    });
  });

  group('the D-pad without the bar', () {
    testWidgets('Right, Down, OK: the controls, Captions highlighted, then the captions picker', (tester) async {
      await start(tester, timeshift: false);
      await key(tester, right);
      expect(optionLit(tester), isNull);
      await key(tester, down);
      expect(optionLit(tester), PlayerOption.captions);
      expect(rowLit(tester), isEmpty, reason: 'one highlight');
      await key(tester, ok);
      expect(captionsPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('Left and Right move between the two; Down does nothing; Up and Escape leave without the guide',
        (tester) async {
      await start(tester, timeshift: false);
      final was = tuner().channel!.id;
      await keys(tester, [right, down, right]);
      expect(optionLit(tester), PlayerOption.quality);
      await key(tester, right);
      expect(optionLit(tester), PlayerOption.quality);
      await key(tester, down);
      expect(optionLit(tester), PlayerOption.quality);
      expect(tuner().channel!.id, was, reason: 'Down on the options never surfs');
      await key(tester, left);
      expect(optionLit(tester), PlayerOption.captions);
      await key(tester, up);
      expect(optionLit(tester), isNull);
      expect(options, findsOneWidget, reason: 'the controls stay');
      expect(rowLit(tester), isEmpty, reason: 'Up leaves, it does not jump to the row');
      await keys(tester, [down, LogicalKeyboardKey.escape]);
      expect(optionLit(tester), isNull);
      expect(guide, findsNothing);
      expect(tuner().channel!.id, was);
      await h.end(tester);
    });

    testWidgets('Android Back on Quality removes the highlight with the controls up and no exit prompt',
        (tester) async {
      await start(tester, platform: TargetPlatform.android, timeshift: false);
      await keys(tester, [right, down, right]);
      expect(optionLit(tester), PlayerOption.quality);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.pump();
      expect(optionLit(tester), isNull);
      expect(options, findsOneWidget);
      expect(find.text(TvScreen.exitPrompt), findsNothing);
      expect(guide, findsNothing);
      // Android 13+: Back comes as a pop, which the app turns into a key.
      await key(tester, down);
      expect(dispatchKey(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack), isTrue);
      await tester.pump();
      expect(optionLit(tester), isNull);
      expect(find.text(TvScreen.exitPrompt), findsNothing);
      await h.end(tester);
    });

    testWidgets('a channel key leaves the options and tunes', (tester) async {
      await start(tester, timeshift: false);
      final was = tuner().channel!.id;
      await keys(tester, [right, down]);
      await key(tester, LogicalKeyboardKey.channelUp);
      expect(tuner().channel!.id, isNot(was));
      expect(options, findsNothing, reason: 'a channel change shows the banner only');
      await h.end(tester);
    });

    testWidgets('keys keep them up; after 5 s they go with the highlight, and Down then surfs', (tester) async {
      await start(tester, timeshift: false);
      await keys(tester, [right, down]);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 4));
        await key(tester, i.isEven ? right : left);
        expect(options, findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 6));
      expect(options, findsNothing);
      final was = tuner().channel!.id;
      await key(tester, down);
      expect(tuner().channel!.id, isNot(was));
      await h.end(tester);
    });

    testWidgets('with nothing on screen, Down twice changes channel twice', (tester) async {
      await start(tester, timeshift: false);
      final first = tuner().channel!.id;
      await key(tester, down);
      final second = tuner().channel!.id;
      expect(second, isNot(first));
      await key(tester, down);
      expect(tuner().channel!.id, isNot(second));
      expect(options, findsNothing);
      await h.end(tester);
    });
  });

  group('one highlight for the pointer and the D-pad', () {
    testWidgets('pointing moves it between the top row and the options, and never presses', (tester) async {
      await start(tester, timeshift: false);
      final m = await mouse(tester);
      await m.moveTo(tester.getCenter(captionsButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(optionLit(tester), PlayerOption.captions);
      expect(rowLit(tester), isEmpty);
      await key(tester, right);
      expect(optionLit(tester), PlayerOption.quality);
      await m.moveTo(tester.getCenter(find.text('Guide')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowLit(tester), ['Guide']);
      expect(optionLit(tester), isNull);
      await m.moveTo(tester.getCenter(qualityButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowLit(tester), isEmpty);
      expect(optionLit(tester), PlayerOption.quality);
      expect(dialog, findsNothing);
      await key(tester, ok);
      expect(quickPickerOpen(), isTrue);
      await h.end(tester);
    });

    testWidgets('on the bar, pointing at Back 10 highlights it, and Right then goes to Live; the row takes it back',
        (tester) async {
      await start(tester);
      final m = await mouse(tester);
      expect(bar, findsOneWidget);
      await m.moveTo(tester.getCenter(find.bySemanticsLabel('Back 10')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(barLit(tester), TransportFocus.back10);
      await key(tester, right);
      expect(barLit(tester), TransportFocus.live);
      await m.moveTo(tester.getCenter(qualityButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(barLit(tester), TransportFocus.quality);
      await m.moveTo(tester.getCenter(find.text('Menu')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowLit(tester), ['Menu']);
      expect(barLit(tester), isNull);
      await h.end(tester);
    });
  });

  group('the quality picker', () {
    testWidgets('lists the presets in order, and opens on the cap in effect', (tester) async {
      await start(tester, playback: const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      await keys(tester, [left, down, right, right, right]);
      expect(find.descendant(of: qualityButton, matching: find.text('8 Mbps')), findsOneWidget);
      await key(tester, ok);
      final labels = [for (final t in tester.widgetList<TvToggle>(find.descendant(of: dialog, matching: find.byType(TvToggle)))) t.label];
      expect(labels, ['Original (no limit)', '40 Mbps · 4K', '20 Mbps · 1080p high', '12 Mbps · 1080p', '8 Mbps · 1080p', '4 Mbps · 720p']);
      final eight = tester.widget<TvToggle>(find.widgetWithText(TvToggle, '8 Mbps · 1080p'));
      expect(eight.on, isTrue);
      expect(eight.autofocus, isTrue);
      expect(find.text('Connected through Plex Relay; quality is limited.'), findsNothing);
      await h.end(tester);
    });

    testWidgets('with converting off, Original is ticked; picking 4 Mbps saves it, turns converting on, says so and re-opens under the cap',
        (tester) async {
      await start(tester);
      await keys(tester, [left, down, right, right, right, ok]);
      final original = tester.widget<TvToggle>(find.widgetWithText(TvToggle, 'Original (no limit)'));
      expect((original.on, original.autofocus), (true, true));
      final opens = player().opens.length;
      // Down to 4 Mbps, the last, with the D-pad.
      for (var i = 0; i < 5; i++) {
        await key(tester, down);
      }
      await key(tester, ok);
      await settle(tester);
      expect(dialog, findsNothing);
      expect(h.app.settings.playback.transcodeIfNeeded, isTrue);
      expect(h.app.settings.playback.maxKbps, 4000);
      await until(tester, find.text('Quality: 4 Mbps'));
      expect(find.text('Quality: 4 Mbps'), findsOneWidget);
      expect(player().opens.length, greaterThan(opens), reason: 'applied at once');
      expect(player().opens.last.url.path, endsWith('/stream.ts'));
      expect(tuner().status, TunerStatus.playing);
      await h.end(tester);
    });

    testWidgets('Back closes it with nothing saved or re-opened', (tester) async {
      await start(tester);
      await keys(tester, [left, down, right, right, right, ok]);
      expect(quickPickerOpen(), isTrue);
      final opens = player().opens.length;
      await key(tester, LogicalKeyboardKey.escape);
      await settle(tester);
      expect(dialog, findsNothing);
      expect(h.app.settings.playback, PlaybackSettings.off);
      expect(player().opens.length, opens);
      await h.end(tester);
    });

    testWidgets('the cap already in effect closes it without re-opening', (tester) async {
      await start(tester, playback: const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      await keys(tester, [left, down, right, right, right, ok]);
      final opens = player().opens.length;
      await key(tester, ok);
      await settle(tester);
      expect(dialog, findsNothing);
      await until(tester, find.text('Quality: 8 Mbps'));
      expect(find.text('Quality: 8 Mbps'), findsOneWidget);
      expect(player().opens.length, opens);
      await h.end(tester);
    });

    testWidgets('on Plex Relay it says quality is limited', (tester) async {
      await start(tester);
      h.app.session = h.app.session!.withServerUrl(h.app.session!.serverUrl, relay: true);
      await keys(tester, [left, down, right, right, right, ok]);
      expect(find.descendant(of: dialog, matching: find.text('Connected through Plex Relay; quality is limited.')), findsOneWidget);
      await h.end(tester);
    });

    testWidgets('touch: tapping Quality, then a preset', (tester) async {
      await start(tester, platform: TargetPlatform.android);
      await tester.tapAt(const Offset(960, 400), kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(qualityButton, kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('12 Mbps · 1080p'), kind: PointerDeviceKind.touch);
      await settle(tester);
      expect(h.app.capInEffect, 12000);
      await until(tester, find.text('Quality: 12 Mbps'));
      expect(find.text('Quality: 12 Mbps'), findsOneWidget);
      await h.end(tester);
    });
  });

  group('a phone held sideways, in every language', () {
    setUpAll(loadAppFonts);
    for (final language in supportedLanguages) {
      for (final timeshift in [true, false]) {
        testWidgets('$language, ${timeshift ? 'in the bar' : 'above the banner'}: the options fit and nothing overflows',
            (tester) async {
          await startSideways(tester, language, timeshift: timeshift);
          if (timeshift) {
            await tester.tapAt(const Offset(457, 150), kind: PointerDeviceKind.touch);
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            // With Pause and rewind off a tap opens the guide; a remote's
            // Right brings the controls.
            await key(tester, right);
          }
          expect(timeshift ? find.descendant(of: bar, matching: options) : options, findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'nothing overflows');
          final q = tester.getRect(qualityButton), c = tester.getRect(captionsButton);
          expect(c.left, greaterThanOrEqualTo(0));
          expect(q.right, lessThanOrEqualTo(915.5));
          if (timeshift) {
            expect(c.left, greaterThan(tester.getRect(find.bySemanticsLabel(tr.live2)).right - 0.5),
                reason: 'the transport and the options do not overlap');
          }
          // The toast a pick shows fits too.
          await tester.tap(qualityButton, kind: PointerDeviceKind.touch);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text(PlaybackSettings.presets.last.label), kind: PointerDeviceKind.touch);
          // The toast follows the save: wait for it (a busy machine takes
          // longer), within 5 s.
          final toast = find.text(tr.playerQualityValue(tr.playerQualityMbps(4)));
          for (var i = 0; i < 50 && toast.evaluate().isEmpty; i++) {
            await settle(tester);
          }
          expect(toast, findsOneWidget);
          expect(tester.takeException(), isNull);
          await h.end(tester);
        });
      }
    }
  });

  group('a YouTube channel', () {
    testWidgets('Quality reads Auto, greyed; the D-pad skips it, and hover, click and touch do nothing', (tester) async {
      await start(tester);
      pretendOn(youTube);
      await key(tester, right);
      expect(bar, findsNothing);
      expect(options, findsOneWidget);
      expect(find.descendant(of: qualityButton, matching: find.text('Auto')), findsOneWidget);
      expect(tester.widget<Opacity>(find.descendant(of: qualityButton, matching: find.byType(Opacity))).opacity, lessThan(1));
      await key(tester, down);
      expect(optionLit(tester), PlayerOption.captions);
      await key(tester, right);
      expect(optionLit(tester), PlayerOption.captions, reason: 'Captions stays highlighted');
      final m = await mouse(tester);
      await m.moveTo(tester.getCenter(qualityButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(optionLit(tester), PlayerOption.captions, reason: 'no highlight on hover');
      await tester.tap(qualityButton, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(dialog, findsNothing, reason: 'nothing opens');
      expect(guide, findsNothing, reason: 'the click is not a click on the picture');
      final opens = player().opens.length;
      await tester.runAsync(() => tuner().applyQuality(12345));
      expect(player().opens.length, opens, reason: 'YouTube plays on');
      // Captions still opens its Off/On picker.
      await tester.tap(captionsButton, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.descendant(of: dialog, matching: find.text('On')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('Off')), findsOneWidget);
      tuner().channel = null;
      await h.end(tester);
    });
  });
}
