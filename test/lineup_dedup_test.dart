import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/show_key_remap.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/live/live_data.dart';
import 'package:nightingale_tv/live/live_source.dart';

import 'fixtures.dart';
import 'lineup_fixture.dart';

/// What breaks the lineup rules (lineup-dedup D8): a show or movie on two
/// generated channels other than All Shows and Movie Channel, an empty
/// generated channel, a genre channel under its minimum, two generated
/// channels with one name.
List<String> lineupProblems(LibraryIndex library, List<Channel> channels) {
  const options = GeneratorOptions();
  final problems = <String>[];
  final showOn = <String, String>{}, movieOn = <String, String>{}, names = <String, String>{};
  for (final c in channels.where((c) => c.auto && !c.isLive)) {
    if (names[c.name.toLowerCase()] case final other?) problems.add('"${c.name}" is ${c.id} and $other');
    names[c.name.toLowerCase()] = c.id;
    if (c.playlist.isEmpty) problems.add('${c.name} (${c.id}) is empty');
    if (c.id == 'auto:all-shows' || c.id == 'auto:movies') continue;
    final items = [for (final id in c.playlist) ?library[id]];
    final shows = {for (final e in items) ?e.seriesKey};
    final movies = {for (final e in items) if (e.kind == MediaKind.movie) e.id};
    for (final s in shows) {
      if (showOn[s] case final other?) problems.add('$s is on $other and ${c.name}');
      showOn[s] = c.name;
    }
    for (final m in movies) {
      if (movieOn[m] case final other?) problems.add('$m is on $other and ${c.name}');
      movieOn[m] = c.name;
    }
    if (c.id.startsWith('auto:genre:') &&
        (shows.length < options.minSeriesPerGenre || items.length < options.minEpisodesPerGenre)) {
      problems.add('${c.name} has ${shows.length} shows, ${items.length} episodes');
    }
    if (c.id.startsWith('auto:movies:') && movies.length < options.minMoviesPerMovieGenre) {
      problems.add('${c.name} has ${movies.length} movies');
    }
  }
  return problems;
}

/// What a refresh may not change without a reason: ids, numbers, names,
/// sources and playlists.
String snapshot(List<Channel> channels) => [
      for (final c in channels)
        '${c.id} ${c.number} ${c.name} ${c.hidden} ${jsonEncode(c.source.toJson())} ${c.playlist.join(',')}',
    ].join('\n');

FixtureLibrary withItem(FixtureLibrary l, String id, FixtureItem? Function(FixtureItem s) change) =>
    l.copyWith(items: [for (final s in l.items) ?(s.id == id ? change(s) : s)]);

