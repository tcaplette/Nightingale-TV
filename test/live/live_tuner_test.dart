import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';

import '../fake_playback.dart';
import '../fixtures.dart';

/// A server's Live TV that records what's opened and closed.
class FakeLiveTv implements LiveTv {
  FakeLiveTv(this.log);

  final List<String> log;
  final channelList = [
    for (final n in ['2.1', '4.1', '7.1']) LiveChannelInfo(key: 'ch$n', name: 'Channel $n', number: n, guideId: 'ch$n'),
  ];

  /// Failures for the next opens, in order.
  final failures = <LiveFailure>[];

  /// Opens wait for this (when set).
  Completer<void>? hold;
  final openNow = <String>{};
  final reports = <String>[];
  var opened = 0;

  @override
  Future<LiveTvAvailability> availability() async => LiveTvAvailability.available;

  @override
  Future<List<LiveChannelInfo>> channels() async => channelList;

  @override
  Future<Map<String, List<LiveProgramme>>> programs(List<String> ids, DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day, from.hour);
    return {
      for (final id in ids)
        id: [
          for (var h = 0; h < 30; h++)
            LiveProgramme(
                start: start.add(Duration(hours: h)), end: start.add(Duration(hours: h + 1)), title: '$id show $h'),
        ],
    };
  }

  @override
  Future<LiveStream> open(String channelId, {int? maxBitrate, bool forceTranscode = false, Map<String, Object?>? profile}) async {
    log.add('live-open:$channelId');
    await hold?.future;
    if (failures.isNotEmpty) {
      final f = failures.removeAt(0);
      log.add('live-fail:$channelId:${f.name}');
      throw LiveTvException(f, 'scripted');
    }
    final id = 'ls${++opened}';
    openNow.add(id);
    return LiveStream(
        channelId: channelId,
        uri: Uri.parse('https://jf.example/LiveTv/LiveStreamFiles/$id/stream.ts'),
        liveStreamId: id,
        playSessionId: 'ps$id');
  }

  @override
  Future<void> close(LiveStream stream) async {
    if (stream.closed) return;
    stream.closed = true;
    openNow.remove(stream.liveStreamId);
    log.add('live-close:${stream.liveStreamId}');
  }

  @override
  Future<void> reportStart(LiveStream s) async => reports.add('start:${s.liveStreamId}');
  @override
  Future<void> reportProgress(LiveStream s, Duration p) async => reports.add('progress:${s.liveStreamId}');
  @override
  Future<void> reportStopped(LiveStream s, Duration p) async => reports.add('stopped:${s.liveStreamId}');
}

class LiveClient extends FakeClient {
  LiveClient(super.log) : tv = FakeLiveTv(log);

  final FakeLiveTv tv;

