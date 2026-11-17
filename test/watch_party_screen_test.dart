import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';
import 'package:nightingale_tv/remote/remote_control.dart';
import 'package:nightingale_tv/sharing/party_timeline.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';
import 'package:nightingale_tv/sharing/watch_party.dart';
import 'package:nightingale_tv/ui/menu_screen.dart' show MenuScreen;
import 'package:nightingale_tv/ui/sharing_screen.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'fake_party.dart';
import 'portrait_harness.dart';
import 'sharing_fakes.dart';

const _tyler = ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl', avatarColor: 1);
const _alex = ShareProfile(userId: 'user-alex', name: 'Alex', handle: 'alex', avatar: 'cat');

/// Watch together on the TV screen and the portrait player (watch-together
/// 5.7): the D-pad through Watch together, the party row and the reactions;
/// the invite banner never taking focus; pointer and touch; leaving.
void main() {
  late PortraitHarness h;
  late FakeShareBackend backend;
  late FakePartyBackend partyBackend;
  late ShareService sharing;

  WatchParty party() => sharing.party;

  Future<void> start(WidgetTester tester,
      {Size window = const Size(1920, 1080), TargetPlatform platform = TargetPlatform.linux, bool television = true}) async {
    runAs(platform, television: television);
    setWindow(tester, window);
    h = await PortraitHarness.start(tester, sleep: true);
    WatchParty.checkEvery = const Duration(hours: 1);
    WatchParty.heartbeat = const Duration(hours: 1);
    WatchParty.stateEvery = const Duration(hours: 1);
    backend = FakeShareBackend()
      ..profile = {
        'user_id': FakeShareBackend.userId,
        'presence': 'off',
        'display_name': 'Mom',
        'handle': 'mom_tv',
        'avatar': 'fox',
        'avatar_color': 0,
        'station': '',
      }
      ..friends.addAll([_tyler, _alex]);
    partyBackend = FakePartyBackend(partyProfile(FakeShareBackend.userId, 'Mom'), DateTime.now);
    await tester.runAsync(() async {
      final ch = h.app.channels.firstWhere((c) => !c.isMusic);
      await h.app.setLastChannel(ch);
      await h.app.setPlayback(const PlaybackSettings(pauseAndRewind: false));
      sharing = h.household.sharing = ShareService(h.household, h.household.root,
          url: 'https://share.test', key: 'k', host: 'share.example', httpClient: backend.client, watchLifecycle: false)
        ..debugPartyBackend = partyBackend;
      await sharing.load();
      final c = await sharing.setUp(h.household.current!);
      await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
      sharing.party.tuner = h.tuner;
      await sharing.attachChannels();
      for (var i = 0; i < 100 && partyBackend.invitesChanged == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(partyBackend.invitesChanged, isNotNull, reason: 'the party is attached');
    addTearDown(() async {
      await tester.runAsync(() async {
        h.household.sharing = null;
        sharing.party.tuner = null;
        sharing.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    });
  }

  Future<void> settle(WidgetTester tester, {int ms = 60}) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  Future<void> watch(WidgetTester tester) async {
    await h.show(tester, const TvScreen());
    for (var i = 0; i < 30 && h.tuner.status != TunerStatus.playing; i++) {
      await settle(tester, ms: 10);
    }
    expect(h.tuner.status, TunerStatus.playing);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.runAsync(() async {
      if (party().active) await party().leave();
      party().hideBanner();
      await sharing.party.attach(null, null);
    });
    await tester.pump(const Duration(seconds: 4));
    await h.end(tester);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    if (k == LogicalKeyboardKey.goBack) {
      // The remote's Back button, as the other TV tests send it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.browserBack, platform: 'windows');
    } else {
      await tester.sendKeyEvent(k);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> lit(WidgetTester tester) => [
        for (final b in tester.widgetList<TvPointerButton>(find.byType(TvPointerButton)))
          if (b.highlighted) b.label.isEmpty ? 'reaction' : b.label,
      ];

  /// The label of the dialog button the focus is on.
  String? focusedButton() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx?.findAncestorWidgetOfExactType<TvButton>()?.label;
  }

  MediaEntry episode() => h.app.library.episodes.first;

  /// Tyler's party, playing [episode] 5 minutes in.
  PartyInfo tylersParty() => PartyInfo(
        id: 'p9',
        host: _tyler.userId,
        channelName: '90s Sitcoms',
        state: PartyTimeline(
          seq: 1,
          item: PartyItem.of(episode(), h.app.library),
          title: episode().seriesName!,
          anchorMs: DateTime.now().millisecondsSinceEpoch - 300000,
        ).toJson(),
        ended: false,
        members: const [_tyler],
      );

  /// Tyler invites this profile while it watches.
  Future<void> invited(WidgetTester tester) async {
    partyBackend
      ..joinInfo = tylersParty()
      ..invites = [PartyInvite(party: 'p9', host: _tyler, title: 'Alpha', channelName: '90s Sitcoms', at: DateTime.now())];
    await tester.runAsync(() async {
      partyBackend.invitesChanged!();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  Future<void> joined(WidgetTester tester) async {
    partyBackend.joinInfo = tylersParty();
    await tester.runAsync(() async {
      expect(await party().join('p9'), PartyJoinStatus.ok);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(h.tuner.partyGuest, isTrue);
  }

  testWidgets('D-pad: Watch together after Captions, the sheet, Start; then the party row and a reaction', (tester) async {
    await start(tester);
    await watch(tester);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(lit(tester), ['Guide']);
    for (final label in ['Menu', 'Sleep', 'Captions', 'Watch together']) {
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(lit(tester), [label]);
    }
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester, ms: 150);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alex'), findsOneWidget, reason: 'the friends to pick');
    expect(find.text('Tyler'), findsOneWidget);
    // Alex (first, by name) is focused: Select picks.
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    for (var i = 0; i < 6 && !{'Cancel', 'Get a link', 'Start'}.contains(focusedButton()); i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    for (var i = 0; i < 3 && focusedButton() != 'Start'; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusedButton(), 'Start');
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester, ms: 100);
    await tester.pump(const Duration(milliseconds: 300));
    expect(partyBackend.starts.single.invite, [_alex.userId]);
    expect(party().active, isTrue);
    expect(h.tuner.partyHosting, isTrue);
    expect(find.byType(PartyMembersChip), findsOneWidget);

    // The party row: Invite, six reactions, Leave, then the usual buttons.
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 12; i++) {
      await key(tester, LogicalKeyboardKey.arrowLeft);
    }
    expect(lit(tester), ['Invite']);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(lit(tester), ['reaction']);
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester);
    expect(partyBackend.room.sent.where((s) => s.$1 == 'reaction').single.$2['emoji'], '😂');
    expect(find.byType(ReactionImage), findsWidgets);
    for (var i = 0; i < 6; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(lit(tester), ['Leave']);
    await finish(tester);
  });

  testWidgets('Watch together sheet: one Down from the last friend reaches the buttons; Right walks them', (tester) async {
    await start(tester);
    await watch(tester);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 4; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(lit(tester), ['Watch together']);
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester, ms: 150);
    await tester.pump(const Duration(milliseconds: 300));
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byIcon(Icons.check_box), findsOneWidget, reason: 'Tyler picked');
    await key(tester, LogicalKeyboardKey.arrowDown);
    final first = focusedButton();
    expect(first, isNotNull, reason: 'one Down from the last friend is a button');
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.arrowLeft);
    }
    expect(focusedButton(), 'Cancel');
    final seen = <String?>[];
    for (var i = 0; i < 2; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
      seen.add(focusedButton());
    }
    expect(seen, ['Get a link', 'Start']);
    await key(tester, LogicalKeyboardKey.escape);
    await finish(tester);
  });

  testWidgets('the invite banner never takes focus; channel keys still tune; Up then Select joins', (tester) async {
    await start(tester);
    await watch(tester);
    final tvFocus = FocusManager.instance.primaryFocus;
    await invited(tester);
    expect(find.byType(PartyInviteBanner), findsOneWidget);
    expect(find.text('Tyler invited you to watch Alpha together'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, tvFocus, reason: 'shown without moving focus');

    final before = h.tuner.channel!.id;
    await key(tester, LogicalKeyboardKey.channelUp);
    await settle(tester);
    expect(h.tuner.channel!.id, isNot(before), reason: 'channel up still changes channels');
    expect(find.byType(PartyInviteBanner), findsOneWidget);

    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(lit(tester), ['Join']);
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester, ms: 150);
    expect(party().active, isTrue);
    expect(h.tuner.partyGuest, isTrue);
    expect(h.tuner.segment?.item?.id, episode().id);
    expect(find.byType(PartyInviteBanner), findsNothing);
    await finish(tester);
  });

  testWidgets('Back dismisses the banner; Not now leaves it listed', (tester) async {
    await start(tester);
    await watch(tester);
    await invited(tester);
    await key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(PartyInviteBanner), findsNothing);
    expect(party().invites.single.party, 'p9', reason: 'still in Sharing → Watch parties');
    await finish(tester);
  });

  testWidgets('pointer and touch: a mouse on a reaction, a tap on Join', (tester) async {
    await start(tester, platform: TargetPlatform.android);
    await watch(tester);
    await invited(tester);
    await tester.tap(find.text('Join'), kind: PointerDeviceKind.touch);
    await settle(tester, ms: 150);
    expect(party().active, isTrue);
    // The air mouse brings up the row; a click reacts.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 600));
    addTearDown(mouse.removePointer);
    await mouse.moveBy(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 300));
    final pop = find.byWidgetPredicate((w) => w is ReactionImage && w.emoji == '🍿');
    expect(pop, findsOneWidget);
    await tester.tap(pop, kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(partyBackend.room.sent.where((s) => s.$1 == 'reaction').single.$2['emoji'], '🍿');
    await finish(tester);
  });

  testWidgets('"Tyler paused" shows below the button row while it is up', (tester) async {
    await start(tester);
    await watch(tester);
    await joined(tester);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(find.byType(PartyMembersChip), findsOneWidget);
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(() async {
      partyBackend.onMessage!('timeline', PartyTimeline(
        seq: 2,
        item: PartyItem.of(episode(), h.app.library),
        title: episode().seriesName!,
        anchorMs: now - 300000,
        playing: false,
        pausedAt: now,
        by: (user: _tyler.userId, kind: 'pause'),
      ).toJson());
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(find.text('Tyler paused'), findsOneWidget);
    expect(tester.getRect(find.byType(TvToast)).top, greaterThan(tester.getRect(find.byType(PartyMembersChip)).bottom));
    await finish(tester);
  });

  testWidgets('a friend\'s reaction rises up the picture', (tester) async {
    await start(tester);
    await watch(tester);
    await joined(tester);
    final rising = find.descendant(of: find.byType(FloatingReactions), matching: find.byType(ReactionImage));
    expect(rising, findsNothing);
    await tester.runAsync(() async {
      partyBackend.onMessage!('reaction', {'by': _tyler.userId, 'emoji': '😂'});
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(rising, findsOneWidget);
    final at = tester.getRect(rising);
    final screen = tester.getRect(find.byType(TvScreen));
    expect(screen.overlaps(at), isTrue, reason: 'on screen: $at in $screen');
    await tester.pump(const Duration(seconds: 3));
    expect(rising, findsNothing);
    await finish(tester);
  });

  testWidgets('back from the Menu, a guest is still in the party', (tester) async {
    await start(tester);
    await watch(tester);
    await joined(tester);
    await key(tester, LogicalKeyboardKey.keyM);
    await settle(tester, ms: 100);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(MenuScreen))).pop();
    await settle(tester, ms: 150);
    await tester.pump(const Duration(milliseconds: 400));
    expect(party().active, isTrue, reason: 'the party channel is not in the lineup, and that is fine');
    expect(h.tuner.partyGuest, isTrue);
    expect(partyBackend.leaves, isEmpty);
    await finish(tester);
  });

  testWidgets('a channel tapped on the phone remote asks "Leave the watch party?" first', (tester) async {
    await start(tester);
    h.household.remote = RemoteControl(h.household, firewallCheck: FirewallCheck(linux: false), isThisDevice: (_) async => false);
    addTearDown(() => h.household.remote = null);
    await watch(tester);
    await joined(tester);
    final tune = h.household.remote!.tuneRequest;
    expect(tune, isNotNull, reason: 'the TV screen takes the phone\'s channel taps');
    final other = h.app.channels.where((c) => !c.isMusic).last;
    late Future<bool> asked;
    await tester.runAsync(() async {
      asked = tune!(other.number);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave the watch party?'), findsOneWidget);
    expect(focusedButton(), 'Stay');
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester);
    expect(await tester.runAsync(() => asked), isFalse);
    expect(party().active, isTrue);
    await finish(tester);
  });

  testWidgets('Back asks "Leave the watch party?": Stay first, Leave goes back to the channel before', (tester) async {
    await start(tester, platform: TargetPlatform.android);
    await watch(tester);
    final before = h.tuner.channel!.id;
    await joined(tester);
    await key(tester, LogicalKeyboardKey.goBack);
    expect(find.text('Leave the watch party?'), findsOneWidget);
    expect(focusedButton(), 'Stay', reason: 'an accidental Back then Select stays');
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester);
    expect(party().active, isTrue);
    expect(find.text('Leave the watch party?'), findsNothing);

    // A channel change asks too.
    await key(tester, LogicalKeyboardKey.channelDown);
    expect(find.text('Leave the watch party?'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedButton(), 'Leave');
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester, ms: 150);
    expect(party().active, isFalse);
    expect(h.tuner.partyGuest, isFalse);
    expect(partyBackend.leaves.single.party, 'p9');
    expect(h.tuner.channel!.id, isNot('party'));
    expect(h.app.channels.any((c) => c.id == h.tuner.channel!.id), isTrue);
    expect(before, isNotEmpty);
    await finish(tester);
  });

  testWidgets('portrait: the party bar under the player, reactions by touch, Leave asks', (tester) async {
    await start(tester, window: const Size(1080, 2340), platform: TargetPlatform.android, television: false);
    await watch(tester);
    await joined(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PartyMembersChip), findsOneWidget);
    final popcorn = find.byWidgetPredicate((w) => w is ReactionImage && w.emoji == '🍿');
    expect(popcorn, findsOneWidget);
    await tester.tap(popcorn);
    await settle(tester);
    expect(partyBackend.room.sent.where((s) => s.$1 == 'reaction').single.$2['emoji'], '🍿');
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave the watch party?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TvButton, 'Leave'));
    await settle(tester, ms: 150);
    expect(party().active, isFalse);
    await finish(tester);
  });

  testWidgets('no Watch together on a live channel or without a link', (tester) async {
    await start(tester);
    await watch(tester);
    expect(party().canStartOn(h.tuner.channel), isTrue);
    final live = Channel.live(ref: const LiveRef(sourceId: 'src', key: 'k1'), number: 900, name: 'Live One', icon: const ChannelIcon.builtin('tv'));
    expect(party().canStartOn(live), isFalse);
    await tester.runAsync(() => sharing.party.attach(null, null));
    expect(party().canStartOn(h.tuner.channel), isFalse);
    await finish(tester);
  });
}
