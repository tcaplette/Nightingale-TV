import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/server/plex/plex_library.dart';

/// Libraries shaped like real ones (lineup-dedup D8), as Jellyfin, Emby and
/// Plex list them: matched and bare copies of a show, season folders,
/// release tags, remakes, sequels and episodes with no show. Names are
/// synthetic; tests check properties, never titles.

/// One item a server lists for a show, and the episodes under it.
class FixtureItem {
  const FixtureItem(this.id, this.name,
      {this.year, this.genres = const [], this.logo = false, this.providerIds = const {}, this.episodes = const []});

  final String id;
  final String name;
  final int? year;
  final List<String> genres;
  final bool logo;

  /// Provider → id (`{'Tvdb': '100'}`).
  final Map<String, String> providerIds;

  /// (season, episode) numbers; either can be null.
  final List<(int?, int?)> episodes;

  /// This item with its metadata gone (a bare copy) or [genres] given.
  FixtureItem bare() => FixtureItem(id, name, episodes: episodes);

  FixtureItem matched({required int year, required List<String> genres, Map<String, String> providerIds = const {}}) =>
      FixtureItem(id, name, year: year, genres: genres, logo: true, providerIds: providerIds, episodes: episodes);

  FixtureItem withEpisodes(List<(int?, int?)> episodes) =>
      FixtureItem(id, name, year: year, genres: genres, logo: logo, providerIds: providerIds, episodes: episodes);

  String episodeId(int i) => '$id-x$i';
}

/// Seasons [from]..[to], [perSeason] episodes each.
List<(int?, int?)> seasons(int from, int to, int perSeason) => [
      for (var s = from; s <= to; s++)
        for (var e = 1; e <= perSeason; e++) (s, e),
    ];

class FixtureLibrary {
  const FixtureLibrary({required this.items, this.unnamed = 0, this.movies = const {}, this.namedMovies = const []});

  final List<FixtureItem> items;

  /// Episodes with no show at all.
  final int unnamed;

  /// Movie count by genre; each movie has one genre.
  final Map<String, int> movies;

  /// Movies by name, with their genres in the server's order.
  final List<(String name, List<String> genres)> namedMovies;

  FixtureLibrary copyWith({List<FixtureItem>? items, int? unnamed, Map<String, int>? movies}) => FixtureLibrary(
      items: items ?? this.items, unnamed: unnamed ?? this.unnamed, movies: movies ?? this.movies, namedMovies: namedMovies);

  /// The library the lineup-dedup tests start from.
  static FixtureLibrary standard() => FixtureLibrary(
        items: [
          // A matched copy holding one season, a bare copy holding all nine.
          FixtureItem('a1', 'Show A',
              year: 2001, genres: ['Comedy'], logo: true, providerIds: {'Tvdb': '100'}, episodes: seasons(8, 8, 20)),
          FixtureItem('a2', 'Show A', episodes: seasons(1, 9, 20)),
          // Season folders, numbered as the folder says, as season 1, or not at all.
          FixtureItem('b1', 'Show B Season 1 [1080p AI 10bit', episodes: seasons(1, 1, 12)),
          FixtureItem('b3', 'Show B Season 3',
              year: 2009, genres: ['Animation', 'Comedy'], logo: true, episodes: seasons(1, 1, 12)),
          FixtureItem('b4', 'Show B SEASON 04', episodes: [for (var e = 1; e <= 12; e++) (null, e)]),
          // Release tags.
          FixtureItem('c1', 'Show C (Complete cartoon series in MP4 format)',
              year: 2014, genres: ['Animation', 'Comedy'], episodes: seasons(1, 4, 10)),
          // A remake pair.
          FixtureItem('d1', 'Show D', year: 1978, genres: ['Science Fiction'], episodes: seasons(1, 2, 12)),
          FixtureItem('d2', 'Show D', year: 2004, genres: ['Science Fiction', 'Drama'], episodes: seasons(1, 4, 18)),
          // A sequel pair.
          FixtureItem('e1', 'Show E', year: 1996, genres: ['Crime'], episodes: seasons(1, 3, 10)),
          FixtureItem('e2', 'Show E II', year: 2020, genres: ['Crime'], episodes: seasons(1, 2, 12)),
          // Plain shows.
          FixtureItem('f1', 'Show F', year: 2010, genres: ['Drama'], episodes: seasons(1, 3, 12)),
          FixtureItem('g1', 'Show G', year: 2012, genres: ['Drama', 'Crime'], episodes: seasons(1, 3, 12)),
          FixtureItem('h1', 'Show H & Friends', year: 2015, genres: ['Animation'], episodes: seasons(1, 2, 13)),
          FixtureItem('h2', 'Show H and Friends', episodes: seasons(3, 3, 10)),
          // Small shows, so the library has room for two show channels (one
          // per 8 named shows, cable-lineup D2).
          for (var i = 1; i <= 6; i++)
            FixtureItem('p$i', 'Show P$i', year: 1990 + i, genres: ['Documentary'], episodes: seasons(1, 1, 6)),
        ],
        unnamed: 70,
        movies: {'Comedy': 14, 'Action': 13, 'Drama': 12, 'Horror': 4},
      );

