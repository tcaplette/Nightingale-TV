import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/live/live_download.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/live/live_source_client.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';

// live-channel-repair 2: a server's channel list is read one entry at a time.

Map<String, Object?> load(String path) => jsonDecode(File('test/fixtures/$path.json').readAsStringSync()) as Map<String, Object?>;

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

const bigNumber = '4021733519837465190276453';

/// The recorded Jellyfin lineup with one entry whose number isn't text
/// (unreadable) and one with a 25-digit number.
Map<String, Object?> jellyfinLineup() {
  final page = load('jellyfin_live/channels');
  final items = [...(page['Items'] as List).cast<Map<String, Object?>>()];
  items.insert(1, {...items[1], 'Id': 'bad', 'Name': 'Broken', 'Number': 12, 'ChannelNumber': 12});
  items.add({...items[0], 'Id': 'big', 'Name': 'Big Number', 'Number': bigNumber, 'ChannelNumber': bigNumber});
  return {...page, 'Items': items};
}

void main() {
  JellyfinClient jellyfinLike(bool emby, Object? Function() channels) {
    http.Response handle(http.Request r) => r.url.path == '/LiveTv/Channels' ? json(channels()) : http.Response('', 404);
    return emby
        ? EmbyClient(
            serverUrl: 'http://emby.local:8096',
            deviceId: 'dev1',
            deviceName: 'Test',
            accessToken: 'tok',
            userId: 'u',
            httpClient: MockClient((r) async => handle(r)))
        : JellyfinClient(
            serverUrl: 'http://jf.local:8097',
            deviceId: 'dev1',
            deviceName: 'Test',
            accessToken: 'tok',
            userId: 'u',
            httpClient: MockClient((r) async => handle(r)));
  }

  for (final emby in [false, true]) {
    final kind = emby ? 'Emby' : 'Jellyfin';
    test('$kind: an unreadable entry is skipped, the rest load in order with the 25-digit one by name', () async {
      final channels = await jellyfinLike(emby, jellyfinLineup).liveTv.channels();
      expect([for (final c in channels) c.name],
          ['Fake H264', 'Fake MPEG2', 'Fake-Captions', 'Fake HLS', 'Fake No Guide', 'Big Number']);
      expect(channels.last.number, bigNumber);
    });

    test('$kind: no readable entry fails the refresh with a reason', () async {
      final client = jellyfinLike(emby, () => {
            'Items': [
              {'Id': 'a', 'Name': 'A', 'Number': 1},
              {'Id': 'b', 'Name': 7},
            ]
          });
      await expectLater(client.liveTv.channels(), throwsA(isA<LiveChannelsUnreadable>()));
      final source = LiveSource(id: 's', kind: LiveSourceKind.server, name: 'Den Live TV');
      await expectLater(
          ServerLiveSource(source, client.liveTv).fetchChannels(),
          throwsA(isA<LiveSourceException>()
              .having((e) => e.message, 'message', "Couldn't read Den Live TV's channel list")));
    });
  }

  test('an empty list is still an empty list, not a failure', () async {
    expect(await jellyfinLike(false, () => {'Items': []}).liveTv.channels(), isEmpty);
  });

  group('Plex', () {
    const epg = 'tv.plex.providers.epg.xmltv:2';
    PlexClient plex(Map<String, Object?> lineup) => PlexClient(
          serverUrl: 'http://plex.local:32400',
          deviceId: 'dev1',
          deviceName: 'Test',
          accessToken: 'tok',
          httpClient: MockClient((r) async => switch (r.url.path) {
                '/livetv/dvrs' => json(load('plex_live/dvrs')),
                '/$epg/lineups/dvr/channels' => json(lineup),
                _ => http.Response('', 404),
              }),
        );

    test('an unreadable entry is skipped and a 25-digit number sorts by name', () async {
      final lineup = load('plex_live/channels');
      final container = lineup['MediaContainer'] as Map<String, Object?>;
      final list = [...(container['Channel'] as List).cast<Map<String, Object?>>()];
      list.insert(0, {...list[0], 'id': 'bad.test', 'vcn': 5});
      list.add({...list[0], 'id': 'big.test', 'gridKey': 'big.test', 'vcn': bigNumber, 'title': 'Big Number'});
      container['Channel'] = list;
      final channels = await plex(lineup).liveTv.channels();
      expect([for (final c in channels) c.key], ['fake21.test', 'fake41.test', 'fake71.test', 'big.test']);
    });

    test('no readable entry fails', () async {
      await expectLater(
          plex({
            'MediaContainer': {
              'Channel': [
                {'id': 'x', 'vcn': 3}
              ]
            }
          }).liveTv.channels(),
          throwsA(isA<LiveChannelsUnreadable>()));
    });
  });

  test('a skipped entry leaves a breadcrumb through the hook ErrorReports sets', () async {
    final previous = liveTvBreadcrumb;
    addTearDown(() async {
      liveTvBreadcrumb = previous;
      await ErrorReports.debugReset();
    });
    liveTvBreadcrumb = null;
    await ErrorReports.startServer(const {}, log: (_) {});
    expect(liveTvBreadcrumb, isNotNull, reason: 'set when reporting starts');

    final crumbs = <(String, String, Map<String, Object?>)>[];
    liveTvBreadcrumb = (category, message, data) => crumbs.add((category, message, data));
    // One entry, unreadable: skipped (and with nothing else, the list fails).
    expect(
        () => readChannelEntries('jellyfin', [
              {'Id': 'b', 'Number': 12},
            ], (item) => throw const FormatException('no name')),
        throwsA(isA<LiveChannelsUnreadable>()));
    expect(crumbs, hasLength(1));
    expect(crumbs.single.$1, 'server');
    expect(crumbs.single.$3, {'server': 'jellyfin', 'error': 'FormatException', 'fields': 'Id,Number'});
  });
}