void main() {
  group('a fresh lineup', () {
    for (final shape in ServerShape.values) {
      test('keeps the rules on ${shape.name}', () {
        final library = FixtureLibrary.standard().index(shape);
        final channels = ChannelGenerator(library, anchor: DateTime(2026)).generate();
        expect(lineupProblems(library, channels), isEmpty);
        expect(channels.map((c) => c.number), [for (var i = 1; i <= channels.length; i++) i]);
        expect(channels.where((c) => c.source.seriesKeys.contains(SeriesEntry.unknownKey)), isEmpty);
        // Unnamed episodes still air on All Shows.
        final all = channels.firstWhere((c) => c.id == 'auto:all-shows').playlist.toSet();
        expect(library.episodesBySeries[SeriesEntry.unknownKey]!.every((e) => all.contains(e.id)), isTrue);
      });
    }

    test('a show named like another channel adds its kind', () {
      final library = FixtureLibrary(items: [
        FixtureItem('x', 'Comedy Movies', year: 2000, genres: ['Drama'], episodes: seasons(1, 3, 25)),
        FixtureItem('y', 'Other', year: 2001, genres: ['Drama'], episodes: seasons(1, 1, 10)),
      ], movies: {'Comedy': 14, 'Action': 13}).index(ServerShape.jellyfin);
      final names = ChannelGenerator(library, anchor: DateTime(2026)).generate().map((c) => c.name).toList();
      expect(names, containsAll(['Comedy Movies (Show)', 'Comedy Movies']));
    });
  });

  test('spreadTitles retires a genre channel left thin and shares its titles', () {
    final standard = FixtureLibrary.standard();
    final before = standard.index(ServerShape.jellyfin);
    final channels = ChannelGenerator(before, anchor: DateTime(2026)).generate();
    final genre = [for (final c in channels) if (c.id.startsWith('auto:genre:')) c];
    expect(genre, hasLength(greaterThanOrEqualTo(2)));
    // The first genre channel's shows but one leave the library.
    final first = buildPlaylist(before, genre.first.source, genre.first.order, seed: 1);
    final shows = {for (final id in first) before[id]!.seriesId};
    final left = shows.skip(1).toSet();
    final after = standard.copyWith(items: [for (final s in standard.items) if (!left.contains(s.id)) s]).index(ServerShape.jellyfin);
    final thin = ChannelGenerator.spreadTitles(after, channels);
    expect(thin, contains(genre.first.id));
    for (final c in channels) {
      c.playlist = buildPlaylist(after, c.source, c.order, seed: 1);
    }
    expect(genre.first.playlist, isEmpty, reason: 'a thin channel never falls back to its whole genre');
    expect(lineupProblems(after, [for (final c in channels) if (!thin.contains(c.id)) c]), isEmpty);
  });

  group('saved show keys follow merged shows', () {
    final standard = FixtureLibrary.standard();
    final old = standard.legacyIndex();
    final fresh = standard.index(ServerShape.jellyfin);

    test('by their episodes, else by name', () {
      final remap = ShowKeyRemap(fresh, previous: old);
      expect(remap.resolve('show b season 1 [1080p ai 10bit|'), 'show b|2009');
      expect(remap.resolve('show b season 3|2009'), 'show b|2009');
      expect(remap.resolve('show a|'), 'show a|2001');
      expect(remap.resolve('show d|1978'), 'show d|1978');
      final byName = ShowKeyRemap(fresh);
      expect(byName.resolve('show a|'), 'show a|2001');
      expect(byName.resolve('show c (complete cartoon series in mp4 format)|2014'), 'show c|2014');
      expect(byName.resolve('show d|'), isNull, reason: 'two years: ambiguous');
      expect(byName.resolve('gone|1990'), isNull);
      expect(byName.map('movie-Comedy-1'), 'movie-Comedy-1');
    });

    test('in channel and block sources, block lineups and show channel ids', () {
      Channel channel(String id, ChannelSource source) => Channel(
          id: id,
          number: 1,
          name: id,
          icon: const ChannelIcon.builtin('tv'),
          source: source,
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: DateTime(2026));
      final custom = channel(
          'custom',
          const ChannelSource(
              seriesKeys: ['show a|', 'show a|2001', 'show c (complete cartoon series in mp4 format)|2014', 'gone|1990'],
              excluded: ['show b season 3|2009', 'show b season 04|', 'movie-Comedy-1']));
      final show = channel('auto:show:show a|', const ChannelSource(seriesKeys: ['show a|']));
      final block = ProgramBlock(
          id: 'b',
          title: 'b',
          channelId: 'custom',
          days: {1},
          startMinute: 0,
          endMinute: 60,
          source: const ChannelSource(seriesKeys: ['show b season 4|']),
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: DateTime(2026),
          lineup: [LineupSlot(seriesKey: 'show a|', count: 2), LineupSlot(seriesKey: 'show a|2001')]);
      final renames = ShowKeyRemap(fresh, previous: old).apply([custom, show], [block]);
      expect(custom.source.seriesKeys, ['show a|2001', 'show c|2014', 'gone|1990']);
      expect(custom.source.excluded, ['show b|2009', 'movie-Comedy-1']);
      expect(show.source.seriesKeys, ['show a|2001']);
      expect(renames, {'auto:show:show a|': 'auto:show:show a|2001'});
      expect(block.source.seriesKeys, ['show b|2009']);
      expect([for (final s in block.lineup) '${s.seriesKey}×${s.count}'], ['show a|2001×2', 'show a|2001×1']);
    });
  });

  group('refreshes', () {
    late Directory dir;
    late AppState app;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_lineup'));
    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    Future<void> addLive() async {
      final source = LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'IPTV', playlistUrl: 'http://127.0.0.1:9/x.m3u');
      await app.live.addSource(source, [LiveChannelInfo(key: 'k0', name: 'Live 0', number: '2.1', url: 'http://p/0.ts')]);
      await app.chooseLiveChannels(source, {'k0'});
    }

    Future<void> refresh(FixtureLibrary library) async {
      app.client = library.jellyfinServer();
      await app.refreshLibrary(background: true);
    }

    test('five refreshes keep the rules; user-built and live channels stay; a repeat changes nothing', () async {
      var library = FixtureLibrary.standard();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin), editChannels: (channels) {
        channels.add({
          ...channels.firstWhere((c) => (c['id'] as String).startsWith('auto:show:')),
          'id': 'custom:mine',
          'number': 30,
          'name': 'Mine',
          'auto': false,
        });
      });
      await addLive();
      Channel custom() => app.channelById('custom:mine')!;
      Channel live() => app.allChannels.firstWhere((c) => c.isLive);
      expect(live().number, 100);
      final steps = <String, FixtureLibrary Function(FixtureLibrary)>{
        'a show added': (l) => l.copyWith(items: [
              ...l.items,
              FixtureItem('i1', 'Show I', year: 2018, genres: ['Comedy'], episodes: seasons(1, 5, 14)),
            ]),
        'a show removed': (l) => withItem(l, 'f1', (_) => null),
        'matched copies listed bare': (l) => withItem(withItem(l, 'a1', (s) => s.bare()), 'b3', (s) => s.bare()),
        'season folders appear': (l) => l.copyWith(items: [
              ...l.items,
              FixtureItem('i2', 'Show I Season 6 [720p', episodes: seasons(1, 1, 10)),
              FixtureItem('e3', 'Show E S04', episodes: seasons(4, 4, 8)),
            ]),
        'bare copies matched again': (l) => withItem(
            withItem(l, 'a1', (s) => s.matched(year: 2001, genres: ['Comedy'], providerIds: {'Tvdb': '100'})),
            'b3',
            (s) => s.matched(year: 2009, genres: ['Animation', 'Comedy'])),
      };
      for (final MapEntry(key: what, value: change) in steps.entries) {
        library = change(library);
        await refresh(library);
        expect(lineupProblems(app.library, app.allChannels), isEmpty, reason: what);
        expect((custom().number, custom().name, custom().auto, custom().playlist.isNotEmpty), (30, 'Mine', false, true),
            reason: what);
        expect(live().number, 100, reason: what);
        final after = snapshot(app.allChannels);
        await refresh(library);
        expect(snapshot(app.allChannels), after, reason: '$what: a repeat refresh changes nothing');
      }
    });

    test('a show that falls below the threshold loses its channel and airs on a genre channel', () async {
      final library = FixtureLibrary.standard();
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      const id = 'auto:show:show d|2004';
      expect(app.channelById(id), isNotNull);
      await refresh(withItem(library, 'd2', (s) => s.withEpisodes(seasons(1, 2, 20))));
      expect(app.channelById(id), isNull);
      final genre = [for (final c in app.allChannels) if (c.id.startsWith('auto:genre:')) ...c.playlist];
      expect(genre.any((e) => app.library[e]?.seriesKey == 'show d|2004'), isTrue);
      expect(lineupProblems(app.library, app.allChannels), isEmpty);
    });

    test('a healthy show channel outranked by a growing show stays', () async {
      final library = FixtureLibrary(items: [
        for (var i = 1; i <= 6; i++)
          FixtureItem('s$i', 'Big $i', year: 2000 + i, genres: ['Drama'], episodes: seasons(1, 3, 20 + i)),
        FixtureItem('s7', 'Big 7', year: 2010, genres: ['Drama'], episodes: seasons(1, 2, 20)),
      ]);
      app = await signedInApp(dir, library.index(ServerShape.jellyfin));
      final ids = {for (final c in app.allChannels) c.id};
      expect(ids.where((id) => id.startsWith('auto:show:')), hasLength(6));
      await refresh(withItem(library, 's7', (s) => s.withEpisodes(seasons(1, 5, 20))));
      expect({for (final c in app.allChannels) c.id}, ids, reason: '${[for (final c in app.allChannels) c.id]}');
    });

    test("a show's second channel merges into its first, keeping the user's settings", () async {
      // Saved before show identity: Show A's matched and bare copies each
      // have a channel.
      final library = FixtureLibrary(items: [
        FixtureItem('a1', 'Show A', year: 2001, genres: ['Comedy'], logo: true, episodes: seasons(1, 4, 20)),
        FixtureItem('a2', 'Show A', episodes: seasons(4, 9, 20)),
        FixtureItem('f1', 'Show F', year: 2010, genres: ['Drama'], episodes: seasons(1, 3, 12)),
      ]);
      app = await signedInApp(dir, library.legacyIndex());
      final first = app.channelById('auto:show:show a|2001')!;
      final second = app.channelById('auto:show:show a|')!;
      final lower = first.number < second.number ? first.number : second.number;
      second
        ..favorite = true
        ..hidden = true
        ..name = 'My A'
        ..icon = const ChannelIcon(kind: ChannelIconKind.custom, value: 'a.png')
        ..logoMode = LogoMode.always
        ..retro = const ChannelRetro(crt: CrtStyle.off)
        ..commercialPlan = BreakPlan.off;
      final group = await app.createGroup('Mine');
      await app.setInGroup(group, second, true);
      await app.setLastChannel(second);
      await refresh(library);

      expect(app.allChannels.where((c) => c.source.seriesKeys.contains('show a|2001') && c.auto), hasLength(1));
      expect(app.channelById('auto:show:show a|'), isNull);
      final a = app.channelById('auto:show:show a|2001')!;
      expect(a.favorite, isTrue);
      expect(a.hidden, isFalse, reason: 'hidden only if both were');
      expect((a.name, a.icon.value, a.logoMode, a.retro.crt, a.commercialPlan), ('My A', 'a.png', LogoMode.always, CrtStyle.off, BreakPlan.off));
      expect(a.number, lower);
      expect(app.settings.groups.single.channelIds, ['auto:show:show a|2001']);
      expect(app.settings.lastChannelId, a.id);
      expect(app.currentChannelId('auto:show:show a|'), a.id);
      expect(a.playlist.toSet(), {for (final e in app.library.episodesBySeries['show a|2001']!) e.id});
      expect(app.scheduleFor(a)!.programAt(DateTime.now()).item, isNotNull);
      expect(lineupProblems(app.library, app.allChannels), isEmpty);
    });
  });

  group('the one-time cleanup', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_cleanup'));
    tearDown(() async => dir.delete(recursive: true));

    final library = FixtureLibrary.standard().copyWith(items: [
      ...FixtureLibrary.standard().items.map((s) => switch (s.id) {
            'a1' => s.withEpisodes(seasons(1, 4, 20)),
            // Big enough for a channel named with its release tags.
            'c1' => s.withEpisodes(seasons(1, 7, 10)),
            _ => s,
          }),
      FixtureItem('k1', 'Show K', year: 2011, genres: ['Western'], episodes: seasons(1, 2, 20)),
    ]);

    /// A profile saved like the test server's: generated 2 and up, two
    /// channels for one show, a one-show genre channel, an empty "Unknown
    /// show", a custom channel at 30 and a live one at 100. Lineup version 0.
    Future<AppStorage> savedProfile() async {
      final legacy = library.legacyIndex();
      final app = await signedInApp(dir, legacy, editChannels: (channels) {
        for (final c in channels) {
          c['number'] = (c['number'] as int) + 1;
        }
        Map<String, Object?> copy(String id, Map<String, Object?> changes) =>
            {...channels.firstWhere((c) => (c['id'] as String).startsWith('auto:show:')), 'id': id, ...changes};
        final top = channels.fold(0, (n, c) => c['number'] as int > n ? c['number'] as int : n);
        channels.addAll([
          copy('auto:genre:Western', {
            'number': top + 1,
            'name': 'Frontier TV',
            'source': const ChannelSource(genres: ['Western']).toJson(),
            'playlist': [for (final e in legacy.episodesBySeries['show k|2011']!) e.id],
          }),
          copy('auto:show:unknown show|', {
            'number': top + 2,
            'name': 'Unknown show',
            'source': const ChannelSource(seriesKeys: ['unknown show|']).toJson(),
            'playlist': <String>[],
          }),
          copy('custom:mine', {'number': 30, 'name': 'Mine', 'auto': false}),
        ]);
        channels.firstWhere((c) => c['id'] == 'auto:show:show a|')['favorite'] = true;
      });
      final source = LiveSource(id: 'iptv', kind: LiveSourceKind.m3u, name: 'IPTV', playlistUrl: 'http://127.0.0.1:9/x.m3u');
      await app.live.addSource(source, [LiveChannelInfo(key: 'k0', name: 'Live 0', number: '2.1', url: 'http://p/0.ts')]);
      await app.chooseLiveChannels(source, {'k0'});
      expect(app.allChannels.firstWhere((c) => c.isLive).number, 100);
      expect(app.allChannels.where((c) => c.id.startsWith('auto:show:show a|')), hasLength(2));
      await app.close();
      final storage = await AppStorage.at(dir);
      final settings = (await storage.readJson('settings.json') as Map<String, Object?>)..remove('lineupVersion');
      await storage.writeJson('settings.json', settings);
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

    test('numbers generated channels from 1 with no gaps and removes duplicates, once', () async {
      final storage = await savedProfile();
      final backups = <String>[];
      final app = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup']);
      expect(app.settings.lineupVersion, AppSettings.currentLineupVersion);
      expect(lineupProblems(app.library, app.allChannels), isEmpty);
      final generated = [for (final c in app.allChannels) if (c.auto && !c.isLive) c.number];
      final expected = <int>[];
      for (var n = 1; expected.length < generated.length; n++) {
        if (n != 30 && n != 100) expected.add(n);
      }
      expect(generated, expected);
      expect(app.channelById('custom:mine')!.number, 30);
      expect(app.allChannels.firstWhere((c) => c.isLive).number, 100);
      expect(app.channelById('auto:genre:Western'), isNull);
      expect(app.channelById('auto:show:unknown show|'), isNull);
      final showA = [for (final c in app.allChannels) if (c.auto && c.source.seriesKeys.contains('show a|2001')) c];
      expect(showA, hasLength(1));
      expect(showA.single.favorite, isTrue, reason: "the duplicate's favorite carries over");
      expect(app.channelById('auto:show:show c|2014')!.name, 'Show C', reason: 'the generated name loses its tags');
      final saved = await File('${dir.path}/channels.json').readAsString();
      await app.close();

      final again = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup'], reason: 'a second launch does nothing');
      expect(await File('${dir.path}/channels.json').readAsString(), saved);
      await again.close();
    });

    test('a failed backup leaves everything as it was and tries again next launch', () async {
      final storage = await savedProfile();
      final channelsBefore = await File('${dir.path}/channels.json').readAsString();
      final libraryBefore = await File('${dir.path}/library.json').readAsString();
      final failed = await launch(storage, [], backupFails: true);
      expect(failed.settings.lineupVersion, 0);
      await failed.close();
      expect(await File('${dir.path}/channels.json').readAsString(), channelsBefore);
      expect(await File('${dir.path}/library.json').readAsString(), libraryBefore);
      expect((jsonDecode(await File('${dir.path}/settings.json').readAsString()) as Map)['lineupVersion'], isNull);

      final backups = <String>[];
      final next = await launch(storage, backups);
      expect(backups, ['before-lineup-cleanup']);
      expect(next.settings.lineupVersion, AppSettings.currentLineupVersion);
      expect(next.allChannels.where((c) => c.auto && !c.isLive).first.number, 1);
      await next.close();
    });
  });
}
