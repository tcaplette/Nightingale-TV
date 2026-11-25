import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/retro.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/sharing/channel_recipe.dart';
import 'package:nightingale_tv/sharing/recipe_matcher.dart';

/// A library as one server would list it: [prefix] makes the item ids its own.
LibraryIndex serverLibrary(
  String prefix, {
  String showName = 'Friends',
  int? showYear = 1994,
  Map<String, String> showIds = const {'Tvdb': '79168', 'Imdb': 'tt0108778'},
  int episodes = 6,
  Set<int> missing = const {},
  bool numbered = true,
  Map<String, String> matrixIds = const {'Tmdb': '603'},
  bool matrix = true,
  bool nameless = true,
  Duration episodeLength = const Duration(minutes: 22),
}) {
  final showId = '$prefix-show';
  return LibraryIndex.fromJellyfinItems(
    seriesItems: [
      {'Id': showId, 'Name': showName, 'Type': 'Series', 'ProductionYear': ?showYear, 'ProviderIds': showIds},
    ],
    episodeItems: [
      for (var i = 1; i <= episodes; i++)
        if (!missing.contains(i))
          {
            'Id': '$prefix-e$i',
            'Name': 'The One $i',
            'Type': 'Episode',
            'SeriesId': showId,
            'SeriesName': showName,
            if (numbered) 'ParentIndexNumber': 1,
            if (numbered) 'IndexNumber': i,
            'RunTimeTicks': episodeLength.inMicroseconds * 10,
            'LocationType': 'FileSystem',
            'Path': '/media/$prefix/friends/s01e$i.mkv',
          },
    ],
    movieItems: [
      if (matrix)
        {
          'Id': '$prefix-matrix',
          'Name': 'The Matrix',
          'Type': 'Movie',
          'ProductionYear': 1999,
          'ProviderIds': matrixIds,
          'RunTimeTicks': const Duration(minutes: 136).inMicroseconds * 10,
          'LocationType': 'FileSystem',
        },
      if (nameless)
        {
          'Id': '$prefix-home',
          'Name': 'Home Video',
          'Type': 'Movie',
          'RunTimeTicks': const Duration(minutes: 40).inMicroseconds * 10,
          'LocationType': 'FileSystem',
        },
    ],
    fetchedAt: DateTime(2026),
  );
}

Channel channelOf(LibraryIndex library, {String id = 'user:abc', List<String>? playlist}) => Channel(
      id: id,
      number: 12,
      name: '90s Sitcoms',
      icon: const ChannelIcon.builtin('weekend', color: 0xFF42A5F5),
      source: const ChannelSource(includeEpisodes: false),
      order: PlaybackOrder.cyclic,
      playlist: playlist ?? [for (final e in library.episodes) e.id, for (final m in library.movies) m.id],
      anchor: DateTime(2026, 11, 1),
      auto: false,
    );

List<(DateTime, String)> guide(Channel ch, LibraryIndex library) {
  final schedule = ChannelSchedule.build(ch, library, const [], BreakContext.none)!;
  final from = DateTime(2026, 11, 16, 8);
  return [
    for (final p in schedule.programsBetween(from, from.add(const Duration(hours: 24))))
      (p.start, p.item?.title ?? ''),
  ];
}

