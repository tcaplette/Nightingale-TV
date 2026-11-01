import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/icons/icon_catalog.dart';
import 'package:nightingale_tv/ui/widgets/channel_logo.dart';
import 'package:nightingale_tv/ui/widgets/nightingale_mark.dart';

void main() {
  Future<void> pump(WidgetTester tester, String key) => tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr, child: ChannelLogo(icon: ChannelIcon.builtin(key), size: 48)));

  testWidgets('the default TV icon is the TV with the bird, never the stock symbol', (tester) async {
    await pump(tester, 'live_tv');
    expect(find.byType(NightingaleTv), findsOneWidget);
    expect(find.byIcon(Icons.live_tv), findsNothing);
  });

  testWidgets("an icon this version doesn't know is the TV with the bird too", (tester) async {
    await pump(tester, 'from_a_newer_version');
    expect(find.byType(NightingaleTv), findsOneWidget);
    expect(find.byIcon(Icons.live_tv), findsNothing);
  });

  testWidgets('other built-in icons keep their symbols', (tester) async {
    await pump(tester, 'movie');
    expect(find.byIcon(Icons.movie), findsOneWidget);
    expect(find.byType(NightingaleTv), findsNothing);
  });

  test('the saved key stays, so existing channels keep working', () {
    expect(iconCatalog['TV & Movies'], contains('live_tv'));
    expect(drawsNightingaleTv('live_tv'), isTrue);
    expect(drawsNightingaleTv('tv'), isFalse);
  });

  test("the TV's colour replaces its frame's yellow, and the default is unchanged", () {
    expect(nightingaleTvSvg(), contains('#FFD23F'));
    final orange = nightingaleTvSvg(const Color(0xFFFF6B35));
    expect(orange, contains('#ff6b35'));
    expect(orange, isNot(contains('#FFD23F')));
  });
}
