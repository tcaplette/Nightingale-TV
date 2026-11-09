import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_spread'));
  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  const shows = {'A': 40, 'B': 40, 'C': 40, 'D': 40, 'F': 30, 'G': 30};
  const genres = {
    'A': ['Comedy', 'Family'],
    'B': ['Comedy', 'Family'],
    'C': ['Comedy'],
    'F': ['Comedy'],
    'D': ['Family'],
    'G': ['Family'],
  };

  /// A server with [shows] and [movies] movies in "TV Shows".
  JellyfinClient server({int movies = 30}) {
    final items = fakeItems(shows: shows, genres: genres, movies: movies);
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
                ]
              }),
              200);
        }
        final q = r.url.queryParameters;
        final all = switch ((q['ParentId'], q['IncludeItemTypes'])) {
          ('tv', 'Series') => items.series,
          ('tv', 'Episode') => items.episodes,
          ('tv', 'Movie') => items.movies,
          _ => const <Map<String, Object?>>[],
        };
        final start = int.parse(q['StartIndex'] ?? '0'), limit = int.parse(q['Limit'] ?? '500');
        return http.Response(
            jsonEncode({'Items': all.skip(start).take(limit).toList(), 'TotalRecordCount': all.length}), 200);
      }),
    );
  }

  Set<String> showsOn(Channel c) => {for (final id in c.playlist) id.split('-e').first};

  test('a refresh opens an older lineup up: every show on each genre channel it matches', () async {
    app = await signedInApp(dir, fakeLibrary(shows: shows, genres: genres, movies: 30), editChannels: (channels) {
      // Saved by a version that gave each show one genre channel.
      for (final c in channels) {
        final source = c['source'] as Map<String, Object?>;
        if (c['id'] == 'auto:genre:Comedy') source['excluded'] = ['A', 'B'];
        if (c['id'] == 'auto:movies:Comedy') source['excluded'] = ['movie-1', 'movie-3'];
      }
    });
    expect(app.channelById('auto:genre:Comedy')!.source.excluded, ['A', 'B']);

    app.client = server();
    await app.refreshLibrary(background: true);
    expect(showsOn(app.channelById('auto:genre:Comedy')!), {'A', 'B', 'C', 'F'});
    expect(showsOn(app.channelById('auto:genre:Family')!), {'A', 'B', 'D', 'G'});
    for (final c in app.allChannels.where((c) => c.id.startsWith('auto:movies:'))) {
      expect(c.source.excluded, isEmpty, reason: c.name);
      final genre = c.source.genres.single;
      expect(c.playlist.toSet(), {
        for (final m in app.library.movies)
          if (m.genres.contains(genre)) m.id,
      }, reason: c.name);
    }
  });

  test('a new movie airs next on the Movie Channel, and the refresh says what it found', () async {
    app = await signedInApp(dir, fakeLibrary(shows: shows, genres: genres, movies: 30));
    final channel = app.channelById('auto:movies')!;
    final now = DateTime.now();
    final onAir = app.scheduleFor(channel)!.programAt(now).item!.id;
    app.client = server(movies: 31);
    await app.refreshLibrary(background: true);
    final after = app.channelById('auto:movies')!;
    expect(app.scheduleFor(after)!.programAt(now).item!.id, onAir, reason: 'what is on stays on');
    final at = after.playlist.indexOf(onAir);
    expect(after.playlist[(at + 1) % after.playlist.length], 'movie-31');
    expect(app.lastRefresh, (shows: 0, episodes: 0, movies: 1, songs: 0, channels: 0));
  });
}
