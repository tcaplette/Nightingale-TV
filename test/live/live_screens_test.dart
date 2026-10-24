import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/channel_editor_screen.dart';
import 'package:nightingale_tv/ui/live_sources_screen.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import '../backup_fixtures.dart';
import '../fake_playback.dart';
import '../fixtures.dart';
import '../portrait_harness.dart';

/// A server whose Live TV is there, or not.
class NoLiveTv extends FakeClient {
  NoLiveTv(super.log, this.answer);

  final LiveTvAvailability answer;

  @override
  LiveTv get liveTv => _Availability(answer);
}

class _Availability implements LiveTv {
  _Availability(this.answer);

  final LiveTvAvailability answer;

  @override
  Future<LiveTvAvailability> availability() async => answer;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<LiveChannelInfo> channels(int n, {String Function(int i)? group}) => [
      for (var i = 0; i < n; i++)
        LiveChannelInfo(
          key: 'k$i',
          name: 'Channel $i',
          number: '${i + 2}.1',
          group: group?.call(i) ?? 'Locals',
          url: 'http://p/$i.ts',
          hasGuide: i.isEven,
        ),
    ];

void main() {
  late Directory dir;
  late AppState app;
  late Tuner tuner;

  Future<void> setUpApp(WidgetTester tester, {int count = 3, LiveTvAvailability server = LiveTvAvailability.noChannels}) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('live_screens');
      app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 4}));
      app.client = NoLiveTv([], server);
      final source = LiveSource(
          id: 'iptv', kind: LiveSourceKind.m3u, name: 'My IPTV', playlistUrl: 'http://provider/get.php?username=a&password=secret');
      await app.live.addSource(source, channels(count, group: (i) => i % 4 == 0 ? 'US News' : 'Sports'));
      await app.live.choose(source, {for (var i = 0; i < count && i < 2; i++) 'k$i'}, taken: {1, 2, 3}, groups: app.settings.groups);
    });
    tuner = Tuner(app, player: FakePlayer([]))
      ..prefetch = false
      ..preload = false;
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        await app.close();
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    // The scope sits above the app, as in main(), so pushed screens see it.
    await tester.pumpWidget(AppScope(
      app: app,
      tuner: tuner,
      child: MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        builder: (context, child) => Material(child: child),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorWidgetOfExactType<TvButton>()?.label;
  }

  testWidgets("the sources list: kind, counts, masked address; the D-pad goes Add source, then each source's buttons",
      (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester, count: 40);
    await show(tester, const LiveSourcesScreen());
    expect(find.text('M3U playlist · 2 of 40 channels'), findsOneWidget);
    expect(find.textContaining('password=••••'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(focusedLabel(), 'Add source');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'Choose channels');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'Refresh now');
  });

  testWidgets('Remove asks first, then takes the source and its channels away', (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester);
    await show(tester, const LiveSourcesScreen());
    expect(app.allChannels.where((c) => c.isLive), hasLength(2));
    await tester.tap(find.widgetWithText(TvButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove "My IPTV"?'), findsOneWidget);
    expect(find.text('Its channels leave the guide, their groups and favorites.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(app.live.sources, hasLength(1));
    // What confirming does (file work runs outside the test's fake time).
    await tester.runAsync(() => app.removeLiveSource(app.live.sources.single));
    await tester.pumpAndSettle();
    expect(find.text('No sources yet.'), findsOneWidget);
    expect(app.allChannels.where((c) => c.isLive), isEmpty);
  });

  testWidgets('upright on a phone: the source and the picker fit, and work with touch', (tester) async {
    runAs(TargetPlatform.android);
    setWindow(tester, pixel8);
    final harness = await PortraitHarness.start(tester);
    await tester.runAsync(() async {
      final source = LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'My IPTV', playlistUrl: 'http://p/x.m3u');
      await harness.app.live.addSource(source, channels(3));
      await harness.app.live.choose(source, {'k0', 'k1'}, taken: {1, 2, 3}, groups: harness.app.settings.groups);
    });
    await harness.show(tester, const LiveSourcesScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('M3U playlist · 2 of 3 channels'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(TvButton, 'Choose channels'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TvButton, 'Choose channels'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2 of 3 chosen'), findsOneWidget);
    await tester.tap(find.text('Channel 2'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 chosen'), findsOneWidget);
  });

  testWidgets("Add source: a server without Live TV shows why, and can't be picked", (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester);
    app.session = const ServerSessionForTest().session;
    await show(tester, const AddLiveSourceScreen());
    final server = tester.widget<TvButton>(find.widgetWithText(TvButton, 'Den Live TV'));
    expect(server.onPressed, isNull);
    expect(find.text('Den has no Live TV channels'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'M3U playlist'), findsOneWidget);
    expect(focusedLabel(), 'M3U playlist');
  });

  testWidgets("Add source: a user who may not watch Live TV is told so", (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester, server: LiveTvAvailability.noAccess);
    app.session = const ServerSessionForTest().session;
    await show(tester, const AddLiveSourceScreen());
    expect(find.text("Your Den account can't watch Live TV"), findsOneWidget);
  });

  testWidgets("Add source on a phone: the reason is shown whole, under the server's button", (tester) async {
    setWindow(tester, const Size(412, 915));
    await setUpApp(tester);
    app.session = const ServerSessionForTest().session;
    await show(tester, const AddLiveSourceScreen());
    expect(tester.takeException(), isNull);
    final reason = tester.renderObject<RenderParagraph>(find.text('Den has no Live TV channels'));
    expect(reason.didExceedMaxLines, isFalse);
    expect(tester.getTopLeft(find.text('Den has no Live TV channels')).dy,
        greaterThan(tester.getBottomLeft(find.widgetWithText(TvButton, 'Den Live TV')).dy));
  });

  testWidgets('the M3U form says what is missing and keeps what was typed', (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester);
    await show(tester, const M3uSourceScreen());
    await tester.enterText(find.byType(TextField).first, 'Living room IPTV');
    await tester.tap(find.widgetWithText(TvButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text("Enter the playlist's address, or choose a playlist file"), findsOneWidget);
    expect(find.text('Living room IPTV'), findsOneWidget);
  });

  testWidgets('the picker: 10,000 channels by group, search, a group checkbox, Done', (tester) async {
    setWindow(tester, const Size(1920, 1080));
    await setUpApp(tester, count: 10000);
    final watch = Stopwatch()..start();
    await show(tester, LiveChannelPickerScreen(source: app.live.sources.single));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(find.text('2 of 10000 chosen'), findsOneWidget);
    expect(find.text('US NEWS'), findsOneWidget);
    expect(find.text('GUIDE'), findsWidgets);
    expect(focusedLabel(), 'Done');

    await tester.enterText(find.byType(TextField), 'news');
    await tester.pumpAndSettle();
    expect(find.text('SPORTS'), findsNothing);
    await tester.tap(find.text('US NEWS'));
    await tester.pumpAndSettle();
    // US News's 2,500, and the Sports channel chosen before.
    expect(find.text('2501 of 10000 chosen'), findsOneWidget);
    expect(find.text('2500 of 2500'), findsOneWidget);

    // Moving down the list with the D-pad stays smooth: rows are built as
    // they come into view.
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final source = app.live.sources.single;
    // What Done does (file work runs outside the test's fake time).
    await tester.runAsync(() => app.chooseLiveChannels(source, {...source.chosen.keys, for (var i = 0; i < 10000; i += 4) 'k$i'}));
    expect(source.chosen, hasLength(2501));
    expect(app.allChannels.where((c) => c.isLive), hasLength(2501));
  });

  testWidgets('Channels & icons offers a live channel only what applies to it', (tester) async {
    setWindow(tester, const Size(1920, 1400));
    await setUpApp(tester);
    await show(tester, const ChannelEditorScreen());
    final live = app.allChannels.firstWhere((c) => c.isLive);
    await tester.tap(find.textContaining(live.name).first);
    await tester.pumpAndSettle();
    expect(find.text('COMMERCIALS'), findsNothing);
    expect(find.text('New episode premieres'), findsNothing);
    expect(find.text('In order (shows take turns)'), findsNothing);
    expect(find.text('CHANNEL LOGO'), findsWidgets);
    expect(find.widgetWithText(TvButton, 'Change icon'), findsOneWidget);
    expect(find.widgetWithText(TvButton, "Source's logo"), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Favorite'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Hide from guide'), findsOneWidget);
    expect(find.textContaining('Live · My IPTV'), findsOneWidget);
  });

  testWidgets('the menu offers Live TV sources on a grown-up profile, not on a kid profile', (tester) async {
    setWindow(tester, const Size(1920, 2400));
    late Household household;
    late Directory root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('live_menu');
      await writeHousehold(root, [
        Profile(id: 'mom0000000000001', name: 'Mom'),
        Profile(id: 'kid0000000000001', name: 'Kid', kind: ProfileKind.kid),
      ], fakeLibrary(shows: {'Alpha': 4}));
      household = await openHousehold(root);
      await household.select(household.profiles.first);
    });
    final t = Tuner(household.app!, player: FakePlayer([]));
    Future<void> menu() async {
      await tester.pumpWidget(HouseholdScope(
        household: household,
        child: AppScope(
          app: household.app!,
          tuner: t,
          child: MaterialApp(theme: GuideTheme.cableGuide.toThemeData(), home: const MenuScreen()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await menu();
    expect(find.widgetWithText(TvButton, 'Live TV sources'), findsOneWidget);
    await tester.runAsync(() => household.select(household.profiles.last));
    await menu();
    expect(find.widgetWithText(TvButton, 'Live TV sources'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    t.dispose();
    await tester.runAsync(() async {
      household.leave();
      household.backups?.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await root.delete(recursive: true);
    });
  });
}

/// A session on a server named "Den".
class ServerSessionForTest {
  const ServerSessionForTest();

  ServerSession get session => const ServerSession(
      serverUrl: 'https://jf.example', serverName: 'Den', userId: 'u', userName: 'n', accessToken: 't', deviceId: 'd');
}
