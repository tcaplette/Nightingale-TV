import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/friend_avatar_stack.dart';
import 'package:nightingale_tv/ui/widgets/friends_watching_card.dart';
import 'package:nightingale_tv/ui/widgets/share_avatar.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';
import 'sharing_fakes.dart';

const _tyler = ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl', avatarColor: 1);
const _alex = ShareProfile(userId: 'user-alex', name: 'Alex', handle: 'alex', avatar: 'cat');
const _kim = ShareProfile(userId: 'user-kim', name: 'Kim', handle: 'kim', avatar: 'frog');
const _lee = ShareProfile(userId: 'user-lee', name: 'Lee', handle: 'lee', avatar: 'bear');

/// Friend presence on the TV screen, the guide and the portrait player
/// (friend-presence 4.7).
void main() {
  late PortraitHarness h;
  late FakeShareBackend backend;
  late ShareService sharing;
  late Channel shared;

  /// Mom, linked, Show what I'm watching on Friends, four friends; the first
  /// channel is shared (sc-1) and is the one the TV comes on with.
  /// [before]: friends already watching when the app connects.
  Future<void> start(WidgetTester tester,
      {Size window = const Size(1920, 1080),
      TargetPlatform platform = TargetPlatform.linux,
      bool television = true,
      void Function()? before}) async {
    runAs(platform, television: television);
    setWindow(tester, window);
    h = await PortraitHarness.start(tester, sleep: true);
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
      ..friends.addAll([_tyler, _alex, _kim, _lee])
      // The channel this profile shares (channel sharing keeps the link).
      ..sharedChannels['sc-1'] = {'owner': FakeShareBackend.userId, 'name': 'Shared', 'recipe': const {}, 'version': 1};
    await tester.runAsync(() async {
      final ch = h.app.channels.firstWhere((c) => !c.isMusic);
      await h.app.setShareLink(ch, const ShareLink(id: 'sc-1', role: ShareRole.out, version: 1));
      shared = h.app.channelById(ch.id)!;
      await h.app.setLastChannel(shared);
      await h.app.setPlayback(const PlaybackSettings(pauseAndRewind: false));
      before?.call();
      sharing = h.household.sharing = ShareService(h.household, h.household.root,
          url: 'https://share.test', key: 'k', host: 'share.example', httpClient: backend.client, watchLifecycle: false);
      await sharing.load();
      final c = await sharing.setUp(h.household.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
      sharing.presence.tuner = h.tuner;
      await sharing.attachChannels();
      // Connected: the first load (after the feed is live) is done.
      for (var i = 0; i < 100 && !backend.requests.contains('GET /rest/v1/now_watching'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(backend.realtimeOpen, isTrue);
    addTearDown(() async {
      await tester.runAsync(() async {
        h.household.sharing = null;
        sharing.presence.tuner = null;
        sharing.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
  }

  /// The TV screen, playing.
  Future<void> watch(WidgetTester tester) async {
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 30 && h.tuner.status != TunerStatus.playing; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(h.tuner.status, TunerStatus.playing);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }

  /// Presence lets go (as going to the background does), then playback ends.
  Future<void> finish(WidgetTester tester) async {
    final detached = sharing.presence.attach(null, null);
    await tester.pump();
    await detached;
    await h.end(tester);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A friend's row arrives over the feed.
  Future<void> arrives(WidgetTester tester, ShareProfile who, {String sharedId = 'sc-1'}) async {
    backend.friendWatching(who, title: 'Alpha', channel: 'Comedy', sharedId: sharedId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  List<String> lit(WidgetTester tester) => [
        for (final b in tester.widgetList<TvPointerButton>(find.byType(TvPointerButton)))
          if (b.highlighted) b.label,
      ];

  double cardOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.descendant(of: find.byType(FriendsWatchingCard), matching: find.byType(AnimatedOpacity)))
      .opacity;

  /// Nothing in [of] can take focus.
  void noFocus(Finder of) {
    for (final e in find.descendant(of: of, matching: find.byType(Focus)).evaluate()) {
      final node = (e.widget as Focus).focusNode;
      expect(node?.canRequestFocus ?? false, isFalse);
    }
    expect(find.ancestor(of: of.first, matching: find.byType(ExcludeFocus)).evaluate().isNotEmpty ||
        find.descendant(of: of.first, matching: find.byType(ExcludeFocus)).evaluate().isNotEmpty, isTrue);
  }

  testWidgets('"+n" after three avatars at four friends', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: FriendAvatarStack(friends: [_alex, _kim, _lee, _tyler])),
    ));
    expect(find.byType(ShareAvatar), findsNWidgets(3));
    expect(find.text('+1'), findsOneWidget);
    expect(watchingLabel(const [_alex, _kim, _lee, _tyler]), 'Alex and 3 friends are watching');
    expect(watchingTooLabel(const [_tyler]), 'Tyler is watching too');
  });

  testWidgets('the guide: a chip and "Tyler is watching" on the shared channel only; the D-pad and hover as before',
      (tester) async {
    await start(tester);
    await watch(tester);
    await arrives(tester, _tyler);
    await arrives(tester, _alex, sharedId: 'sc-not-here');
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byType(GuideView), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FriendAvatarStack), findsOneWidget, reason: 'one shared channel; Alex is on another');
    expect(find.text('Tyler is watching'), findsOneWidget);
    noFocus(find.byType(FriendAvatarStack));
    final guideFocus = FocusManager.instance.primaryFocus;

    // The D-pad goes down a row and back, as it always has.
    final rowOf = find.ancestor(of: find.byType(FriendAvatarStack), matching: find.byType(Row)).first;
    final chipTop = tester.getTopLeft(find.byType(FriendAvatarStack)).dy;
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus, guideFocus, reason: 'focus never lands on the chip');
    expect(tester.getTopLeft(find.byType(FriendAvatarStack)).dy, chipTop);

    // A mouse over the chip changes nothing.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(FriendAvatarStack)));
    addTearDown(mouse.removePointer);
    await mouse.moveBy(const Offset(2, 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(FocusManager.instance.primaryFocus, guideFocus);
    expect(rowOf, findsOneWidget);

    // Tyler stops: the chip goes, live.
    backend.friendStopped(_tyler);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FriendAvatarStack), findsNothing);
    expect(find.text('Tyler is watching'), findsNothing);
    await finish(tester);
  });

  testWidgets('the banner: the chip; the row is Guide, Menu, Sleep, Captions, Watch together, Watch privately; OK hides presence',
      (tester) async {
    await start(tester);
    await watch(tester);
    await arrives(tester, _tyler);
    await tester.pump(const Duration(seconds: 6));
    expect(backend.myWatching?['channel_name'], shared.displayName, reason: 'published while watching');
    expect(backend.myWatching?['shared_channel_id'], 'sc-1');
    final before = FocusManager.instance.primaryFocus;

    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.descendant(of: find.byType(ChannelBanner), matching: find.byType(FriendAvatarStack)), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(lit(tester), ['Guide']);
    for (final label in ['Menu', 'Sleep', 'Captions', 'Watch together', 'Watch privately', 'Watch privately']) {
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(lit(tester), [label]);
    }
    final sentBefore = backend.published.length;
    await key(tester, LogicalKeyboardKey.select);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
    expect(sharing.presence.private.value, isTrue);
    expect(lit(tester), ['Watching privately'], reason: 'the button shows its state');
    expect(backend.myWatching, isNull, reason: 'removed at once');
    expect(FocusManager.instance.primaryFocus, before, reason: 'the row is drawn by the TV screen');

    // A channel change stays private.
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.channelUp);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
    expect(h.tuner.channel?.id, isNot(shared.id));
    expect(backend.published.skip(sentBefore).whereType<Map>(), isEmpty, reason: 'nothing published while private');
    await finish(tester);
  });

  testWidgets('the card: "Tyler is watching too" for 5 seconds, never focused; a friend arriving shows it again',
      (tester) async {
    await start(tester, before: () => backend.friendWatching(_tyler, title: 'Alpha', channel: 'Comedy', sharedId: 'sc-1'));
    final focusBefore = FocusManager.instance.primaryFocus;
    await watch(tester);
    expect(find.text('Tyler is watching too'), findsOneWidget);
    expect(cardOpacity(tester), 1);
    noFocus(find.byType(FriendsWatchingCard));
    expect(FocusManager.instance.primaryFocus, isNot(focusBefore));
    final tvFocus = FocusManager.instance.primaryFocus;
    await tester.pump(const Duration(seconds: 3));
    expect(cardOpacity(tester), 1);
    await tester.pump(const Duration(seconds: 3));
    expect(cardOpacity(tester), 0, reason: 'gone after 5 seconds');

    await arrives(tester, _alex);
    expect(cardOpacity(tester), 1, reason: 'a friend starting to watch shows it again');
    expect(find.text('Alex and 1 friend are watching too'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, tvFocus);
    // The remote keeps working: Right brings up the banner as usual.
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Guide'), findsWidgets);
    await tester.pump(const Duration(seconds: 6));
    await finish(tester);
  });

  testWidgets('four friends: three avatars and "+1" in the card', (tester) async {
    await start(tester, before: () {
      for (final f in [_tyler, _alex, _kim, _lee]) {
        backend.friendWatching(f, title: 'Alpha', channel: 'Comedy', sharedId: 'sc-1');
      }
    });
    await watch(tester);
    final card = find.byType(FriendsWatchingCard);
    expect(find.descendant(of: card, matching: find.byType(ShareAvatar)), findsNWidgets(3));
    expect(find.descendant(of: card, matching: find.text('+1')), findsOneWidget);
    expect(find.text('Alex and 3 friends are watching too'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await finish(tester);
  });

  testWidgets('the notice on connect: once, over the picture, without focus', (tester) async {
    await start(tester, before: () {
      backend.friendWatching(_tyler, title: 'Alpha', channel: 'Comedy', sharedId: 'sc-1');
      backend.friendWatching(_kim, title: 'Beta', channel: 'Other', sharedId: 'sc-elsewhere');
    });
    await watch(tester);
    expect(find.text('Tyler is watching now'), findsOneWidget, reason: 'Kim isn\'t on a channel this profile has');
    final focus = FocusManager.instance.primaryFocus;
    expect(focus?.debugLabel, 'tv');
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Tyler is watching now'), findsNothing);
    expect(sharing.presence.notice.value, isNull);
    await finish(tester);
  });

  testWidgets('portrait: the chip and "Tyler is watching" in the list; Watch privately by touch', (tester) async {
    await start(tester, window: pixel8, platform: TargetPlatform.android, television: false);
    await watch(tester);
    await arrives(tester, _tyler);
    expect(find.text('Tyler is watching'), findsOneWidget);
    expect(find.byType(FriendAvatarStack), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    // The player's buttons come with a tap on the picture.
    await tester.tapAt(tester.getCenter(find.byType(TvPicture)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Watch privately'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
    expect(sharing.presence.private.value, isTrue);
    expect(backend.myWatching, isNull);
    await tester.pump(const Duration(seconds: 6));
    await finish(tester);
  });
}