  @override
  LiveTv get liveTv => tv;
}

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late LiveClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;
  late LiveSource server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live_tuner');
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 10, 'Beta': 8}));
    log = [];
    client = LiveClient(log);
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1)
      ..liveRetries = const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
        Duration(milliseconds: 40),
        Duration(milliseconds: 80),
      ]
      ..liveRetryEvery = const Duration(milliseconds: 100)
      ..liveStartTimeout = const Duration(milliseconds: 200)
      ..liveStallCheck = const Duration(milliseconds: 20)
      ..liveReportEvery = const Duration(milliseconds: 50);
    server = LiveSource(id: 'srv', kind: LiveSourceKind.server, name: 'Den Live TV', serverKind: ServerKind.jellyfin);
    await app.addLiveSource(server, await client.tv.channels());
    // Adding it loads its guide.
    for (var i = 0; i < 100 && app.live.isRefreshing(server); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  tearDown(() async {
    PlatformInfo.debugOverride = null;
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle([Duration wait = Duration.zero]) async {
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    await pumpEventQueue();
  }

  /// Waits for [source]'s refresh (adding one loads its guide).
  Future<void> refreshed(LiveSource source) async {
    for (var i = 0; i < 100 && app.live.isRefreshing(source); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Channel liveCh(int i) => app.allChannels.where((c) => c.isLive).toList()[i];
  Channel generated() => app.allChannels.firstWhere((c) => !c.isLive);

  test('a live channel plays from the live point: no join position, no proxy, a LIVE programme', () async {
    await tuner.tune(liveCh(0));
    await settle();
    expect(tuner.status, TunerStatus.playing);
    expect(player.liveOpens.single.path, '/LiveTv/LiveStreamFiles/ls1/stream.ts');
    final open = player.opens.single;
    expect((open.start, open.end), (null, null));
    expect(tuner.program!.title, 'ch2.1 show 0');
    expect(tuner.program!.isLive, isTrue);
    expect(tuner.inBreak, isFalse);
    expect(client.decisions, isEmpty);
    expect(client.tv.reports, ['start:ls1']);
    await settle(const Duration(milliseconds: 120));
    expect(client.tv.reports.where((r) => r.startsWith('progress')), isNotEmpty);
    expect(client.reports, isEmpty);
  });

  test('changing to a generated channel closes the live stream and reports it stopped', () async {
    await tuner.tune(liveCh(0));
    await settle();
    await tuner.tune(generated());
    await settle();
    expect(client.tv.openNow, isEmpty);
    expect(log, contains('live-close:ls1'));
    expect(client.tv.reports, contains('stopped:ls1'));
    expect(tuner.status, TunerStatus.playing);
    expect(tuner.isLive, isFalse);
  });

  test('the open stream closes before the next one opens', () async {
    await tuner.tune(liveCh(0));
    await settle();
    await tuner.tune(liveCh(1));
    await settle();
    final close = log.indexOf('live-close:ls1');
    final open = log.indexOf('live-open:ch4.1');
    expect(close, greaterThanOrEqualTo(0));
    expect(close, lessThan(open));
    expect(client.tv.openNow, {'ls2'});
  });

  test('surfing quickly through live channels leaves only the last one open', () async {
    client.tv.hold = Completer();
    final tunes = [tuner.tune(liveCh(0)), tuner.tune(liveCh(1)), tuner.tune(liveCh(2))];
    await settle();
    client.tv.hold!.complete();
    await Future.wait(tunes);
    await settle(const Duration(milliseconds: 50));
    expect(client.tv.openNow, hasLength(1));
    expect(tuner.channel!.id, liveCh(2).id);
    expect(tuner.status, TunerStatus.playing);
    expect(player.liveOpens, hasLength(1));
  });

  test("each cause has its card, and the channel tries again ('tuners in use')", () async {
    client.tv.failures.add(LiveFailure.tunersBusy);
    app.session = ServerSession(
        serverUrl: 'https://jf.example', serverName: 'Den', userId: 'u', userName: 'n', accessToken: 't', deviceId: 'd');
    await tuner.tune(liveCh(0));
    await settle();
    expect(tuner.status, TunerStatus.error);
    expect(tuner.liveMessage, "All of Den's tuners are in use");
    await settle(const Duration(milliseconds: 40));
    expect(tuner.status, TunerStatus.playing);
    expect(tuner.liveMessage, isNull);
    expect(client.tv.openNow, hasLength(1));

    String card(LiveFailure f) => tuner.liveFailureText(f, liveCh(0), server);
    expect(card(LiveFailure.unreachable), "Can't reach Den Live TV");
    expect(card(LiveFailure.refused), "Your Den account can't watch this channel");
    expect(card(LiveFailure.providerRefused), 'Den Live TV refused the stream. It may be playing on another device.');
    expect(card(LiveFailure.cantDecode), "This device can't play this channel's video");
    expect(card(LiveFailure.unsupportedScheme), "This channel's stream type isn't supported on this device");
  });

  test('a dropped stream: Reconnecting… after 1, 2, 4, 8, then Lost the signal, each a fresh open', () async {
    await tuner.tune(liveCh(0));
    await settle();
    player.onOpen = (_) => OpenResult.errors;
    player.complete();
    await settle();
    expect(tuner.status, TunerStatus.standby);
    expect(tuner.liveMessage, 'Reconnecting…');
    expect(client.tv.openNow, isEmpty, reason: 'the old live stream is closed before reopening');
    await settle(const Duration(milliseconds: 10 + 20 + 40 + 80 + 30));
    expect(tuner.liveMessage, 'Lost the signal on ${liveCh(0).name}');
    final opensBefore = client.tv.opened;
    player.onOpen = (_) => OpenResult.plays;
    await settle(const Duration(milliseconds: 150));
    expect(tuner.status, TunerStatus.playing);
    expect(client.tv.opened, greaterThan(opensBefore));
    expect(client.tv.openNow, hasLength(1));
  });

  test('a stream that stops moving for 10 seconds reconnects', () async {
    await tuner.tune(liveCh(0));
    await settle();
    now = now.add(const Duration(seconds: 11));
    await settle(const Duration(milliseconds: 40));
    expect(log, contains('live-close:ls1'));
    await settle(const Duration(milliseconds: 50));
    expect(tuner.status, TunerStatus.playing);
    expect(client.tv.openNow, {'ls2'});
  });

  test("no picture within the start time: '{name} didn't start', and a retry", () async {
    player.onOpen = (_) => OpenResult.noPicture;
    tuner.liveRetries = const [Duration(milliseconds: 150)];
    await tuner.tune(liveCh(1));
    await settle(const Duration(milliseconds: 250));
    expect(tuner.status, TunerStatus.error);
    expect(tuner.liveMessage, "${liveCh(1).name} didn't start");
    player.onOpen = (_) => OpenResult.plays;
    await settle(const Duration(milliseconds: 150));
    expect(tuner.status, TunerStatus.playing);
  });

  test("an IPTV provider's connection limit (458) names the provider", () async {
    final m3u = LiveSource(id: 'tv', kind: LiveSourceKind.m3u, name: 'IPTV Co', playlistUrl: 'http://127.0.0.1:9/x.m3u');
    await app.addLiveSource(m3u, const [
      LiveChannelInfo(key: 'm1', name: 'M One', number: '1', url: 'http://p/1.ts', headers: {'User-Agent': 'TiviMate/4.7'}),
    ]);
    await refreshed(m3u);
    final ch = app.allChannels.firstWhere((c) => c.live?.sourceId == 'tv');
    player.onOpen = (_) => OpenResult.hangs;
    await tuner.tune(ch);
    await settle();
    expect(player.liveOpens.single.toString(), 'http://p/1.ts');
    expect(player.opens.single.headers, {'User-Agent': 'TiviMate/4.7'});
    player.debugError('Failed to open http://p/1.ts: HTTP error 458 Unknown');
    await settle();
    expect(tuner.liveMessage, 'IPTV Co refused the stream. It may be playing on another device.');
  });

  test("Android: a stream type it can't play shows its card instead of tuning", () async {
    PlatformInfo.debugOverride = TargetPlatform.android;
    final m3u = LiveSource(id: 'tv', kind: LiveSourceKind.m3u, name: 'IPTV Co', playlistUrl: 'http://127.0.0.1:9/x.m3u');
    await app.addLiveSource(m3u, const [LiveChannelInfo(key: 'u', name: 'UDP One', url: 'udp://@239.1.1.1:1234')]);
    await refreshed(m3u);
    await tuner.tune(app.allChannels.firstWhere((c) => c.live?.sourceId == 'tv'));
    await settle(const Duration(milliseconds: 60));
    expect(tuner.status, TunerStatus.error);
    expect(tuner.liveMessage, "This channel's stream type isn't supported on this device");
    expect(player.liveOpens, isEmpty);
  });

  test('stopping (Android out of sight, full-screen settings) closes the live stream', () async {
    await tuner.tune(liveCh(0));
    await settle();
    await tuner.stop();
    expect(client.tv.openNow, isEmpty);
    await tuner.tune(liveCh(0));
    await settle();
    await tuner.closeLiveForExit();
    expect(client.tv.openNow, isEmpty);
  });

  test("the guide's next programme shows without reopening the stream", () async {
    await tuner.tune(liveCh(0));
    await settle();
    final first = tuner.program!;
    now = first.end.add(const Duration(minutes: 1));
    await tuner.reschedule();
    expect(tuner.program!.start, first.end);
    expect(player.opens, hasLength(1));
    expect(tuner.status, TunerStatus.playing);
  });
}
