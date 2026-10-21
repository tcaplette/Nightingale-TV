import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';

// Monday 19 October 2026.
DateTime _mon(int h, [int m = 0]) => DateTime(2026, 10, 19, h, m);
DateTime _day(int offset, int h, [int m = 0]) => DateTime(2026, 10, 19 + offset, h, m);

MediaEntry _ep(String show, int n,
        {DateTime? added, DateTime? availableAt, Duration runtime = const Duration(minutes: 22)}) =>
    MediaEntry(
      id: '$show-e$n',
      kind: MediaKind.episode,
      title: 'Episode $n',
      runtime: runtime,
      seriesKey: show,
      seriesName: show,
      season: 1,
      episode: n,
      added: added,
      availableAt: availableAt ?? added,
    );

LibraryIndex _library(List<MediaEntry> episodes) => LibraryIndex(
      series: [
        for (final key in {for (final e in episodes) e.seriesKey!}) SeriesEntry(key: key, id: key, name: key),
      ],
      episodes: episodes,
      movies: const [],
      fetchedAt: _mon(0),
    );

Channel _channel(String id, int number, Iterable<MediaEntry> items, {bool premieres = true}) => Channel(
      id: id,
      number: number,
      name: id,
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: [for (final e in items) e.id],
      anchor: DateTime(2026, 10, 1),
      premieres: premieres,
    );

/// Old episodes (added long ago) so loops have something to play.
List<MediaEntry> _old(String show, int count) => [
      for (var i = 1; i <= count; i++) _ep(show, i, added: DateTime(2025), availableAt: DateTime(2025)),
    ];

