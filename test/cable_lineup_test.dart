import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'cable_fixture.dart';
import 'fixtures.dart';
import 'lineup_dedup_test.dart' show lineupProblems;
import 'lineup_fixture.dart';

/// The fixture items (show ids) [c]'s regular loop plays.
Set<String> showIds(Channel c) => {
      for (final id in c.playlist)
        if (id.contains('-x')) id.substring(0, id.indexOf('-x')),
    };

Channel byName(List<Channel> channels, String name) => channels.firstWhere((c) => c.name == name);

String keyOf(LibraryIndex library, String fixtureId) => library['$fixtureId-x0']!.seriesKey!;

BreakPlan automatic(Channel _) => BreakPlan.automatic;

/// Midnight on Tuesday, 3 November 2026.
final day = DateTime(2026, 11, 3);
DateTime at(int hour, [int minute = 0, int days = 0]) => DateTime(day.year, day.month, day.day + days, hour, minute);

MediaEntry episode(String show, int n, {int minutes = 22}) => MediaEntry(
    id: '$show-$n',
    kind: MediaKind.episode,
    title: '$show $n',
    runtime: Duration(minutes: minutes),
    seriesKey: show,
    seriesName: show,
    season: 1,
    episode: n);

MediaEntry movie(String id, {int minutes = 110}) =>
    MediaEntry(id: id, kind: MediaKind.movie, title: id, runtime: Duration(minutes: minutes));

LibraryIndex libraryOf(List<MediaEntry> episodes, [List<MediaEntry> movies = const []]) => LibraryIndex(
    series: [for (final k in {for (final e in episodes) e.seriesKey!}) SeriesEntry(key: k, id: k, name: k)],
    episodes: episodes,
    movies: movies,
    fetchedAt: DateTime(2026));

Channel channelOf(List<String> playlist, DateTime anchor) => Channel(
    id: 'ch',
    number: 2,
    name: 'Test',
    icon: const ChannelIcon.builtin('tv'),
    source: const ChannelSource(),
    order: PlaybackOrder.cyclic,
    playlist: playlist,
    anchor: anchor);

ProgramBlock blockOf(String id, int start, int end, List<String> playlist, {Daypart? generated}) => ProgramBlock(
    id: id,
    title: id,
    channelId: 'ch',
    days: {1, 2, 3, 4, 5, 6, 7},
    startMinute: start,
    endMinute: end,
    source: const ChannelSource(includeEpisodes: false, includeMovies: true),
    order: PlaybackOrder.random,
    playlist: playlist,
    anchor: day,
    generated: generated);

