import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

void main() {
  group('LibraryIndex.fromJellyfinItems', () {
    test('drops virtual (missing) episodes and dedupes duplicate series', () {
      final series = [
        {'Id': 's1', 'Name': 'Show', 'ProductionYear': 2015, 'Genres': ['Comedy']},
        {'Id': 's2', 'Name': 'Show', 'ProductionYear': 2015, 'Genres': ['Kids'], 'ImageTags': {'Logo': 'x'}},
      ];
      final episodes = [
        {'Id': 'e1', 'Name': 'One', 'SeriesId': 's1', 'SeriesName': 'Show', 'ParentIndexNumber': 1, 'IndexNumber': 1, 'RunTimeTicks': 13200000000, 'LocationType': 'FileSystem'},
        // Same episode listed under the duplicate series.
        {'Id': 'e1b', 'Name': 'One', 'SeriesId': 's2', 'SeriesName': 'Show', 'ParentIndexNumber': 1, 'IndexNumber': 1, 'RunTimeTicks': 13200000000, 'LocationType': 'FileSystem'},
        {'Id': 'e2', 'Name': 'Two', 'SeriesId': 's1', 'SeriesName': 'Show', 'ParentIndexNumber': 1, 'IndexNumber': 2, 'LocationType': 'Virtual'},
      ];
      final index = LibraryIndex.fromJellyfinItems(seriesItems: series, episodeItems: episodes, movieItems: const []);
      expect(index.series, hasLength(1));
      expect(index.series.single.genres, containsAll(['Comedy', 'Kids']));
      expect(index.series.single.hasLogo, isTrue);
      expect(index.series.single.id, 's2', reason: 'prefers the copy with a logo');
      expect(index.episodes.map((e) => e.id), ['e1']);
    });

    test('cleans file-name episode titles', () {
      String clean(String s, [int? n]) => LibraryIndex.cleanEpisodeTitle(s, episode: n);
      expect(clean('The.Loud.House.S01E29E27-Toads.and.Tiaras+Two.Boys.and.a.Baby'),
          'Toads and Tiaras / Two Boys and a Baby');
      expect(clean('Bluey.S03E09', 9), 'Episode 9');
      expect(clean('Pottery-A-Rooney'), 'Pottery-A-Rooney');
      expect(clean("Them's the Breaks, Kid"), "Them's the Breaks, Kid");
      expect(clean('', 4), 'Episode 4');
    });

    test('round-trips through JSON', () {
      final index = fakeLibrary(movies: 3);
      final copy = LibraryIndex.fromJson(index.toJson());
      expect(copy.episodes.length, index.episodes.length);
      expect(copy.movies.length, 3);
      expect(copy['Alpha-e3']!.runtime, const Duration(minutes: 22));
    });

    test('clip, chapter, Etag and pool fields round-trip through JSON', () {
      const clip = MediaEntry(
        id: 'reel@47063',
        kind: MediaKind.commercial,
        title: 'Reel',
        runtime: Duration(seconds: 30),
        sourceId: 'reel',
        clipStart: Duration(milliseconds: 47063),
        etag: 'abc',
        chapters: [Duration.zero, Duration(minutes: 2, seconds: 29)],
        poolIds: ['p1', 'p2'],
      );
      final copy = MediaEntry.fromJson(clip.toJson());
      expect(copy.sourceId, 'reel');
      expect(copy.clipStart, const Duration(milliseconds: 47063));
      expect(copy.isClip, isTrue);
      expect(copy.sourceStart, const Duration(milliseconds: 47063));
      expect(copy.etag, 'abc');
      expect(copy.chapters, clip.chapters);
      expect(copy.poolIds, ['p1', 'p2']);
    });

    test('a library.json from before clips and pools still loads', () {
      final old = {
        'fetchedAt': '2026-10-01T12:00:00.000',
        'series': [
          {'key': 'show|2000', 'id': 's1', 'name': 'Show', 'year': 2000}
        ],
        'episodes': [
          {'id': 'e1', 'kind': 'episode', 'title': 'One', 'runtimeMs': 1320000, 'seriesKey': 'show|2000'}
        ],
        'movies': <Object?>[],
        'commercials': [
          {'id': 'ad', 'kind': 'commercial', 'title': 'Ad', 'runtimeMs': 30000}
        ],
      };
      final index = LibraryIndex.fromJson(old);
      final e = index['e1']!;
      expect(e.sourceId, 'e1');
      expect(e.clipStart, isNull);
      expect(e.isClip, isFalse);
      expect(e.etag, isNull);
      expect(e.chapters, isEmpty);
      expect(index['ad']!.poolIds, isEmpty);
      expect(e.toJson().containsKey('sourceId'), isFalse, reason: 'whole items do not repeat their id');
    });
  });

  group('fetchLibraryIndex with commercial pools', () {
    // A Movies library with a "Trailers" folder inside, and a Commercials
    // library holding one 122-minute reel.
    Map<String, Object?> video(String id, String type, Duration length, {String? series}) => {
          'Id': id,
          'Name': id,
          'Type': type,
          'RunTimeTicks': length.inMicroseconds * 10,
          'LocationType': 'FileSystem',
          'Etag': 'etag-$id',
          if (series != null) ...{'SeriesId': series, 'SeriesName': series, 'ParentIndexNumber': 1, 'IndexNumber': 1},
          'Chapters': [
            {'StartPositionTicks': 0},
            {'StartPositionTicks': 1493580000},
          ],
        };
    final folders = <String, List<Map<String, Object?>>>{
      'movies': [
        video('movie-1', 'Movie', const Duration(minutes: 95)),
        video('trailer-1', 'Movie', const Duration(minutes: 2)),
        video('trailer-2', 'Movie', const Duration(seconds: 90)),
      ],
      'trailers': [
        video('trailer-1', 'Movie', const Duration(minutes: 2)),
        video('trailer-2', 'Movie', const Duration(seconds: 90)),
      ],
      'ads': [video('reel', 'Episode', const Duration(minutes: 122), series: 'Favorite Commercials')],
      'tv': [
        video('ep-1', 'Episode', const Duration(minutes: 22), series: 'Show'),
        {...video('mv-1', 'MusicVideo', const Duration(minutes: 4)), 'Artists': ['a-ha'], 'ProductionYear': 1985},
      ],
      'music': [
        {...video('song-1', 'Audio', const Duration(minutes: 3)), 'Artists': ['Queen'], 'Album': 'The Game', 'AlbumId': 'al-1'},
      ],
      'photos': [video('photo-1', 'Audio', const Duration(minutes: 3))],
      // A collection of a movie, two trailers and a show: the show's
      // episodes come from listing it.
      'box80s': [
        video('movie-1', 'Movie', const Duration(minutes: 95)),
        video('trailer-1', 'Movie', const Duration(minutes: 2)),
        {'Id': 'Show', 'Name': 'Show', 'Type': 'Series'},
      ],
      'Show': [video('ep-1', 'Episode', const Duration(minutes: 22), series: 'Show')],
    };
    final asked = <String>[];
    JellyfinClient fakeServer() => JellyfinClient(
          serverUrl: 'https://jf.example',
          deviceId: 'd',
          deviceName: 'pc',
          accessToken: 't',
          userId: 'u',
          httpClient: MockClient((r) async {
            final q = r.url.queryParameters;
            if (r.url.path == '/UserViews') {
              return http.Response(
                  jsonEncode({
                    'Items': [
                      {'Id': 'movies', 'Name': 'Movies', 'CollectionType': 'movies'},
                      {'Id': 'ads', 'Name': 'Commercials', 'CollectionType': 'tvshows'},
                      {'Id': 'tv', 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
                      {'Id': 'music', 'Name': 'Music', 'CollectionType': 'music'},
                      {'Id': 'photos', 'Name': 'Photos', 'CollectionType': 'photos'},
                    ]
                  }),
                  200);
            }
            final parent = q['ParentId']!;
            final types = q['IncludeItemTypes']!.split(',');
            asked.add('$parent:${q['IncludeItemTypes']}:${q['Fields']}');
            final items = [
              for (final i in folders[parent] ?? const <Map<String, Object?>>[])
                if (types.contains(i['Type'])) i,
              if (types.contains('Series') && parent == 'tv') {'Id': 'Show', 'Name': 'Show', 'Type': 'Series'},
            ];
            return http.Response(jsonEncode({'Items': items, 'TotalRecordCount': items.length}), 200);
          }),
        );

    setUp(asked.clear);

    test('a pool folder inside Movies leaves the channel lineups', () async {
      final pools = [
        CommercialPool(id: 'trailers', name: 'Trailers', roots: const [
          PoolRoot(itemId: 'trailers', libraryId: 'movies', label: 'Movies › Trailers'),
        ]),
      ];
      final index = await fetchLibraryIndex(fakeServer(), pools: pools);
      expect([for (final m in index.movies) m.id], ['movie-1']);
      expect([for (final c in index.commercials) c.id], ['trailer-1', 'trailer-2']);
      expect(index.commercials.first.poolIds, ['trailers']);
      // Folders removed from every pool come back as programs.
      final again = await fetchLibraryIndex(fakeServer());
      expect([for (final m in again.movies) m.id], ['movie-1', 'trailer-1', 'trailer-2']);
      expect(again.commercials, isEmpty);
    });

    test('an item in two pools carries both pool ids', () async {
      final pools = [
        CommercialPool(id: 'p1', name: 'Commercials', roots: const [
          PoolRoot(itemId: 'trailers', libraryId: 'movies', label: 'Trailers'),
        ]),
        CommercialPool(id: 'p2', name: 'Commercials 2', roots: const [
          PoolRoot(itemId: 'movies', libraryId: 'movies', label: 'Movies'),
        ]),
      ];
      final index = await fetchLibraryIndex(fakeServer(), pools: pools);
      final trailer = index['trailer-1']!;
      expect(trailer.kind, MediaKind.commercial);
      expect(trailer.poolIds, ['p1', 'p2']);
      expect(index['movie-1']!.poolIds, ['p2']);
      expect(index.movies, isEmpty);
      // A library that is itself a pool folder isn't scanned for programs.
      expect(asked.where((a) => a.startsWith('movies:Movie:Overview')), isEmpty);
    });

    test('a 122-minute reel is kept as a commercial item; programs get chapters and Etags', () async {
      final pools = [
        CommercialPool(id: 'p1', name: 'Commercials', roots: const [
          PoolRoot(itemId: 'ads', libraryId: 'ads', label: 'Commercials'),
        ]),
      ];
      final index = await fetchLibraryIndex(fakeServer(), pools: pools);
      final reel = index['reel']!;
      expect(reel.kind, MediaKind.commercial);
      expect(reel.runtime, const Duration(minutes: 122));
      expect(reel.etag, 'etag-reel');
      expect(index.episodes.map((e) => e.id), ['ep-1']);
      final ep = index['ep-1']!;
      expect(ep.etag, 'etag-ep-1');
      expect(ep.chapters, [Duration.zero, const Duration(milliseconds: 149358)]);
      expect(asked, contains('ads:Movie,Episode,Video,MusicVideo,Trailer:Chapters,Etag'));
      expect(asked, contains('tv:Episode:Overview,Chapters,Etag,DateCreated'));
    });

    test('a channel collection holds its movie and its show\'s episodes; pool items stay commercials', () async {
      final pools = [
        CommercialPool(id: 'trailers', name: 'Trailers', roots: const [
          PoolRoot(itemId: 'trailers', libraryId: 'movies', label: 'Movies › Trailers'),
        ]),
      ];
      final index = await fetchLibraryIndex(fakeServer(), pools: pools, channelRoots: {'box80s', 'deleted'});
      expect(index.itemsByRoot['box80s'], {'movie-1', 'ep-1'});
      expect(index['trailer-1']!.kind, MediaKind.commercial);
      expect(index.roots, {'box80s', 'deleted'});
      expect(index.missingRoots, {'deleted'}, reason: 'the server has nothing under it');
      expect(asked.where((a) => a.startsWith('box80s:')), hasLength(1), reason: 'each root is listed once');
      final playlist = buildPlaylist(
          index,
          const ChannelSource(roots: [PoolRoot(itemId: 'box80s', libraryId: 'movies', label: '80s')]),
          PlaybackOrder.random,
          seed: 1);
      expect(playlist.toSet(), {'movie-1', 'ep-1'});
    });

    test('music libraries give songs and video libraries music videos', () async {
      final index = await fetchLibraryIndex(fakeServer());
      expect(index.songs.map((s) => s.id), ['song-1']);
      expect(index['song-1']!.artist, 'Queen');
      expect(index['song-1']!.albumId, 'al-1');
      expect(index.musicVideos.map((s) => s.id), ['mv-1']);
      expect(index['mv-1']!.artist, 'a-ha');
      // Music libraries are scanned for songs only; other kinds not at all.
      expect([for (final a in asked) if (a.startsWith('music:')) a.split(':')[1]], ['Audio']);
      expect(asked.firstWhere((a) => a.startsWith('music:')), contains('Artists,AlbumArtist,Album,AlbumId'));
      expect(asked.where((a) => a.startsWith('photos:')), isEmpty);
    });

    test('pool videos under 5 seconds are ignored', () {
      final index = LibraryIndex.fromJellyfinItems(
        seriesItems: const [],
        episodeItems: const [],
        movieItems: const [],
        commercialItems: [
          {'Id': 'a', 'RunTimeTicks': 3 * 10000000, 'LocationType': 'FileSystem'},
          {'Id': 'b', 'RunTimeTicks': 30 * 10000000, 'LocationType': 'FileSystem'},
          {'Id': 'c', 'RunTimeTicks': 30 * 10000000, 'LocationType': 'Virtual'},
        ],
        poolsByItem: const {'a': ['p'], 'b': ['p'], 'c': ['p']},
      );
      expect([for (final c in index.commercials) c.id], ['b']);
    });
  });

  group('buildPlaylist', () {
    test('cyclic keeps each show in airing order and plays every episode once', () {
      final library = fakeLibrary(shows: {'Big': 175, 'Small': 6});
      final ids = buildPlaylist(library, const ChannelSource(), PlaybackOrder.cyclic, seed: 1);
      expect(ids, hasLength(181));
      expect(ids.toSet(), hasLength(181));
      final small = ids.where((id) => id.startsWith('Small')).toList();
      expect(small, ['Small-e1', 'Small-e2', 'Small-e3', 'Small-e4', 'Small-e5', 'Small-e6']);
      // The small show is spread out, not bunched at the start.
      final positions = [for (final id in small) ids.indexOf(id)];
      expect(positions.last - positions.first, greaterThan(100));
    });

    test('random avoids the same show back to back when possible', () {
      final library = fakeLibrary(shows: {'A': 20, 'B': 20, 'C': 20});
      final ids = buildPlaylist(library, const ChannelSource(), PlaybackOrder.random, seed: 7);
      var repeats = 0;
      for (var i = 1; i < ids.length; i++) {
        if (ids[i].split('-').first == ids[i - 1].split('-').first) repeats++;
      }
      expect(repeats, lessThanOrEqualTo(1));
    });

    test('is deterministic for a seed', () {
      final library = fakeLibrary();
      expect(buildPlaylist(library, const ChannelSource(), PlaybackOrder.random, seed: 3),
          buildPlaylist(library, const ChannelSource(), PlaybackOrder.random, seed: 3));
    });
  });

  group('ChannelGenerator', () {
    test('builds mix, genre, show and movie channels without near-duplicates', () {
      final library = fakeLibrary(
        shows: {'Toons': 80, 'Sitcom': 40, 'Mystery Kids': 30},
        genres: {
          'Toons': ['Animation', 'Comedy', 'Kids'],
          'Sitcom': ['Comedy', 'Family'],
          'Mystery Kids': ['Animation', 'Kids', 'Mystery'],
        },
        movies: 14,
      );
      final channels = ChannelGenerator(library, anchor: DateTime(2026)).generate();
      final names = channels.map((c) => c.name).toList();
      expect(names.first, 'All Shows');
      // Animation and Kids cover the same two shows: only one of them, which
      // Toons and Mystery Kids list first. That leaves Comedy with one show:
      // too few for a genre channel. Three shows have no room for a marathon.
      expect(names, ['All Shows', 'Toon TV', 'Movie Channel']);
      // Numbers are unique and sequential from 1.
      expect(channels.map((c) => c.number), [for (var i = 0; i < channels.length; i++) i + 1]);
    });

    test('each show airs on one genre channel; marathon shows only on their own', () {
      final library = fakeLibrary(
        shows: {'Seinfeld': 180, 'Tyson': 70, 'Archer': 40, 'Office': 50, 'Simpsons': 45, 'Monk': 30, 'Psych': 35},
        genres: {
          'Seinfeld': ['Comedy'],
          'Tyson': ['Animation', 'Comedy', 'Mystery'],
          'Archer': ['Animation', 'Comedy', 'Action'],
          'Office': ['Comedy'],
          'Simpsons': ['Animation', 'Comedy'],
          'Monk': ['Mystery', 'Comedy', 'Crime'],
          'Psych': ['Mystery', 'Comedy'],
        },
        movies: 0,
      );
      final channels = ChannelGenerator(library,
              anchor: DateTime(2026), options: const GeneratorOptions(maxShowChannels: 2, showsPerShowChannel: 1))
          .generate();
      final genre = channels.where((c) => c.id.startsWith('auto:genre:')).toList();
      expect(genre, hasLength(greaterThanOrEqualTo(2)));
      String showOf(String id) => id.split('-e').first;
      final seen = <String, String>{};
      for (final c in genre) {
        for (final show in c.playlist.map(showOf).toSet()) {
          expect(seen[show], isNull, reason: '$show is on ${seen[show]} and ${c.name}');
          seen[show] = c.name;
        }
      }
      expect(channels.where((c) => c.id.startsWith('auto:show:')).map((c) => c.name), ['Seinfeld', 'Tyson']);
      expect(seen.keys, isNot(contains('Seinfeld')));
      expect(seen.keys, isNot(contains('Tyson')));
      // Comedy is every show (All Shows again), so Office, comedy only, is on All Shows.
      expect(seen.keys.toSet(), {'Archer', 'Simpsons', 'Monk', 'Psych'});
    });

    test('each movie airs on one movie genre channel', () {
      final library = LibraryIndex.fromJellyfinItems(seriesItems: const [], episodeItems: const [], movieItems: [
        for (var i = 1; i <= 60; i++)
          {
            'Id': 'm$i',
            'Name': 'Movie $i',
            'RunTimeTicks': const Duration(minutes: 95).inMicroseconds * 10,
            'Genres': [if (i % 2 == 0) 'Comedy', if (i % 3 == 0) 'Drama', if (i % 5 != 0) 'Action', if (i % 4 == 0) 'Thriller'],
          },
      ]);
      final channels = ChannelGenerator(library, anchor: DateTime(2026)).generate();
      expect(channels.firstWhere((c) => c.id == 'auto:movies').playlist, hasLength(60));
      final genre = channels.where((c) => c.id.startsWith('auto:movies:')).toList();
      // Every even movie lists Comedy first, so Drama is left too few and
      // Thriller none: Comedy and Action.
      expect(genre.map((c) => c.name), ['Action & Adventure Movies', 'Comedy Movies']);
      final seen = <String>{};
      for (final c in genre) {
        expect(c.playlist.length, greaterThanOrEqualTo(12), reason: c.name);
        for (final id in c.playlist) {
          expect(seen.add(id), isTrue, reason: '$id is on two movie genre channels');
          // On the channel of its first listed genre that has one.
          final first = normalizeGenre(library[id]!.genres.firstWhere((g) => ['Comedy', 'Action'].contains(g)));
          expect(c.source.genres, [first], reason: id);
        }
      }
    });

    test('spreadTitles shares titles again after a channel is hidden', () {
      final library = fakeLibrary(
        shows: {'A': 40, 'B': 40, 'C': 40, 'D': 40, 'E': 40},
        genres: {
          'A': ['Family', 'Comedy'],
          'B': ['Family', 'Comedy'],
          'C': ['Comedy'],
          'D': ['Family', 'Drama'],
          'E': ['Comedy'],
        },
      );
      final channels = ChannelGenerator(library, anchor: DateTime(2026)).generate();
      final comedy = channels.firstWhere((c) => c.id == 'auto:genre:Comedy');
      final family = channels.firstWhere((c) => c.id == 'auto:genre:Family');
      Set<String> shows(Channel c) =>
          buildPlaylist(library, c.source, c.order, seed: 1).map((id) => id.split('-e').first).toSet();
      expect(shows(comedy).intersection(shows(family)), isEmpty);
      expect(shows(family), {'A', 'B', 'D'}, reason: 'each show on its first genre');
      expect(shows(comedy), {'C', 'E'});
      family.hidden = true;
      ChannelGenerator.spreadTitles(library, channels);
      expect(shows(comedy), {'A', 'B', 'C', 'E'}, reason: 'Comedy takes what hidden Family had');
    });
  });

  group('spliceNew', () {
    test('new items air from the start, every few programs, wrapping around', () {
      final loop = [for (var i = 0; i < 10; i++) 'o$i'];
      expect(spliceNew(loop, ['n1', 'n2'], 4), ['n1', 'o4', 'o5', 'o6', 'n2', 'o7', 'o8', 'o9', 'o0', 'o1', 'o2', 'o3']);
      expect(spliceNew(loop, ['n1'], 10).first, 'n1');
      final many = spliceNew(loop, [for (var i = 0; i < 30; i++) 'n$i'], 0);
      expect(many, hasLength(40));
      expect(many.take(4), ['n0', 'o0', 'n1', 'o1']);
      expect(spliceNew(const [], ['n1'], 0), ['n1']);
    });

    test('normalizes genre spellings', () {
      expect(normalizeGenre('Science Fiction'), 'Sci-Fi & Fantasy');
      expect(normalizeGenre('Action'), 'Action & Adventure');
      expect(normalizeGenre('Kids'), 'Kids');
    });
  });

  group('JellyfinClient.normalizeServerUrl', () {
    test('adds a scheme, fixes missing slashes, trims trailing slashes', () {
      expect(JellyfinClient.normalizeServerUrl('example.org:8920'), 'https://example.org:8920');
      expect(JellyfinClient.normalizeServerUrl('https:example.org:8920/'), 'https://example.org:8920');
      expect(JellyfinClient.normalizeServerUrl(' http://10.0.0.5:8096// '), 'http://10.0.0.5:8096');
    });
  });
}