void main() {
  group('What a recipe holds (3.2)', () {
    test('no server address, name, token, item id, image, path or pool id', () {
      // Ids as the multi-server set keeps an added server's: "s2~…".
      final library = serverLibrary('s2~8f3a9c');
      final ch = channelOf(library)
        ..icon = const ChannelIcon(kind: ChannelIconKind.jellyfin, value: 's2~8f3a9c-show')
        ..commercialPlan = BreakPlan(
            mode: BreakMode.custom,
            roles: const CustomRoles(preRoll: Duration(seconds: 30), prePool: 'pool-ads', bumperPool: 'pool-bumpers'))
        ..slotRule = const SlotRule(
            length: Duration(minutes: 30), tail: TailMode.filler, poolId: 'pool-filler', offlineImage: 'offline-card.png')
        ..slotCarry = SlotCarry(itemId: 's2~8f3a9c-e2', start: DateTime(2026, 11, 16, 8), end: DateTime(2026, 11, 16, 8, 30))
        ..retro = const ChannelRetro(surround: Surround.image, surroundImage: 'my-surround.png', crt: CrtStyle.off);
      final block = ProgramBlock(
        id: 'block:x1',
        title: 'Saturday Morning',
        channelId: ch.id,
        days: {6},
        startMinute: 8 * 60,
        endMinute: 12 * 60,
        source: const ChannelSource(seriesKeys: ['friends|1994']),
        order: PlaybackOrder.cyclic,
        playlist: [for (final e in library.episodes) e.id],
        anchor: DateTime(2026, 11, 7),
      );
      final recipe = ChannelRecipe.fromChannel(ch, [block], library, station: 'Tyler TV');
      final text = jsonEncode(recipe.toJson());
      final secrets = [
        'http://192.168.1.20:8096', 'Living Room Server', 'token-abc123', // the session's
        '8f3a9c', 's2~', '/media/', '.mkv', // ids and paths
        'pool-ads', 'pool-bumpers', 'pool-filler', 'offline-card.png', 'my-surround.png', 'block:x1', 'user:abc',
        for (final id in [...ch.playlist, ...block.playlist]) id,
      ];
      for (final s in secrets) {
        expect(text, isNot(contains(s)), reason: s);
      }
      expect(recipe.icon, isNull, reason: 'a server image becomes the default badge');
      expect(recipe.total, 6 + 2 + 6);
      expect(text, contains('tvdb:79168'));
      expect(text, contains('"station":"Tyler TV"'));
      expect(recipe.slot!.length, const Duration(minutes: 30));
      expect(recipe.breaks!.roles.preRoll, const Duration(seconds: 30));
      expect(recipe.retro.crt, CrtStyle.off);
      expect(recipe.retro.surround, isNull);
    });

    test('a built-in icon travels; JSON round-trips to the same hash', () {
      final library = serverLibrary('a');
      final recipe = ChannelRecipe.fromChannel(channelOf(library), const [], library);
      expect(recipe.icon!.value, 'weekend');
      final again = ChannelRecipe.fromJson(jsonDecode(jsonEncode(recipe.toJson())));
      expect(again.hash, recipe.hash);
      expect(again.items.length, 8);
      expect(again.anchor, recipe.anchor);
    });

    test('unknown fields are ignored; a newer version is refused', () {
      final library = serverLibrary('a');
      final json = ChannelRecipe.fromChannel(channelOf(library), const [], library).toJson()
        ..['laterField'] = {'x': 1};
      expect(ChannelRecipe.fromJson(json).name, '90s Sitcoms');
      expect(() => ChannelRecipe.fromJson({...json, 'v': 2}), throwsA(isA<RecipeTooNew>()));
      expect(() => ChannelRecipe.fromJson({'name': 'x'}), throwsFormatException);
    });

    test('over 20,000 programs can not be shared', () {
      final library = serverLibrary('a', episodes: 2);
      final ch = channelOf(library, playlist: [for (var i = 0; i < 20001; i++) 'a-e${i % 2 + 1}']);
      expect(() => ChannelRecipe.fromChannel(ch, const [], library), throwsA(isA<RecipeTooBig>()));
    });
  });

  group('Matching (3.4)', () {
    final sender = serverLibrary('jf');
    final recipe = ChannelRecipe.fromChannel(channelOf(sender), const [], sender);

    test('the same library gives the same slots as the sender', () {
      final mine = serverLibrary('jf', nameless: false);
      final original = channelOf(mine)..order = PlaybackOrder.random;
      final r = ChannelRecipe.fromChannel(original, const [], mine);
      final receiver = serverLibrary('plex', nameless: false);
      final m = RecipeMatcher(receiver).match(r);
      expect((m.matched, m.total), (7, 7));
      expect(m.playlist, [for (var i = 1; i <= 6; i++) 'plex-e$i', 'plex-matrix']);
      final copy = channelOf(receiver, id: 'user:copy', playlist: m.playlist)
        ..anchor = r.anchor
        ..order = r.order;
      final theirs = guide(copy, receiver), ours = guide(original, mine);
      expect(theirs.length, greaterThan(30));
      expect(theirs, ours);
    });

    test('partly matched: counts, and the sender order kept', () {
      final receiver = serverLibrary('plex', missing: {2, 5});
      final m = RecipeMatcher(receiver).match(recipe);
      expect((m.matched, m.total), (6, 8), reason: 'two episodes missing');
      expect(m.playlist, ['plex-e1', 'plex-e3', 'plex-e4', 'plex-e6', 'plex-matrix', 'plex-home']);
    });

    test('a renamed show matches by provider id', () {
      final receiver = serverLibrary('plex', showName: 'Friends (US)', showYear: 1995);
      final m = RecipeMatcher(receiver).match(recipe);
      expect(m.playlist.where((id) => id.startsWith('plex-e')).length, 6);
    });

    test('title and year only: no provider ids on either side', () {
      final bare = serverLibrary('jf', showIds: const {}, matrixIds: const {});
      final r = ChannelRecipe.fromChannel(channelOf(bare), const [], bare);
      final receiver = serverLibrary('plex', showIds: const {}, matrixIds: const {});
      final m = RecipeMatcher(receiver).match(r);
      expect(m.playlist, [for (var i = 1; i <= 6; i++) 'plex-e$i', 'plex-matrix', 'plex-home']);
      expect((m.matched, m.total), (8, 8), reason: 'the yearless movie matches by title and length (smb-sources)');
    });

    test('provider ids only: a show and a movie under other names', () {
      final receiver = LibraryIndex.fromJellyfinItems(
        seriesItems: [
          {'Id': 'x-show', 'Name': 'Totally Different', 'Type': 'Series', 'ProviderIds': {'Imdb': 'tt0108778'}},
        ],
        episodeItems: [
          {
            'Id': 'x-e3',
            'Name': 'Another title',
            'Type': 'Episode',
            'SeriesId': 'x-show',
            'SeriesName': 'Totally Different',
            'ParentIndexNumber': 1,
            'IndexNumber': 3,
            'RunTimeTicks': 13200000000,
            'LocationType': 'FileSystem',
          },
        ],
        movieItems: [
          {
            'Id': 'x-m',
            'Name': 'Matrix, The',
            'Type': 'Movie',
            'ProductionYear': 2001,
            'ProviderIds': {'Tmdb': '603'},
            'RunTimeTicks': 81600000000,
            'LocationType': 'FileSystem',
          },
        ],
      );
      final m = RecipeMatcher(receiver).match(recipe);
      expect(m.playlist, ['x-e3', 'x-m']);
    });

    test('the same provider with another id is a different title', () {
      final receiver = serverLibrary('plex', matrixIds: const {'Tmdb': '604'}, showIds: const {'Tvdb': '1'});
      final m = RecipeMatcher(receiver).match(recipe);
      // Only the yearless movie, which no provider describes, matches.
      expect(m.playlist, ['plex-home']);
    });

    test('a movie without a year matches by title and length, only when one does (smb-sources)', () {
      expect(RecipeMatcher(serverLibrary('plex', matrix: false)).match(recipe).playlist, contains('plex-home'));
      final twice = LibraryIndex(
          series: const [],
          episodes: const [],
          movies: [
            for (final id in ['x1', 'x2'])
              MediaEntry(id: id, kind: MediaKind.movie, title: 'Home Video', runtime: const Duration(minutes: 40)),
          ],
          fetchedAt: DateTime(2026));
      expect(RecipeMatcher(twice).match(recipe).playlist, isEmpty);
    });

    test('episodes without numbers match by title within the show', () {
      final unnumbered = serverLibrary('jf', numbered: false);
      final r = ChannelRecipe.fromChannel(channelOf(unnumbered), const [], unnumbered);
      final m = RecipeMatcher(serverLibrary('plex', numbered: false)).match(r);
      expect(m.playlist.where((id) => id.startsWith('plex-e')).length, 6);
    });

    test('blocks and their lineups map to the receiver\'s shows', () async {
      final ch = channelOf(sender)..blockOnly = true;
      final block = ProgramBlock(
        id: 'block:1',
        title: 'Saturday Morning',
        channelId: ch.id,
        days: {6},
        startMinute: 8 * 60,
        endMinute: 12 * 60,
        source: const ChannelSource(includeEpisodes: false),
        order: PlaybackOrder.cyclic,
        playlist: [for (final e in sender.episodes) e.id],
        anchor: DateTime(2026, 11, 7),
        lineup: [LineupSlot(seriesKey: sender.series.single.key, count: 2)],
      );
      final r = ChannelRecipe.fromJson(jsonDecode(jsonEncode(ChannelRecipe.fromChannel(ch, [block], sender).toJson())));
      final receiver = serverLibrary('plex', showName: 'Friends (US)', showYear: null);
      final m = await RecipeMatcher.run(r, receiver);
      expect(r.blocks.single.title, 'Saturday Morning');
      expect(m.playlist, isEmpty);
      expect(m.blockPlaylists.single.length, 6);
      expect(m.blockLineups.single.single.seriesKey, receiver.series.single.key);
      expect(m.blockLineups.single.single.count, 2);
    });
  });
}