void main() {
  group('placement', () {
    test("a show listed twice keeps the best-matched item's genre order first", () {
      final index = LibraryIndex.fromJellyfinItems(seriesItems: [
        {'Id': 's1', 'Name': 'Show', 'Genres': ['Comedy', 'Drama', 'Horror']},
        {'Id': 's2', 'Name': 'Show', 'ProductionYear': 2015, 'Genres': ['Drama', 'Comedy'], 'ImageTags': {'Logo': 'x'}},
      ], episodeItems: [
        for (final (i, s) in ['s1', 's2'].indexed)
          {'Id': 'e$i', 'Name': 'E', 'SeriesId': s, 'SeriesName': 'Show', 'ParentIndexNumber': 1, 'IndexNumber': i + 1,
            'RunTimeTicks': 13200000000, 'LocationType': 'FileSystem'},
      ], movieItems: const []);
      expect(index.series.single.genres, ['Drama', 'Comedy', 'Horror']);
    });

    test('a show tagged Comedy and Drama airs on Laugh Track and Drama Central', () {
      final library = fakeLibrary(shows: {'C1': 40, 'C2': 40, 'X': 40, 'D1': 40, 'D2': 40}, genres: {
        'C1': ['Comedy'],
        'C2': ['Comedy'],
        'X': ['Comedy', 'Drama'],
        'D1': ['Drama'],
        'D2': ['Drama', 'Comedy'],
      });
      final channels = ChannelGenerator(library, anchor: day).generate();
      Set<String> shows(String name) => {for (final id in byName(channels, name).playlist) id.split('-e').first};
      expect(shows('Laugh Track'), {'C1', 'C2', 'X', 'D2'});
      expect(shows('Drama Central'), {'X', 'D1', 'D2'});
    });

    test('Sci-Fi and Fantasy are genres of their own', () {
      final library = fakeLibrary(shows: {'T': 40, 'F1': 40, 'F2': 40, 'O': 10}, genres: {
        'T': ['Horror', 'Fantasy'],
        'F1': ['Fantasy'],
        'F2': ['Science Fiction'],
        'O': ['News'],
      });
      final channels = ChannelGenerator(library, anchor: day).generate();
      expect({for (final id in byName(channels, 'Fantasy TV').playlist) id.split('-e').first}, {'T', 'F1'});
      expect(channels.where((c) => c.name == 'Sci-Fi TV' || c.name == 'Fright Night'), isEmpty,
          reason: 'one show each');
    });

    test("the test server's library gives design D3's lineup", () {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      final generator = ChannelGenerator(library, anchor: day, planOf: automatic);
      final channels = generator.generate();
      // Genres biggest first, then decades oldest first, then decade +
      // genre, then the show channel, then the movie side
      // (genre-decade-channels D5).
      expect(channels.map((c) => c.name), [
        'All Shows',
        'Laugh Track',
        'Drama Central',
        'Adventure TV',
        'Action TV',
        'Fantasy TV',
        'Crime & Justice',
        'Sci-Fi TV',
        'Mystery & Thrills',
        'Romance TV',
        'Toon TV',
        'Discovery Zone',
        '90s TV',
        '2000s TV',
        '2010s TV',
        '2020s TV',
        '90s Crime TV',
        'Seinfeld',
        'Movie Channel',
        'Comedy Movies',
        'Action Movies',
        'Drama Movies',
      ]);
      expect(channels.map((c) => c.number), [for (var i = 1; i <= channels.length; i++) i]);
      // Every show of its genre, a show on each of its genres' channels.
      expect(showIds(byName(channels, 'Laugh Track')),
          {'30rock', 'rick', 'calif', 'tyson', 'lotus', 'archer', 'shameless', 'eastbound'});
      expect(showIds(byName(channels, 'Drama Central')), {'lotus', 'sopranos', 'twinpeaks', 'calif', 'eastbound', 'shameless'});
      expect(showIds(byName(channels, 'Adventure TV')), {'highlander', 'archer', 'rick'});
      expect(showIds(byName(channels, 'Action TV')), {'archer', 'tyson', 'highlander'});
      expect(showIds(byName(channels, 'Mystery & Thrills')), {'ff2', 'twinpeaks', 'highlander'});
      expect(showIds(byName(channels, 'Discovery Zone')), {'ff', 'ff2'});
      expect(showIds(byName(channels, '90s TV')), {'highlander', 'sopranos', 'twinpeaks', 'ff'});
      expect(showIds(byName(channels, '90s Crime TV')), {'twinpeaks', 'sopranos', 'ff'});
      for (final (name, icon) in [
        ('Action TV', 'bolt'),
        ('Adventure TV', 'public'),
        ('Sci-Fi TV', 'rocket_launch'),
        ('Fantasy TV', 'castle'),
        ('Mystery & Thrills', 'search'),
        ('90s TV', 'tv'),
        ('90s Crime TV', 'local_police'),
        ('Comedy Movies', 'theater_comedy'),
      ]) {
        expect(byName(channels, name).icon.value, icon, reason: name);
      }
      for (final c in channels.where((c) => c.id.startsWith('auto:decade:') || c.id.startsWith('auto:genre:'))) {
        expect(c.order, PlaybackOrder.cyclic, reason: c.name);
      }
      for (final c in channels.where((c) => c.id.startsWith('auto:movies'))) {
        expect(c.order, PlaybackOrder.random, reason: c.name);
      }
      expect(showIds(byName(channels, 'Seinfeld')), {'seinfeld'});
      expect(showIds(byName(channels, 'All Shows')), isNot(contains('seinfeld')));
      expect(lineupProblems(library, channels, generator.blocks), isEmpty);
    });
  });

  group('show channels scale with the library', () {
    test('14 named shows, six with 60 or more episodes: one show channel, the biggest', () {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      expect(const GeneratorOptions().showChannelCap(library), 1);
      final shows = ChannelGenerator(library, anchor: day).generate().where((c) => c.id.startsWith('auto:show:'));
      expect(shows.map((c) => c.name), ['Seinfeld']);
    });

    test('6 named shows: no show channel', () {
      final library = fakeLibrary(
          shows: {'A': 100, 'B': 100, 'C': 20, 'D': 20, 'E': 20, 'F': 20},
          genres: {for (final s in 'ABCDEF'.split('')) s: s.compareTo('C') < 0 ? ['Comedy'] : ['Drama']});
      final channels = ChannelGenerator(library, anchor: day).generate();
      expect(channels.where((c) => c.id.startsWith('auto:show:')), isEmpty);
      expect(lineupProblems(library, channels), isEmpty);
    });
  });

  group('movie homes', () {
    test("every comedy movie airs in Laugh Track's evenings and on Comedy Movies", () {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      final generator = ChannelGenerator(library, anchor: day, planOf: automatic);
      final channels = generator.generate();
      final evening = generator.blocks.firstWhere((b) => b.generated == Daypart.evening && b.channelId == 'auto:genre:Comedy');
      expect(evening.playlist, hasLength(23));
      expect(evening.playlist.map((id) => library[id]!.title), containsAll(['Dumb and Dumber', 'The Princess Bride']));
      expect(byName(channels, 'Comedy Movies').playlist.toSet(), evening.playlist.toSet());
      // A movie tagged Action and Comedy is in both evenings.
      final action = generator.blocks.firstWhere((b) => b.generated == Daypart.evening && b.channelId == 'auto:genre:Action');
      expect(action.playlist.toSet().intersection(evening.playlist.toSet()), isNotEmpty);
      expect(byName(channels, 'Movie Channel').playlist, hasLength(38));
    });

    test('movies of a genre with no show channel get a movie genre channel', () {
      final library = FixtureLibrary(items: [
        FixtureItem('d1', 'Drama 1', year: 2001, genres: ['Drama'], episodes: seasons(1, 1, 20)),
        FixtureItem('d2', 'Drama 2', year: 2002, genres: ['Drama'], episodes: seasons(1, 1, 20)),
      ], movies: {'Horror': 15, 'Drama': 3}).index(ServerShape.jellyfin);
      final generator = ChannelGenerator(library, anchor: day);
      final channels = generator.generate();
      expect(byName(channels, 'Horror Movies').playlist, hasLength(15));
      expect(generator.blocks.where((b) => b.generated == Daypart.evening), isEmpty, reason: 'Drama has 3 movies');
    });

    test('too few movies: no evening, and they air on Movie Channel only', () {
      final library = FixtureLibrary(items: [
        FixtureItem('f1', 'Doc 1', year: 2001, genres: ['Documentary'], episodes: seasons(1, 1, 20)),
        FixtureItem('f2', 'Doc 2', year: 2002, genres: ['Documentary'], episodes: seasons(1, 1, 20)),
        FixtureItem('o1', 'Other', year: 2003, genres: ['News'], episodes: seasons(1, 1, 5)),
      ], movies: {'Documentary': 3, 'Western': 4}).index(ServerShape.jellyfin);
      final generator = ChannelGenerator(library, anchor: day);
      final channels = generator.generate();
      expect(byName(channels, 'Discovery Zone'), isNotNull);
      expect(generator.blocks.where((b) => b.generated == Daypart.evening), isEmpty);
      expect(byName(channels, 'Movie Channel').playlist, hasLength(7));
      expect(channels.where((c) => c.id.startsWith('auto:movies:')), isEmpty);
    });
  });

  group('lineup rules hold', () {
    for (final shape in ServerShape.values) {
      for (final (name, fixture) in [('standard', FixtureLibrary.standard()), ('test server', testServerLibrary())]) {
        test('$name library on ${shape.name}', () {
          final library = fixture.index(shape);
          final generator = ChannelGenerator(library, anchor: day, planOf: automatic);
          final channels = generator.generate();
          expect(lineupProblems(library, channels, generator.blocks), isEmpty);
          // A show with its own channel airs only there.
          for (final c in channels.where((c) => c.id.startsWith('auto:show:'))) {
            final key = c.source.seriesKeys.single;
            final elsewhere = [
              for (final o in channels)
                if (o != c && o.playlist.any((id) => library[id]?.seriesKey == key)) o.name,
            ];
            expect(elsewhere, isEmpty, reason: key);
          }
          expect(generator.blocks.map((b) => b.channelId), everyElement(startsWith('auto:genre:')));
        });
      }
    }
  });

  group('dayparts', () {
    test('the same show airs at the same time every day, with its next episodes', () {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      final generator = ChannelGenerator(library, anchor: day, planOf: automatic);
      final laugh = byName(generator.generate(), 'Laugh Track');
      final daytime = generator.blocks.firstWhere((b) => b.channelId == laugh.id && b.generated == Daypart.daytime);
      expect((daytime.startMinute, daytime.endMinute, daytime.days.length), (6 * 60, 18 * 60, 7));
      expect(daytime.lineup.map((s) => (s.seriesKey, s.count)),
          [
            for (final id in ['30rock', 'rick', 'calif', 'tyson', 'archer', 'shameless', 'lotus', 'eastbound'])
              (keyOf(library, id), 2)
          ]);
      final s = ChannelSchedule.build(laugh, library, generator.blocks, const BreakContext(plan: BreakPlan.automatic))!;
      final rock = library.episodesBySeries[keyOf(library, '30rock')]!;
      int number(ScheduledProgram p) => rock.indexOf(p.item!);
      for (final d in [1, 2]) {
        expect(s.programAt(at(6, 0, d)).item!.seriesKey, keyOf(library, '30rock'));
        expect(s.programAt(at(6, 30, d)).item!.seriesKey, keyOf(library, '30rock'));
        expect(s.programAt(at(7, 0, d)).item!.seriesKey, keyOf(library, 'rick'));
      }
      expect(number(s.programAt(at(6, 30, 1))), number(s.programAt(at(6, 0, 1))) + 1);
      expect(number(s.programAt(at(6, 0, 2))), greaterThan(number(s.programAt(at(6, 30, 1)))));
      // Evening movies from 6 PM, the shows again at midnight.
      expect(s.programAt(at(18, 0, 1)).item!.kind, MediaKind.movie);
      expect(s.programAt(at(0, 0, 2)).blockTitle, isNull);
    });

    test('30 shows: the 12 biggest make the Daytime lineup', () {
      final library = fakeLibrary(shows: {
        for (var i = 1; i <= 30; i++) 'S$i': 10 + i,
        'Other': 40,
      }, genres: {
        for (var i = 1; i <= 30; i++) 'S$i': ['Comedy'],
        'Other': ['Drama'],
      });
      final generator = ChannelGenerator(library, anchor: day, planOf: automatic);
      generator.generate();
      final daytime = generator.blocks.single;
      expect(daytime.lineup.map((s) => library.seriesByKey[s.seriesKey]!.name), [for (var i = 30; i > 18; i--) 'S$i']);
    });

    test('only genre channels get them', () {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      final channels = ChannelGenerator(library, anchor: day).generate();
      final custom = Channel(
          id: 'user:x',
          number: 50,
          name: 'Mine',
          icon: const ChannelIcon.builtin('tv'),
          source: const ChannelSource(genres: ['Comedy']),
          order: PlaybackOrder.cyclic,
          playlist: byName(channels, 'Laugh Track').playlist,
          anchor: day,
          auto: false);
      final blocks = ChannelGenerator.dayparts(
          library, [...channels.where((c) => !c.id.startsWith('auto:genre:')), custom],
          anchor: day, planOf: automatic);
      expect(blocks, isEmpty);
    });

    test("time no movie fits at the evening's end is filled with episodes", () {
      final eps = [for (var i = 1; i <= 6; i++) episode('Show', i)];
      final library = libraryOf(eps, [movie('m1', minutes: 145), movie('m2', minutes: 145)]);
      final evening = blockOf('eve', 18 * 60, 0, ['m1', 'm2'], generated: Daypart.evening);
      final s = ChannelSchedule.build(channelOf([for (final e in eps) e.id], day), library, [evening],
          const BreakContext(plan: BreakPlan.automatic))!;
      final programs = s.blocks.single.programsIn((start: at(18), end: at(0, 0, 1)));
      expect([for (final p in programs) (p.start, p.item!.kind)], [
        (at(18), MediaKind.movie),
        (at(20, 30), MediaKind.movie),
        (at(23), MediaKind.episode),
        (at(23, 30), MediaKind.episode),
      ]);
      expect(programs.last.end, at(0, 0, 1));
      expect(programs.every((p) => p.duration == s.slotPlanFor(p.item!).slotLength), isTrue, reason: 'nothing cut');
    });
  });

  group('clock-aligned slots', () {
    test('three shorts, then a sitcom: the last short pads to the half hour', () {
      final shorts = [for (var i = 1; i <= 3; i++) episode('Short', i, minutes: 11)];
      final sitcom = episode('Sitcom', 1);
      final library = libraryOf([...shorts, sitcom]);
      final s = ChannelSchedule.build(
          channelOf([for (final e in [...shorts, sitcom]) e.id], at(21)), library, const [],
          const BreakContext(plan: BreakPlan.automatic))!;
      expect([for (final p in s.programsBetween(at(21), at(22, 30))) (p.start, p.end)], [
        (at(21), at(21, 15)),
        (at(21, 15), at(21, 30)),
        (at(21, 30), at(22)),
        (at(22), at(22, 30)),
      ]);
      expect(s.playbackAt(at(21, 50)).role, BreakRole.tail, reason: 'the pad is a slot tail');
    });

    test('a loop of whole half hours: its last short pads when the loop wraps', () {
      final library = libraryOf([episode('Sitcom', 1), episode('Short', 1, minutes: 11)]);
      final channel = channelOf(['Sitcom-1', 'Short-1'], at(0));
      final loop = LoopSchedule.build(channel, library,
          slotOf: (e) => resolve(BreakPlan.automatic, e.runtime).slotLength, align: true)!;
      expect(loop.loopLength, const Duration(minutes: 60));
      final s = ChannelSchedule.build(channel, library, const [], const BreakContext(plan: BreakPlan.automatic))!;
      for (final p in s.programsBetween(at(0), at(12))) {
        if (p.item!.runtime >= BreakPlan.automaticShortUnder) expect(p.start.minute % 30, 0);
      }
    });

    test('a day of sitcoms and dramas starts on the hour and half hour', () {
      final eps = [episode('A', 1), episode('B', 1, minutes: 31), episode('C', 1, minutes: 44)];
      final s = ChannelSchedule.build(channelOf([for (final e in eps) e.id], at(20)), libraryOf(eps), const [],
          const BreakContext(plan: BreakPlan.automatic))!;
      expect([for (final p in s.programsBetween(at(20), at(22, 31))) p.start], [at(20), at(20, 30), at(21, 30), at(22, 30)]);
    });

    // Four 22-minute episodes, then a 110-minute movie: a 4-hour loop.
    final eps = [for (var i = 1; i <= 4; i++) episode('Show', i)];
    final library = libraryOf(eps, [movie('film')]);
    final playlist = [for (final e in eps) e.id, 'film'];
    ChannelSchedule scheduleWith(DateTime anchor, List<ProgramBlock> blocks, [BreakContext breaks = const BreakContext(plan: BreakPlan.automatic)]) =>
        ChannelSchedule.build(channelOf(playlist, anchor), library, blocks, breaks)!;

    test("a movie that would cross into a block's start gives way to earlier programs", () {
      // The movie would run 5:00–7:00 PM; the block starts at 6:00.
      final s = scheduleWith(at(15), [blockOf('eve', 18 * 60, 0, ['film'])]);
      final before = s.programsBetween(at(17), at(18));
      expect([for (final p in before) (p.start, p.end, p.item!.id)],
          [(at(17), at(17, 30), 'Show-4'), (at(17, 30), at(18), 'Show-3')]);
    });

    test("after a block, the loop's next program starts on time and nothing joins partway", () {
      // The block ends at 6:00 PM, 30 minutes into the movie's slot (5:30–7:30).
      final s = scheduleWith(at(15, 30), [blockOf('day', 6 * 60, 18 * 60, ['film'])]);
      final after = s.programsBetween(at(18), at(19, 30));
      expect(after.map((p) => p.item!.kind), everyElement(MediaKind.episode));
      expect(after.first.start, at(18));
      expect(after.last.end, at(19, 30));
      expect(after.every((p) => p.start.minute % 30 == 0 && p.layoutStart == p.start), isTrue);
      expect((s.programAt(at(19, 30)).start, s.programAt(at(19, 30)).item!.id), (at(19, 30), 'Show-1'));
      // The same every time it's built.
      final again = scheduleWith(at(15, 30), [blockOf('day', 6 * 60, 18 * 60, ['film'])]);
      String guide(ChannelSchedule s) =>
          [for (final p in s.programsBetween(at(0), at(0, 0, 2))) '${p.start} ${p.end} ${p.item?.id}'].join('\n');
      expect(guide(again), guide(s));
    });

    test('breaks off, or a slot length: the loop is cut at block edges as before', () {
      for (final breaks in [
        BreakContext.none,
        const BreakContext(plan: BreakPlan.automatic, slotRule: SlotRule(length: Duration(minutes: 30))),
      ]) {
        final s = scheduleWith(at(15, 30), [blockOf('day', 6 * 60, 18 * 60, ['film'])], breaks);
        final joined = s.programAt(at(18));
        expect(joined.item!.id, 'film');
        expect(joined.start, at(18));
        expect(joined.layoutStart.isBefore(at(18)), isTrue);
      }
    });
  });

  group('the lineup in the app', () {
    late Directory dir;
    late AppState app;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_cable'));
    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    Future<void> refresh(FixtureLibrary library) async {
      app.client = library.jellyfinServer();
      await app.refreshLibrary(background: true);
    }

    FixtureLibrary without(FixtureLibrary l, Set<String> ids) =>
        l.copyWith(items: [for (final s in l.items) if (!ids.contains(s.id)) s]);

    ProgramBlock? daypart(String channelId, Daypart part) =>
        app.blocks.where((b) => b.id == ChannelGenerator.daypartId(channelId, part)).firstOrNull;

    test('a refresh never retires a healthy show channel over the cap', () async {
      final library = testServerLibrary().copyWith(items: [
        ...testServerLibrary().items,
        for (var i = 1; i <= 2; i++) FixtureItem('q$i', 'Small $i', year: 1980 + i, genres: ['History'], episodes: seasons(1, 1, 4)),
      ]);
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      final shows = {for (final c in app.allChannels) if (c.id.startsWith('auto:show:')) c.id};
      expect(shows, hasLength(2));
      await refresh(without(library, {'q1', 'q2'}));
      expect({for (final c in app.allChannels) if (c.id.startsWith('auto:show:')) c.id}, shows);
      expect(lineupProblems(app.library, app.allChannels, app.blocks), isEmpty);
    });

    test('a show whose channel retires returns to All Shows and its genre channel', () async {
      final library = testServerLibrary();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      expect(showIds(app.channelById('auto:all-shows')!), isNot(contains('seinfeld')));
      await refresh(library.copyWith(items: [
        for (final s in library.items) s.id == 'seinfeld' ? s.withEpisodes(seasons(1, 1, 40)) : s,
      ]));
      expect(app.allChannels.where((c) => c.id.startsWith('auto:show:') && showIds(c).contains('seinfeld')), isEmpty);
      expect(showIds(app.channelById('auto:all-shows')!), contains('seinfeld'));
      expect(showIds(app.channelById('auto:genre:Comedy')!), contains('seinfeld'));
    });

    test('refreshes rebuild generated blocks, starting over only when their content changes', () async {
      final library = testServerLibrary();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      await refresh(library);
      final daytime = daypart('auto:genre:Comedy', Daypart.daytime)!;
      expect(daypart('auto:genre:Comedy', Daypart.evening), isNotNull);
      expect(daypart('auto:genre:Documentary', Daypart.evening), isNull, reason: 'Discovery Zone has no movies');
      final old = DateTime(2026, 1, 1);
      daytime.anchor = old;
      await refresh(library);
      expect(daypart('auto:genre:Comedy', Daypart.daytime)!.anchor, old, reason: 'nothing changed');

      await refresh(library.copyWith(items: [
        ...library.items,
        FixtureItem('new', 'New Sitcom', year: 2024, genres: ['Comedy'], episodes: seasons(1, 1, 10)),
      ]));
      final after = daypart('auto:genre:Comedy', Daypart.daytime)!;
      expect(after.lineup.map((s) => s.seriesKey), contains('new sitcom|2024'));
      expect(after.anchor, isNot(old), reason: 'the lineup starts over');
      expect(after.generated, Daypart.daytime);
    });

    test("the user's edit makes a generated block theirs; a deleted one stays deleted", () async {
      final library = testServerLibrary();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      await refresh(library);
      final evening = daypart('auto:genre:Comedy', Daypart.evening)!.copy();
      await app.saveBlock(evening.copy());
      expect(daypart('auto:genre:Comedy', Daypart.evening)!.generated, Daypart.evening, reason: 'saved unchanged');
      await app.saveBlock(evening..startMinute = 20 * 60);
      expect(daypart('auto:genre:Comedy', Daypart.evening)!.generated, isNull);
      final daytime = daypart('auto:genre:Drama', Daypart.daytime)!.copy()..enabled = false;
      await app.saveBlock(daytime);
      expect(daypart('auto:genre:Drama', Daypart.daytime)!.generated, isNull, reason: 'disabling is an edit');
      await app.deleteBlock(daypart('auto:genre:Sci-Fi', Daypart.daytime)!);

      await refresh(library);
      final mine = daypart('auto:genre:Comedy', Daypart.evening)!;
      expect((mine.startMinute, mine.generated), (20 * 60, null));
      expect(app.blocks.where((b) => b.channelId == 'auto:genre:Comedy' && b.startMinute == 18 * 60), isEmpty);
      expect(daypart('auto:genre:Drama', Daypart.daytime)!.enabled, isFalse);
      expect(daypart('auto:genre:Sci-Fi', Daypart.daytime), isNull);
    });

    test("a retired genre channel's generated blocks go with it", () async {
      final library = testServerLibrary();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      await refresh(library);
      expect(daypart('auto:genre:Documentary', Daypart.daytime), isNotNull);
      await refresh(without(library, {'ff2'}));
      expect(app.channelById('auto:genre:Documentary'), isNull, reason: 'one show left');
      expect(app.blocks.where((b) => b.channelId == 'auto:genre:Documentary'), isEmpty);
    });
  });

  group('the one-time rebuild', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_rebuild'));
    tearDown(() async => dir.delete(recursive: true));

    const marathons = ['30rock', 'highlander', 'sopranos', 'rick', 'calif'];

    /// A lineup from before cable rules: six show channels, 30 Rock a
    /// favorite, Highlander in a group with breaks off. Lineup version 1.
    Future<AppStorage> savedProfile() async {
      final library = testServerLibrary().index(ServerShape.jellyfin);
      final settings = AppSettings.fresh()..groups = [ChannelGroup(id: 'group:mine', name: 'Mine')];
      final app = await signedInApp(dir, library, settings: settings.toJson(), editChannels: (channels) {
        final seinfeld = channels.firstWhere((c) => (c['id'] as String).startsWith('auto:show:'));
        var number = channels.fold(0, (n, c) => c['number'] as int > n ? c['number'] as int : n);
        for (final id in marathons) {
          final key = keyOf(library, id);
          channels.add({
            ...seinfeld,
            'id': 'auto:show:$key',
            'number': ++number,
            'name': library.seriesByKey[key]!.name,
            'source': ChannelSource(seriesKeys: [key]).toJson(),
            'playlist': [for (final e in library.episodesBySeries[key]!) e.id],
            if (id == '30rock') 'favorite': true,
            if (id == 'highlander') 'commercialPlan': BreakPlan.off.toJson(),
          });
        }
      });
      await app.setInGroup(app.settings.groups.single, app.channelById('auto:show:${keyOf(library, 'highlander')}')!, true);
      expect(app.allChannels.where((c) => c.id.startsWith('auto:show:')), hasLength(6));
      await app.close();
      final storage = await AppStorage.at(dir);
      final saved = (await storage.readJson('settings.json') as Map<String, Object?>)..['lineupVersion'] = 1;
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

    test('six show channels: the biggest and the favorite stay; the rest go to genre channels', () async {
      final storage = await savedProfile();
      final backups = <String>[];
      final app = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup']);
      expect(app.settings.lineupVersion, AppSettings.currentLineupVersion);
      final library = app.library;
      expect({for (final c in app.allChannels) if (c.id.startsWith('auto:show:')) c.name}, {'Seinfeld', '30 Rock'});
      expect(showIds(app.channelById('auto:genre:Sci-Fi')!), containsAll(['highlander', 'rick']));
      // Highlander's channel went to a genre channel airing it, its
      // settings with it.
      final taker = app.channelById(app.settings.groups.single.channelIds.single)!;
      expect(taker.id, startsWith('auto:genre:'));
      expect(showIds(taker), contains('highlander'));
      expect(showIds(app.channelById('auto:genre:Drama')!), containsAll(['calif', 'sopranos']));
      expect(showIds(app.channelById('auto:genre:Comedy')!), isNot(contains('30rock')));
      expect(taker.commercialPlan, BreakPlan.off);
      expect(app.blocks.where((b) => b.generated != null).map((b) => b.channelId), everyElement(startsWith('auto:genre:')));
      expect(daypartOf(app, 'auto:genre:Comedy', Daypart.evening), isNotNull);
      final numbers = [for (final c in app.allChannels) if (c.auto && !c.isLive) c.number];
      expect(numbers, [for (var i = 1; i <= numbers.length; i++) i]);
      expect(lineupProblems(library, app.allChannels, app.blocks), isEmpty);
      final saved = await File('${dir.path}/channels.json').readAsString();
      await app.close();

      final again = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup'], reason: 'it runs once');
      expect(await File('${dir.path}/channels.json').readAsString(), saved);
      await again.close();
    });

    test('a failed backup leaves the lineup as it was and the rebuild runs next launch', () async {
      final storage = await savedProfile();
      final before = await File('${dir.path}/channels.json').readAsString();
      final failed = await launch(storage, [], backupFails: true);
      expect(failed.settings.lineupVersion, 1);
      await failed.close();
      expect(await File('${dir.path}/channels.json').readAsString(), before);
      final next = await launch(storage, []);
      expect(next.settings.lineupVersion, AppSettings.currentLineupVersion);
      expect(next.allChannels.where((c) => c.id.startsWith('auto:show:')), hasLength(2));
      await next.close();
    });
  });

  group('generated blocks are saved', () {
    test('the field round-trips, and blocks saved before it load as the user\'s', () {
      final b = blockOf('x', 0, 60, const [], generated: Daypart.daytime);
      expect(ProgramBlock.fromJson(b.toJson()).generated, Daypart.daytime);
      final plain = blockOf('y', 0, 60, const []).toJson();
      expect(plain.containsKey('generated'), isFalse);
      expect(ProgramBlock.fromJson(plain).generated, isNull);
    });
  });
}

ProgramBlock? daypartOf(AppState app, String channelId, Daypart part) =>
    app.blocks.where((b) => b.id == ChannelGenerator.daypartId(channelId, part)).firstOrNull;
