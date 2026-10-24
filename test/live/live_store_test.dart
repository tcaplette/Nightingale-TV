import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/live/live_cache.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/live/live_source_files.dart';
import 'package:nightingale_tv/server/media_server.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('live_store'));
  tearDown(() => dir.delete(recursive: true));

  test('sources round-trip through live_sources.json; picked files are copied in', () async {
    final storage = await AppStorage.at(dir);
    final store = LiveSourceStore(storage);
    final picked = File('${dir.path}/picked.m3u')..writeAsStringSync('#EXTM3U\n');
    final name = await store.copyIn(picked, 'srcA', 'playlist');
    expect(name, 'srcA-playlist.m3u');
    expect(store.fileFor(name).readAsStringSync(), '#EXTM3U\n');

    final left = DateTime(2026, 10, 1);
    await store.save([
      LiveSource(id: 'srcA', kind: LiveSourceKind.m3u, name: 'IPTV', playlistFile: name,
          guideUrl: 'http://e/g.xml.gz', guideFromPlaylist: true, chosen: {
        'wxyz.us': LiveChannelSettings(number: 100, name: 'My WXYZ', favorite: true),
        'kabc': LiveChannelSettings(number: 101, logoMode: null, hidden: true),
      }, departed: {
        'old': DepartedChannel(settings: LiveChannelSettings(number: 105, favorite: true), groupIds: ['group:a'], leftAt: left),
      }),
      LiveSource(id: 'srcB', kind: LiveSourceKind.server, name: 'Jellyfin Live TV',
          serverKind: ServerKind.jellyfin, serverId: 'abc'),
    ]);
    final [a, b] = await store.load();
    expect((a.kind, a.name, a.playlistFile, a.guideUrl, a.guideFromPlaylist), (LiveSourceKind.m3u, 'IPTV', name, 'http://e/g.xml.gz', true));
    expect(a.chosen['wxyz.us']!.name, 'My WXYZ');
    expect(a.chosen['wxyz.us']!.favorite, isTrue);
    expect(a.chosen['wxyz.us']!.logoMode, LogoMode.off);
    expect(a.chosen['kabc']!.logoMode, isNull);
    expect(a.chosen['kabc']!.hidden, isTrue);
    expect(a.departed['old']!.settings.number, 105);
    expect(a.departed['old']!.groupIds, ['group:a']);
    expect(a.departed['old']!.leftAt, left);
    expect((b.kind, b.serverKind, b.serverId), (LiveSourceKind.server, ServerKind.jellyfin, 'abc'));

    a.forgetDeparted(left.add(const Duration(days: 29)));
    expect(a.departed, isNotEmpty);
    a.forgetDeparted(left.add(const Duration(days: 31)));
    expect(a.departed, isEmpty);
  });

  test('the cache keeps channels, guide, index and refresh state per source', () async {
    final cache = LiveCache(dir);
    final now = DateTime(2026, 10, 21, 20);
    await cache.saveChannels('s', [const LiveChannelInfo(key: 'k', name: 'K', number: '2.1', url: 'http://s/k', headers: {'User-Agent': 'X'})]);
    await cache.saveGuide('s', {
      'k': [LiveProgramme(start: now, end: now.add(const Duration(minutes: 30)), title: 'News', isNew: true)],
    });
    await cache.saveGuideIndex('s', [const GuideChannel(id: 'k.id', names: ['K'])]);
    await cache.saveState('s', LiveRefreshState(channelsAt: now, lastError: "Couldn't reach the playlist", failures: 2));
    final e = await cache.load('s');
    expect(e.channels.single.headers, {'User-Agent': 'X'});
    expect(e.guide['k']!.single.title, 'News');
    expect(e.guideIndex.single.names, ['K']);
    expect(e.state.channelsAt, now);
    expect(e.state.failures, 2);
    expect(e.state.lastRefresh, now);
    expect((await cache.load('other')).channels, isEmpty);
    await cache.delete('s');
    expect((await cache.load('s')).guide, isEmpty);
  });
}
