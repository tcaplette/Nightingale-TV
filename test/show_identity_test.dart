import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'lineup_fixture.dart';

void main() {
  ShowItem item(String name, {int? year, List<String> ids = const []}) =>
      ShowItem(id: '$name|$year', name: name, year: year, providerIds: ids);
  bool same(ShowItem a, ShowItem b) => ShowIdentity.same(a, b);

  group('ShowIdentity', () {
    test('a matched and a bare copy are one show', () {
      expect(same(item('Show A', year: 2001, ids: ['tvdb:1']), item('Show A')), isTrue);
    });

    test('season, series and disc suffixes in their spellings are dropped', () {
      for (final raw in [
        'Show B Season 02',
        'Show B SEASON 2',
        'Show B S03',
        'Show B Seasons 1-3',
        'Show B Series 3',
        'Show B Disc 2',
        'Show B - Season 1 Disc 2',
        'Show B Complete Series',
        'Show B Complete',
      ]) {
        expect(ShowIdentity.of(raw).key, 'show b', reason: raw);
        expect(ShowIdentity.of(raw).name, 'Show B', reason: raw);
      }
      expect(ShowIdentity.of('Show B Season 02').season, 2);
      expect(ShowIdentity.of('Show B S03').season, 3);
      expect(ShowIdentity.of('Show B Series 3').season, 3);
      expect(ShowIdentity.of('Show B Seasons 1-3').season, isNull, reason: 'a range is no one season');
      expect(ShowIdentity.of('Show B Disc 2').season, isNull);
    });

    test('an unclosed bracket and its tags are dropped', () {
      final id = ShowIdentity.of('Show B Season 1  [1080p AI 10bit');
      expect(id.key, 'show b');
      expect(id.name, 'Show B');
      expect(id.season, 1);
      expect(ShowIdentity.of('Show B [x265] [Dual Audio]').key, 'show b');
    });

    test('parenthesised tags go; a parenthesised year is the year', () {
      final tagged = ShowIdentity.of('Show C (Complete cartoon series in MP4 format)', year: 2014);
      expect((tagged.key, tagged.name, tagged.year), ('show c', 'Show C', 2014));
      final dated = ShowIdentity.of('Show C (2014)');
      expect((dated.key, dated.year), ('show c', 2014));
      expect(ShowIdentity.of('Show C (2014)', year: 2015).year, 2015, reason: "the item's own year wins");
      expect(same(item('Show C (2014)'), item('Show C', year: 2014)), isTrue);
    });

    test('& and "and" are the same; case and punctuation don\'t matter', () {
      expect(same(item('Show H & Friends'), item('show h and friends')), isTrue);
      expect(same(item('Show: H, the Friends!'), item('Show H the Friends')), isTrue);
    });

    test('remakes with different years stay apart', () {
      expect(same(item('Show D', year: 1978), item('Show D', year: 2004)), isFalse);
    });

    test('numerals and roman numerals are kept', () {
      expect(ShowIdentity.of('Show E II').key, 'show e ii');
      expect(same(item('Show E', year: 1996), item('Show E II', year: 2020)), isFalse);
      expect(same(item('Show E'), item('Show E II')), isFalse);
      expect(ShowIdentity.of('Show 24').key, 'show 24');
    });

    test('a yearless item matching shows of two years stays its own show', () {
      final shows = ShowIndexer([
        ShowItem(id: 'old', name: 'Show D', year: 1978),
        ShowItem(id: 'new', name: 'Show D', year: 2004),
        ShowItem(id: 'bare', name: 'Show D'),
      ], [
        (showId: 'old', showName: 'Show D', season: 1, number: 1, title: 'a'),
        (showId: 'new', showName: 'Show D', season: 1, number: 1, title: 'b'),
        (showId: 'bare', showName: 'Show D', season: 1, number: 1, title: 'c'),
      ]);
      expect(shows.series.map((s) => s.key), unorderedEquals(['show d|1978', 'show d|2004', 'show d|']));
    });

    test('a shared provider id overrides different names; different ids keep names apart', () {
      expect(same(item('Show A', year: 2001, ids: ['tvdb:1']), item('The A Show', year: 2003, ids: ['tvdb:1'])), isTrue);
      expect(same(item('Show A', year: 2001, ids: ['tvdb:1']), item('Show A', year: 2001, ids: ['tvdb:2'])), isFalse);
      expect(same(item('Show A', year: 2001, ids: ['tvdb:1']), item('Show A', ids: ['tmdb:9'])), isTrue,
          reason: 'ids of different providers say nothing');
    });

    test('a name that is only tags is kept', () {
      expect(ShowIdentity.of('[Group]').name, '[Group]');
      expect(ShowIdentity.of('Season 1').name, 'Season 1');
    });
  });

  group('a scan merges a server\'s items for one show', () {
    for (final shape in ServerShape.values) {
      group(shape.name, () {
        final index = FixtureLibrary.standard().index(shape);
        SeriesEntry show(String key) => index.seriesByKey[key]!;
        Set<int?> seasonsOf(String key) => {for (final e in index.episodesBySeries[key]!) e.season};

        test('matched and bare copies are one show, the shared season once', () {
          final a = show('show a|2001');
          expect((a.name, a.year, a.hasLogo), ('Show A', 2001, true));
          expect(a.genres, ['Comedy']);
          expect(a.providerIds, ['tvdb:100']);
          expect(index.series.where((s) => s.name == 'Show A'), hasLength(1));
          expect(seasonsOf('show a|2001'), {for (var s = 1; s <= 9; s++) s});
          expect(index.episodesBySeries['show a|2001'], hasLength(180));
          final codes = [for (final e in index.episodesBySeries['show a|2001']!) '${e.season}x${e.episode}'];
          expect(codes.toSet(), hasLength(codes.length), reason: 'season 8 appears once');
        });

        test('season folders are one show, each folder its season', () {
          expect(show('show b|2009').name, 'Show B');
          expect(index.series.where((s) => s.key.startsWith('show b')), hasLength(1));
          expect(seasonsOf('show b|2009'), {1, 3, 4});
          expect(index.episodesBySeries['show b|2009'], hasLength(36));
        });

        test('release tags are dropped from the name', () {
          expect(show('show c|2014').name, 'Show C');
        });

        test('remakes and sequels stay apart', () {
          expect(index.seriesByKey.keys, containsAll(['show d|1978', 'show d|2004', 'show e|1996', 'show e ii|2020']));
        });

        test('& and "and" copies merge', () {
          expect(index.episodesBySeries['show h and friends|2015'], hasLength(36));
        });

        test('episodes with no show are the unknown show', () {
          expect(index.episodesBySeries[SeriesEntry.unknownKey], hasLength(70));
          expect(show(SeriesEntry.unknownKey).isUnknown, isTrue);
        });
      });
    }

    test('every server type gives the same shows and episodes', () {
      final library = FixtureLibrary.standard();
      String describe(LibraryIndex index) => [
            for (final s in [...index.series]..sort((a, b) => a.key.compareTo(b.key)))
              '${s.key} ${s.name} ${s.year} ${s.genres} ${s.hasLogo}: '
                  '${[for (final e in index.episodesBySeries[s.key]!) '${e.id}@${e.season}x${e.episode}'].join(',')}',
          ].join('\n');
      final jellyfin = describe(library.index(ServerShape.jellyfin));
      expect(describe(library.index(ServerShape.emby)), jellyfin);
      expect(describe(library.index(ServerShape.plex)), jellyfin);
    });

    test('a saved index re-keys to what a scan gives', () {
      final library = FixtureLibrary.standard();
      final scanned = library.index(ServerShape.jellyfin);
      // As a scan before show identity keyed it: name|year, as listed.
      final j = library.jellyfin();
      final old = LibraryIndex(
        series: [
          for (final s in j.series)
            SeriesEntry(
                key: '${(s['Name'] as String).toLowerCase()}|${s['ProductionYear'] ?? ''}',
                id: s['Id'] as String,
                name: s['Name'] as String,
                year: s['ProductionYear'] as int?,
                genres: (s['Genres'] as List).cast<String>()),
          const SeriesEntry(key: 'unknown show|', id: 'unknown show|', name: 'Unknown show'),
        ],
        episodes: [
          for (final e in scanned.episodes)
            e.withShow(
                e.seriesId == null
                    ? 'unknown show|'
                    : () {
                        final s = j.series.firstWhere((s) => s['Id'] == e.seriesId);
                        return '${(s['Name'] as String).toLowerCase()}|${s['ProductionYear'] ?? ''}';
                      }(),
                e.seriesId == null ? 'Unknown show' : j.series.firstWhere((s) => s['Id'] == e.seriesId)['Name'] as String,
                e.season),
        ],
        movies: scanned.movies,
        fetchedAt: scanned.fetchedAt,
      );
      final rekeyed = old.rekeyed();
      expect({for (final s in rekeyed.series) s.key}, {for (final s in scanned.series) s.key});
      expect(
          {for (final e in rekeyed.episodes) '${e.id} ${e.seriesKey} ${e.season}'},
          {for (final e in scanned.episodes) '${e.id} ${e.seriesKey} ${e.season}'});
    });
  });
}
