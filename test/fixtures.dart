import 'dart:io';

import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';

/// The Jellyfin item JSON behind a [fakeLibrary].
typedef FakeItems = ({
  List<Map<String, Object?>> series,
  List<Map<String, Object?>> episodes,
  List<Map<String, Object?>> movies,
  List<Map<String, Object?>> commercials,
});

/// Builds a library with [shows] (name → episode count, 22 min each unless
/// [lengths] says otherwise), movies, and genres per show. Its commercials
/// (`ad-1`, `ad-2`, …) are in [commercialPool].
LibraryIndex fakeLibrary({
  Map<String, int> shows = const {'Alpha': 10, 'Beta': 4},
  Map<String, List<String>> genres = const {},
  Map<String, String> ratings = const {},
  Map<String, Duration> lengths = const {},
  int movies = 0,
  Map<int, String> movieRatings = const {},
  Duration episodeLength = const Duration(minutes: 22),
  List<Duration> commercials = const [],
  String commercialPool = fakePoolId,
  List<Map<String, Object?>> songs = const [],
  List<Map<String, Object?>> musicVideos = const [],
}) {
  final items = fakeItems(
      shows: shows,
      genres: genres,
      ratings: ratings,
      lengths: lengths,
      movies: movies,
      movieRatings: movieRatings,
      episodeLength: episodeLength,
      commercials: commercials);
  return LibraryIndex.fromJellyfinItems(
      seriesItems: items.series,
      episodeItems: items.episodes,
      movieItems: items.movies,
      commercialItems: items.commercials,
      songItems: songs,
      musicVideoItems: musicVideos,
      poolsByItem: {for (final c in items.commercials) c['Id'] as String: [commercialPool]},
      fetchedAt: DateTime(2026));
}

/// Jellyfin JSON for [count] songs (or music videos), `<prefix>-1` …, by
/// [artists] artists in turn, from [year], tagged [genres], 3:30 each.
List<Map<String, Object?>> fakeMusic(int count,
        {String prefix = 'song',
        int artists = 10,
        int year = 1985,
        List<String> genres = const ['Rock'],
        bool videos = false,
        String? rating}) =>
    [
      for (var i = 1; i <= count; i++)
        {
          'Id': '$prefix-$i',
          'Name': '${videos ? 'Video' : 'Song'} $i',
          'Type': videos ? 'MusicVideo' : 'Audio',
          'RunTimeTicks': const Duration(minutes: 3, seconds: 30).inMicroseconds * 10,
          'ProductionYear': year,
          'Genres': genres,
          'Artists': ['$prefix artist ${i % artists}'],
          'Album': '$prefix album ${i % artists}',
          'AlbumId': '$prefix-album-${i % artists}',
          'OfficialRating': ?rating,
          'Container': 'mp3',
          'LocationType': 'FileSystem',
        },
    ];

/// The Jellyfin JSON for the items of a [fakeLibrary] with the same
/// arguments (for a fake server). [movieRatings] rates `movie-<n>` by n.
FakeItems fakeItems({
  Map<String, int> shows = const {'Alpha': 10, 'Beta': 4},
  Map<String, List<String>> genres = const {},
  Map<String, String> ratings = const {},
  Map<String, Duration> lengths = const {},
  int movies = 0,
  Map<int, String> movieRatings = const {},
  Duration episodeLength = const Duration(minutes: 22),
  List<Duration> commercials = const [],
}) {
  final series = <Map<String, Object?>>[];
  final episodes = <Map<String, Object?>>[];
  shows.forEach((name, count) {
    final id = 'series-$name';
    series.add({
      'Id': id,
      'Name': name,
      'Type': 'Series',
      'ProductionYear': 2000,
      'Genres': genres[name] ?? const [],
      'OfficialRating': ?ratings[name],
    });
    for (var i = 1; i <= count; i++) {
      episodes.add({
        'Id': '$name-e$i',
        'Name': '$name episode $i',
        'Type': 'Episode',
        'SeriesId': id,
        'SeriesName': name,
        'ParentIndexNumber': 1,
        'IndexNumber': i,
        'RunTimeTicks': (lengths[name] ?? episodeLength).inMicroseconds * 10,
        'LocationType': 'FileSystem',
      });
    }
  });
  final movieItems = [
    for (var i = 1; i <= movies; i++)
      {
        'Id': 'movie-$i',
        'Name': 'Movie $i',
        'ProductionYear': 1990 + i,
        'Type': 'Movie',
        'Genres': i.isEven ? ['Family'] : ['Comedy'],
        'OfficialRating': ?movieRatings[i],
        'RunTimeTicks': const Duration(minutes: 95).inMicroseconds * 10,
        'LocationType': 'FileSystem',
      },
  ];
  final commercialItems = [
    for (final (i, length) in commercials.indexed)
      {
        'Id': 'ad-${i + 1}',
        'Name': 'Ad ${i + 1}',
        'Type': 'Video',
        'RunTimeTicks': length.inMicroseconds * 10,
        'LocationType': 'FileSystem',
        'Etag': 'etag-ad-${i + 1}',
      },
  ];
  return (series: series, episodes: episodes, movies: movieItems, commercials: commercialItems);
}

/// The pool [fakeLibrary]'s commercials are in.
const fakePoolId = 'pool-1';

/// An app with a cached library and lineup, as after a previous sign-in.
///
/// [settings] replaces the saved settings, and [editChannels] can change the
/// saved channel JSON first (e.g. to seed files in an older format).
///
/// With [serverId], the sign-in knows its server, so analysis results (in
/// `analysis/<serverId>.json`) are used; [runAnalysis] also starts the
/// background analyzer.
Future<AppState> signedInApp(Directory dir, LibraryIndex fake,
    {Map<String, Object?>? settings,
    void Function(List<Map<String, Object?>> channels)? editChannels,
    String? serverId,
    String serverUrl = 'http://127.0.0.1:9',
    bool runAnalysis = false,
    Duration libraryAge = Duration.zero,
    int? maxRatingRank}) async {
  final storage = await AppStorage.at(dir);
  final library = LibraryIndex(
      series: fake.series,
      episodes: fake.episodes,
      movies: fake.movies,
      commercials: fake.commercials,
      songs: fake.songs,
      musicVideos: fake.musicVideos,
      rootsByItem: fake.rootsByItem,
      roots: fake.roots,
      missingRoots: fake.missingRoots,
      fetchedAt: DateTime.now().subtract(libraryAge));
  // A library with commercials comes with the pool that holds them.
  await storage.writeJson(
      'settings.json',
      settings ??
          (AppSettings.fresh()
                ..commercialPools = [
                  if (fake.commercials.isNotEmpty)
                    CommercialPool(id: fakePoolId, name: 'Commercials', roots: const [
                      PoolRoot(itemId: 'ads', libraryId: 'ads', label: 'Commercials'),
                    ]),
                ])
              .toJson());
  await storage.writeJson('session.json', {
    'serverUrl': serverUrl,
    'userId': 'u1',
    'userName': 'tester',
    'accessToken': 'none',
    'deviceId': 'test',
    'serverId': ?serverId,
  });
  await storage.writeJson('library.json', library.toJson());
  final channels = [for (final c in ChannelGenerator(library).generate()) c.toJson()];
  editChannels?.call(channels);
  await storage.writeJson('channels.json', channels);
  final app = AppState(storage, runAnalysis: runAnalysis, maxRatingRank: maxRatingRank);
  await app.start();
  return app;
}
