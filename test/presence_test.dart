import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_schedule.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/sharing/presence.dart';
import 'package:nightingale_tv/sharing/share_client.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

const _tyler = ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler', avatar: 'owl');
const _alex = ShareProfile(userId: 'user-alex', name: 'Alex', handle: 'alex');
const _kim = ShareProfile(userId: 'user-kim', name: 'Kim', handle: 'kim');
const _lee = ShareProfile(userId: 'user-lee', name: 'Lee', handle: 'lee');

/// The presence part of the backend, in memory (friend-presence 3.4).
class FakePresenceBackend implements PresenceBackend {
  @override
  bool started = true;
  @override
  String? userId = 'user-me';

  String? presence = 'friends';
  final friendList = <ShareProfile>[_tyler, _alex, _kim, _lee];

  /// Every publish in order (null: a clear).
  final sent = <Watching?>[];

  /// Fails every publish while set.
  bool offline = false;
  final rows = <PresenceRow>[];

  /// The backend's clock, and each sample's round trip.
  DateTime Function() serverClock = () => DateTime.now().toUtc();
  final rtts = <Duration>[];
  bool listening = false;
  void Function(PresenceRow row)? _onRow;

  void push(PresenceRow row) {
    rows
      ..removeWhere((r) => r.userId == row.userId)
      ..add(row);
    _onRow?.call(row);
  }

  @override
  Future<ShareProfile?> profile() async =>
      ShareProfile(userId: userId!, name: 'Sam', handle: 'sam', presence: presence);

  @override
  Future<FriendsList> friends() async => FriendsList(friendList, const []);

  @override
  Future<void> setPresence(String value) async => presence = value;

  @override
  Future<void> setWatching(Watching? w) async {
    if (offline) throw const ShareUnavailable('offline');
    sent.add(w);
  }

  @override
  Future<List<PresenceRow>> watchingRows() async => [...rows];

  @override
  Future<({DateTime server, Duration rtt})> serverTime() async {
    final rtt = rtts.isEmpty ? Duration.zero : rtts.removeAt(0);
    return (server: serverClock(), rtt: rtt);
  }

  @override
  Future<void> watchRows(
      {required void Function(PresenceRow row) onRow,
      required void Function() onReady,
      required void Function(Object error) onError}) async {
    listening = true;
    _onRow = onRow;
    scheduleMicrotask(onReady);
  }

  @override
  Future<void> stopWatchingRows() async {
    listening = false;
    _onRow = null;
  }
}

PresenceRow _row(ShareProfile who, {String? title = 'Show', String? channel = 'Channel', String? shared, required DateTime at}) =>
    PresenceRow(userId: who.userId, title: title, channelName: channel, sharedChannelId: shared, startedAt: at, updatedAt: at);

