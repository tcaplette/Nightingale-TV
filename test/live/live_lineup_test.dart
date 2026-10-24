import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/channel_numbers.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_tv_manager.dart';
import 'package:nightingale_tv/live/live_schedule.dart';

import '../fixtures.dart';

/// A tiny IPTV provider: a playlist and a gzipped guide.
class Provider {
  late HttpServer server;
  var token = 1;
  var channels = ['2.1', '4.1', '7.1'];
  bool down = false;
  final requests = <String>[];

  String get base => 'http://127.0.0.1:${server.port}';

  String playlist() => [
        '#EXTM3U x-tvg-url="$base/epg.xml"',
        for (final n in channels) ...[
          '#EXTINF:-1 tvg-id="ch$n" tvg-chno="$n" tvg-logo="$base/logo/$n.png" group-title="Locals",Channel $n',
          '$base/live/$n.ts?token=$token',
        ],
      ].join('\r\n');

  String guide() {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day, now.hour);
    String t(DateTime d) => '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}'
        '${'${d.hour}'.padLeft(2, '0')}0000 +0000';
    return '<?xml version="1.0"?><tv>${[
      for (final n in channels) '<channel id="ch$n"><display-name>Channel $n</display-name></channel>',
      for (final n in channels)
        for (var h = 0; h < 6; h++)
          '<programme start="${t(start.add(Duration(hours: h)))}" stop="${t(start.add(Duration(hours: h + 1)))}" channel="ch$n">'
              '<title>Show $n.$h</title><desc>About $n</desc></programme>',
    ].join()}</tv>';
  }

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      requests.add(r.uri.path);
      if (down) {
        r.response.statusCode = 503;
      } else if (r.uri.path == '/list.m3u') {
        r.response.write(playlist());
      } else if (r.uri.path == '/epg.xml') {
        r.response.add(gzip.encode(utf8.encode(guide())));
      } else {
        r.response.statusCode = 404;
      }
      await r.response.close();
    });
  }
}

