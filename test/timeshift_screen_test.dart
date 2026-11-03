import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/format.dart';
import 'package:nightingale_tv/ui/portrait_watch_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_playback.dart';
import 'portrait_harness.dart';

void main() {
  late DateTime now;
  late PortraitHarness h;

  Tuner tuner() => h.tuner;
  FakePlayer player() => h.tuner.media as FakePlayer;
  final bar = find.byType(TransportBar);
  final chip = find.byType(PausedChip);
  final guide = find.byType(GuideView);

  /// The TV screen on the first generated channel, at a long part's middle.
  Future<void> start(WidgetTester tester,
      {Size window = const Size(1920, 1080), TargetPlatform platform = TargetPlatform.linux, bool television = false}) async {
    runAs(platform, television: television);
    setWindow(tester, window);
    now = DateTime.now();
    h = await PortraitHarness.start(tester, clock: () => now);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    await h.show(tester, const TvScreen());
    // Android asks the fake server first.
    for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tuner().status, TunerStatus.playing);
    await tester.pump(const Duration(seconds: 6));
    expect(bar, findsNothing);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump();
  }

  Future<void> end(WidgetTester tester) async {
    await h.end(tester);
  }

  group('the D-pad and media keys (D8)', () {
    testWidgets('Left opens the bar, Select pauses, and the chip stays once it closes', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(bar, findsOneWidget);
      expect(tuner().seekTarget, isNull, reason: 'the first press only opens it');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getTopLeft(find.byType(ChannelBanner)).dy, greaterThanOrEqualTo(1080), reason: 'the bar replaces it');
      await key(tester, LogicalKeyboardKey.select);
      expect(tuner().paused, isTrue);
      expect(player().paused, isTrue);
      expect(chip, findsNothing, reason: 'the bar says so');
      await tester.pump(const Duration(seconds: 6));
      expect(bar, findsNothing);
      expect(chip, findsOneWidget);
      // Select resumes while paused, and doesn't open the guide.
      await key(tester, LogicalKeyboardKey.select);
      expect(tuner().paused, isFalse);
      expect(guide, findsNothing);
      expect(chip, findsNothing);
      await end(tester);
    });

    testWidgets('Select with the bar closed opens the guide, as today', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.select);
      expect(guide, findsOneWidget);
      await end(tester);
    });

    testWidgets('Left and Right skip on the bar; a close waits for the pending seek', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(tuner().seekTarget, now.subtract(const Duration(seconds: 10)));
      await tester.pump(Tuner.seekDebounce);
      await tester.pump();
      expect(tuner().behind, const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 6));
      expect(bar, findsNothing);
      await end(tester);
    });

    testWidgets('Down goes to Restart and Live, Up comes back and then goes to the button row', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      TransportFocus? focused() => tester.widget<TransportBar>(bar).focused;
      expect(focused(), TransportFocus.seekBar);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), TransportFocus.restart);
      expect(tuner().channel, isNotNull);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(focused(), TransportFocus.live);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(focused(), TransportFocus.restart);
      await key(tester, LogicalKeyboardKey.select);
      expect(tuner().shifted, now != tuner().viewNow());
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), TransportFocus.seekBar);
      final was = tuner().channel!.id;
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(bar, findsOneWidget, reason: 'Back closes it, not Up');
      expect(focused(), isNull);
      expect(tester.widget<TvPointerButton>(find.widgetWithText(TvPointerButton, 'Guide')).highlighted, isTrue);
      expect(tuner().channel!.id, was);
      await end(tester);
    });

    testWidgets('Up and Down with the bar closed still change channel, showing only the banner', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(tuner().channel!.id, isNot(was));
      expect(bar, findsNothing);
      expect(
          tester.widget<AnimatedOpacity>(
                  find.ancestor(of: find.text('Guide'), matching: find.byType(AnimatedOpacity)).first)
              .opacity,
          0,
          reason: 'no button row on a surf');
      await end(tester);
    });

    testWidgets('Escape closes the bar rather than opening the guide', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.escape);
      expect(bar, findsNothing);
      expect(guide, findsNothing);
      await end(tester);
    });

    testWidgets('media keys act at once, and the bar shows', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.mediaPause);
      expect(tuner().paused, isTrue);
      expect(bar, findsOneWidget);
      await key(tester, LogicalKeyboardKey.mediaPlay);
      expect(tuner().paused, isFalse);
      await key(tester, LogicalKeyboardKey.mediaPlayPause);
      expect(tuner().paused, isTrue);
      await key(tester, LogicalKeyboardKey.keyP);
      expect(tuner().paused, isFalse);
      final at = tuner().viewNow();
      await key(tester, LogicalKeyboardKey.mediaRewind);
      expect(tuner().seekTarget, at.subtract(const Duration(seconds: 10)));
      await key(tester, LogicalKeyboardKey.mediaFastForward);
      expect(tuner().seekTarget, at.add(const Duration(seconds: 20)).isAfter(now) ? now : anything);
      await tester.pump(Tuner.seekDebounce);
      await end(tester);
    });

    testWidgets('with the setting off, Left shows only the banner and media keys do nothing', (tester) async {
      await start(tester);
      await tester.runAsync(() => h.app.setPlayback(const PlaybackSettings(pauseAndRewind: false)));
      await tester.pump();
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(bar, findsNothing);
      await key(tester, LogicalKeyboardKey.mediaPause);
      expect(tuner().paused, isFalse);
      await key(tester, LogicalKeyboardKey.keyP);
      expect(tuner().paused, isFalse);
      await end(tester);
    });

    testWidgets('a key restores a long-paused picture, still paused', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.mediaPause);
      await tester.pump(TvScreen.dimAfter);
      await tester.pump();
      expect(tester.widget<TvPicture>(find.byType(TvPicture)).dimmed, isTrue);
      await key(tester, LogicalKeyboardKey.select);
      expect(tester.widget<TvPicture>(find.byType(TvPicture)).dimmed, isFalse);
      expect(tuner().paused, isTrue);
      await end(tester);
    });
  });

  testWidgets('on a live channel, Left shows only the banner and media keys say they cannot pause', (tester) async {
    await start(tester);
    final was = tuner().channel!;
    await tuner().stop();
    await tester.pump();
    final live = Channel(
        id: 'live-test',
        number: 900,
        name: 'News',
        icon: was.icon,
        source: was.source,
        order: was.order,
        playlist: const [],
        anchor: was.anchor,
        live: const LiveRef(sourceId: 's', key: 'c'));
    await tester.runAsync(() => tuner().tune(live));
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(bar, findsNothing);
    await key(tester, LogicalKeyboardKey.mediaPause);
    expect(tuner().paused, isFalse);
    expect(find.text(TvScreen.liveCantPause), findsOneWidget);
    await end(tester);
  });

  group('air mouse and touch', () {
    testWidgets('moving the pointer shows the bar; a click on the picture opens the guide', (tester) async {
      await start(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 300));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(const Offset(910, 310));
      await tester.pump();
      expect(bar, findsOneWidget);
      await tester.tapAt(const Offset(910, 310), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(guide, findsOneWidget);
      await end(tester);
    });

    testWidgets('the bar\'s buttons click, and a click on the seek bar seeks', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.tap(find.bySemanticsLabel('Pause'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump();
      expect(tuner().paused, isTrue);
      await tester.tap(find.bySemanticsLabel('Play'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.pump();
      expect(tuner().paused, isFalse);
      final track = find.byKey(const ValueKey('transport-seek'));
      await tester.tapAt(tester.getCenter(track), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(tuner().seekTarget, isNotNull);
      expect(guide, findsNothing, reason: 'a click on the bar isn\'t on the picture');
      await tester.pump(Tuner.seekDebounce);
      await tester.pump();
      expect(tuner().shifted, isTrue);
      await end(tester);
    });

    testWidgets('a touch tap shows the banner with Guide and the bar; dragging the seek bar seeks', (tester) async {
      await start(tester, platform: TargetPlatform.android, window: const Size(915, 412));
      await tester.tapAt(const Offset(450, 80), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(guide, findsNothing);
      expect(bar, findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      final track = find.byKey(const ValueKey('transport-seek'));
      await tester.drag(track, const Offset(-100, 0), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(tuner().seekTarget, isNotNull);
      await tester.pump(Tuner.seekDebounce);
      await tester.pump();
      expect(tuner().shifted, isTrue);
      await tester.tap(find.text('Guide'));
      await tester.pump();
      expect(guide, findsOneWidget);
      await end(tester);
    });

    testWidgets('with the setting off, a touch tap opens the guide', (tester) async {
      await start(tester, platform: TargetPlatform.android, window: const Size(915, 412));
      await tester.runAsync(() => h.app.setPlayback(const PlaybackSettings(pauseAndRewind: false)));
      await tester.pump();
      await tester.tapAt(const Offset(450, 80), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(guide, findsOneWidget);
      await end(tester);
    });
  });

  group('overlays follow the picture (D9)', () {
    testWidgets('the banner shows the viewing program and how far behind, and the guide stays on the clock', (tester) async {
      await start(tester);
      final ch = tuner().channel!;
      final schedule = tuner().schedule!;
      final onAir = schedule.programAt(now);
      // Into the program before the one on air.
      final earlier = schedule.programAt(onAir.start.subtract(const Duration(seconds: 30)));
      await key(tester, LogicalKeyboardKey.arrowLeft);
      tuner().seekTo(earlier.start.isBefore(tuner().earliestView()) ? tuner().earliestView() : onAir.start.subtract(const Duration(seconds: 30)));
      await tester.pump(Tuner.seekDebounce);
      await tester.pump();
      await tester.pump();
      final view = tuner().viewNow();
      expect(tester.widget<ChannelBanner>(find.byType(ChannelBanner)).viewTime, view);
      expect(find.text(formatBehind(tuner().behind)), findsWidgets);
      expect(tuner().program!.isOnAt(view), isTrue);
      expect(h.app.scheduleFor(ch)!.programAt(now).start, onAir.start);
      // The tuned channel's guide row plays on, and picking it keeps the place.
      await key(tester, LogicalKeyboardKey.keyG);
      expect(guide, findsOneWidget);
      expect(tuner().shifted, isTrue);
      await end(tester);
    });

    testWidgets('the banner counts up while paused', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.mediaPause);
      now = now.add(const Duration(seconds: 45));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('0:45 behind'), findsWidgets);
      await end(tester);
    });
  });

  group('the portrait player', () {
    testWidgets('a tap shows the transport controls; Pause pauses and the panel says how far behind', (tester) async {
      await start(tester, platform: TargetPlatform.android, window: const Size(412, 915));
      expect(find.byType(PortraitWatchScreen), findsOneWidget);
      await tester.tapAt(const Offset(200, 100));
      await tester.pump();
      expect(bar, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Pause'));
      await tester.pump();
      await tester.pump();
      expect(tuner().paused, isTrue);
      now = now.add(const Duration(seconds: 65));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('1:05 behind'), findsWidgets);
      final panel = tester.widget<PortraitNowPanel>(find.byType(PortraitNowPanel));
      expect(panel.now, tuner().viewNow());
      expect(identical(panel.schedule, tuner().schedule), isTrue);
      // The controls stay 5 s after the last touch.
      await tester.pump(const Duration(seconds: 3));
      expect(bar, findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(bar, findsNothing);
      expect(chip, findsOneWidget);
      await end(tester);
    });

    testWidgets('a media key shows the controls in portrait', (tester) async {
      await start(tester, platform: TargetPlatform.android, window: const Size(412, 915));
      await key(tester, LogicalKeyboardKey.mediaPause);
      expect(tuner().paused, isTrue);
      expect(bar, findsOneWidget);
      await end(tester);
    });
  });

  test('the "behind" text', () {
    expect(formatBehind(const Duration(minutes: 12, seconds: 34)), '12:34 behind');
    expect(formatBehind(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03 behind');
    expect(formatBehind(const Duration(seconds: 5)), '0:05 behind');
  });
}
