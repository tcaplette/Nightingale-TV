import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'cable_fixture.dart';
import 'lineup_fixture.dart';

/// `ShowIndexer._group` as it was before library-scan-anr (lineup-dedup),
/// copied unchanged: the reference the lookup version must equal (D1).
List<List<ShowItem>> referenceGroup(List<ShowItem> items) {
  final groups = <List<ShowItem>>[];
  bool conflicts(List<ShowItem> g, ShowItem s) =>
      g.any((o) => ShowIdentity.providersAgree(o.providerIds, s.providerIds) == false);
  bool sharesProvider(List<ShowItem> g, ShowItem s) =>
      g.any((o) => ShowIdentity.providersAgree(o.providerIds, s.providerIds) == true);
  void join(ShowItem s, List<ShowItem>? g) => g == null ? groups.add([s]) : g.add(s);

  final unknown = [for (final s in items) if (s.isUnknown) s];
  final dated = [for (final s in items) if (!s.isUnknown && s.identity.year != null) s];
  final yearless = [for (final s in items) if (!s.isUnknown && s.identity.year == null) s];
  for (final s in dated) {
    join(
        s,
        groups.where((g) => sharesProvider(g, s)).firstOrNull ??
            groups
                .where((g) => !conflicts(g, s) && g.any((o) => o.identity.key == s.identity.key && o.identity.year == s.identity.year))
                .firstOrNull);
  }
  final datedGroups = [...groups];
  for (final s in yearless) {
    final byProvider = groups.where((g) => sharesProvider(g, s)).firstOrNull;
    if (byProvider != null) {
      byProvider.add(s);
      continue;
    }
    final named = [
      for (final g in datedGroups)
        if (!conflicts(g, s) && g.any((o) => o.identity.key == s.identity.key)) g,
    ];
    if (named.length == 1) {
      named.single.add(s);
      continue;
    }
    // No dated show of the name, or several (ambiguous): one yearless show.
    join(
        s,
        groups
            .where((g) => !datedGroups.contains(g) && !conflicts(g, s) && g.first.identity.key == s.identity.key)
            .firstOrNull);
  }
  if (unknown.isNotEmpty) groups.add(unknown);
  return groups;
}

/// Groups as item ids, in order.
List<List<String>> ids(List<List<ShowItem>> groups) => [
      for (final g in groups) [for (final s in g) s.id],
    ];

List<ShowItem> fromFixture(FixtureLibrary library) => [
      for (final s in library.items)
        ShowItem(
            id: s.id,
            name: s.name,
            year: s.year,
            genres: s.genres,
            hasLogo: s.logo,
            providerIds: LibraryIndex.providerIdsOf(s.providerIds)),
      if (library.unnamed > 0) ShowItem(id: SeriesEntry.unknownKey, name: SeriesEntry.unknownName),
    ];

/// Fresh copies of [items] (their identities not yet worked out).
List<ShowItem> fresh(List<ShowItem> items) => [
      for (final s in items)
        ShowItem(id: s.id, name: s.name, year: s.year, genres: s.genres, hasLogo: s.hasLogo, providerIds: s.providerIds),
    ];

const _bases = ['Show A', 'Show B', 'The Show C', 'Show & D', 'Show-E', 'Show E II', 'Show F'];
const _years = [1978, 2001, 2004, 2020];
const _ids = ['tvdb:1', 'tvdb:2', 'tvdb:3', 'tmdb:1', 'tmdb:2', 'imdb:tt1', 'imdb:tt2', 'local7'];

/// A seeded random library: names with brackets, parenthesised years and
/// season markers; dated and yearless copies; shared, conflicting and
/// missing provider ids; yearless names matching shows of two years.
List<ShowItem> generated(Random r, {int? size}) {
  final n = size ?? 1 + r.nextInt(60);
  String name(String base, int? year) {
    final decorated = switch (r.nextInt(9)) {
      0 => '$base [1080p x265]',
      1 => year != null ? '$base ($year)' : '$base (Complete series)',
      2 => '$base Season ${1 + r.nextInt(9)}',
      3 => '$base S${1 + r.nextInt(12)}',
      4 => '$base Disc 2',
      5 => '$base [Group',
      6 => base.toUpperCase(),
      _ => base,
    };
    return decorated;
  }

  return [
    for (var i = 0; i < n; i++)
      () {
        if (r.nextInt(25) == 0) return ShowItem(id: 'u$i', name: SeriesEntry.unknownName);
        final base = _bases[r.nextInt(_bases.length)];
        final year = r.nextInt(3) == 0 ? null : _years[r.nextInt(_years.length)];
        // Sometimes the year is only in the name.
        final inName = year != null && r.nextInt(4) == 0;
        return ShowItem(
          id: 'i$i',
          name: inName ? '$base ($year)' : name(base, year),
          year: inName ? null : year,
          genres: r.nextBool() ? const ['Comedy'] : const [],
          hasLogo: r.nextInt(3) == 0,
          providerIds: [for (var k = r.nextInt(4); k > 0; k--) _ids[r.nextInt(_ids.length)]],
        );
      }(),
  ];
}

