import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/library/library_index.dart';

LibraryIndex _library() => LibraryIndex.fromJellyfinItems(
      seriesItems: [
        for (final (name, rating) in [('Bluey', 'TV-Y'), ('Toons', 'TV-G'), ('Adult Toon', 'TV-MA'), ('Mystery', null)])
          {'Id': name, 'Name': name, 'OfficialRating': ?rating},
      ],
      episodeItems: [
        for (final name in ['Bluey', 'Toons', 'Adult Toon', 'Mystery'])
          for (var i = 1; i <= 3; i++)
            {
              'Id': '$name-$i',
              'Name': '$name $i',
              'SeriesId': name,
              'SeriesName': name,
              'ParentIndexNumber': 1,
              'IndexNumber': i,
              'RunTimeTicks': const Duration(minutes: 22).inMicroseconds * 10,
              'LocationType': 'FileSystem',
            },
      ],
      movieItems: [
        {'Id': 'm1', 'Name': 'Movie', 'OfficialRating': 'G', 'RunTimeTicks': 60000000000, 'LocationType': 'FileSystem'},
      ],
    );

Channel _ch(String id, int number, List<String> playlist,
        {ChannelSource source = const ChannelSource(), bool favorite = false, bool blockOnly = false}) =>
    Channel(
      id: id,
      number: number,
      name: id,
      icon: const ChannelIcon.builtin('tv'),
      source: source,
      order: PlaybackOrder.cyclic,
      playlist: playlist,
      anchor: DateTime(2026, 10, 1),
      favorite: favorite,
      blockOnly: blockOnly,
    );

List<String> _eps(String show) => ['$show-1', '$show-2', '$show-3'];

void main() {
  final library = _library();
  final kids = _ch('kids', 2, [..._eps('Bluey'), ..._eps('Toons')]);
  final toonTv = _ch('toon-tv', 3, [..._eps('Toons'), ..._eps('Adult Toon')], favorite: true);
  final mystery = _ch('mystery', 4, _eps('Mystery'));
  final movies = _ch('movies', 5, ['m1'], source: const ChannelSource(includeEpisodes: false, includeMovies: true));
  final radio = _ch('radio', 6, const [], source: const ChannelSource(includeEpisodes: false, includeSongs: true));
  final lineup = [kids, toonTv, mystery, movies, radio];

  AutoGroups auto({List<ProgramBlock> blocks = const [], bool kidProfile = false}) =>
      AutoGroups(library, blocks, kidProfile: kidProfile);

  group('automatic tabs', () {
    test('Favorites, Movies and Music from the lineup', () {
      final a = auto();
      expect([for (final c in lineup) if (a.contains(GuideTabs.favorites, c)) c.id], ['toon-tv']);
      expect([for (final c in lineup) if (a.isMovies(c)) c.id], ['movies']);
      expect([for (final c in lineup) if (a.isMusic(c)) c.id], ['radio']);
    });

    test('Kids: everything rated TV-G/G or younger; adult animation or unrated keep a channel out', () {
      final a = auto();
      expect([for (final c in lineup) if (a.isKids(c)) c.id], ['kids', 'movies']);
    });

    test("a block's items count too", () {
      final block = ProgramBlock(
        id: 'b',
        title: 'Late Night',
        channelId: 'kids',
        days: {6},
        startMinute: 22 * 60,
        endMinute: 23 * 60,
        source: const ChannelSource(),
        order: PlaybackOrder.cyclic,
        playlist: _eps('Adult Toon'),
        anchor: DateTime(2026, 10, 1),
      );
      expect(auto(blocks: [block]).isKids(kids), isFalse);
    });

    test('kid profiles have no Kids tab', () {
      final tabs = resolveGuideTabs(
          visible: lineup, groups: const [], order: GuideTabs.defaultOrder, hidden: const {}, auto: auto(kidProfile: true));
      expect([for (final t in tabs) t.id], isNot(contains(GuideTabs.kids)));
    });
  });

  group('the tab list', () {
    test('in order, without empty or hidden tabs; channels in number order', () {
      final tabs = resolveGuideTabs(
        visible: lineup,
        groups: [ChannelGroup(id: 'group:sat', name: 'Saturday', channelIds: ['mystery', 'kids'])],
        order: GuideTabs.normalize(GuideTabs.defaultOrder, [ChannelGroup(id: 'group:sat', name: 'Saturday')]),
        hidden: {GuideTabs.music},
        auto: auto(),
      );
      expect([for (final t in tabs) t.name], ['All', 'Favorites', 'Saturday', 'Movies', 'Kids']);
      expect([for (final c in tabs[2].channels) c.number], [2, 4]);
      expect(tabs.first.channels, hasLength(5));
    });

    test('no favorites: no Favorites tab', () {
      final tabs = resolveGuideTabs(
          visible: [kids, mystery], groups: const [], order: GuideTabs.defaultOrder, hidden: const {}, auto: auto());
      expect([for (final t in tabs) t.id], [GuideTabs.all, GuideTabs.kids]);
    });

    test('hidden and deleted channels drop out of groups', () {
      final group = ChannelGroup(id: 'group:sat', name: 'Saturday', channelIds: ['kids', 'mystery', 'gone']);
      final tabs = resolveGuideTabs(
          visible: [kids, toonTv], groups: [group], order: GuideTabs.normalize(const [], [group]), hidden: const {}, auto: auto());
      expect(tabs.firstWhere((t) => t.id == 'group:sat').channels.map((c) => c.id), ['kids']);
    });

    test('All is first and never hidden; new groups go after Favorites; deleted ones drop', () {
      final groups = [ChannelGroup(id: 'group:a', name: 'A'), ChannelGroup(id: 'group:b', name: 'B')];
      expect(GuideTabs.normalize(['auto:music', 'group:a', 'group:old', 'all'], groups),
          ['all', 'favorites', 'group:b', 'auto:movies', 'auto:music', 'auto:kids', 'group:a']);
      final tabs = resolveGuideTabs(
          visible: lineup, groups: const [], order: GuideTabs.defaultOrder, hidden: {GuideTabs.all}, auto: auto());
      expect(tabs.first.id, GuideTabs.all);
    });
  });

  test("M3U group-title: the first group in tab order, else the automatic group, else the profile's", () {
    final groups = [
      ChannelGroup(id: 'group:late', name: 'Late', channelIds: ['mystery']),
      ChannelGroup(id: 'group:sat', name: 'Saturday', channelIds: ['mystery', 'kids']),
    ];
    final order = ['all', 'favorites', 'group:sat', 'group:late', 'auto:movies', 'auto:music', 'auto:kids'];
    String groupOf(Channel c) => m3uGroupFor(c, groups: groups, order: order, auto: auto(), fallback: 'Nightingale TV · Ann');
    expect(groupOf(mystery), 'Saturday');
    expect(groupOf(movies), 'Movies');
    expect(groupOf(radio), 'Music');
    expect(groupOf(kids), 'Saturday');
    expect(groupOf(toonTv), 'Nightingale TV · Ann');
  });

  test('ChannelGroup round-trips', () {
    final back = ChannelGroup.fromJson(ChannelGroup(id: 'group:x', name: 'X', channelIds: ['a', 'b']).toJson());
    expect((back.id, back.name), ('group:x', 'X'));
    expect(back.channelIds, ['a', 'b']);
  });
}
