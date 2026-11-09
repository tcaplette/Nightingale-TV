import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/library/pool_root.dart';

import 'fixtures.dart';
import 'lineup_dedup_test.dart' show lineupProblems;
import 'lineup_fixture.dart';

/// A show for [lib]: [episodes] episodes, each with its year from [years]
/// in turn (null: none), the show's own [year] and [genres].
class Show {
  const Show(this.name, this.genres, {this.year, this.episodes = 20, this.years});
  final String name;
  final List<String> genres;
  final int? year;
  final int episodes;
  final List<int?>? years;
}

/// [n] movies named [prefix]-1…, tagged [genres], each year from [years] in
/// turn.
List<MediaEntry> films(String prefix, int n, List<String> genres, List<int?> years) => [
      for (var i = 1; i <= n; i++)
        MediaEntry(
            id: '$prefix-$i',
            kind: MediaKind.movie,
            title: '$prefix $i',
            runtime: const Duration(minutes: 100),
            genres: genres,
            year: years[(i - 1) % years.length]),
    ];

LibraryIndex lib(List<Show> shows, [List<MediaEntry> movies = const []]) =>
    LibraryIndex(
      series: [for (final s in shows) SeriesEntry(key: s.name, id: s.name, name: s.name, year: s.year, genres: s.genres)],
      episodes: [
        for (final s in shows)
          for (var i = 1; i <= s.episodes; i++)
            MediaEntry(
                id: '${s.name}-e$i',
                kind: MediaKind.episode,
                title: '${s.name} $i',
                runtime: const Duration(minutes: 22),
                seriesKey: s.name,
                seriesName: s.name,
                season: 1,
                episode: i,
                year: s.years == null ? null : s.years![(i - 1) % s.years!.length]),
      ],
      movies: movies,
      fetchedAt: DateTime(2026),
    );

List<Channel> generate(LibraryIndex library) => ChannelGenerator(library, anchor: DateTime(2026)).generate();

Channel? named(List<Channel> channels, String name) => channels.where((c) => c.name == name).firstOrNull;

Set<String> showsOf(LibraryIndex library, Iterable<String> ids) => {for (final id in ids) ?library[id]?.seriesKey};

