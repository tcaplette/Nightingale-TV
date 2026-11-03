import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/remote/key_dispatch.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/transport_bar.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

/// The watch screen's on-screen button row with the D-pad (dpad-buttons).
void main() {
  late PortraitHarness h;

  Tuner tuner() => h.tuner;
  final guide = find.byType(GuideView);
  final menu = find.byType(MenuScreen);
  final dialog = find.byType(Dialog);
  final bar = find.byType(TransportBar);

  /// The TV screen with a sleep timer, playing the first generated channel.
  /// [timeshift] off: no transport bar, as on a live channel.
  Future<void> start(WidgetTester tester,
      {TargetPlatform platform = TargetPlatform.linux, bool timeshift = false}) async {
    runAs(platform, television: true);
    setWindow(tester, const Size(1920, 1080));
    h = await PortraitHarness.start(tester, sleep: true);
    final ch = h.app.channels.firstWhere((c) => !c.isMusic);
    await tester.runAsync(() => h.app.setLastChannel(ch));
    if (!timeshift) await tester.runAsync(() => h.app.setPlayback(const PlaybackSettings(pauseAndRewind: false)));
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 20 && tuner().status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tuner().status, TunerStatus.playing);
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

  /// Guide, Menu and Sleep are showing.
  bool rowUp(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Guide'), matching: find.byType(AnimatedOpacity)).first)
          .opacity ==
      1;

  /// The highlighted buttons on the row.
  List<String> lit(WidgetTester tester) => [
        for (final b in tester.widgetList<TvPointerButton>(find.byType(TvPointerButton)))
          if (b.highlighted) b.label,
      ];

  Future<TestGesture> mouse(WidgetTester tester) async {
    final m = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await m.addPointer(location: const Offset(900, 500));
    addTearDown(m.removePointer);
    return m;
  }

  const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown;
  const left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;
  const ok = LogicalKeyboardKey.select;

  group('when the row shows', () {
    testWidgets('surfing shows the banner without the row', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await key(tester, up);
      expect(tuner().channel!.id, isNot(was));
      expect(tester.getTopLeft(find.byType(ChannelBanner)).dy, lessThan(1080), reason: 'the banner is up');
      expect(rowUp(tester), isFalse);
      await h.end(tester);
    });

    testWidgets('Right shows the banner and the row', (tester) async {
      await start(tester);
      await key(tester, right);
      expect(rowUp(tester), isTrue);
      expect(lit(tester), isEmpty);
      await h.end(tester);
    });

    testWidgets('Info shows the row; a number tune hides it', (tester) async {
      await start(tester);
      await key(tester, LogicalKeyboardKey.keyI);
      expect(rowUp(tester), isTrue);
      final other = h.app.channels.firstWhere((c) => c.id != tuner().channel!.id && !c.isMusic);
      for (final d in '${other.number}'.split('')) {
        await key(tester, LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)));
      }
      await key(tester, ok);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(tuner().channel!.id, other.id);
      expect(rowUp(tester), isFalse);
      await h.end(tester);
    });
  });

  group('the D-pad on the row', () {
    testWidgets('Right, Up, Right, OK opens the Menu', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await keys(tester, [right, up]);
      expect(lit(tester), ['Guide']);
      expect(tuner().channel!.id, was, reason: 'Up went to the row, not the channel');
      await key(tester, right);
      expect(lit(tester), ['Menu']);
      await key(tester, ok);
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu, findsOneWidget);
      await h.end(tester);
    });

    testWidgets('Right, Up, Right, Right, OK opens the sleep picker; Right stops at the end', (tester) async {
      await start(tester);
      await keys(tester, [right, up, right, right]);
      expect(lit(tester), ['Sleep']);
      await key(tester, right);
      expect(lit(tester), ['Sleep']);
      await keys(tester, [left, left, left]);
      expect(lit(tester), ['Guide']);
      await keys(tester, [right, right, ok]);
      expect(dialog, findsOneWidget);
      expect(find.text('Sleep timer'), findsOneWidget);
      await h.end(tester);
    });

    testWidgets('OK on Guide opens the guide; closing it shows no row', (tester) async {
      await start(tester);
      await keys(tester, [right, up, ok]);
      expect(guide, findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(guide, findsNothing);
      expect(rowUp(tester), isFalse);
      expect(lit(tester), isEmpty);
      await h.end(tester);
    });

    testWidgets('Up twice with nothing on screen surfs twice', (tester) async {
      await start(tester);
      final first = tuner().channel!.id;
      await key(tester, up);
      final second = tuner().channel!.id;
      await key(tester, up);
      expect(second, isNot(first));
      expect(tuner().channel!.id, isNot(second));
      expect(lit(tester), isEmpty);
      await h.end(tester);
    });

    testWidgets('Up on the row does nothing; Down and Escape leave it with the controls up', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await keys(tester, [right, up, up]);
      expect(lit(tester), ['Guide']);
      expect(tuner().channel!.id, was);
      await key(tester, down);
      expect(lit(tester), isEmpty);
      expect(rowUp(tester), isTrue);
      expect(tuner().channel!.id, was, reason: 'Down left the row only');
      await keys(tester, [up, LogicalKeyboardKey.escape]);
      expect(lit(tester), isEmpty);
      expect(rowUp(tester), isTrue);
      expect(guide, findsNothing, reason: 'Escape left the row rather than opening the guide');
      await h.end(tester);
    });

    testWidgets('Channel Up leaves the row and surfs', (tester) async {
      await start(tester);
      final was = tuner().channel!.id;
      await keys(tester, [right, up, LogicalKeyboardKey.channelUp]);
      expect(tuner().channel!.id, isNot(was));
      expect(lit(tester), isEmpty);
      expect(rowUp(tester), isFalse);
      await h.end(tester);
    });

    testWidgets('Android Back leaves the row without the exit prompt', (tester) async {
      await start(tester, platform: TargetPlatform.android);
      await keys(tester, [right, up, right]);
      expect(lit(tester), ['Menu']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.pump();
      expect(lit(tester), isEmpty);
      expect(rowUp(tester), isTrue);
      expect(find.text(TvScreen.exitPrompt), findsNothing);
      // Android 13+: Back comes as a pop, which the app turns into a key.
      await key(tester, up);
      expect(lit(tester), ['Guide']);
      expect(dispatchKey(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack), isTrue);
      await tester.pump();
      expect(lit(tester), isEmpty);
      expect(find.text(TvScreen.exitPrompt), findsNothing);
      await h.end(tester);
    });

    testWidgets('keys keep the controls up; after 5 s they go with the highlight and Up surfs', (tester) async {
      await start(tester);
      await keys(tester, [right, up]);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 4));
        await key(tester, i.isEven ? right : left);
        expect(rowUp(tester), isTrue);
      }
      expect(lit(tester), isNotEmpty);
      await tester.pump(const Duration(seconds: 6));
      expect(rowUp(tester), isFalse);
      expect(lit(tester), isEmpty);
      final was = tuner().channel!.id;
      await key(tester, up);
      expect(tuner().channel!.id, isNot(was));
      await h.end(tester);
    });
  });

  group('with the transport bar', () {
    testWidgets('Up from the seek bar highlights Guide and the bar stays; Down goes back', (tester) async {
      await start(tester, timeshift: true);
      await key(tester, right);
      expect(bar, findsOneWidget);
      expect(rowUp(tester), isTrue);
      await key(tester, up);
      expect(bar, findsOneWidget);
      expect(lit(tester), ['Guide']);
      expect(tester.widget<TransportBar>(bar).focused, isNull, reason: 'one highlight');
      await key(tester, right);
      expect(lit(tester), ['Menu']);
      expect(tuner().seekTarget, isNull, reason: 'Right moved on the row, not the seek bar');
      await key(tester, down);
      expect(lit(tester), isEmpty);
      expect(tester.widget<TransportBar>(bar).focused, TransportFocus.seekBar);
      await h.end(tester);
    });
  });

  group('one highlight for pointer and D-pad', () {
    testWidgets('point at Menu, then Right highlights Sleep', (tester) async {
      await start(tester);
      final m = await mouse(tester);
      await m.moveTo(const Offset(910, 510));
      await tester.pump(const Duration(milliseconds: 300));
      await m.moveTo(tester.getCenter(find.text('Menu')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lit(tester), ['Menu']);
      await key(tester, right);
      expect(lit(tester), ['Sleep']);
      await h.end(tester);
    });

    testWidgets('Guide by the D-pad, then pointing at Sleep highlights only Sleep', (tester) async {
      await start(tester);
      final m = await mouse(tester);
      await keys(tester, [right, up]);
      expect(lit(tester), ['Guide']);
      await m.moveTo(tester.getCenter(find.text('Sleep')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lit(tester), ['Sleep']);
      await key(tester, ok);
      expect(dialog, findsOneWidget);
      await h.end(tester);
    });
  });
}
