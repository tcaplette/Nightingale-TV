import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/break_notices.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/break_points.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/break_sources.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

final _anchor = DateTime(2026, 10, 10, 18); // a Saturday, 6 PM

class _Points implements BreakPointSource {
  const _Points();

  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) => ProgramBreakInfo(
      source: PointSource.chapters,
      candidates: const [Duration(minutes: 7, seconds: 10), Duration(minutes: 14, seconds: 40)]);
}

/// The first moment after [from] that a notice of [kind] comes up on
/// [schedule], to the second: its start, so the whole countdown is ahead
/// (one already on at [from] may be nearly over).
DateTime firstNotice(ProgramSchedule schedule, DateTime from, BreakNoticeKind kind) {
  bool on(DateTime t) => breakNoticeAt(schedule, t)?.kind == kind;
  for (var t = from.add(const Duration(seconds: 1));
      t.isBefore(from.add(const Duration(hours: 3)));
      t = t.add(const Duration(seconds: 1))) {
    if (on(t) && !on(t.subtract(const Duration(seconds: 1)))) return t;
  }
  throw StateError('no $kind notice');
}

void main() {
  final library = fakeLibrary(shows: {'Archer': 10});
  MediaEntry clip(String id, int seconds) => MediaEntry(
      id: id, kind: MediaKind.commercial, title: id, runtime: Duration(seconds: seconds), poolIds: const ['ads']);
  final ads = [for (var i = 0; i < 12; i++) clip('ad$i', 30), for (var i = 0; i < 4; i++) clip('short$i', 15)];
  // Each half hour: pre 0:00–0:15, show –7:25, mid –10:25, show –17:55,
  // mid –20:55, show –28:15, post –30:00.
  final schedule = ChannelSchedule.build(
      Channel(
        id: 'ch',
        number: 2,
        name: 'Test',
        icon: const ChannelIcon.builtin('tv'),
        source: const ChannelSource(),
        order: PlaybackOrder.cyclic,
        playlist: [for (var i = 1; i <= 10; i++) 'Archer-e$i'],
        anchor: _anchor,
      ),
      library,
      const [],
      BreakContext(plan: BreakPlan.automatic, clips: FixedClips(ads, byPool: {'ads': ads}), points: const _Points()))!;

  group('the card', () {
    late DateTime start;
    late DateTime testStart;
    late int taps;
    late List<String> keys;
    late List<(BreakNoticeKind, DateTime)> shown;

    DateTime now(WidgetTester tester) => start.add(tester.binding.clock.now().difference(testStart));

    Future<void> pump(WidgetTester tester, {bool hidden = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: TvCanvas(
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) keys.add(event.logicalKey.keyLabel);
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              // The TV screen opens the guide on a tap anywhere.
              onTap: () => taps++,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(fit: StackFit.expand, children: [
                  Positioned(
                    left: 90,
                    bottom: 70,
                    child: BreakNoticeCard(
                      schedule: schedule,
                      hidden: hidden,
                      clock: () => now(tester),
                      onShown: (kind, at) => shown.add((kind, at)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> show(WidgetTester tester, DateTime at, {bool hidden = false}) async {
      tester.view.physicalSize = TvCanvas.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      start = at;
      testStart = tester.binding.clock.now();
      taps = 0;
      keys = [];
      shown = [];
      await pump(tester, hidden: hidden);
    }

    double opacity(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    Future<void> end(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('counts down a mid-roll from 10 to 1 and leaves at the cut', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 7, 12));
      expect(opacity(tester), 0, reason: '13 s before the break');
      await tester.pump(const Duration(milliseconds: 2600)); // 18:07:15.1
      expect(opacity(tester), 1);
      expect(find.text('Commercial break in 10'), findsOneWidget);
      expect(shown, [(BreakNoticeKind.breakStarts, DateTime(2026, 10, 10, 18, 7, 25))]);
      for (var n = 9; n >= 1; n--) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Commercial break in $n'), findsOneWidget, reason: '$n');
      }
      await tester.pump(const Duration(seconds: 1)); // 18:07:25.1
      expect(opacity(tester), 0, reason: 'the break has started');
      expect(shown, hasLength(1));
      await end(tester);
    });

    testWidgets('the number changes on the second', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 7, 20)); // shown at :20.5
      expect(find.text('Commercial break in 5'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450)); // :20.950
      expect(find.text('Commercial break in 5'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60)); // :21.010
      expect(find.text('Commercial break in 4'), findsOneWidget);
      await end(tester);
    });

    testWidgets('"Programming resumes" with "Back to" after a mid-roll', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 10, 19));
      expect(opacity(tester), 0);
      await tester.pump(const Duration(seconds: 1)); // 18:10:20.5
      expect(find.text('Programming resumes in 5'), findsOneWidget);
      expect(find.text('Back to Archer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(tester), 0);
      await end(tester);
    });

    testWidgets('"Up next" after a post-roll and pre-roll, not at the end of the post-roll', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 29, 54));
      expect(opacity(tester), 0);
      await tester.pump(const Duration(seconds: 7)); // 18:30:01.5
      expect(opacity(tester), 0, reason: 'the pre-roll is still to come');
      await tester.pump(const Duration(seconds: 9)); // 18:30:10.5
      expect(find.text('Programming resumes in 5'), findsOneWidget);
      expect(find.text('Up next: Archer'), findsOneWidget);
      await end(tester);
    });

    testWidgets('hidden while the banner is up, and back after it goes', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 7, 18));
      expect(find.text('Commercial break in 7'), findsOneWidget);
      await pump(tester, hidden: true); // :18.5
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(tester), 0);
      await tester.pump(const Duration(seconds: 2)); // :21.0
      await pump(tester); // :21.5
      expect(opacity(tester), 1);
      expect(find.text('Commercial break in 4'), findsOneWidget, reason: 'the right number');
      await end(tester);
    });

    testWidgets('screen readers hear the opening text once, as a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, DateTime(2026, 10, 10, 18, 7, 15, 500));
      final node = find.bySemanticsLabel('Commercial break in 10');
      expect(node, findsOneWidget);
      expect(tester.getSemantics(node).flagsCollection.isLiveRegion, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel('Commercial break in 10'), findsOneWidget, reason: 'not every tick');
      expect(find.bySemanticsLabel('Commercial break in 7'), findsNothing);
      semantics.dispose();
      await end(tester);
    });

    testWidgets('D-pad keys and taps act as with no card', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 7, 18));
      expect(opacity(tester), 1);
      final focus = FocusManager.instance.primaryFocus!.context!;
      expect(find.descendant(of: find.byType(BreakNoticeCard), matching: find.byWidget(focus.widget)), findsNothing,
          reason: 'it never takes focus');
      expect(tester.widget<ExcludeFocus>(
              find.descendant(of: find.byType(BreakNoticeCard), matching: find.byType(ExcludeFocus))).excluding,
          isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(keys, ['Arrow Up', 'Select']);
      await tester.tap(find.text('Commercial break in 7'), warnIfMissed: false);
      expect(taps, 1, reason: 'the tap goes to the picture');
      await end(tester);
    });

    testWidgets('sits bottom left, 90 px in and 70 px up', (tester) async {
      await show(tester, DateTime(2026, 10, 10, 18, 7, 18));
      await tester.pump(const Duration(milliseconds: 500));
      final card = tester.getRect(find.byType(Container).last);
      expect(card.left, 90);
      expect(card.bottom, 1080 - 70);
      await end(tester);
    });
  });

  group('in the picture', () {
    late Directory dir;
    late AppState app;
    late Tuner tuner;
    late DateTime start;
    late DateTime testStart;

    Future<Channel> setUpApp(WidgetTester tester, DateTime Function() clock) async {
      tester.view.physicalSize = TvCanvas.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late Channel ch;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('nightingale_tv_break_notice');
        app = await signedInApp(dir, fakeLibrary(commercials: const [Duration(seconds: 30), Duration(seconds: 15)]));
        await app.setGlobalPlan(BreakPlan.automatic);
        ch = app.channels.first;
      });
      tuner = Tuner(app, player: FakePlayer([]), clock: clock)
        ..prefetch = false
        ..preload = false
        ..channel = ch
        ..status = TunerStatus.playing;
      addTearDown(() async {
        tuner.dispose();
        await tester.runAsync(() async {
          await app.close();
          await dir.delete(recursive: true);
        });
      });
      return ch;
    }

    Future<void> showPicture(WidgetTester tester, {bool bannerUp = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: AppScope(app: app, tuner: tuner, child: TvCanvas(child: TvPicture(bannerUp: bannerUp))),
      ));
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Starts the clock 3 seconds into a break notice.
    Future<void> intoCountdown(WidgetTester tester) async {
      late DateTime Function() clock;
      clock = () => start.add(tester.binding.clock.now().difference(testStart));
      start = DateTime.now();
      testStart = tester.binding.clock.now();
      final ch = await setUpApp(tester, () => clock());
      start = firstNotice(app.scheduleFor(ch)!, DateTime.now(), BreakNoticeKind.breakStarts).add(const Duration(seconds: 3));
      testStart = tester.binding.clock.now();
    }

    double opacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find.descendant(of: find.byType(BreakNoticeCard), matching: find.byType(AnimatedOpacity)))
        .opacity;

    testWidgets('shows while playing, and the banner hides it until it goes', (tester) async {
      await intoCountdown(tester);
      await showPicture(tester);
      expect(opacity(tester), 1);
      expect(find.textContaining('Commercial break in '), findsOneWidget);
      await showPicture(tester, bannerUp: true);
      expect(opacity(tester), 0);
      await showPicture(tester);
      expect(opacity(tester), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('none in stand-by', (tester) async {
      await intoCountdown(tester);
      tuner.status = TunerStatus.standby;
      await showPicture(tester);
      expect(find.byType(BreakNoticeCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('turning the setting off removes it at once, with no re-tune', (tester) async {
      await intoCountdown(tester);
      await showPicture(tester);
      expect(opacity(tester), 1);
      await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(breakNotices: false)));
      await tester.pump();
      expect(find.byType(BreakNoticeCard), findsNothing);
      expect(tuner.status, TunerStatus.playing);
      await tester.runAsync(() => app.setPlayback(app.settings.playback.copyWith(breakNotices: true)));
      await tester.pump();
      expect(find.byType(BreakNoticeCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