  static const _episodeTicks = 22 * 60 * 10000000;
  static const _movieTicks = 95 * 60 * 10000000;

  List<Map<String, Object?>> get _movieList => [
        for (final MapEntry(key: g, value: n) in movies.entries)
          for (var i = 1; i <= n; i++) {'id': 'movie-$g-$i', 'name': '$g Film $i', 'genres': [g], 'year': 1990 + i},
        for (final (i, (name, genres)) in namedMovies.indexed)
          {'id': 'movie-n$i', 'name': name, 'genres': genres, 'year': 1980 + i % 40},
      ];

  /// As Jellyfin lists it.
  ({List<Map<String, Object?>> series, List<Map<String, Object?>> episodes, List<Map<String, Object?>> movies})
      jellyfin({bool emby = false}) => (
            series: [
              for (final s in items)
                {
                  'Id': s.id,
                  'Name': s.name,
                  'Type': 'Series',
                  'ProductionYear': ?s.year,
                  'Genres': s.genres,
                  // Emby leaves out what an item doesn't have.
                  if (s.logo) 'ImageTags': {'Logo': 'tag'} else if (!emby) 'ImageTags': <String, Object?>{},
                  if (s.providerIds.isNotEmpty || !emby) 'ProviderIds': s.providerIds,
                },
            ],
            episodes: [
              for (final s in items)
                for (final (i, (season, number)) in s.episodes.indexed)
                  {
                    'Id': s.episodeId(i),
                    'Name': 'Episode ${number ?? i}',
                    'Type': 'Episode',
                    'SeriesId': s.id,
                    'SeriesName': s.name,
                    'ParentIndexNumber': ?season,
                    'IndexNumber': ?number,
                    'RunTimeTicks': _episodeTicks,
                    if (!emby) 'LocationType': 'FileSystem',
                  },
              for (var i = 1; i <= unnamed; i++)
                {'Id': 'unnamed-$i', 'Name': 'Clip $i', 'Type': 'Episode', 'RunTimeTicks': _episodeTicks},
            ],
            movies: [
              for (final m in _movieList)
                {
                  'Id': m['id'],
                  'Name': m['name'],
                  'Type': 'Movie',
                  'ProductionYear': m['year'],
                  'Genres': m['genres'],
                  'RunTimeTicks': _movieTicks,
                },
            ],
          );

  /// As Plex lists it.
  ({List<Map<String, Object?>> shows, List<Map<String, Object?>> episodes, List<Map<String, Object?>> movies})
      plex() => (
            shows: [
              for (final s in items)
                {
                  'ratingKey': s.id,
                  'title': s.name,
                  'year': ?s.year,
                  'Genre': [for (final g in s.genres) {'tag': g}],
                  if (s.logo) 'Image': [{'type': 'clearLogo'}],
                  'Guid': [for (final MapEntry(:key, :value) in s.providerIds.entries) {'id': '${key.toLowerCase()}://$value'}],
                },
            ],
            episodes: [
              for (final s in items)
                for (final (i, (season, number)) in s.episodes.indexed)
                  {
                    'ratingKey': s.episodeId(i),
                    'title': 'Episode ${number ?? i}',
                    'grandparentRatingKey': s.id,
                    'grandparentTitle': s.name,
                    'parentIndex': ?season,
                    'index': ?number,
                    'duration': _episodeTicks ~/ 10000,
                  },
              for (var i = 1; i <= unnamed; i++)
                {'ratingKey': 'unnamed-$i', 'title': 'Clip $i', 'duration': _episodeTicks ~/ 10000},
            ],
            movies: [
              for (final m in _movieList)
                {
                  'ratingKey': m['id'],
                  'title': m['name'],
                  'year': m['year'],
                  'Genre': [for (final g in m['genres']! as List<String>) {'tag': g}],
                  'duration': _movieTicks ~/ 10000,
                },
            ],
          );

