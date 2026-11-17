import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/party_schedule.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/sharing/channel_recipe.dart';
import 'package:nightingale_tv/sharing/party_reactions.dart';
import 'package:nightingale_tv/sharing/party_timeline.dart';
import 'package:nightingale_tv/sharing/watch_party.dart';

import 'fake_party.dart';
import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;
  late WatchParty party;
  late FakePartyBackend backend;
  final tyler = partyProfile('tyler', 'Tyler');
  final sam = partyProfile('sam', 'Sam');
  final alex = partyProfile('alex', 'Alex');
  const offset = Duration(milliseconds: 1500);

  final library = fakeLibrary(
    shows: {'Alpha': 6, 'Beta': 6},
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_party');
    app = await signedInApp(dir, library);
    log = [];
    app.client = FakeClient(log);
    player = FakePlayer(log);
    now = DateTime(2026, 11, 17, 20);
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
    WatchParty.checkEvery = const Duration(hours: 1);
    WatchParty.heartbeat = const Duration(hours: 1);
    WatchParty.stateEvery = const Duration(hours: 1);
    party = WatchParty(clock: () => now)..tuner = tuner;
  });

  tearDown(() async {
    party.dispose();
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();
  int backendMs(DateTime local) => local.add(offset).millisecondsSinceEpoch;
  MediaEntry episode(String show, int n) =>
      app.library.episodes.where((e) => e.seriesName == show).toList()[n];
  PartyItem item(MediaEntry e) => PartyItem.of(e, app.library)!;
  final zeta = PartyItem(
    const RecipeItem.episode(show: 0, season: 1, episode: 1, title: 'Pilot', runtime: Duration(minutes: 22)),
    const RecipeShow(ids: ['tvdb:999999'], name: 'Zeta'),
  );

  /// Sam's app joins Tyler's party, whose timeline is [tl].
  Future<void> joinAs(PartyTimeline tl) async {
    backend = FakePartyBackend(sam, () => now, offset: offset)
      ..joinInfo = PartyInfo(id: 'p1', host: 'tyler', channelName: '90s Sitcoms', state: tl.toJson(), ended: false, members: [tyler, sam]);
    await tuner.tune(app.channels.first);
    await settle();
    await party.attach(backend, app);
    expect(await party.join('p1'), PartyJoinStatus.ok);
    await settle();
  }

  /// A timeline for [e], [at] into it now.
  PartyTimeline playingAt(MediaEntry e, Duration at, {int seq = 1, PartyItem? next, PartyBreak? brk, PartyBy? by}) =>
      PartyTimeline(
        seq: seq,
        item: item(e),
        title: e.seriesName!,
        anchorMs: backendMs(now) - at.inMilliseconds,
        next: next,
        brk: brk,
        by: by,
      );

  void receive(String event, Map<String, Object?> payload) =>
      backend.onMessage!(event, Map<String, dynamic>.from(payload));

  group('a guest', () {
    /// The open lands [drift] off the host's [target] and plays on: two
    /// checks a second apart. Returns the host's position after them.
    Future<Duration> landOpen(Duration target, Duration drift) async {
      player.position = target + drift;
      party.debugCheck();
      await settle();
      now = now.add(const Duration(seconds: 1));
      target += const Duration(seconds: 1);
      player.position = target + drift;
      party.debugCheck();
      await settle();
      return target;
    }

    test('opens its own copy a little ahead of the host\'s position, by the backend clock', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      expect(party.clockOffset, offset);
      expect(tuner.partyGuest, isTrue);
      expect(tuner.segment?.item?.id, e.id);
      expect(player.opens.last.start, const Duration(minutes: 12) + WatchParty.initialLead);
      expect(player.opens.last.exact, isTrue);
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.channel?.name, contains('90s Sitcoms'));
    });

    test('an open that lands ahead holds the picture until the host gets there', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      // The open cost 2.6 s of its 3 s lead: 400 ms ahead.
      await landOpen(const Duration(minutes: 12), const Duration(milliseconds: 400));
      expect(party.debugHolding, isTrue);
      expect(player.log.last, 'pause');
      expect(party.sync, PartySync.catchingUp);
      expect(player.seeks, isEmpty, reason: 'a landing ahead is never a seek');
      expect(party.debugLead, const Duration(milliseconds: 2600 + 750), reason: 'what the open cost, and a margin');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(party.debugHolding, isFalse);
      expect(player.log.last, 'resume');
    });

    test('corrects drift: a seek above 2 s, a ±5% nudge from 250 ms, none within it', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      final target = await landOpen(const Duration(minutes: 12), Duration.zero);

      player.position = target + const Duration(milliseconds: 200);
      party.debugCheck();
      expect(party.debugSpeed, 1.0, reason: 'within 250 ms: left alone');
      expect(party.sync, PartySync.inSync);

      player.position = target + const Duration(milliseconds: 900);
      party.debugCheck();
      expect(party.debugSpeed, closeTo(0.95, 1e-9), reason: 'ahead: slower');
      expect(player.speeds.last, closeTo(0.95, 1e-9));

      player.position = target + const Duration(milliseconds: 150);
      party.debugCheck();
      expect(party.debugSpeed, closeTo(0.95, 1e-9), reason: 'nudging on until within 100 ms');

      player.position = target + const Duration(milliseconds: 60);
      party.debugCheck();
      expect(party.debugSpeed, 1.0);
      expect(player.speeds.last, 1.0);

      player.position = target - const Duration(milliseconds: 700);
      party.debugCheck();
      expect(party.debugSpeed, closeTo(1.05, 1e-9), reason: 'behind: faster');

      // A stall leaves it 3 s behind; it plays on from there.
      final seeks = player.seeks.length;
      now = now.add(const Duration(seconds: 1));
      player.position = target + const Duration(seconds: 1) - const Duration(seconds: 3);
      party.debugCheck();
      await settle();
      expect(player.seeks.length, seeks, reason: 'no seek while the picture stands still');
      now = now.add(const Duration(seconds: 1));
      player.position = target + const Duration(seconds: 2) - const Duration(seconds: 3);
      party.debugCheck();
      await settle();
      expect(player.seeks.length, seeks + 1);
      expect(player.seeks.last, target + const Duration(seconds: 2) + party.debugLead, reason: 'aimed ahead by what a move costs');
      expect(party.debugSpeed, 1.0);
      expect(party.sync, PartySync.catchingUp);
    });

    test('over 2 s ahead is a hold, not a seek', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      final target = await landOpen(const Duration(minutes: 12), Duration.zero);
      player.position = target + const Duration(seconds: 3);
      party.debugCheck();
      await settle();
      expect(party.debugHolding, isTrue);
      expect(player.seeks, isEmpty);
    });

    test('a slow link: the next seek aims ahead by what the open lost, and lands within a hold', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      // Each move costs 8 s here: the open (3 s ahead) lands 5 s behind.
      var target = await landOpen(const Duration(minutes: 12), const Duration(seconds: -5));
      const lead = Duration(seconds: 8, milliseconds: 750);
      expect(party.debugLead, lead);
      expect(player.seeks, [target + lead]);
      final aimed = player.seeks.single;
      // The player buffers for 8 seconds, reporting the seek's target, then
      // plays on from there.
      for (var i = 1; i <= 9; i++) {
        now = now.add(const Duration(seconds: 1));
        target += const Duration(seconds: 1);
        player.position = i < 9 ? aimed : aimed + const Duration(seconds: 1);
        party.debugCheck();
        await settle();
        if (i < 9) expect(party.debugHolding, isFalse, reason: 'waiting for the picture to move ($i s)');
      }
      expect(player.seeks.length, 1, reason: 'it landed ahead: no second seek');
      expect(party.debugHolding, isTrue, reason: '750 ms ahead: held');
      expect(party.debugLead, lead);
    });

    test('one fast move brings the lead down slowly: the next may be slow again', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      // The open cost all 3 s of its lead.
      var target = await landOpen(const Duration(minutes: 12), Duration.zero);
      expect(party.debugLead, const Duration(milliseconds: 3750));
      // 5 s behind and playing on: a seek, which costs 1 s and lands 2.75 s ahead.
      now = now.add(const Duration(seconds: 1));
      target += const Duration(seconds: 1);
      player.position = target - const Duration(seconds: 5);
      party.debugCheck();
      now = now.add(const Duration(seconds: 1));
      target += const Duration(seconds: 1);
      player.position = target - const Duration(seconds: 5);
      party.debugCheck();
      await settle();
      final aimed = player.seeks.single;
      expect(aimed, target + const Duration(milliseconds: 3750));
      for (var i = 1; i <= 2; i++) {
        now = now.add(const Duration(seconds: 1));
        target += const Duration(seconds: 1);
        player.position = aimed + Duration(seconds: i - 1);
        party.debugCheck();
        await settle();
      }
      expect(party.debugHolding, isTrue);
      // Cost 3 s * 0.8 = 2.4 s beats the 1 s just seen.
      expect(party.debugLead, const Duration(milliseconds: 2400 + 750));
    });

    test('a seek still buffering after 10 s is waited for, never repeated', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      await landOpen(const Duration(minutes: 12), const Duration(seconds: -5));
      final aimed = player.seeks.single;
      // The player reports the seek's target for 20 s while it buffers.
      for (var i = 1; i <= 20; i++) {
        now = now.add(const Duration(seconds: 1));
        player.position = aimed;
        party.debugCheck();
        await settle();
      }
      expect(player.seeks, [aimed], reason: 'another seek would only start the wait again');
      expect(party.sync, PartySync.catchingUp);
    });

    test('catching up after an open, 1.5 s behind is a seek; once in sync, the same drift is a nudge', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      // The open landed 1.5 s behind and plays on.
      var target = await landOpen(const Duration(minutes: 12), const Duration(milliseconds: -1500));
      expect(player.seeks, [target + party.debugLead], reason: 'still catching up: within 1 s by 10 s needs a seek');
      // In sync, then drifting 1.5 s: nudged, never seeked.
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 1));
        target += const Duration(seconds: 1);
        player.position = target - (i < 2 ? Duration.zero : const Duration(milliseconds: 1500));
        party.debugCheck();
        await settle();
      }
      expect(player.seeks.length, 1);
      expect(party.debugSpeed, closeTo(1.05, 1e-9));
    });

    test('a nudge the player ignores turns to seeking behind, and holding ahead', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 12)));
      var target = await landOpen(const Duration(minutes: 12), const Duration(milliseconds: -800));
      expect(party.debugSpeed, closeTo(1.05, 1e-9));
      // Passthrough audio: the speed changes nothing, the drift stays.
      Duration? seekedAt;
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 1));
        target += const Duration(seconds: 1);
        player.position = target - const Duration(milliseconds: 800);
        final seeks = player.seeks.length;
        party.debugCheck();
        await settle();
        if (player.seeks.length > seeks) seekedAt ??= target;
      }
      expect(party.debugNudgeWorks, isFalse);
      expect(party.debugSpeed, 1.0);
      expect(seekedAt, isNotNull, reason: 'it seeks once the nudge gave up');
      expect(player.seeks.first, seekedAt! + party.debugLead);
      expect(seekedAt - const Duration(minutes: 12), greaterThan(WatchParty.nudgeGivesUp));
      // Landed, then 800 ms ahead: a hold, as a nudge won't do.
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 1));
        target += const Duration(seconds: 1);
        player.position = target + (i < 2 ? Duration.zero : const Duration(milliseconds: 800));
        party.debugCheck();
        await settle();
      }
      expect(party.debugHolding, isTrue);
    });

    test('follows the host to the next program, and preloads it first', () async {
      tuner.preload = true;
      final a = episode('Alpha', 2), b = episode('Alpha', 3);
      // 20 seconds of A left.
      await joinAs(playingAt(a, a.runtime - const Duration(seconds: 20), next: item(b)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();
      expect(player.enqueued.map((q) => q.url.toString()).join(), contains(b.sourceId), reason: 'the next program is pre-opened');
      expect(player.enqueued.last.start, Duration.zero);
      // The host moves on.
      now = now.add(const Duration(seconds: 21));
      receive('timeline', playingAt(b, const Duration(seconds: 1), seq: 2).toJson());
      await settle();
      expect(tuner.segment?.item?.id, b.id);
    });

    test('a program it doesn\'t have shows the card, keeps reactions, and rejoins at the next match', () async {
      final b = episode('Beta', 1);
      await joinAs(PartyTimeline(
          seq: 1, item: zeta, title: 'Zeta', anchorMs: backendMs(now) - 60000, next: item(b)));
      expect(tuner.partyMissing, 'Zeta');
      expect(tuner.status, TunerStatus.offAir);
      party.debugCheck();
      expect(party.sync, PartySync.missing);
      expect(party.react('🍿'), isTrue);
      expect(backend.room.sent.last.$1, 'reaction');
      now = now.add(const Duration(minutes: 22));
      receive('timeline', playingAt(b, const Duration(seconds: 2), seq: 2).toJson());
      await settle();
      expect(tuner.partyMissing, isNull);
      expect(tuner.segment?.item?.id, b.id);
      expect(tuner.status, TunerStatus.playing);
    });

    test('from the card, the preloaded next program is kept when the host\'s timeline arrives before its picture', () async {
      tuner.preload = true;
      final b = episode('Beta', 1);
      // 20 seconds of Zeta left.
      await joinAs(PartyTimeline(
          seq: 1, item: zeta, title: 'Zeta', anchorMs: backendMs(now) - (const Duration(minutes: 22) - const Duration(seconds: 20)).inMilliseconds,
          next: item(b)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();
      expect(player.enqueued.last.url.toString(), contains(b.sourceId));
      final opens = player.opens.length;
      // The card's end: the player moves on to B, whose picture is slow.
      player.holdPicture = true;
      now = now.add(const Duration(seconds: 20));
      player.reachEnd();
      await settle();
      expect(tuner.segment?.item?.id, b.id);
      receive('timeline', playingAt(b, Duration.zero, seq: 2, brk: PartyBreak(backendMs(now) + 40000, 60000)).toJson());
      await settle();
      expect(player.opens.length, opens, reason: 'no second open of the same program');
      player.showPicture(Duration.zero);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.segment?.item?.id, b.id);
    });

    test('pauses where the host paused, and resumes with it', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      final at = backendMs(now);
      receive('timeline', PartyTimeline(
          seq: 2, item: item(e), title: 'Alpha', anchorMs: at - 300000, playing: false, pausedAt: at,
          by: (user: 'tyler', kind: 'pause')).toJson());
      await settle();
      expect(tuner.paused, isTrue);
      expect(player.paused, isTrue);
      now = now.add(const Duration(seconds: 30));
      receive('timeline', PartyTimeline(seq: 3, item: item(e), title: 'Alpha', anchorMs: backendMs(now) - 300000).toJson());
      await settle();
      expect(tuner.paused, isFalse);
      expect(player.paused, isFalse);
    });

    test('a pause and resume move nothing: the lead stays what the open taught', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      await landOpen(const Duration(minutes: 5), Duration.zero);
      final lead = party.debugLead;
      var at = backendMs(now);
      receive('timeline', PartyTimeline(
          seq: 2, item: item(e), title: 'Alpha', anchorMs: at - 301000, playing: false, pausedAt: at).toJson());
      await settle();
      now = now.add(const Duration(seconds: 10));
      receive('timeline', PartyTimeline(seq: 3, item: item(e), title: 'Alpha', anchorMs: backendMs(now) - 301000).toJson());
      await settle();
      // The picture goes on from where it was held, 120 ms behind.
      await landOpen(const Duration(seconds: 301), const Duration(milliseconds: -120));
      expect(party.debugLead, lead);
      expect(player.seeks, [const Duration(seconds: 301)], reason: 'only the pause placing the held picture');
    });

    test('a skip is corrected as its timeline arrives, not at the next check', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      final target = await landOpen(const Duration(minutes: 5), Duration.zero);
      receive('timeline', PartyTimeline(
          seq: 2, item: item(e), title: 'Alpha', anchorMs: backendMs(now) - (target + const Duration(seconds: 30)).inMilliseconds,
          by: (user: 'tyler', kind: 'forward')).toJson());
      await settle();
      expect(player.seeks, [target + const Duration(seconds: 30) + party.debugLead]);
    });

    test('pressing pause asks the host instead of pausing alone', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      party.act('pause');
      party.act('skip', by: const Duration(seconds: -10));
      await settle();
      expect(backend.room.sent.map((s) => '${s.$1}:${s.$2['kind']}:${s.$2['byMs']}'),
          containsAllInOrder(['action:pause:null', 'action:skip:-10000']));
      expect(tuner.paused, isFalse);
    });

    test('shows who did it when the action\'s timeline arrives', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      final toasts = <String>[];
      party.toasts.listen(toasts.add);
      receive('timeline', playingAt(e, const Duration(minutes: 7), seq: 2, by: (user: 'tyler', kind: 'forward')).toJson());
      receive('hello', {'by': 'alex', 'profile': alex.toRow()});
      receive('bye', {'by': 'alex'});
      await settle();
      expect(toasts, ['Tyler skipped', 'Alex joined', 'Alex left']);
    });

    test('a host silent for 60 seconds ends the party, back on the channel it had', () async {
      final e = episode('Alpha', 2);
      final before = app.channels.first;
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      final toasts = <String>[];
      party.toasts.listen(toasts.add);
      now = now.add(const Duration(seconds: 59));
      party.debugCheck();
      expect(party.active, isTrue);
      now = now.add(const Duration(seconds: 2));
      party.debugCheck();
      await settle();
      expect(backend.leaves.single, (party: 'p1', hostGone: true));
      expect(party.active, isFalse);
      expect(tuner.partyGuest, isFalse);
      expect(tuner.channel?.id, before.id);
      expect(toasts, ['Tyler ended the watch party']);
    });

    test('the host leaving ends it for the guest', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      receive('bye', {'by': 'tyler', 'ended': true});
      await settle();
      expect(party.active, isFalse);
      expect(tuner.partyGuest, isFalse);
    });

    test('one reaction per second per member, both ways', () async {
      final e = episode('Alpha', 2);
      await joinAs(playingAt(e, const Duration(minutes: 5)));
      final shown = <FloatingReaction>[];
      party.reactions.listen(shown.add);
      expect(party.react('😂'), isTrue);
      expect(party.react('😮'), isFalse, reason: 'within the second');
      receive('reaction', {'by': 'tyler', 'emoji': '❤️'});
      receive('reaction', {'by': 'tyler', 'emoji': '👏'});
      receive('reaction', {'by': 'stranger', 'emoji': '🍿'});
      now = now.add(const Duration(milliseconds: 1001));
      expect(party.react('😮'), isTrue);
      await settle();
      expect(shown.map((r) => '${r.from?.name}:${r.emoji}'), ['Sam:😂', 'Tyler:❤️', 'Sam:😮']);
    });
  });

  group('the host', () {
    late ScheduledProgram part;

    Future<void> host() async {
      final ch = app.channels.first;
      final schedule = app.scheduleFor(ch)!;
      part = schedule.playbackAt(now);
      for (var i = 0; i < 200 && (part.isBreak || part.item == null || part.duration < const Duration(minutes: 3)); i++) {
        part = schedule.playbackAt(part.end);
      }
      now = part.start.add(const Duration(minutes: 1));
      await tuner.tune(ch);
      await settle();
      backend = FakePartyBackend(tyler, () => now, offset: offset);
      await party.attach(backend, app);
      await party.start(friends: ['sam']);
      await settle();
      receive('hello', {'by': 'sam', 'profile': sam.toRow()});
      receive('hello', {'by': 'alex', 'profile': alex.toRow()});
      await settle();
    }

    PartyTimeline last() => PartyTimeline.fromJson(backend.room.timelines.last)!;

    test('publishes the program, its position on the backend clock, and the break after it', () async {
      await host();
      expect(backend.starts.single.invite, ['sam']);
      expect(tuner.partyHosting, isTrue);
      final tl = last();
      expect(tl.item?.key, item(part.item!).key);
      expect(tl.positionAt(now.add(offset).millisecondsSinceEpoch), part.positionAt(now));
      expect(tl.playing, isTrue);
      final after = app.scheduleFor(app.channels.first)!.playbackAt(part.end);
      if (after.isBreak) {
        expect(tl.brk?.startMs, part.end.add(offset).millisecondsSinceEpoch);
      }
    });

    test('applies actions in the order received: the last one wins', () async {
      await host();
      final sent = backend.room.timelines.length;
      receive('action', {'by': 'sam', 'kind': 'pause'});
      await settle();
      receive('action', {'by': 'alex', 'kind': 'resume'});
      await settle();
      expect(tuner.paused, isFalse);
      final out = backend.room.timelines.skip(sent).map(PartyTimeline.fromJson).toList();
      expect(out.map((t) => '${t!.by?.user}:${t.by?.kind}:${t.playing}'), ['sam:pause:false', 'alex:resume:true']);
    });

    test('a skip by a guest moves the host and goes out once it lands', () async {
      await host();
      receive('action', {'by': 'sam', 'kind': 'skip', 'byMs': -10000});
      await Future<void>.delayed(Tuner.seekDebounce + const Duration(milliseconds: 100));
      await settle();
      party.debugCheck();
      final tl = last();
      expect(tl.by, (user: 'sam', kind: 'back'));
      expect(tl.positionAt(now.add(offset).millisecondsSinceEpoch), part.positionAt(now) - const Duration(seconds: 10));
    });

    test('a heartbeat-free check sends nothing new while nothing changed', () async {
      await host();
      final sent = backend.room.timelines.length;
      now = now.add(const Duration(seconds: 3));
      party.debugCheck();
      expect(backend.room.timelines.length, sent);
    });

    test('leaving ends the party for everyone', () async {
      await host();
      await party.leave();
      expect(backend.room.sent.last.$1, 'bye');
      expect(backend.room.sent.last.$2['ended'], isTrue);
      expect(backend.leaves.single.party, 'p1');
      expect(tuner.partyHosting, isFalse);
    });
  });

  group('the party schedule', () {
    test('fills the host\'s break window with this member\'s commercials, to the second', () {
      final e = library.episodes.first;
      final anchor = DateTime(2026, 1, 1, 20);
      final s = PartySchedule(
        anchor: anchor,
        item: e,
        title: 'Alpha',
        hostRuntime: e.runtime,
        breakStart: anchor.add(const Duration(minutes: 8)),
        breakLength: const Duration(minutes: 2),
        clips: app.catalog,
        roles: app.planFor(app.channels.first).roles,
      );
      final before = s.playbackAt(anchor.add(const Duration(minutes: 7)));
      expect(before.item?.id, e.id);
      expect(before.positionAt(anchor.add(const Duration(minutes: 7))), const Duration(minutes: 7));
      expect(before.end, anchor.add(const Duration(minutes: 8)));
      var t = anchor.add(const Duration(minutes: 8));
      final clips = <ScheduledProgram>[];
      while (t.isBefore(anchor.add(const Duration(minutes: 10)))) {
        final c = s.playbackAt(t);
        expect(c.isBreak, isTrue);
        expect(c.item?.kind, MediaKind.commercial);
        clips.add(c);
        t = c.end;
      }
      expect(t, anchor.add(const Duration(minutes: 10)), reason: 'exactly the window');
      final after = s.playbackAt(anchor.add(const Duration(minutes: 11)));
      expect(after.item?.id, e.id);
      expect(after.positionAt(anchor.add(const Duration(minutes: 11))), const Duration(minutes: 9));
    });

    test('with no commercials the window is the break card', () {
      final e = library.episodes.first;
      final anchor = DateTime(2026, 1, 1, 20);
      final s = PartySchedule(
          anchor: anchor,
          item: e,
          title: 'Alpha',
          hostRuntime: e.runtime,
          breakStart: anchor.add(const Duration(minutes: 8)),
          breakLength: const Duration(minutes: 2));
      final b = s.playbackAt(anchor.add(const Duration(minutes: 9)));
      expect(b.isBreak, isTrue);
      expect(b.offline, isTrue);
      expect(b.end, anchor.add(const Duration(minutes: 10)));
    });

    test('a post-roll window leads into the next program', () {
      final a = library.episodes.first, b = library.episodes[1];
      final anchor = DateTime(2026, 1, 1, 20);
      final s = PartySchedule(
        anchor: anchor,
        item: a,
        title: 'Alpha',
        hostRuntime: a.runtime,
        breakStart: anchor.add(a.runtime),
        breakLength: const Duration(minutes: 3),
        nextItem: b,
        nextHostRuntime: b.runtime,
      );
      final next = s.playbackAt(anchor.add(a.runtime).add(const Duration(minutes: 3, seconds: 1)));
      expect(next.item?.id, b.id);
      expect(next.itemFrom, Duration.zero);
      expect(next.start, anchor.add(a.runtime).add(const Duration(minutes: 3)));
    });
  });

  test('a timeline survives its JSON', () {
    final e = library.episodes.first;
    final tl = PartyTimeline(
        seq: 4,
        item: PartyItem.of(e, library),
        title: 'Alpha',
        anchorMs: 1000,
        playing: false,
        pausedAt: 5000,
        brk: const PartyBreak(9000, 120000),
        next: zeta,
        by: (user: 'sam', kind: 'pause'));
    final back = PartyTimeline.fromJson(tl.toJson())!;
    expect(back.sameAs(tl), isTrue);
    expect(back.seq, 4);
    expect(back.by, (user: 'sam', kind: 'pause'));
    expect(back.next?.title, 'Zeta');
    expect(back.positionAt(99999), const Duration(milliseconds: 4000));
  });
}
