import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo_bug.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';

const _show = MediaEntry(id: 'e1', kind: MediaKind.episode, title: 'Pilot', runtime: Duration(minutes: 22));
const _ad = MediaEntry(id: 'ad', kind: MediaKind.commercial, title: 'Ad', runtime: Duration(seconds: 30));
const _badge = ChannelIcon(kind: ChannelIconKind.badge, value: 'KTV', color: 0xFFD32F2F);

void main() {
  late DateTime now;
  late int taps;

  Future<void> show(WidgetTester tester, ScheduledProgram segment,
      {LogoMode mode = LogoMode.always, bool hidden = false, List<({DateTime from, DateTime to})> blackouts = const []}) async {
    tester.view.physicalSize = TvCanvas.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: TvCanvas(
        child: GestureDetector(
          // The TV screen opens the guide on a tap anywhere.
          onTap: () => taps++,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(fit: StackFit.expand, children: [
              ChannelLogoBug(
                  icon: _badge, mode: mode, segment: segment, hidden: hidden, blackouts: blackouts, clock: () => now),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double opacity(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  setUp(() {
    now = DateTime(2026, 10, 20, 19, 7);
    taps = 0;
  });

  ScheduledProgram part(DateTime start, DateTime end) => ScheduledProgram(item: _show, start: start, end: end);

  testWidgets('a station badge at 70% in the title-safe corner, 81 px tall at 1080p', (tester) async {
    await show(tester, part(DateTime(2026, 10, 20, 19), DateTime(2026, 10, 20, 19, 22)));
    final box = tester.getRect(find.byType(ChannelLogo));
    expect(box.height, 81);
    expect(box.right, 1920 - 96);
    expect(box.bottom, 1080 - 54);
    expect(box.width, 81 * 2.5);
    expect(opacity(tester), 0.7);
    // The badge hugs the right edge of its box.
    expect(tester.getRect(find.byType(StationBadge)).right, closeTo(1920 - 96, 1));
  });

  testWidgets('hidden during a break', (tester) async {
    await show(
        tester,
        ScheduledProgram(
            item: _ad,
            start: DateTime(2026, 10, 20, 19, 6),
            end: DateTime(2026, 10, 20, 19, 9),
            role: BreakRole.mid,
            program: _show));
    expect(opacity(tester), 0);
  });

  testWidgets('hidden while the banner is up', (tester) async {
    await show(tester, part(DateTime(2026, 10, 20, 19), DateTime(2026, 10, 20, 19, 22)), hidden: true);
    expect(opacity(tester), 0);
  });

  testWidgets('a tap on the logo reaches the TV screen', (tester) async {
    await show(tester, part(DateTime(2026, 10, 20, 19), DateTime(2026, 10, 20, 19, 22)));
    await tester.tapAt(tester.getCenter(find.byType(StationBadge)));
    expect(taps, 1);
  });

  testWidgets('Now and then: in at the quarter hour, gone 20 seconds later; out for the Up next card',
      (tester) async {
    now = DateTime(2026, 10, 20, 19, 14, 50);
    await show(tester, part(DateTime(2026, 10, 20, 19), DateTime(2026, 10, 20, 19, 40)),
        mode: LogoMode.nowAndThen,
        blackouts: [(from: DateTime(2026, 10, 20, 19, 15, 5), to: DateTime(2026, 10, 20, 19, 15, 10))]);
    expect(opacity(tester), 0);
    Future<void> advance(Duration d) async {
      now = now.add(d);
      await tester.pump(d);
    }

    await advance(const Duration(seconds: 10));
    expect(opacity(tester), 0.7, reason: '7:15:00');
    await advance(const Duration(seconds: 5));
    expect(opacity(tester), 0, reason: 'Up next card at 7:15:05');
    await advance(const Duration(seconds: 5));
    expect(opacity(tester), 0.7, reason: 'back at 7:15:10');
    await advance(const Duration(seconds: 10));
    expect(opacity(tester), 0, reason: 'faded out by 7:15:20');
    await tester.pumpWidget(const SizedBox());
  });
}