void main() {
  group('genres and decades', () {
    test('the genre chips merge combined tags into the major genres', () {
      final library = lib([
        const Show('A', ['Sci-Fi & Fantasy']),
      ], films('m', 2, ['Science Fiction'], [2000]));
      final chips = {
        for (final s in library.series) ...titleGenres(s.genres),
        for (final m in library.movies) ...titleGenres(m.genres),
      };
      expect(chips, {'Sci-Fi', 'Fantasy'});
    });

    test('a combined TV tag counts as both genres', () {
      final library = lib([
        const Show('AA1', ['Action & Adventure'], episodes: 20),
        const Show('AA2', ['Action & Adventure'], episodes: 20),
        const Show('C', ['Comedy'], episodes: 20),
      ]);
      Set<String> plays(String genre) =>
          showsOf(library, buildPlaylist(library, ChannelSource(genres: [genre]), PlaybackOrder.cyclic, seed: 1));
      expect(plays('Action'), {'AA1', 'AA2'});
      expect(plays('Adventure'), {'AA1', 'AA2'});
    });

    test('saved genre names convert, and play the same titles', () {
      expect(migrateGenres(['Action & Adventure']), ['Action', 'Adventure']);
      expect(migrateGenres(['Sci-Fi & Fantasy', 'Comedy']), ['Comedy', 'Fantasy', 'Sci-Fi']);
      expect(migrateGenres(['Thriller', 'Mystery']), ['Thriller & Mystery']);
      expect(migrateGenres(['Comedy', 'Drama']), ['Comedy', 'Drama']);

      final library = lib([
        const Show('Act', ['Action']),
        const Show('Adv', ['Adventure']),
        const Show('Both', ['Action & Adventure']),
        const Show('Thr', ['Thriller']),
        const Show('Mys', ['Mystery']),
        const Show('Sus', ['Suspense']),
        const Show('Com', ['Comedy']),
      ], [
        ...films('act', 2, ['Action'], [1990]),
        ...films('sus', 2, ['Suspense'], [1990]),
        ...films('com', 2, ['Comedy'], [1990]),
      ]);
      // A custom channel saved with Action & Adventure.
      final channel = Channel.fromJson({
        ...Channel(
          id: 'user:1',
          number: 40,
          name: 'Mine',
          icon: const ChannelIcon.builtin('tv'),
          source: const ChannelSource(),
          order: PlaybackOrder.random,
          playlist: const [],
          anchor: DateTime(2026),
          auto: false,
        ).toJson(),
        'source': {'genres': ['Action & Adventure'], 'episodes': true, 'movies': true},
      });
      expect(channel.source.genres, ['Action', 'Adventure']);
      final ids = buildPlaylist(library, channel.source, PlaybackOrder.random, seed: 1).toSet();
      expect(showsOf(library, ids), {'Act', 'Adv', 'Both'});
      expect(ids.where((id) => library[id]!.kind == MediaKind.movie), {'act-1', 'act-2'});

      // A block from an old backup with Thriller and Mystery.
      final block = ProgramBlock.fromJson({
        ...ProgramBlock(
          id: 'b',
          title: 'Whodunits',
          channelId: 'user:1',
          days: {5},
          startMinute: 20 * 60,
          endMinute: 0,
          source: const ChannelSource(),
          order: PlaybackOrder.random,
          playlist: const [],
          anchor: DateTime(2026),
        ).toJson(),
        'source': {'genres': ['Thriller', 'Mystery'], 'episodes': true, 'movies': true},
      });
      expect(block.source.genres, ['Thriller & Mystery']);
      final played = buildPlaylist(library, block.source, block.order, seed: 1).toSet();
      expect(showsOf(library, played), {'Thr', 'Mys', 'Sus'});
      expect(played.where((id) => library[id]!.kind == MediaKind.movie), {'sus-1', 'sus-2'});
      // Written back in the new form.
      expect(block.toJson()['source'], containsPair('genres', ['Thriller & Mystery']));
    });
  });

  group('playlists with decades', () {
    final library = lib([
      // 1989–1998: its 1989 episodes are the 80s.
      const Show('Frasier', ['Comedy'], year: 1989, episodes: 10, years: [1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998]),
      const Show('Sitcom 90s', ['Comedy'], year: 1993),
      const Show('Drama 90s', ['Drama'], year: 1995),
      // No episode years: the show's year counts.
      const Show('Comedy 2000s', ['Comedy'], year: 2004),
      const Show('No Year', ['Comedy']),
    ], [
      ...films('action80', 5, ['Action'], [1982, 1987]),
      ...films('action90', 3, ['Action'], [1994]),
      ...films('comedy90', 2, ['Comedy'], [1991]),
      ...films('noyear', 2, ['Action'], [null]),
    ]);
    List<String> play(ChannelSource s) => buildPlaylist(library, s, PlaybackOrder.random, seed: 3);

    test('90s sitcoms: every comedy episode of the 1990s and no movies', () {
      final ids = play(const ChannelSource(genres: ['Comedy'], decades: [1990]));
      expect(ids.every((id) => library[id]!.kind == MediaKind.episode), isTrue);
      expect(showsOf(library, ids), {'Frasier', 'Sitcom 90s'});
      expect(ids.where((id) => id.startsWith('Frasier')), hasLength(9), reason: '1990–1998');
    });

    test('a picked show is narrowed by decade', () {
      final ids = play(const ChannelSource(seriesKeys: ['Frasier'], decades: [1980]));
      expect(ids, ['Frasier-e1']);
    });

    test('80s action movies, Shows off: no episodes', () {
      final ids = play(const ChannelSource(genres: ['Action'], decades: [1980], includeEpisodes: false, includeMovies: true));
      expect(ids.toSet(), {for (var i = 1; i <= 5; i++) 'action80-$i'});
    });

    test('90s shows and movies, no genres: every episode and movie of the 1990s', () {
      final ids = play(const ChannelSource(decades: [1990], includeMovies: true)).toSet();
      expect(showsOf(library, ids), {'Frasier', 'Sitcom 90s', 'Drama 90s'});
      expect(ids.where((id) => library[id]!.kind == MediaKind.movie).toSet(),
          {'action90-1', 'action90-2', 'action90-3', 'comedy90-1', 'comedy90-2'});
    });

    test('no year matches no decade, and still plays without one', () {
      expect(play(const ChannelSource(decades: [1980, 1990, 2000], includeMovies: true)).where((id) => id.startsWith('No Year') || id.startsWith('noyear')),
          isEmpty);
      final all = play(const ChannelSource(includeMovies: true));
      expect(all, containsAll(['No Year-e1', 'noyear-1']));
    });

    test('roots are narrowed by decade too', () {
      final rooted = library.withRoots({
        'box': {'Frasier-e1', 'Frasier-e2', 'action80-1', 'action90-1'},
      });
      const root = PoolRoot(itemId: 'box', libraryId: 'tv', label: 'Box');
      final ids = buildPlaylist(rooted, const ChannelSource(roots: [root], decades: [1980], includeEpisodes: false),
          PlaybackOrder.random, seed: 1);
      expect(ids.toSet(), {'Frasier-e1', 'action80-1'});
    });

    test('an 80s movie night block plays only 80s action movies', () {
      final block = ProgramBlock(
        id: 'friday',
        title: '80s Action',
        channelId: 'user:1',
        days: {5},
        startMinute: 20 * 60,
        endMinute: 0,
        source: const ChannelSource(genres: ['Action'], decades: [1980], includeEpisodes: false, includeMovies: true),
        order: PlaybackOrder.random,
        playlist: const [],
        anchor: DateTime(2026),
      );
      final ids = buildPlaylist(library, block.source, block.order, seed: stableHash(block.id));
      expect(ids.toSet(), {for (var i = 1; i <= 5; i++) 'action80-$i'});
    });
  });

  group('generated genre channels', () {
    const majors = [
      'Action',
      'Adventure',
      'Comedy',
      'Drama',
      'Horror',
      'Sci-Fi',
      'Fantasy',
      'Romance',
      'Thriller & Mystery',
      'Western',
      'Documentary',
      'Animation',
    ];
    const tags = {'Sci-Fi': 'Science Fiction', 'Thriller & Mystery': 'Thriller'};

    test('a library with every major genre gets 12 show and 12 movie genre channels', () {
      final library = lib([
        for (final (i, g) in majors.indexed)
          for (var n = 1; n <= 3; n++) Show('$g $n', [tags[g] ?? g], year: 1950 + i * 5, episodes: 14),
      ], [
        for (final (i, g) in majors.indexed) ...films('m-$g', 15, [tags[g] ?? g], [1950 + i * 5]),
      ]);
      final channels = generate(library);
      final showGenres = [for (final c in channels) if (c.id.startsWith('auto:genre:')) c.source.genres.single];
      final movieGenres = [
        for (final c in channels)
          if (c.id.startsWith('auto:movies:') && c.source.decades.isEmpty) c.source.genres.single,
      ];
      expect(showGenres.toSet(), majors.toSet());
      expect(movieGenres.toSet(), majors.toSet());
      expect(showGenres, hasLength(12));
      expect(movieGenres, hasLength(12));
      expect({for (final c in channels) if (c.id.startsWith('auto:genre:')) c.name}, {
        'Action TV',
        'Adventure TV',
        'Laugh Track',
        'Drama Central',
        'Fright Night',
        'Sci-Fi TV',
        'Fantasy TV',
        'Romance TV',
        'Mystery & Thrills',
        'Frontier TV',
        'Discovery Zone',
        'Toon TV',
      });
      expect(named(channels, 'Thriller & Mystery Movies'), isNotNull);
      expect(lineupProblems(library, channels), isEmpty);
    });

    test('Action and Adventure with the same shows make one channel', () {
      final library = lib([
        const Show('A1', ['Action & Adventure'], episodes: 30),
        const Show('A2', ['Action', 'Adventure'], episodes: 30),
        const Show('C1', ['Comedy'], episodes: 20),
        const Show('C2', ['Comedy'], episodes: 20),
      ]);
      final genre = [for (final c in generate(library)) if (c.id.startsWith('auto:genre:')) c.source.genres.single];
      expect(genre.where((g) => g == 'Action' || g == 'Adventure'), hasLength(1));
      expect(genre, contains('Comedy'));
    });

    test('a genre outside the 12: Crime gets a show and a movie channel', () {
      final library = lib([
        const Show('Cr1', ['Crime'], episodes: 20),
        const Show('Cr2', ['Crime'], episodes: 15),
        const Show('Cr3', ['Crime'], episodes: 15),
        const Show('Co1', ['Comedy'], episodes: 20),
      ], [
        ...films('crime', 14, ['Crime'], [1990, 2000, 2010]),
        ...films('other', 10, ['Comedy'], [1990, 2000, 2010]),
      ]);
      final channels = generate(library);
      expect(named(channels, 'Crime & Justice'), isNotNull);
      expect(named(channels, 'Crime Movies')!.playlist, hasLength(14));
    });

    test('8 westerns: no Western Movies; they air on Movie Channel', () {
      final library = lib([], [
        ...films('west', 8, ['Western'], [1960]),
        ...films('com', 20, ['Comedy'], [1990, 2000]),
      ]);
      final channels = generate(library);
      expect(named(channels, 'Western Movies'), isNull);
      expect(named(channels, 'Movie Channel')!.playlist, containsAll(['west-1', 'west-8']));
    });
  });

  group('generated decade channels', () {
    test('a 90s-heavy library gets 90s Movies and 90s TV', () {
      final library = lib([
        for (var i = 1; i <= 5; i++) Show('S90 $i', [i.isEven ? 'Comedy' : 'Drama'], year: 1990 + i, episodes: 40),
        for (var i = 1; i <= 3; i++) Show('S00 $i', ['Comedy'], year: 2000 + i, episodes: 20),
      ], [
        ...films('m90c', 20, ['Comedy'], [1991, 1995, 1998]),
        ...films('m90d', 20, ['Drama'], [1992, 1996]),
        ...films('m10', 20, ['Drama'], [2012]),
      ]);
      final channels = generate(library);
      expect(named(channels, '90s TV')!.playlist, hasLength(200));
      expect(named(channels, '90s Movies')!.playlist, hasLength(40));
      expect(named(channels, '90s TV')!.order, PlaybackOrder.cyclic);
      expect(named(channels, '90s Movies')!.order, PlaybackOrder.random);
      expect(named(channels, '90s TV')!.id, 'auto:decade:1990');
      expect(named(channels, '90s Movies')!.id, 'auto:movies:decade:1990');
      expect(lineupProblems(library, channels), isEmpty);
    });

    test('a show across decades: its 80s episodes on 80s TV, its 90s ones on 90s TV', () {
      final library = lib([
        Show('Long', const ['Comedy'], year: 1987, episodes: 180, years: [
          for (var i = 0; i < 180; i++) i < 30 ? 1987 + i % 3 : 1990 + i % 7,
        ]),
        const Show('Other 80s', ['Drama'], year: 1985, episodes: 30),
        const Show('Other 90s', ['Drama'], year: 1995, episodes: 30),
        const Show('Other 2010s', ['Drama'], year: 2015, episodes: 60),
      ]);
      final channels = generate(library);
      final eighties = named(channels, '80s TV')!.playlist.where((id) => id.startsWith('Long-')).toSet();
      final nineties = named(channels, '90s TV')!.playlist.where((id) => id.startsWith('Long-')).toSet();
      expect(eighties, hasLength(30));
      expect(nineties, hasLength(150));
      expect(eighties.intersection(nineties), isEmpty);
    });

    test('decade channels come after the genre channels, oldest first', () {
      final library = lib([
        for (var i = 1; i <= 3; i++) Show('S70 $i', ['Comedy'], year: 1975, episodes: 20),
        for (var i = 1; i <= 3; i++) Show('S90 $i', ['Drama'], year: 1995, episodes: 20),
        for (var i = 1; i <= 3; i++) Show('S10 $i', ['Comedy', 'Drama'], year: 2015, episodes: 20),
      ]);
      final names = generate(library).map((c) => c.name).toList();
      expect(names.indexOf('70s TV'), greaterThan(names.indexOf('Laugh Track')));
      expect(names.indexOf('70s TV'), greaterThan(names.indexOf('Drama Central')));
      expect(names.indexOf('70s TV'), lessThan(names.indexOf('90s TV')));
      expect(names.indexOf('90s TV'), lessThan(names.indexOf('2010s TV')));
    });
  });

  group('decade + genre channels', () {
    test('80s Action Movies is made', () {
      // 120 action movies, 40 of them from the 80s; 150 movies from the 80s.
      final library = lib([], [
        ...films('a80', 40, ['Action'], [1981, 1985, 1988]),
        ...films('a00', 80, ['Action'], [2001, 2005, 2012, 2018]),
        ...films('d80', 110, ['Drama'], [1982, 1986]),
        ...films('c90', 60, ['Comedy'], [1993]),
      ]);
      final channels = generate(library);
      final c = named(channels, '80s Action Movies')!;
      expect(c.id, 'auto:movies:decade:1980:Action');
      expect(c.playlist.toSet(), {for (var i = 1; i <= 40; i++) 'a80-$i'});
      expect(c.icon.value, 'bolt');
      expect(lineupProblems(library, channels), isEmpty);
    });

    test('almost all of a genre in one decade: no 80s Horror Movies', () {
      final library = lib([], [
        ...films('h80', 38, ['Horror'], [1984]),
        ...films('h90', 2, ['Horror'], [1994]),
        ...films('d80', 60, ['Drama'], [1983]),
        ...films('c00', 60, ['Comedy'], [2005]),
      ]);
      final channels = generate(library);
      expect(named(channels, 'Horror Movies'), isNotNull);
      expect(named(channels, '80s Horror Movies'), isNull);
    });

    test('nine qualifying pairs: the four biggest get channels', () {
      // Three genres in three decades; each pair has 25 + its rank movies.
      final movies = <MediaEntry>[];
      var extra = 0;
      for (final g in ['Action', 'Comedy', 'Drama']) {
        for (final d in [1980, 1990, 2000]) {
          movies.addAll(films('$g-$d', 25 + extra++, [g], [d + 5]));
        }
      }
      final library = lib([], movies);
      final pairs = [
        for (final c in generate(library))
          if (c.id.startsWith('auto:movies:decade:') && c.source.genres.isNotEmpty) c.name,
      ];
      // The biggest pairs: Drama in the 2000s, 90s and 80s, then Comedy in the 2000s.
      expect(pairs, ['2000s Drama Movies', '90s Drama Movies', '80s Drama Movies', '2000s Comedy Movies']);
    });

    test('show decade + genre channels: 90s Comedy TV', () {
      final library = lib([
        for (var i = 1; i <= 4; i++) Show('C90 $i', ['Comedy'], year: 1992, episodes: 20),
        for (var i = 1; i <= 4; i++) Show('C10 $i', ['Comedy'], year: 2012, episodes: 20),
        for (var i = 1; i <= 4; i++) Show('D90 $i', ['Drama'], year: 1994, episodes: 20),
      ]);
      final channels = generate(library);
      final c = named(channels, '90s Comedy TV')!;
      expect(c.id, 'auto:decade:1990:Comedy');
      expect(showsOf(library, c.playlist), {'C90 1', 'C90 2', 'C90 3', 'C90 4'});
      expect(c.order, PlaybackOrder.cyclic);
      expect(lineupProblems(library, channels), isEmpty);
    });
  });

  group('evenings', () {
    test('a movie tagged Comedy and Horror is in both evenings', () {
      final library = lib([
        for (var i = 1; i <= 2; i++) Show('C$i', ['Comedy'], episodes: 20),
        for (var i = 1; i <= 2; i++) Show('H$i', ['Horror'], episodes: 20),
      ], [
        ...films('both', 1, ['Comedy', 'Horror'], [1990]),
        ...films('com', 12, ['Comedy'], [1990]),
        ...films('hor', 12, ['Horror'], [1990]),
      ]);
      final generator = ChannelGenerator(library, anchor: DateTime(2026));
      generator.generate();
      final evenings = {
        for (final b in generator.blocks)
          if (b.generated == Daypart.evening) b.channelId: b.playlist.toSet(),
      };
      expect(evenings['auto:genre:Comedy'], contains('both-1'));
      expect(evenings['auto:genre:Horror'], contains('both-1'));
      expect(evenings['auto:genre:Comedy'], hasLength(13));
    });

    test('Documentary with 3 movies gets no evening', () {
      final library = lib([
        for (var i = 1; i <= 2; i++) Show('D$i', ['Documentary'], episodes: 20),
        const Show('N', ['News'], episodes: 5),
      ], films('doc', 3, ['Documentary'], [2001]));
      final generator = ChannelGenerator(library, anchor: DateTime(2026));
      generator.generate();
      expect(generator.blocks.where((b) => b.generated == Daypart.evening), isEmpty);
    });
  });

  group('refreshes', () {
    late Directory dir;
    late AppState app;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_decades'));
    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    // Movies of a genre run 1991 on, so 90s Movies holds 9 of each.
    FixtureLibrary withMovies(Map<String, int> movies) => FixtureLibrary(items: [
          FixtureItem('c1', 'Comedy One', year: 2001, genres: ['Comedy'], episodes: seasons(1, 1, 20)),
          FixtureItem('c2', 'Comedy Two', year: 2003, genres: ['Comedy'], episodes: seasons(1, 1, 20)),
        ], movies: movies);

    Future<void> refresh(FixtureLibrary library) async {
      app.client = library.jellyfinServer();
      await app.refreshLibrary(background: true);
      expect(lineupProblems(app.library, app.allChannels, app.blocks), isEmpty);
    }

    test('channels the library grows into are added after the highest generated number; '
        'one under its minimum retires, a healthy one stays', () async {
      final start = withMovies({'Comedy': 9, 'Drama': 9, 'Horror': 20});
      app = await signedInApp(dir, start.index(ServerShape.jellyfin));
      expect(app.channelById('auto:movies:decade:1990')!.playlist, hasLength(27));
      expect(app.channelById('auto:movies:Horror'), isNotNull);
      int highest() => app.allChannels.where((c) => c.auto && !c.isLive).fold(0, (n, c) => c.number > n ? c.number : n);
      final top = highest();

      await refresh(withMovies({'Comedy': 9, 'Drama': 9, 'Horror': 20, 'Western': 14}));
      expect(app.channelById('auto:movies:Western')!.number, top + 1);

      // 90s Movies falls to 9 movies.
      await refresh(withMovies({'Horror': 20}));
      expect(app.channelById('auto:movies:decade:1990'), isNull);
      expect(app.channelById('auto:movies:Western'), isNull);
      expect(app.channelById('auto:movies:Horror')!.playlist, hasLength(20), reason: 'still meets its minimum');
    });
  });

  group('the one-time update', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_major_genres'));
    tearDown(() async => dir.delete(recursive: true));

    final library = lib([
      const Show('M1', ['Mystery'], year: 1992),
      const Show('M2', ['Thriller'], year: 2003),
      const Show('M3', ['Mystery', 'Suspense'], year: 2001),
      const Show('C1', ['Comedy'], year: 1985),
      const Show('C2', ['Comedy'], year: 1995),
      const Show('D1', ['Drama'], year: 1988),
      const Show('D2', ['Drama'], year: 2005),
    ], [
      ...films('act', 12, ['Action'], [1993]),
      ...films('dra', 12, ['Drama'], [2014]),
    ]);

    /// A lineup from before the major genres (lineup version 2): Mystery TV
    /// as channel 6, a favorite carrying the user's block; Thrill TV as 9,
    /// in a group; Action & Adventure Movies as 10; the highest generated
    /// channel 14.
    Future<AppStorage> savedProfile() async {
      final app = await signedInApp(dir, library, editChannels: (channels) {
        Map<String, Object?> byId(String id) => channels.firstWhere((c) => c['id'] == id);
        final all = byId('auto:all-shows'), comedy = byId('auto:genre:Comedy'), drama = byId('auto:genre:Drama');
        final movies = byId('auto:movies');
        Map<String, Object?> old(Map<String, Object?> from, String id, int number, String name, String icon, ChannelSource source,
                {bool favorite = false}) =>
            {
              ...from,
              'id': id,
              'number': number,
              'name': name,
              'icon': ChannelIcon.builtin(icon).toJson(),
              'source': source.toJson(),
              'favorite': favorite,
            };
        channels
          ..clear()
          ..addAll([
            {...all, 'number': 1},
            {...comedy, 'number': 3},
            old(comedy, 'auto:genre:Mystery', 6, 'Mystery TV', 'search', const ChannelSource(genres: ['Mystery']),
                favorite: true),
            old(comedy, 'auto:genre:Thriller', 9, 'Thrill TV', 'visibility', const ChannelSource(genres: ['Thriller'])),
            old(movies, 'auto:movies:Action & Adventure', 10, 'Action & Adventure Movies', 'bolt',
                const ChannelSource(genres: ['Action & Adventure'], includeEpisodes: false, includeMovies: true)),
            {...movies, 'number': 11},
            {...drama, 'number': 14},
          ]);
      });
      await app.saveBlock(ProgramBlock(
        id: 'user-block',
        title: 'Late Mysteries',
        channelId: 'auto:genre:Mystery',
        days: {6},
        startMinute: 22 * 60,
        endMinute: 23 * 60,
        source: const ChannelSource(genres: ['Thriller & Mystery']),
        order: PlaybackOrder.cyclic,
        playlist: const [],
        anchor: DateTime(2026),
      ));
      final group = ChannelGroup(id: 'group:mine', name: 'Mine');
      app.settings.groups = [group];
      await app.setInGroup(group, app.channelById('auto:genre:Thriller')!, true);
      await app.close();
      final storage = await AppStorage.at(dir);
      final saved = (await storage.readJson('settings.json') as Map<String, Object?>)..['lineupVersion'] = 2;
      await storage.writeJson('settings.json', saved);
      return storage;
    }

    Future<AppState> launch(AppStorage storage, List<String> backups, {bool backupFails = false}) async {
      final app = AppState(storage, runAnalysis: false, safetyBackup: (reason) async {
        if (backupFails) throw const FileSystemException('disk full');
        backups.add(reason);
      });
      await app.start();
      return app;
    }

    test('old genre channels become the major genres, keeping numbers, favorites, groups and blocks', () async {
      final storage = await savedProfile();
      final backups = <String>[];
      final app = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup']);
      expect(app.settings.lineupVersion, AppSettings.currentLineupVersion);

      final mystery = app.channelById('auto:genre:Thriller & Mystery')!;
      expect((mystery.number, mystery.name, mystery.favorite, mystery.icon.value), (6, 'Mystery & Thrills', true, 'search'));
      expect(app.channelById('auto:genre:Mystery'), isNull);
      expect(app.channelById('auto:genre:Thriller'), isNull);
      expect(app.allChannels.where((c) => c.number == 9), isEmpty);
      expect(showsOf(app.library, mystery.playlist), {'M1', 'M2', 'M3'});
      expect(app.settings.groups.single.channelIds, [mystery.id]);
      expect(app.blocks.firstWhere((b) => b.id == 'user-block').channelId, mystery.id);
      expect(app.blocks.where((b) => b.generated != null && b.channelId == mystery.id), isNotEmpty);
      expect(app.currentChannelId('auto:genre:Thriller'), mystery.id);

      final action = app.channelById('auto:movies:Action')!;
      expect((action.number, action.name), (10, 'Action Movies'));
      expect(app.channelById('auto:movies:Action & Adventure'), isNull);

      // Existing numbers stay; new channels follow the highest, 14.
      expect({for (final id in ['auto:all-shows', 'auto:genre:Comedy', 'auto:movies', 'auto:genre:Drama']) app.channelById(id)!.number},
          {1, 3, 11, 14});
      final added = [for (final c in app.allChannels) if (c.number > 14) c]..sort((a, b) => a.number.compareTo(b.number));
      expect(added.map((c) => c.name), containsAll(['80s TV', '90s TV', '2000s TV', 'Drama Movies']));
      expect(added.map((c) => c.number), [for (var i = 15; i < 15 + added.length; i++) i]);
      expect(lineupProblems(app.library, app.allChannels, app.blocks), isEmpty);
      final saved = await File('${dir.path}/channels.json').readAsString();
      await app.close();

      final again = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup'], reason: 'it runs once');
      expect(await File('${dir.path}/channels.json').readAsString(), saved);
      await again.close();
    });

    test('a failed backup leaves the lineup as it was, and the update runs next launch', () async {
      final storage = await savedProfile();
      final before = await File('${dir.path}/channels.json').readAsString();
      final backups = <String>[];
      final failed = await launch(storage, backups, backupFails: true);
      expect(failed.settings.lineupVersion, 2);
      expect(failed.channelById('auto:genre:Mystery'), isNotNull);
      expect(failed.channelById('auto:genre:Thriller & Mystery'), isNull);
      await failed.close();
      expect(await File('${dir.path}/channels.json').readAsString(), before);

      final next = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup']);
      expect(next.channelById('auto:genre:Thriller & Mystery')!.number, 6);
      await next.close();
    });
  });

  test('200 songs from the 1940s give 40s Radio', () {
    final library = fakeLibrary(shows: const {}, songs: [
      ...fakeMusic(100, prefix: 'swing', year: 1944, genres: ['Jazz']),
      ...fakeMusic(100, prefix: 'crooner', year: 1946, genres: ['Pop']),
      ...fakeMusic(200, prefix: 'rock', year: 1985, genres: ['Rock']),
    ]);
    final names = generate(library).map((c) => c.name).toList();
    expect(names, contains('40s Radio'));
  });
}