void main() {
  late Directory dir;
  late AppState app;
  late FakePlayer player;
  late Tuner tuner;
  late FakePresenceBackend backend;
  late Presence presence;
  late DateTime now;
  var started = false;

  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  Future<void> settle() => pumpEventQueue();

  Future<void> start({int? maxRatingRank}) async {
    app = await signedInApp(dir, library, maxRatingRank: maxRatingRank);
    app.client = FakeClient([]);
    player = FakePlayer([]);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
    presence = Presence()..tuner = tuner;
    started = true;
    await presence.attach(backend, app);
    await settle();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_presence');
    backend = FakePresenceBackend();
    Presence.heartbeat = const Duration(minutes: 2);
  });

  tearDown(() async {
    if (!started) return dir.delete(recursive: true);
    started = false;
    presence.dispose();
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  /// The last thing published, or null for a clear.
  Watching? last() => backend.sent.isEmpty ? null : backend.sent.last;

  group('publishing (D2)', () {
    test('a tune publishes the show and channel; a channel change publishes again; stop clears', () async {
      await start();
      final ch = app.channels.first;
      await tuner.tune(ch);
      await settle();
      expect(last()?.channelName, ch.displayName);
      expect(last()?.title, tuner.program!.item!.seriesName, reason: 'the show, not the episode');
      expect(last()?.sharedChannelId, isNull, reason: 'not a shared channel');
      final count = backend.sent.length;
      await tuner.channelUp();
      await settle();
      expect(backend.sent.length, greaterThan(count));
      expect(last()?.channelName, tuner.channel!.displayName);
      await tuner.stop();
      await settle();
      expect(backend.sent.last, isNull, reason: 'stopped: cleared');
    });

    test('a shared channel publishes its shared id', () async {
      await start();
      final ch = app.channels.first;
      await app.setShareLink(ch, const ShareLink(id: 'sc-1', role: ShareRole.out, version: 1));
      await tuner.tune(app.channelById(ch.id)!);
      await settle();
      expect(last()?.sharedChannelId, 'sc-1');
    });

    test('a commercial break keeps the program\'s title', () async {
      await start();
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final schedule = app.scheduleFor(ch)! as ChannelSchedule;
      var seg = schedule.playbackAt(now);
      for (var i = 0; i < 400 && !seg.isBreak; i++) {
        seg = schedule.playbackAt(seg.end);
      }
      expect(seg.isBreak, isTrue);
      now = seg.start.add(const Duration(seconds: 2));
      await tuner.tune(ch);
      await settle();
      expect(tuner.inBreak, isTrue);
      expect(last()?.title, seg.program?.seriesName ?? tuner.program!.item!.seriesName);
      expect(last()?.title, isNot(contains('Commercial')));
    });

    test('nothing is published while Off, before the question, or while private', () async {
      backend.presence = 'off';
      await start();
      await tuner.tune(app.channels.first);
      await settle();
      expect(backend.sent.whereType<Watching>(), isEmpty);

      await presence.setSetting(PresenceSetting.friends);
      await settle();
      expect(last(), isNotNull);

      presence.private.value = true;
      await settle();
      expect(last(), isNull, reason: 'Watch privately clears at once');
      final at = backend.sent.length;
      for (var i = 0; i < 3; i++) {
        await tuner.channelUp();
        await settle();
      }
      expect(backend.sent.skip(at).whereType<Watching>(), isEmpty, reason: 'three channel changes, nothing published');

      presence.private.value = false;
      await settle();
      expect(last()?.channelName, tuner.channel!.displayName);

      await presence.setSetting(PresenceSetting.off);
      await settle();
      expect(last(), isNull, reason: 'Off clears at once');
      expect(backend.presence, 'off');
    });

    test('a profile not asked yet publishes nothing', () async {
      backend.presence = null;
      await start();
      await tuner.tune(app.channels.first);
      await settle();
      expect(presence.setting, isNull);
      expect(backend.sent.whereType<Watching>(), isEmpty);
    });

    test('a kid profile never publishes', () async {
      await start(maxRatingRank: 3);
      await tuner.tune(app.channels.first);
      await settle();
      expect(backend.sent.whereType<Watching>(), isEmpty);
    });

    test('Watch privately starts off: it lives in memory only', () async {
      await start();
      final fresh = Presence();
      expect(fresh.private.value, isFalse);
      fresh.dispose();
    });

    test('going to the background, sleep or another profile: cleared before the client stops', () async {
      await start();
      await tuner.tune(app.channels.first);
      await settle();
      expect(last(), isNotNull);
      await presence.clearBeforeStop();
      expect(last(), isNull);
      backend.started = false;
      await presence.attach(null, null);
      final at = backend.sent.length;
      await tuner.channelUp();
      await settle();
      expect(backend.sent.length, at, reason: 'detached: nothing sent');
    });

    test('a clear that failed offline is sent on the next connect', () async {
      await start();
      await tuner.tune(app.channels.first);
      await settle();
      backend.offline = true;
      await presence.clearBeforeStop();
      await presence.attach(null, null);
      await tuner.stop();
      await settle();
      backend.offline = false;
      final at = backend.sent.length;
      await presence.attach(backend, app);
      await settle();
      expect(backend.sent.skip(at), [null], reason: 'the retried clear');
    });

    test('a heartbeat refreshes what is published', () async {
      Presence.heartbeat = const Duration(milliseconds: 40);
      await start();
      await tuner.tune(app.channels.first);
      await settle();
      final at = backend.sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(backend.sent.length, greaterThan(at + 1));
      expect(backend.sent.skip(at).every((w) => w?.channelName == app.channels.first.displayName), isTrue);
      await tuner.stop();
      await settle();
      final stopped = backend.sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(backend.sent.length, stopped, reason: 'no heartbeat once cleared');
    });
  });

  group('reading friends (D3)', () {
    test('first load and live rows; a friend on a shared channel; four friends', () async {
      final server = DateTime.now().toUtc();
      backend.rows.add(_row(_tyler, shared: 'sc-1', at: server));
      await start();
      expect(presence.watching.map((w) => w.friend.name), ['Tyler']);
      expect(presence.of('user-tyler')!.line, 'Watching Show on Channel');
      for (final f in [_alex, _kim, _lee]) {
        backend.push(_row(f, shared: 'sc-1', at: server));
      }
      expect(presence.on('sc-1').length, 4);
      expect(presence.on('sc-2'), isEmpty);
      backend.push(PresenceRow(userId: _alex.userId, updatedAt: server));
      expect(presence.on('sc-1').map((f) => f.name), ['Kim', 'Lee', 'Tyler'], reason: 'Alex stopped');
    });

    test('a live channel without a guide shows only the channel', () async {
      await start();
      backend.push(_row(_tyler, title: null, channel: 'KTVU', at: DateTime.now().toUtc()));
      expect(presence.of('user-tyler')!.line, 'Watching KTVU');
    });

    test('rows older than 5 minutes by the backend clock are ignored, whatever the device clock says', () async {
      // The device runs an hour slow.
      backend.serverClock = () => DateTime.now().toUtc().add(const Duration(hours: 1));
      backend.rtts.addAll(const [Duration(milliseconds: 900), Duration(milliseconds: 40), Duration(milliseconds: 500)]);
      await start();
      expect(presence.clockOffset.inMinutes, inInclusiveRange(59, 60));
      final server = backend.serverClock();
      backend.push(_row(_tyler, at: server.subtract(const Duration(minutes: 4))));
      backend.push(_row(_alex, at: server.subtract(const Duration(minutes: 6))));
      expect(presence.watching.map((w) => w.friend.name), ['Tyler']);
    });

    test('the clock offset keeps the sample with the shortest round trip', () async {
      var calls = 0;
      final base = DateTime.utc(2026, 11, 16, 12);
      // Each sample's server time is 10 s apart; the second has the shortest trip.
      backend.serverClock = () => base.add(Duration(seconds: 10 * calls++));
      backend.rtts.addAll(const [Duration(milliseconds: 800), Duration(milliseconds: 20), Duration(milliseconds: 600)]);
      await start();
      final serverNow = presence.serverNow();
      // The second sample (base + 10 s, + 10 ms) taken a moment ago.
      expect(serverNow.difference(base.add(const Duration(seconds: 10))).inMilliseconds, inInclusiveRange(0, 2000));
    });

    test('the notice on connect names friends on shared channels the profile has, once', () async {
      final server = DateTime.now().toUtc();
      backend.rows.addAll([
        _row(_tyler, shared: 'sc-1', at: server),
        _row(_alex, shared: 'sc-1', at: server),
        _row(_kim, shared: 'sc-other', at: server),
        _row(_lee, at: server),
      ]);
      app = await signedInApp(dir, library);
      await app.setShareLink(app.channels.first, const ShareLink(id: 'sc-1', role: ShareRole.incoming, owner: 'user-tyler'));
      tuner = Tuner(app, player: FakePlayer([]), clock: () => now)
        ..prefetch = false
        ..preload = false;
      now = DateTime.now();
      presence = Presence()..tuner = tuner;
      started = true;
      await presence.attach(backend, app);
      await settle();
      expect(presence.notice.value, 'Alex and Tyler are watching now');
      presence.notice.value = null;
      backend.started = false;
      await presence.attach(null, null);
      backend.started = true;
      await presence.attach(backend, app);
      await settle();
      expect(presence.notice.value, isNull, reason: 'once per app start');
    });

    test('Realtime closes when the client goes (background, sleep)', () async {
      await start();
      expect(backend.listening, isTrue);
      backend.started = false;
      await presence.attach(null, null);
      await settle();
      expect(backend.listening, isFalse);
    });
  });

  group('titles (D2)', () {
    MediaEntry entry(MediaKind kind, {String title = 'Pilot', String? series}) =>
        MediaEntry(id: 'x', kind: kind, title: title, seriesName: series, runtime: const Duration(minutes: 22));
    ScheduledProgram slot(MediaEntry? e, {bool live = false}) => ScheduledProgram(
        item: e, start: DateTime(2026), end: DateTime(2026).add(const Duration(minutes: 30)), isLive: live);

    test('episodes give the show, movies the title', () {
      expect(presenceTitle(slot(entry(MediaKind.episode, series: 'The Office'))), 'The Office');
      expect(presenceTitle(slot(entry(MediaKind.movie, title: 'Heat'))), 'Heat');
    });

    test('an episode with no show name gives no title, never the episode\'s', () {
      expect(presenceTitle(slot(entry(MediaKind.episode, title: 'Pilot'))), isNull);
      expect(presenceTitle(slot(entry(MediaKind.episode, title: 'Pilot', series: SeriesEntry.unknownName))), isNull);
    });

    test('off the air and music give no title', () {
      expect(presenceTitle(slot(null)), isNull);
      expect(presenceTitle(slot(entry(MediaKind.song, title: 'Song'))), isNull);
      expect(presenceTitle(null), isNull);
    });

    test('live channels give the guide\'s programme, or nothing without a guide', () {
      final start = DateTime(2026, 11, 16, 12);
      final schedule = LiveSchedule(channelId: 'live-1', channelName: 'KTVU', programmes: [
        LiveProgramme(title: 'Evening News', start: start, end: start.add(const Duration(hours: 1))),
      ]);
      expect(presenceTitle(schedule.programAt(start.add(const Duration(minutes: 5)))), 'Evening News');
      expect(presenceTitle(schedule.programAt(start.add(const Duration(hours: 3)))), isNull, reason: 'No guide information');
    });
  });
}
