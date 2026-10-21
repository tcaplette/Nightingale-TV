import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_music'));
  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  /// A server with the shows of [fakeItems] (each episode added at
  /// [added]) in "TV Shows", and [songs] in a "Music" library.
  JellyfinClient server(List<Map<String, Object?>> songs, {DateTime? added}) {
    final items = fakeItems(shows: const {'Alpha': 10, 'Beta': 4}, movies: 6);
    return JellyfinClient(
      serverUrl: 'https://jf.example',
      deviceId: 'd',
      deviceName: 'pc',
      accessToken: 't',
      userId: 'u',
      httpClient: MockClient((r) async {
        if (r.url.path == '/UserViews') {
          return http.Response(
              jsonEncode({
                'Items': [
                  {'Id': 'tv', 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
                  {'Id': 'music', 'Name': 'Music', 'CollectionType': 'music'},
                ]
              }),
              200);
        }
        final q = r.url.queryParameters;
        final type = q['IncludeItemTypes'];
        final all = switch ((q['ParentId'], type)) {
          ('tv', 'Series') => items.series,
          ('tv', 'Episode') => [
              for (final e in items.episodes) {...e, 'DateCreated': ?added?.toUtc().toIso8601String()}
            ],
          ('tv', 'Movie') => items.movies,
          ('music', 'Audio') => songs,
          _ => const <Map<String, Object?>>[],
        };
        final start = int.parse(q['StartIndex'] ?? '0'), limit = int.parse(q['Limit'] ?? '500');
        final page = all.skip(start).take(limit).toList();
        return http.Response(jsonEncode({'Items': page, 'TotalRecordCount': all.length}), 200);
      }),
    );
  }

  test('a refresh adds music channels after the others, without renumbering; the cap holds', () async {
    app = await signedInApp(dir, fakeLibrary(shows: const {'Alpha': 10, 'Beta': 4}, movies: 6));
    final before = {for (final c in app.allChannels) c.id: c.number};
    expect(app.allChannels.any((c) => c.isMusic), isFalse);
    app.client = server(fakeMusic(3100, artists: 50));
    await app.refreshLibrary(background: true);
    for (final e in before.entries) {
      expect(app.channelById(e.key)!.number, e.value, reason: e.key);
    }
    final radio = app.allChannels.firstWhere((c) => c.name == 'Music Radio');
    expect(radio.number, before.values.reduce((a, b) => a > b ? a : b) + 1);
    expect(radio.playlist, hasLength(maxMusicPlaylist));
    expect(app.library.songs, hasLength(3100));

    // More songs: the playlist keeps its fixed sample, in its order.
    final playlist = [...radio.playlist];
    app.client = server(fakeMusic(3300, artists: 50));
    await app.refreshLibrary(background: true);
    final after = app.channelById(radio.id)!;
    expect(after.playlist, hasLength(maxMusicPlaylist));
    final kept = [for (final id in playlist) if (after.playlist.contains(id)) id];
    expect(after.playlist.take(kept.length), kept, reason: 'the old songs keep their order');
  });

  test('newly found episodes become available at the scan; premieres follow', () async {
    app = await signedInApp(dir, fakeLibrary(shows: const {'Alpha': 10, 'Beta': 4}, movies: 6));
    final added = DateTime.now().subtract(const Duration(days: 2));
    app.client = server(const [], added: added);
    final scan = DateTime.now();
    await app.refreshLibrary(background: true);
    final e = app.library['Alpha-e1']!;
    expect(e.added, added.toUtc().toLocal());
    // Upgraded from a library without times: the later of added and the scan.
    expect(e.availableAt!.isBefore(scan), isFalse);
    expect(app.premierePlan, isNotNull);
    expect(app.premierePlan!.homeOf.keys, containsAll(['alpha', 'beta']));
  });
}
