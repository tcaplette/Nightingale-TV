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

  test('a refresh spreads an older lineup: no show on two genre channels', () async {
    app = await signedInApp(dir, fakeLibrary(shows: shows, genres: genres, movies: 30), editChannels: (channels) {
      // Saved by a version that let genre channels share shows.
      for (final c in channels) {
        (c['source'] as Map<String, Object?>).remove('excluded');
      }
    });
    final genre = app.allChannels.where((c) => c.id.startsWith('auto:genre:')).toList();
    expect(genre, hasLength(greaterThanOrEqualTo(2)));
    expect(genre.every((c) => c.source.excluded.isEmpty), isTrue);

    app.client = server();
    await app.refreshLibrary(background: true);
    final seen = <String, String>{};
    for (final c in app.allChannels.where((c) => c.id.startsWith('auto:genre:'))) {
      for (final show in showsOn(c)) {
        expect(seen[show], isNull, reason: '$show is on ${seen[show]} and ${c.name}');
        seen[show] = c.name;
      }
    }
    final movieGenre = app.allChannels.where((c) => c.id.startsWith('auto:movies:'));
    final movies = [for (final c in movieGenre) ...c.playlist];
    expect(movies.toSet(), hasLength(movies.length), reason: 'no movie on two movie genre channels');
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