void main() {
  late Directory dir;
  late Provider provider;
  late AppState app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live_lineup');
    provider = Provider();
    await provider.start();
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 10, 'Beta': 8, 'Gamma': 6}));
  });

  tearDown(() async {
    await app.close();
    await provider.server.close(force: true);
    await dir.delete(recursive: true);
  });

  /// Adds the provider's playlist as a source, as Add source does.
  Future<LiveSource> addSource() async {
    final source = LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'IPTV', playlistUrl: '${provider.base}/list.m3u');
    final client = app.live.clientFor(source)!;
    final channels = await client.fetchChannels();
    await app.addLiveSource(source, channels);
    await settle(app, source);
    return source;
  }

  List<Channel> live() => [for (final c in app.allChannels) if (c.isLive) c];

  test("a source's channels join after the generated ones, numbered in source order (the spec's 2.1, 4.1, 7.1)", () async {
    final highest = app.allChannels.map((c) => c.number).reduce((a, b) => a > b ? a : b);
    expect(highest, lessThan(100));
    final source = await addSource();
    expect([for (final c in live()) c.number], [100, 101, 102]);
    expect([for (final c in live()) c.live!.sourceNumber], ['2.1', '4.1', '7.1']);
    expect(live().first.name, 'Channel 2.1');
    expect(live().first.icon.kind, ChannelIconKind.remote);
    expect(live().first.logoMode, LogoMode.off);
    expect(source.guideUrl, '${provider.base}/epg.xml');
    expect(source.guideFromPlaylist, isTrue);
    // The guide (gzipped, named .xml) is read and matched by tvg-id.
    final schedule = app.scheduleFor(live().first)!;
    expect(schedule, isA<LiveSchedule>());
    expect(schedule.programAt(DateTime.now()).title, 'Show 2.1.0');
    // Channel Up from the last generated channel lands on 100.
    final visible = app.channels;
    final lastGenerated = visible.lastWhere((c) => !c.isLive);
    expect(visible[visible.indexOf(lastGenerated) + 1].number, 100);
  });

  test('live channels are saved with their source, not in channels.json, and load offline', () async {
    await addSource();
    final saved = jsonDecode(await File('${dir.path}/channels.json').readAsString()) as List;
    expect(saved.where((c) => '${(c as Map)['id']}'.startsWith('live:')), isEmpty);
    final sources = jsonDecode(await File('${dir.path}/live_sources.json').readAsString()) as Map;
    expect(((sources['sources'] as List).single as Map)['chosen'], hasLength(3));

    provider.down = true;
    final again = AppState(app.storage);
    await again.start();
    expect([for (final c in again.allChannels) if (c.isLive) c.number], [100, 101, 102]);
    expect(again.scheduleFor(again.allChannels.firstWhere((c) => c.isLive))!.programAt(DateTime.now()).title, 'Show 2.1.0');
    final source = again.live.sources.single;
    await again.refreshLiveSource(source);
    expect(again.live.entryFor(source).state.lastError, "Couldn't reach the playlist");
    expect([for (final c in again.allChannels) if (c.isLive) c.number], [100, 101, 102]);
    await again.close();
  });

  test('rotating stream URLs keep numbers, favorites and groups', () async {
    final source = await addSource();
    final ch = live()[1];
    await app.updateChannel(ch, favorite: true);
    final group = await app.createGroup('Locals');
    await app.setInGroup(group, ch, true);
    provider.token = 99;
    await app.refreshLiveSource(source);
    final after = app.channelById(ch.id)!;
    expect(after.number, 101);
    expect(after.favorite, isTrue);
    expect(app.settings.groups.single.channelIds, [ch.id]);
    expect(app.live.entryFor(source).channels[1].url, contains('token=99'));
  });

  test("a channel that leaves drops out, and comes back as it was (the spec's Monday and Tuesday)", () async {
    final source = await addSource();
    final ch = live()[1];
    await app.updateChannel(ch, favorite: true, name: 'My 4');
    final group = await app.createGroup('Locals');
    await app.setInGroup(group, ch, true);

    provider.channels = ['2.1', '7.1'];
    await app.refreshLiveSource(source);
    expect(app.channelById(ch.id), isNull);
    expect(app.settings.groups.single.channelIds, isEmpty);
    expect(app.guideTabs().where((t) => t.id == GuideTabs.favorites), isEmpty);
    expect(source.departed.keys, ['ch4.1']);

    provider.channels = ['2.1', '4.1', '7.1'];
    await app.refreshLiveSource(source);
    final back = app.channelById(ch.id)!;
    expect((back.number, back.favorite, back.name), (101, true, 'My 4'));
    expect(app.settings.groups.single.channelIds, [ch.id]);
    expect(source.departed, isEmpty);
  });

  test('renumbering is kept; a channel joining later takes the next free number in the block', () async {
    final source = await addSource();
    await app.updateChannel(live().first, number: 150);
    await app.chooseLiveChannels(source, {'ch4.1', 'ch7.1'});
    expect([for (final c in live()) c.number], [101, 102]);
    await app.chooseLiveChannels(source, {'ch2.1', 'ch4.1', 'ch7.1'});
    expect([for (final c in live()) c.number], [101, 102, 103]);
    await app.updateChannel(live().last, number: 150);
    await app.refreshLiveSource(source);
    final again = AppState(app.storage);
    await again.start();
    expect([for (final c in again.allChannels) if (c.isLive) c.number], [101, 102, 150]);
    await again.close();
  });

  test('generated channels skip numbers live channels hold; no number is shared', () async {
    await addSource();
    // A live channel moved into the generated range.
    await app.updateChannel(live().first, number: 3);
    await app.resetChannels();
    final numbers = [for (final c in app.allChannels) c.number];
    expect(numbers.toSet(), hasLength(numbers.length));
    expect(app.allChannels.firstWhere((c) => c.number == 3).isLive, isTrue);

    // The generator growing into the block skips it.
    final generated = [
      for (var i = 0; i < 110; i++)
        Channel(
            id: 'g$i', number: 0, name: 'G', icon: const ChannelIcon.builtin('tv'), source: const ChannelSource(),
            order: PlaybackOrder.cyclic, playlist: const [], anchor: DateTime(2026)),
    ];
    final held = {for (var n = 100; n < 130; n++) n};
    ChannelNumbers.numberSkipping(generated, held, start: 1);
    expect(generated.map((c) => c.number).where(held.contains), isEmpty);
    expect(generated.last.number, 140);
    expect(ChannelNumbers.liveBlockStart([1, 42]), 100);
    expect(ChannelNumbers.liveBlockStart([1, 100]), 200);
  });

  test('a source of 150 or fewer channels starts with all chosen; a bigger one with none', () {
    List<LiveChannelInfo> n(int count) => [for (var i = 0; i < count; i++) LiveChannelInfo(key: 'k$i', name: 'C$i')];
    expect(LiveTvManager.defaultChoice(n(150)), hasLength(150));
    expect(LiveTvManager.defaultChoice(n(151)), isEmpty);
  });

  test("removing a source takes its channels out of the guide, favorites and groups", () async {
    final source = await addSource();
    final ch = live().first;
    await app.updateChannel(ch, favorite: true);
    final group = await app.createGroup('Sports');
    await app.setInGroup(group, ch, true);
    await app.removeLiveSource(source);
    expect(live(), isEmpty);
    expect(app.settings.groups.single.channelIds, isEmpty);
    expect(app.guideTabs().map((t) => t.id), isNot(contains(GuideTabs.favorites)));
    expect(app.guideTabs().map((t) => t.id), isNot(contains(GuideTabs.live)));
    expect(Directory('${dir.path}/live_cache/iptv').existsSync(), isFalse);
  });

  test('a kid profile keeps its sources saved but shows no live channels', () async {
    await addSource();
    await app.close();
    final kid = AppState(app.storage, maxRatingRank: 2);
    await kid.start();
    expect(kid.allChannels.where((c) => c.isLive), isEmpty);
    expect(kid.guideTabs().map((t) => t.id), isNot(contains(GuideTabs.live)));
    expect(kid.live.sources, hasLength(1));
    await kid.close();
    app = AppState(app.storage);
    await app.start();
    expect(live(), hasLength(3));
  });
}

/// Waits for [source]'s refresh to finish.
Future<void> settle(AppState app, LiveSource source) async {
  for (var i = 0; i < 200 && app.live.isRefreshing(source); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  await Future<void>.delayed(Duration.zero);
}
