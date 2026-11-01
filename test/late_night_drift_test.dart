import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/library/pool_root.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/ui/format.dart';

import 'fixtures.dart';

/// Minimum ratings on block mixes and the late-night shortcut
/// (late-night-drift).
void main() {
  const shows = {'Kiddo': 4, 'Family': 3, 'Edgy': 5, 'Grown': 6, 'Blank': 2};
  const ratings = {'Kiddo': 'TV-G', 'Family': 'TV-PG', 'Edgy': 'TV-14', 'Grown': 'TV-MA'};
  const comedy = {'Kiddo': ['Comedy'], 'Family': ['Comedy'], 'Edgy': ['Comedy'], 'Grown': ['Comedy'], 'Blank': ['Comedy']};
  // movie-1 R, movie-2 PG, movie-3 unrated, movie-4 an unknown rating.
  const movieRatings = {1: 'R', 2: 'PG', 4: 'MA 15+'};

  LibraryIndex library() =>
      fakeLibrary(shows: shows, ratings: ratings, genres: comedy, movies: 4, movieRatings: movieRatings);

  Set<String> playlist(LibraryIndex lib, ChannelSource source) =>
      buildPlaylist(lib, source, PlaybackOrder.cyclic, seed: 1).toSet();

  Set<String> episodes(String show, int count) => {for (var i = 1; i <= count; i++) '$show-e$i'};

  group('the model', () {
    test('the minimum round-trips through JSON; old JSON and unknown names have none', () {
      const source = ChannelSource(genres: ['Comedy'], ratingFloor: RatingFloor.mature);
      expect(source.toJson()['ratingFloor'], 'mature');
      expect(ChannelSource.fromJson(source.toJson()).ratingFloor, RatingFloor.mature);
      expect(const ChannelSource().toJson().containsKey('ratingFloor'), isFalse);
      expect(ChannelSource.fromJson({'episodes': true}).ratingFloor, isNull);
      expect(ChannelSource.fromJson({'ratingFloor': 'spicy'}).ratingFloor, isNull);
    });

    test('copyWith keeps, sets and clears the minimum', () {
      const source = ChannelSource(ratingFloor: RatingFloor.teen);
      expect(source.copyWith(genres: ['Drama']).ratingFloor, RatingFloor.teen);
      expect(source.copyWith(ratingFloor: () => RatingFloor.adult).ratingFloor, RatingFloor.adult);
      expect(source.copyWith(ratingFloor: () => null).ratingFloor, isNull);
    });

    test('ranks: X and XXX are at the top; kid limits still keep them out', () {
      expect([for (final r in ['TV-14', 'PG-13', 'TV-MA', 'R', 'NC-17', '18', 'X', 'XXX']) ratingRank(r)],
          [4, 4, 5, 5, 6, 6, 6, 6]);
      expect([for (final f in RatingFloor.values) f.rank], [4, 5, 6]);
      expect(ratingRank('X')! > KidRating.older.maxRank, isTrue);
    });
  });

  group('the filter', () {
    test('a genre mix keeps only shows at the minimum or above, by the show\'s rating', () {
      final lib = library();
      const source = ChannelSource(genres: ['Comedy']);
      expect(playlist(lib, source), {...episodes('Kiddo', 4), ...episodes('Family', 3), ...episodes('Edgy', 5),
          ...episodes('Grown', 6), ...episodes('Blank', 2)});
      expect(playlist(lib, source.copyWith(ratingFloor: () => RatingFloor.mature)), episodes('Grown', 6));
      expect(playlist(lib, source.copyWith(ratingFloor: () => RatingFloor.teen)),
          {...episodes('Edgy', 5), ...episodes('Grown', 6)});
      expect(playlist(lib, source.copyWith(ratingFloor: () => RatingFloor.adult)), isEmpty);
    });

    test('movies go by their own rating; unrated and unknown ratings stay out', () {
      final lib = library();
      const source = ChannelSource(includeEpisodes: false, includeMovies: true);
      expect(playlist(lib, source), {'movie-1', 'movie-2', 'movie-3', 'movie-4'});
      expect(playlist(lib, source.copyWith(ratingFloor: () => RatingFloor.teen)), {'movie-1'});
    });

    test('picked shows and roots are narrowed too', () {
      final base = library();
      final lib = LibraryIndex(
        series: base.series,
        episodes: base.episodes,
        movies: base.movies,
        commercials: base.commercials,
        fetchedAt: base.fetchedAt,
        rootsByItem: {
          for (final id in ['Kiddo-e1', 'Grown-e1', 'movie-1', 'movie-2']) id: ['box'],
        },
        roots: {'box'},
      );
      const picked = ChannelSource(seriesKeys: ['kiddo|2000', 'grown|2000', 'blank|2000'], ratingFloor: RatingFloor.mature);
      expect(playlist(lib, picked), episodes('Grown', 6));
      const rooted = ChannelSource(
          includeEpisodes: false, roots: [PoolRoot(itemId: 'box', libraryId: 'tv', label: 'Box')], ratingFloor: RatingFloor.mature);
      expect(playlist(lib, rooted), {'Grown-e1', 'movie-1'});
    });

    test('music ignores the minimum', () {
      final lib = fakeLibrary(songs: fakeMusic(20));
      const source = ChannelSource(includeEpisodes: false, includeSongs: true);
      expect(playlist(lib, source.copyWith(ratingFloor: () => RatingFloor.adult)), hasLength(20));
    });
  });

  group('the shortcut', () {
    ProgramBlock blank() => ProgramBlock(
          id: 'b',
          title: '',
          channelId: 'c',
          days: {6},
          startMinute: 7 * 60,
          endMinute: 12 * 60,
          source: const ChannelSource(includeEpisodes: false),
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: DateTime(2026, 10, 1),
        );

    Channel channel(ChannelSource source, {bool blockOnly = false, PlaybackOrder order = PlaybackOrder.weighted}) => Channel(
          id: 'c',
          number: 5,
          name: 'Comedy',
          icon: const ChannelIcon.builtin('tv'),
          source: source,
          order: order,
          playlist: const [],
          anchor: DateTime(2026),
          blockOnly: blockOnly,
        );

    test('defaults: Late Night, every day, 11 PM to 4 AM, TV-MA and up', () {
      final b = lateNightDefaults(blank());
      expect((b.title, b.startMinute, b.endMinute), ('Late Night', 23 * 60, 4 * 60));
      expect(b.days, {1, 2, 3, 4, 5, 6, 7});
      expect(b.source.ratingFloor, RatingFloor.mature);
      expect(describeBlock(b), 'Every day  ·  11:00 PM – 4:00 AM  ·  TV-MA / R and up');
    });

    test("a regular channel's source and order are copied with the minimum", () {
      final ch = channel(const ChannelSource(genres: ['Comedy']));
      expect(lateNightSource(ch).toJson(), const ChannelSource(genres: ['Comedy'], ratingFloor: RatingFloor.mature).toJson());
      expect(lateNightOrder(ch, PlaybackOrder.cyclic), PlaybackOrder.weighted);
    });

    test('music, live and block-only channels start with nothing chosen', () {
      final empty = const ChannelSource(includeEpisodes: false, ratingFloor: RatingFloor.mature).toJson();
      final music = channel(const ChannelSource(includeEpisodes: false, includeSongs: true), order: PlaybackOrder.random);
      final blockOnly = channel(const ChannelSource(genres: ['Comedy']), blockOnly: true);
      final live = Channel.live(
          ref: const LiveRef(sourceId: 's', key: 'k'), number: 9, name: 'News', icon: const ChannelIcon.builtin('tv'));
      for (final ch in [music, blockOnly, live]) {
        expect(lateNightSource(ch).toJson(), empty, reason: ch.name);
        expect(lateNightOrder(ch, PlaybackOrder.cyclic), PlaybackOrder.cyclic, reason: ch.name);
      }
    });
  });

  group('in the app', () {
    late Directory dir;
    late AppState app;
    var serverRatings = Map.of(ratings);
    var serverShows = Map.of(shows);

    JellyfinClient server() {
      final items = fakeItems(
          shows: serverShows,
          ratings: serverRatings,
          genres: {for (final name in serverShows.keys) name: const ['Comedy']},
          movies: 4, movieRatings: movieRatings);
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
          return http.Response(jsonEncode({'Items': all, 'TotalRecordCount': all.length}), 200);
        }),
      );
    }

    setUp(() async {
      serverRatings = Map.of(ratings);
      serverShows = Map.of(shows);
      dir = await Directory.systemTemp.createTemp('nightingale_tv_late_night');
      app = await signedInApp(dir, library());
    });

    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    ProgramBlock lateNight() => app.newBlock()
      ..title = 'Late Night'
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = 23 * 60
      ..endMinute = 4 * 60
      ..source = const ChannelSource(genres: ['Comedy'], ratingFloor: RatingFloor.mature);

    test('nothing qualifying: the editor says so', () {
      final block = lateNight()..source = const ChannelSource(seriesKeys: ['kiddo|2000'], ratingFloor: RatingFloor.mature);
      expect(app.blockProblem(block),
          'Nothing in this mix is rated TV-MA or higher. Choose a lower rating or other shows.');
      expect(app.blockProblem(block..source = const ChannelSource(includeEpisodes: false, ratingFloor: RatingFloor.mature)),
          'Choose some shows or movies for the block to play.');
      expect(app.blockProblem(lateNight()), isNull);
    });

    test('a new qualifying show joins after a scan; a corrected rating leaves', () async {
      await app.saveBlock(lateNight());
      final before = [...app.blocks.single.playlist];
      expect(before.toSet(), episodes('Grown', 6));
      serverShows['Night'] = 3;
      serverRatings['Night'] = 'TV-MA';
      app.client = server();
      await app.refreshLibrary(background: true);
      expect(app.blocks.single.playlist.take(6), before, reason: 'the current items keep their order');
      expect(app.blocks.single.playlist.skip(6).toSet(), episodes('Night', 3));

      serverRatings['Grown'] = 'TV-PG';
      app.client = server();
      await app.refreshLibrary(background: true);
      expect(app.blocks.single.playlist.toSet(), episodes('Night', 3));
    });

    test('changing the minimum restarts the lineup', () async {
      final block = lateNight();
      await app.saveBlock(block);
      final oldAnchor = DateTime(2026, 1, 3);
      app.blocks.single.anchor = oldAnchor;
      final changed = app.blocks.single.copy()..source = block.source.copyWith(ratingFloor: () => RatingFloor.teen);
      expect(app.blockRestarts(changed), isTrue);
      await app.saveBlock(changed);
      expect(app.blocks.single.anchor, isNot(oldAnchor));
      expect(app.blocks.single.playlist.toSet(), {...episodes('Edgy', 5), ...episodes('Grown', 6)});
    });

    test('two blocks make a gradual drift', () async {
      final ch = app.channels.first;
      await app.saveBlock(lateNight()
        ..title = 'Prime'
        ..channelId = ch.id
        ..startMinute = 21 * 60
        ..endMinute = 23 * 60
        ..source = const ChannelSource(genres: ['Comedy'], ratingFloor: RatingFloor.teen));
      final late = lateNight()..channelId = ch.id;
      expect(app.blockProblem(late), isNull);
      await app.saveBlock(late);
      expect((app.scheduleFor(ch)! as ChannelSchedule).blocks, hasLength(2));
    });

    test('the Kids tab drops a channel with a mature block', () async {
      final ch = await app.createCustomChannel('Kiddo TV', const ChannelSource(seriesKeys: ['kiddo|2000']));
      expect(app.autoGroups.isKids(ch), isTrue);
      await app.saveBlock(lateNight()
        ..channelId = ch.id
        ..source = const ChannelSource(seriesKeys: ['grown|2000'], ratingFloor: RatingFloor.mature));
      expect(app.autoGroups.isKids(ch), isFalse);
    });
  });

  test('on a kid profile, a rated block has nothing to play and the regular loop continues', () async {
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_late_night_kid');
    final app = await signedInApp(dir, library(), maxRatingRank: KidRating.older.maxRank);
    addTearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });
    final ch = app.channels.first;
    final now = DateTime.now();
    final start = now.add(const Duration(minutes: 2));
    final block = app.newBlock()
      ..title = 'Late Night'
      ..channelId = ch.id
      ..days = {1, 2, 3, 4, 5, 6, 7}
      ..startMinute = start.hour * 60 + start.minute
      ..endMinute = (start.hour * 60 + start.minute + 60) % (24 * 60)
      ..source = const ChannelSource(genres: ['Comedy'], ratingFloor: RatingFloor.teen);
    expect(app.blockPlaylist(block), isEmpty);
    await app.saveBlock(block);
    final schedule = app.scheduleFor(ch)!;
    expect((schedule as ChannelSchedule).blocks, isEmpty);
    final airing = schedule.programsBetween(start, start.add(const Duration(minutes: 60)));
    expect(airing, isNotEmpty);
    for (final p in airing) {
      final item = p.item;
      if (item == null) continue;
      final rating = item.seriesKey == null ? item.officialRating : app.library.seriesByKey[item.seriesKey]?.officialRating;
      expect(ratingRank(rating)! <= KidRating.older.maxRank, isTrue, reason: p.title);
    }
  });
}
