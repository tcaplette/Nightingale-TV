import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/sharing_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_canvas.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'backup_fixtures.dart';
import 'channel_sharing_test.dart' show senderRecipe;
import 'fake_playback.dart';
import 'fixtures.dart';
import 'portrait_harness.dart';
import 'sharing_fakes.dart';

void main() {
  late Directory dir;
  late Household h;
  late Tuner tuner;
  late FakeShareBackend backend;
  ShareService? service;

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Mom, linked to sharing with the fake backend, Tyler a friend; a music
  /// channel on the lineup. [window]: a phone held upright.
  Future<void> setUpLinked(WidgetTester tester, {Size? window}) async {
    tester.view.physicalSize = window ?? const Size(3200, 4000);
    tester.view.devicePixelRatio = window == null ? 1 : 2.625;
    addTearDown(tester.view.reset);
    backend = FakeShareBackend()
      ..profile = {
        'user_id': FakeShareBackend.userId,
        'presence': 'friends',
        'display_name': 'Mom',
        'handle': 'mom_tv',
        'avatar': 'fox',
        'avatar_color': 0,
        'station': '',
      }
      ..friends.add(const ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl'));
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('ntv_channel_sharing_screen');
      await writeHousehold(dir, momAndKids(), fakeLibrary(songs: fakeMusic(30)));
      h = await openHousehold(dir);
      await h.select(h.profiles.firstWhere((p) => p.name == 'Mom'));
      service = h.sharing = ShareService(h, h.root,
          url: 'https://share.test', key: 'sb_publishable_test', host: 'share.example', httpClient: backend.client, watchLifecycle: false);
      await service!.load();
      final c = await service!.setUp(h.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
      await service!.attachChannels();
      if (!h.app!.channels.any((c) => c.isMusic)) {
        await h.app!.createMusicChannel('Radio', const ChannelSource(includeEpisodes: false, includeSongs: true));
      }
    });
    tuner = Tuner(h.app!, player: FakePlayer([]));
    addTearDown(() async {
      tuner.dispose();
      await tester.runAsync(() async {
        h.leave();
        h.backups!.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await dir.delete(recursive: true);
      });
    });
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(HouseholdScope(
      household: h,
      child: AppScope(
        app: h.app!,
        tuner: tuner,
        child: MaterialApp(
          theme: GuideTheme.cableGuide.toThemeData(),
          builder: (context, child) => TvCanvas(child: child!),
          home: screen,
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      h.sharing = null;
      service?.dispose();
      service = null;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }

  String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

  /// The focused row's title text, for rows that aren't buttons.
  bool rowFocused(String text) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    var found = false;
    void visit(Element e) {
      if (e.widget is Text && (e.widget as Text).data == text) found = true;
      e.visitChildren(visit);
    }

    (ctx as Element).visitChildren(visit);
    return found;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key, [int rounds = 3]) async {
    await tester.sendKeyEvent(key);
    await settle(tester, rounds);
  }

  testWidgets('D-pad: Shared with you starts on Add; Select adds the channel', (tester) async {
    await setUpLinked(tester);
    backend.shareIn('sc-1', senderRecipe(const {'Alpha': 10, 'Beta': 4}));
    await show(tester, const SharingScreen());
    await settle(tester, 6);
    expect(find.text('90s Sitcoms'), findsOneWidget);
    expect(find.text('Matched 14 of 14 programs'), findsOneWidget);
    expect(find.text('Tyler  @tyler · Tyler TV'), findsOneWidget);
    expect(focused(), 'Add', reason: 'shares waiting: the remote starts on the first one');
    await press(tester, LogicalKeyboardKey.enter, 20);
    final copy = h.app!.channels.singleWhere((c) => c.isSharedCopy);
    expect(find.text('Added as channel ${copy.number}'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter, 6);
    expect(find.text('Matched 14 of 14 programs'), findsNothing);
    expect(find.text('Nothing is waiting. Channels your friends share with you appear here.'), findsOneWidget);
    expect(focused(), 'Share channels', reason: 'the page stays at the channel sections');
    await finish(tester);
  });

  testWidgets('nothing matching: no Add, the reason, and Decline', (tester) async {
    await setUpLinked(tester);
    backend.shareIn('sc-1', senderRecipe(const {'Zeta': 4}));
    await show(tester, const SharingScreen());
    await settle(tester, 6);
    expect(find.text('None of these programs are on your servers'), findsOneWidget);
    expect(find.widgetWithText(TvButton, 'Add'), findsNothing);
    expect(focused(), 'Decline');
    await press(tester, LogicalKeyboardKey.enter, 8);
    expect(backend.incoming.single['state'], 'declined');
    expect(focused(), 'Share channels');
    await finish(tester);
  });

  testWidgets('D-pad: Share channels, a channel, a friend, Share; music listed without a check box', (tester) async {
    await setUpLinked(tester);
    await show(tester, const ShareChannelsScreen());
    expect(focused(), 'Share with');
    expect(find.text("Music channels can't be shared"), findsWidgets);
    // Select with nothing checked says so.
    await press(tester, LogicalKeyboardKey.enter, 4);
    expect(find.text('Pick at least one channel.'), findsOneWidget);
    final first = h.app!.allChannels.firstWhere((c) => !c.isMusic && !c.isLive);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(rowFocused(first.displayName), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    // The music row never takes focus: Down goes through every other row.
    final rows = h.app!.allChannels.length;
    var musicFocused = false;
    for (var i = 0; i < rows + 2; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown, 1);
      if (h.app!.allChannels.where((c) => c.isMusic).any((c) => rowFocused(c.displayName))) musicFocused = true;
    }
    expect(musicFocused, isFalse);
    // Back up to Share with.
    for (var i = 0; i < rows + 4 && focused() != 'Share with'; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp, 1);
    }
    expect(focused(), 'Share with');
    await press(tester, LogicalKeyboardKey.enter, 6);
    expect(focused(), 'Share');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(rowFocused('Tyler'), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'Share');
    await press(tester, LogicalKeyboardKey.enter, 8);
    expect(find.text('Shared with Tyler'), findsOneWidget);
    expect(backend.lastShare!['to'], ['user-tyler']);
    expect(h.app!.channelById(first.id)!.share?.role, ShareRole.out);
    await finish(tester);
  });

  testWidgets('air mouse or touch: tap a channel, Share with, Get a link', (tester) async {
    await setUpLinked(tester);
    final first = h.app!.allChannels.firstWhere((c) => !c.isMusic && !c.isLive);
    await show(tester, const ShareChannelsScreen());
    await tester.tap(find.text(first.displayName).first);
    await settle(tester, 2);
    await tester.tap(find.text('Share with'));
    await settle(tester, 6);
    await tester.tap(find.text('Get a link'));
    await settle(tester, 8);
    expect(find.text('CH4N·L5'), findsOneWidget);
    expect(find.textContaining('becomes your friend and gets these channels'), findsOneWidget);
    expect(focused(), 'Done');
    expect(backend.lastShare!['link'], isTrue);
    await finish(tester);
  });

  testWidgets('a channel\'s Share… opens the list with it checked', (tester) async {
    await setUpLinked(tester);
    final first = h.app!.allChannels.firstWhere((c) => !c.isMusic && !c.isLive);
    await show(tester, ShareChannelsScreen(initial: {first.id}));
    await tester.tap(find.text('Share with'));
    await settle(tester, 6);
    expect(find.text('Pick at least one channel.'), findsNothing);
    expect(find.text('Tyler'), findsOneWidget);
    await finish(tester);
  });

  for (final size in [narrowPhone, pixel8]) {
    testWidgets('upright at ${size.width.toInt()}×${size.height.toInt()}: Sharing and Share channels fit', (tester) async {
      await setUpLinked(tester, window: size * 2.625);
      backend.shareIn('sc-1', senderRecipe(const {'Alpha': 10}));
      await show(tester, const SharingScreen());
      await settle(tester, 6);
      expect(tester.takeException(), isNull);
      expect(find.text('Matched 10 of 10 programs'), findsOneWidget);
      await tester.tap(find.widgetWithText(TvButton, 'Add'));
      await settle(tester, 20);
      expect(h.app!.channels.where((c) => c.isSharedCopy), hasLength(1));
      await tester.tap(find.text('OK'));
      await settle(tester, 4);
      await show(tester, const ShareChannelsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text("Channels shared with you can't be shared again"), findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets('the menu badge counts waiting shares', (tester) async {
    await setUpLinked(tester);
    backend.shareIn('sc-1', senderRecipe(const {'Alpha': 3}));
    backend.shareIn('sc-2', senderRecipe(const {'Beta': 3}));
    await tester.runAsync(() => service!.channels.refreshIncoming());
    await show(tester, const MenuScreen());
    for (var i = 0; i < 30 && focused() != 'Sharing'; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown, 1);
    }
    final button = tester.widget<TvButton>(find.widgetWithText(TvButton, 'Sharing'));
    expect(button.badge, 2);
    expect(find.text('2'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the new-share notice shows over the picture without taking focus', (tester) async {
    runAs(TargetPlatform.linux);
    setWindow(tester, const Size(1920, 1080));
    final harness = await PortraitHarness.start(tester);
    final sharing = harness.household.sharing = ShareService(harness.household, harness.household.root,
        url: 'https://share.test', key: 'k', host: 'share.example', httpClient: FakeShareBackend().client, watchLifecycle: false);
    await tester.runAsync(() => harness.app.setLastChannel(harness.app.channels.firstWhere((c) => !c.isMusic)));
    await harness.show(tester, const TvScreen());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final before = FocusManager.instance.primaryFocus;
    sharing.channels.notice.value = 'Tyler shared 2 channels with you. Open Menu → Sharing to add those channels.';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tyler shared 2 channels with you. Open Menu → Sharing to add those channels.'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, before, reason: 'playback keeps the focus');
    await tester.pump(const Duration(seconds: 9));
    expect(find.textContaining('Tyler shared 2 channels'), findsNothing, reason: 'it dismisses itself');
    await harness.end(tester);
    harness.household.sharing = null;
    sharing.dispose();
  });

  group('Shared tab', () {
    test('lists exactly the copies, ended ones too', () {
      Channel ch(String id, {ShareLink? share}) => Channel(
          id: id,
          number: 1,
          name: id,
          icon: const ChannelIcon.builtin('tv'),
          source: const ChannelSource(),
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: DateTime(2026),
          auto: false,
          share: share);
      final lineup = [
        ch('a', share: const ShareLink(id: '1', role: ShareRole.incoming)),
        ch('b', share: const ShareLink(id: '2', role: ShareRole.incoming, ended: true)),
        ch('c', share: const ShareLink(id: '3', role: ShareRole.out)),
        ch('d'),
      ];
      final auto = AutoGroups(fakeLibrary(), const [], kidProfile: false);
      final tabs = resolveGuideTabs(visible: lineup, groups: const [], order: GuideTabs.defaultOrder, hidden: {}, auto: auto);
      expect(tabs.map((t) => t.id), contains(GuideTabs.shared));
      expect([for (final c in tabs.firstWhere((t) => t.id == GuideTabs.shared).channels) c.id], ['a', 'b']);
      final none = resolveGuideTabs(visible: [lineup.last], groups: const [], order: GuideTabs.defaultOrder, hidden: {}, auto: auto);
      expect(none.map((t) => t.id), isNot(contains(GuideTabs.shared)), reason: 'no shared channels, no Shared tab');
    });

    test('a saved order from before Shared gets it after the last group, else after Favorites', () {
      final sat = ChannelGroup(id: 'group:sat', name: 'Saturday');
      expect(GuideTabs.normalize(['all', 'favorites', 'group:sat', 'auto:movies'], [sat]).take(5),
          ['all', 'favorites', 'group:sat', 'auto:shared', 'auto:live']);
      expect(GuideTabs.normalize(['all', 'favorites', 'auto:movies'], const []).take(3), ['all', 'favorites', 'auto:shared']);
      expect(GuideTabs.defaultOrder.take(3), ['all', 'favorites', 'auto:shared']);
      expect(GuideTabs.builtinName(GuideTabs.shared), 'Shared');
    });
  });
}