void main() {
  ChannelSchedule schedule(Channel ch, LibraryIndex library, List<Channel> lineup,
      {PremiereSettings settings = const PremiereSettings(),
      List<ProgramBlock> blocks = const [],
      BreakPlan plan = BreakPlan.off}) {
    final premieres = PremierePlan.build(library, lineup, settings);
    return ChannelSchedule.build(ch, library, blocks, BreakContext(plan: plan), premieres)!;
  }

  test('three new episodes of one show premiere on three nights, in airing order', () {
    final added = _mon(6);
    final eps = [..._old('Show', 4), for (final n in [5, 6, 7]) _ep('Show', n, added: added)];
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    final s = schedule(ch, library, [ch]);
    for (final (night, n) in [(0, 5), (1, 6), (2, 7)]) {
      final p = s.programAt(_day(night, 20, 5));
      expect(p.isPremiere, isTrue, reason: 'night $night');
      expect(p.item!.id, 'Show-e$n');
      expect(p.start, _day(night, 20));
      expect(p.blockTitle, PremierePlan.title);
    }
    expect(s.programAt(_day(3, 20, 5)).isPremiere, isFalse, reason: 'nothing left');
    // The slot ends with its one episode; regular programming resumes.
    expect(s.programAt(_mon(20, 23)).isPremiere, isFalse);
    expect(s.programAt(_mon(20, 23)).start, _mon(20, 22));
  });

  test('two half-hour shows premiere back to back; regular programming resumes at 9:00', () {
    final eps = [..._old('Alpha', 3), ..._old('Beta', 3), _ep('Alpha', 4, added: _mon(5)), _ep('Beta', 4, added: _mon(6))];
    final library = _library(eps);
    final ch = _channel('mix', 2, eps);
    final s = schedule(ch, library, [ch], plan: BreakPlan.automatic);
    final first = s.programAt(_mon(20, 1));
    final second = s.programAt(_mon(20, 31));
    expect((first.item!.id, first.start, first.end), ('Alpha-e4', _mon(20), _mon(20, 30)),
        reason: 'the show waiting longest goes first');
    expect((second.item!.id, second.start, second.end), ('Beta-e4', _mon(20, 30), _mon(21)));
    expect(second.isPremiere, isTrue);
    final after = s.programAt(_mon(21, 1));
    expect(after.isPremiere, isFalse);
    expect(after.start, _mon(21));
    // Guide cells mark them.
    final cells = s.programsBetween(_mon(19, 30), _mon(21, 30));
    expect([for (final c in cells) c.isPremiere], contains(true));
  });

  test('a slot stays within two hours; the rest wait for tomorrow', () {
    final shows = ['A', 'B', 'C', 'D', 'E'];
    final eps = [
      for (final show in shows) ..._old(show, 2),
      for (final (i, show) in shows.indexed) _ep(show, 3, added: _mon(1 + i), runtime: const Duration(minutes: 44)),
    ];
    final library = _library(eps);
    final ch = _channel('mix', 2, eps);
    final s = schedule(ch, library, [ch]);
    final tonight = [for (final p in s.programsBetween(_mon(20), _mon(23))) if (p.isPremiere) p.item!.seriesKey];
    expect(tonight, ['A', 'B'], reason: '44 + 44 min fits; a third would make 2:12');
    final tomorrow = [for (final p in s.programsBetween(_day(1, 20), _day(1, 23))) if (p.isPremiere) p.item!.seriesKey];
    expect(tomorrow, ['C', 'D']);
  });

  test('nothing new: regular programming at 8:00', () {
    final eps = _old('Show', 10);
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    final s = schedule(ch, library, [ch]);
    expect(s.programsBetween(_mon(19), _mon(23)).any((p) => p.isPremiere), isFalse);
    expect(PremierePlan.build(library, [ch], const PremiereSettings())?.forChannel(ch,
        slotOf: (e) => e.runtime, blocked: (_, _) => false)?.airingsBetween(_mon(0), _day(1, 0)), isEmpty);
  });

  test('turned off: no slots, nothing marked NEW', () {
    final eps = [..._old('Show', 4), _ep('Show', 5, added: _mon(6))];
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    expect(PremierePlan.build(library, [ch], const PremiereSettings(enabled: false)), isNull);
    final s = schedule(ch, library, [ch], settings: const PremiereSettings(enabled: false));
    expect(s.programsBetween(_mon(0), _day(3, 0)).any((p) => p.isPremiere), isFalse);
  });

  test("a scan at 8:10 PM leaves tonight's slot alone; the episode premieres tomorrow", () {
    final waiting = _ep('Alpha', 4, added: _mon(6));
    final late = _ep('Beta', 4, added: _mon(19), availableAt: _mon(20, 10));
    final before = [..._old('Alpha', 3), ..._old('Beta', 3), waiting];
    final ch = _channel('mix', 2, [...before, late]);
    final tonightBefore = schedule(ch, _library(before), [ch]).programsBetween(_mon(20), _mon(21));
    final s = schedule(ch, _library([...before, late]), [ch]);
    final tonight = s.programsBetween(_mon(20), _mon(21));
    expect([for (final p in tonight) if (p.isPremiere) p.item!.id], ['Alpha-e4']);
    expect([for (final p in tonight) (p.item?.id, p.start, p.end)].take(2),
        [for (final p in tonightBefore) (p.item?.id, p.start, p.end)].take(2));
    final tomorrow = s.programAt(_day(1, 20, 1));
    expect((tomorrow.item!.id, tomorrow.isPremiere), ('Beta-e4', true));
  });

  test("a show premieres on its marathon channel, else on the next-narrowest channel that plays it", () {
    final eps = [
      ..._old('Toons', 3),
      ..._old('Sitcom', 3),
      ..._old('Other', 3),
      _ep('Sitcom', 4, added: _mon(6)),
    ];
    final library = _library(eps);
    final all = _channel('all-shows', 2, eps);
    final laughs = _channel('laugh-track', 3, eps.where((e) => e.seriesKey != 'Toons'));
    final marathon = _channel('sitcom', 4, eps.where((e) => e.seriesKey == 'Sitcom'));
    expect(PremierePlan.build(library, [all, laughs, marathon], const PremiereSettings())!.homeOf['sitcom'], 'sitcom');
    marathon.premieres = false;
    expect(PremierePlan.build(library, [all, laughs, marathon], const PremiereSettings())!.homeOf['sitcom'],
        'laugh-track');
    final s = schedule(all, library, [all, laughs, marathon]);
    expect(s.programAt(_mon(20, 1)).isPremiere, isFalse, reason: 'only on its home channel');
  });

  test('a show Jellyfin lists under two series premieres on one channel, in airing order', () {
    // Seasons 1 and 2 under different series keys, as when Jellyfin keeps a
    // series per folder.
    MediaEntry split(int season, int n, String key) => MediaEntry(
          id: 'rm-s${season}e$n',
          kind: MediaKind.episode,
          title: 'Episode $n',
          runtime: const Duration(minutes: 22),
          seriesKey: key,
          seriesName: 'Rick and Morty',
          season: season,
          episode: n,
          added: _mon(6),
          availableAt: _mon(6),
        );
    final eps = [..._old('Other', 3), split(2, 1, 'rick and morty|2013'), split(1, 1, 'rick and morty|')];
    final library = _library(eps);
    final mix = _channel('mix', 2, eps);
    final marathon = _channel('rick', 3, [eps[4]]);
    final both = _channel('both', 4, eps.skip(3));
    final plan = PremierePlan.build(library, [mix, marathon, both], const PremiereSettings())!;
    // The marathon (one show, lowest number) is home, though it holds only one season.
    expect(plan.homeOf, {'rick and morty': 'rick', 'other': 'mix'});
    final s = schedule(marathon, library, [mix, marathon, both]);
    expect(s.programAt(_mon(20, 1)).item!.id, 'rm-s1e1');
    expect(s.programAt(_day(1, 20, 1)).item!.id, 'rm-s2e1');
    expect(schedule(both, library, [mix, marathon, both]).programAt(_mon(20, 1)).isPremiere, isFalse);
  });

  test('ties go to the lowest channel number; music, block-only and hidden channels never host', () {
    final eps = [..._old('Show', 3), _ep('Show', 4, added: _mon(6))];
    final library = _library(eps);
    final a = _channel('a', 7, eps), b = _channel('b', 5, eps);
    expect(PremierePlan.build(library, [a, b], const PremiereSettings())!.homeOf['show'], 'b');
    final music = _channel('radio', 3, eps)..source = const ChannelSource(includeEpisodes: false, includeSongs: true);
    final blockOnly = _channel('blocks', 4, eps)..blockOnly = true;
    expect(PremierePlan.build(library, [music, blockOnly, a], const PremiereSettings())!.homeOf['show'], 'a');
    expect(PremierePlan.build(library, [music, blockOnly], const PremiereSettings()), isNull);
  });

  test('a Thursday block from 7:30 to 9:00 PM moves the premiere to Friday', () {
    final eps = [..._old('Show', 3), _ep('Show', 4, added: _day(3, 6))];
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    final block = ProgramBlock(
      id: 'block:thu',
      title: 'Thursday Movie',
      channelId: 'show',
      days: {DateTime.thursday},
      startMinute: 19 * 60 + 30,
      endMinute: 21 * 60,
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: [for (final e in eps.take(3)) e.id],
      anchor: DateTime(2026, 10, 1),
    );
    final s = schedule(ch, library, [ch], blocks: [block]);
    expect(_day(3, 0).weekday, DateTime.thursday);
    expect(s.programAt(_day(3, 20, 5)).blockTitle, 'Thursday Movie');
    final friday = s.programAt(_day(4, 20, 5));
    expect((friday.item!.id, friday.isPremiere), ('Show-e4', true));
  });

  test('9:00 PM on weeknights', () {
    // Added Saturday: waits for Monday at 9:00 PM.
    final eps = [..._old('Show', 3), _ep('Show', 4, added: _day(-2, 6))];
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    final s = schedule(ch, library, [ch],
        settings: const PremiereSettings(startMinute: 21 * 60, days: {1, 2, 3, 4, 5}));
    expect(s.programsBetween(_day(-2, 0), _day(0, 20)).any((p) => p.isPremiere), isFalse, reason: 'not at the weekend');
    expect(s.programAt(_mon(20, 30)).isPremiere, isFalse, reason: 'not at 8 PM');
    final p = s.programAt(_mon(21, 5));
    expect((p.item!.id, p.start, p.isPremiere), ('Show-e4', _mon(21), true));
  });

  test('the same slots on every rebuild, whatever is asked first', () {
    final eps = [
      for (final show in ['A', 'B', 'C']) ..._old(show, 2),
      for (var n = 3; n < 9; n++)
        for (final (i, show) in ['A', 'B', 'C'].indexed) _ep(show, n, added: _day(n % 3 - 4, 1 + i)),
    ];
    final library = _library(eps);
    final ch = _channel('mix', 2, eps);
    List<String?> week(ChannelSchedule s) => [
          for (var d = 0; d < 7; d++)
            for (final p in s.programsBetween(_day(d, 20), _day(d, 22))) if (p.isPremiere) p.item!.id,
        ];
    final first = schedule(ch, library, [ch]);
    final forward = week(first);
    final second = schedule(ch, library, [ch]);
    // Ask about Saturday first, then the rest.
    second.programAt(_day(5, 20, 1));
    expect(week(second), forward);
    expect(forward, isNotEmpty);
  });

  test('an episode is new for 14 days: a long queue runs out', () {
    final eps = [..._old('Show', 2), for (var n = 3; n <= 18; n++) _ep('Show', n, added: _mon(6))];
    final library = _library(eps);
    final ch = _channel('show', 2, eps);
    final s = schedule(ch, library, [ch]);
    final premiered = [
      for (var d = 0; d < 20; d++)
        if (s.programAt(_day(d, 20, 1)) case final p when p.isPremiere) p.item!.episode,
    ];
    expect(premiered, [for (var n = 3; n <= 16; n++) n], reason: 'one a night for 14 nights; 17 and 18 expire');
  });

  test('PremiereSettings round-trips and defaults', () {
    const s = PremiereSettings(enabled: false, startMinute: 21 * 60 + 15, days: {6, 7});
    expect(PremiereSettings.fromJson(s.toJson()), s);
    expect(PremiereSettings.fromJson(null), const PremiereSettings());
    expect(PremiereSettings.fromJson({'start': 99999}).startMinute, 20 * 60);
  });
}