void main() {
  group('grouping by lookups equals the earlier grouping (library-scan-anr D1)', () {
    for (final (name, library) in [('standard', FixtureLibrary.standard()), ('test server', testServerLibrary())]) {
      test('lineup-dedup fixture: $name', () {
        final items = fromFixture(library);
        expect(ids(ShowIndexer.groupForTest(fresh(items))), ids(referenceGroup(fresh(items))));
      });
    }

    test('500 generated libraries', () {
      final r = Random(20261112);
      var merged = 0, ambiguous = 0;
      for (var i = 0; i < 500; i++) {
        final items = generated(r);
        final expected = ids(referenceGroup(fresh(items)));
        expect(ids(ShowIndexer.groupForTest(fresh(items))), expected, reason: 'library $i');
        merged += expected.where((g) => g.length > 1).length;
        ambiguous += expected.length;
      }
      // The generator exercises merging, not only singletons.
      expect(merged, greaterThan(500));
      expect(ambiguous, greaterThan(merged));
    });

    test('a few large generated libraries', () {
      final r = Random(7);
      for (var i = 0; i < 5; i++) {
        final items = generated(r, size: 800);
        expect(ids(ShowIndexer.groupForTest(fresh(items))), ids(referenceGroup(fresh(items))), reason: 'library $i');
      }
    });
  });

  test('grouping scales with library size (media-servers "Grouping scales with library size")', () {
    // A library like a real one: mostly distinct shows, some bare copies,
    // season folders and shared provider ids. 10 episodes per item.
    (List<ShowItem>, List<EpisodeRef>) library(int shows) {
      final r = Random(shows);
      final items = <ShowItem>[];
      final episodes = <EpisodeRef>[];
      for (var i = 0; i < shows; i++) {
        final base = 'Series ${i ~/ 2}';
        final item = switch (i % 10) {
          0 => ShowItem(id: 's$i', name: '$base Season ${1 + r.nextInt(5)}'),
          1 => ShowItem(id: 's$i', name: base, year: 1950 + i % 70, providerIds: ['tvdb:${i ~/ 2}']),
          2 => ShowItem(id: 's$i', name: '$base [1080p]', providerIds: ['tvdb:${(i - 1) ~/ 2}']),
          _ => ShowItem(id: 's$i', name: 'Show $i', year: 1950 + i % 70, providerIds: ['tmdb:$i']),
        };
        items.add(item);
        for (var e = 1; e <= 10; e++) {
          episodes.add((showId: item.id, showName: item.name, season: 1, number: e, title: 'Episode $e'));
        }
      }
      return (items, episodes);
    }

    // Each run indexes 20,000 items' worth: ten 2,000-item libraries or one
    // 20,000-item one, so both sizes pay their share of garbage collection
    // inside the timing (a lone small library's garbage is collected after
    // its timing ends). The time per library is the run's time / count.
    double medianMillis(int shows) {
      final count = 20000 ~/ shows;
      final times = <double>[];
      for (var run = 0; run < 3; run++) {
        final libraries = [for (var k = 0; k < count; k++) library(shows)];
        final watch = Stopwatch()..start();
        for (final (items, episodes) in libraries) {
          final indexed = ShowIndexer(items, episodes);
          expect(indexed.episodes, hasLength(episodes.length));
        }
        watch.stop();
        times.add(watch.elapsedMicroseconds / 1000 / count);
      }
      times.sort();
      return times[1];
    }

    // Warm up the JIT at both sizes first.
    medianMillis(2000);
    medianMillis(20000);
    final small = medianMillis(2000);
    final large = medianMillis(20000);
    // ignore: avoid_print
    print('grouping: 2,000 items / 20,000 episodes ${small.toStringAsFixed(1)} ms; '
        '20,000 items / 200,000 episodes ${large.toStringAsFixed(1)} ms (×${(large / small).toStringAsFixed(1)})');
    // Linear measures ×10–13 here (memory and collection costs grow a little
    // with the working set); the square of the size would be ×100.
    expect(large, lessThanOrEqualTo(small * 20));
  });
}
