import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';

import '../fake_playback.dart';
import '../fixtures.dart';
import 'live_lineup_test.dart' show Provider, settle;
import 'live_tuner_test.dart' show LiveClient;

// live-channel-repair 3 and 4: channels the server gave new keys keep their
// place; a channel the server no longer has says so.

/// A channel list as the server has it: [prefix] stands for the ids it
/// gives (a re-added tuner gives new ones).
List<LiveChannelInfo> lineup(String prefix, [List<(String?, String)>? channels]) => [
      for (final (number, name) in channels ?? const [('2.1', 'WXYZ'), ('4.1', 'KABC'), ('7.1', 'KQED')])
        LiveChannelInfo(key: '$prefix-${name.toLowerCase()}-${number ?? 'x'}', name: name, number: number, guideId: name),
    ];

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late LiveClient client;
  late FakePlayer player;
  late Tuner tuner;
  late LiveSource server;
  final captured = <(String, bool)>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live_repair');
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 10, 'Beta': 8}));
    log = [];
    client = LiveClient(log);
    client.tv.channelList
      ..clear()
      ..addAll(lineup('old'));
    app.client = client;
    player = FakePlayer(log);
    tuner = Tuner(app, player: player, clock: DateTime.now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1)
      ..liveRetries = const [Duration(milliseconds: 10), Duration(milliseconds: 20)]
      ..liveRetryEvery = const Duration(milliseconds: 40)
      ..liveStartTimeout = const Duration(milliseconds: 500)
      ..liveGoneRefreshTimeout = const Duration(seconds: 2);
    server = LiveSource(id: 'srv', kind: LiveSourceKind.server, name: 'Den Live TV', serverKind: ServerKind.jellyfin);
    await app.addLiveSource(server, await client.tv.channels());
    await settle(app, server);
    captured.clear();
    ErrorReports.debugOnCapture = (e, area, expected) => captured.add(('${e.runtimeType}:$area', expected));
  });

  tearDown(() async {
    ErrorReports.debugOnCapture = null;
    PlatformInfo.debugOverride = null;
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  List<Channel> live() => [for (final c in app.allChannels) if (c.isLive) c];
  Channel byName(String name) => live().firstWhere((c) => c.name == name);

  /// The server re-creates its channels as [channels].
  void serverHas(List<LiveChannelInfo> channels) => client.tv.channelList
    ..clear()
    ..addAll(channels);

  Future<void> refresh() async {
    await app.refreshLiveSource(server);
    await settle(app, server);
  }

  group('re-keying at refresh', () {
    test('every id changes at once: numbers, names, hide, favorites and groups stay', () async {
      final before = {for (final c in live()) c.name: c.number};
      final group = await app.createGroup('Locals');
      await app.setInGroup(group, byName('WXYZ'), true);
      await app.updateChannel(byName('WXYZ'), favorite: true);
      await app.updateChannel(byName('KQED'), hidden: true);
      await app.setLastChannel(byName('KABC'));

      serverHas(lineup('new'));
      await refresh();

      expect({for (final c in live()) c.name: c.number}, before);
      expect([for (final c in live()) c.live!.key], everyElement(startsWith('new-')));
      expect(byName('WXYZ').favorite, isTrue);
      expect(byName('KQED').hidden, isTrue);
      expect(app.settings.groups.firstWhere((g) => g.id == group.id).channelIds, [byName('WXYZ').id]);
      expect(app.settings.lastChannelId, byName('KABC').id);
      expect(server.departed, isEmpty);
      // Saved: a fresh start has them under the new keys.
      final saved = jsonDecode(await File('${dir.path}/live_sources.json').readAsString()) as Map;
      final chosen = ((saved['sources'] as List).single as Map)['chosen'] as Map;
      expect(chosen.keys, everyElement(startsWith('new-')));
      expect((chosen['new-wxyz-2.1'] as Map)['sourceName'], 'WXYZ');
    });

    test("a channel the user renamed still matches on the server's name", () async {
      await app.updateChannel(byName('KABC'), name: 'My Seven');
      serverHas(lineup('new'));
      await refresh();
      final ch = live().firstWhere((c) => c.live!.key == 'new-kabc-4.1');
      expect(ch.name, 'My Seven');
    });

    test('renumbered and renamed at once: it leaves, and the row counts it', () async {
      serverHas([...lineup('old').take(2), ...lineup('new', [('9.1', 'PBS')])]);
      await refresh();
      expect(live().map((c) => c.name), isNot(contains('KQED')));
      expect(server.departed.keys, ['old-kqed-7.1']);
      // The new channel isn't chosen by itself.
      expect(live().map((c) => c.name), isNot(contains('PBS')));
    });

    test('two new channels with the same name and no number: no match by name alone', () async {
      serverHas(lineup('old', [(null, 'Local')]));
      await refresh();
      await app.chooseLiveChannels(server, {'old-local-x'});
      await settle(app, server);
      expect(live().where((c) => c.name == 'Local'), hasLength(1));

      serverHas(const [
        LiveChannelInfo(key: 'new-local-x', name: 'Local'),
        LiveChannelInfo(key: 'new-local-y', name: 'Local'),
      ]);
      await refresh();
      expect(live().where((c) => c.name == 'Local'), isEmpty);
      expect(server.departed.keys, contains('old-local-x'));
    });

    test('a channel that left comes back under a new id within 30 days', () async {
      await app.updateChannel(byName('KQED'), favorite: true);
      final number = byName('KQED').number;
      serverHas(lineup('old').take(2).toList());
      await refresh();
      expect(server.departed.keys, ['old-kqed-7.1']);

      serverHas([...lineup('old').take(2), ...lineup('new', [('7.1', 'KQED')])]);
      await refresh();
      final back = byName('KQED');
      expect(back.live!.key, 'new-kqed-7.1');
      expect(back.number, number);
      expect(back.favorite, isTrue);
      expect(server.departed, isEmpty);
    });

    test("saved data from 1.2.4 (no source number or name) re-keys from the cached list", () async {
      for (final s in server.chosen.values) {
        s
          ..sourceName = null
          ..sourceNumber = null;
      }
      final before = {for (final c in live()) c.name: c.number};
      serverHas(lineup('new'));
      await refresh();
      expect({for (final c in live()) c.name: c.number}, before);
    });

    test('a channel entry that fails to read keeps the cached list in place', () async {
      final before = [for (final c in live()) c.id];
      client.tv.failChannels = true;
      await refresh();
      expect([for (final c in live()) c.id], before);
      expect(app.live.entryFor(server).state.lastError, "Couldn't read Den Live TV's channel list");
    });
  });

  test('an M3U source is never re-keyed', () async {
    final provider = _RekeyingProvider();
    await provider.start();
    addTearDown(() => provider.server.close(force: true));
    final m3u = LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'IPTV', playlistUrl: '${provider.base}/list.m3u');
    await app.addLiveSource(m3u, await app.live.clientFor(m3u)!.fetchChannels());
    await settle(app, m3u);
    provider.prefix = 'other';
    await app.refreshLiveSource(m3u);
    await settle(app, m3u);
    expect(m3u.chosen, isEmpty);
    expect(m3u.departed, hasLength(3));
  });

  group('404 on open', () {
    test('the channel moved: it plays under its new key, with no stand-by card and no report', () async {
      final ch = byName('WXYZ');
      final statuses = <TunerStatus>[];
      tuner.addListener(() => statuses.add(tuner.status));
      client.tv.goneFor = {'old-wxyz-2.1'};
      serverHas(lineup('new'));
      await tuner.tune(ch);
      await pumpEventQueue();
      for (var i = 0; i < 100 && tuner.status != TunerStatus.playing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.channel!.live!.key, 'new-wxyz-2.1');
      expect(log.where((l) => l.startsWith('live-open')), ['live-open:old-wxyz-2.1', 'live-open:new-wxyz-2.1']);
      expect(statuses, isNot(contains(TunerStatus.error)));
      expect(statuses, isNot(contains(TunerStatus.standby)));
      expect(tuner.liveMessage, isNull);
      expect(captured, isEmpty);

      // The next tune opens it directly.
      await tuner.tune(app.allChannels.firstWhere((c) => !c.isLive));
      log.clear();
      await tuner.tune(byName('WXYZ'));
      await pumpEventQueue();
      expect(log.where((l) => l.startsWith('live-open')), ['live-open:new-wxyz-2.1']);
    });

    test('the channel was deleted: the card, no reconnect, no report, and Channel Up goes on', () async {
      final ch = byName('KABC');
      client.tv.goneFor = {'old-kabc-4.1'};
      serverHas([lineup('old')[0], lineup('old')[2]]);
      await tuner.tune(ch);
      for (var i = 0; i < 100 && tuner.status != TunerStatus.error; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(tuner.status, TunerStatus.error);
      expect(tuner.liveMessage, 'This channel is no longer on ${app.session!.serverName}');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(log.where((l) => l.startsWith('live-open')), ['live-open:old-kabc-4.1'], reason: 'no retries');
      expect(captured, isEmpty);
      expect(server.departed.keys, ['old-kabc-4.1']);

      await tuner.channelUp();
      await pumpEventQueue();
      expect(tuner.channel!.name, 'KQED');
      expect(tuner.channel!.number, greaterThan(ch.number));
    });

    test("the refresh doesn't answer in time: the card", () async {
      tuner.liveGoneRefreshTimeout = const Duration(milliseconds: 50);
      client.tv.goneFor = {'old-wxyz-2.1'};
      client.tv.channelsHold = Completer();
      await tuner.tune(byName('WXYZ'));
      for (var i = 0; i < 100 && tuner.status != TunerStatus.error; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(tuner.liveMessage, 'This channel is no longer on ${app.session!.serverName}');
      // The late refresh finishes before the test's folder goes.
      client.tv.channelsHold!.complete();
      await settle(app, server);
    });

    test('a 404 again under the new key is reported', () async {
      client.tv.goneFor = {'old-wxyz-2.1', 'new-wxyz-2.1'};
      serverHas(lineup('new'));
      await tuner.tune(byName('WXYZ'));
      for (var i = 0; i < 100 && tuner.status != TunerStatus.error; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(tuner.liveMessage, 'This channel is no longer on ${app.session!.serverName}');
      expect(captured, [('LiveTvException:playback', false)]);
    });
  });

  test("Emby's recorded 404 on PlaybackInfo is a channel gone", () {
    final e = LiveTvException.fromServer(
        ServerException('Server error 404 on /Items/<redacted>/PlaybackInfo.', statusCode: 404));
    expect(e.failure, LiveFailure.channelGone);
  });
}

/// An IPTV provider whose tvg-ids change while numbers and names stay.
class _RekeyingProvider extends Provider {
  var prefix = 'ch';

  @override
  String playlist() => [
        '#EXTM3U',
        for (final n in channels) ...[
          '#EXTINF:-1 tvg-id="$prefix$n" tvg-chno="$n" group-title="Locals",Channel $n',
          '$base/live/$n.ts',
        ],
      ].join('\r\n');
}