  /// The index each server type's scan makes of it.
  LibraryIndex index(ServerShape shape, {DateTime? fetchedAt}) {
    switch (shape) {
      case ServerShape.jellyfin || ServerShape.emby:
        final j = jellyfin(emby: shape == ServerShape.emby);
        return LibraryIndex.fromJellyfinItems(
            seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies, fetchedAt: fetchedAt ?? DateTime(2026));
      case ServerShape.plex:
        final p = plex();
        return libraryIndexFromPlex(
            shows: p.shows, episodes: p.episodes, movies: p.movies, fetchedAt: fetchedAt ?? DateTime(2026));
    }
  }

  /// The index a scan made before show identity: shows keyed `name|year`
  /// as listed, episodes under their item's key with the season they say.
  LibraryIndex legacyIndex({DateTime? fetchedAt}) {
    final scanned = index(ServerShape.jellyfin, fetchedAt: fetchedAt);
    String keyOf(FixtureItem s) => '${s.name.trim().toLowerCase()}|${s.year ?? ''}';
    final series = <String, SeriesEntry>{};
    for (final s in items) {
      series.putIfAbsent(
          keyOf(s),
          () => SeriesEntry(
              key: keyOf(s), id: s.id, name: s.name, year: s.year, genres: s.genres, hasLogo: s.logo));
    }
    const unknown = 'unknown show|';
    final episodes = <MediaEntry>[];
    final seen = <String>{};
    final byId = {for (final e in scanned.episodes) e.id: e};
    for (final s in items) {
      for (final (i, (season, number)) in s.episodes.indexed) {
        final key = keyOf(s);
        if (!seen.add(season != null && number != null ? '$key|$season|$number' : '$key|Episode ${number ?? i}')) continue;
        final e = byId[s.episodeId(i)] ?? scannedCopy(s, i);
        episodes.add(e.withShow(key, series[key]!.name, season));
      }
    }
    for (var i = 1; i <= unnamed; i++) {
      episodes.add(byId['unnamed-$i']!.withShow(unknown, 'Unknown show', null));
    }
    if (unnamed > 0) series[unknown] = const SeriesEntry(key: unknown, id: unknown, name: 'Unknown show');
    return LibraryIndex(
        series: series.values.toList(), episodes: episodes, movies: scanned.movies, fetchedAt: scanned.fetchedAt);
  }

  /// [s]'s [i]th episode as an entry (one the new scan dropped as a copy).
  MediaEntry scannedCopy(FixtureItem s, int i) => MediaEntry(
      id: s.episodeId(i),
      kind: MediaKind.episode,
      title: 'Episode ${s.episodes[i].$2 ?? i}',
      runtime: const Duration(minutes: 22),
      seriesId: s.id,
      seriesName: s.name,
      season: s.episodes[i].$1,
      episode: s.episodes[i].$2);

  /// A Jellyfin server with this library in one "TV Shows" library.
  JellyfinClient jellyfinServer() {
    final j = jellyfin();
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
          ('tv', 'Series') => j.series,
          ('tv', 'Episode') => j.episodes,
          ('tv', 'Movie') => j.movies,
          _ => const <Map<String, Object?>>[],
        };
        final start = int.parse(q['StartIndex'] ?? '0'), limit = int.parse(q['Limit'] ?? '500');
        return http.Response(
            jsonEncode({'Items': all.skip(start).take(limit).toList(), 'TotalRecordCount': all.length}), 200);
      }),
    );
  }
}

enum ServerShape { jellyfin, emby, plex }
