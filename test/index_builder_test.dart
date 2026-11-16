import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/server/plex/plex_library.dart';

import 'lineup_fixture.dart';

/// An index as saved, without the time it was built.
String saved(LibraryIndex index) => jsonEncode({...index.toJson()}..remove('fetchedAt'));

/// Indexes built in an isolate (library-scan-anr D2) equal the ones built
/// on the calling isolate: everything they hold can be sent back.
void main() {
  setUp(() {
    IndexBuilder.useIsolate = true;
    // Many chunks even for the fixture, so the hand-over is exercised.
    IndexBuilder.chunk = 7;
  });
  tearDown(() => IndexBuilder.chunk = 1000);

  final library = FixtureLibrary.standard().copyWith(movies: {'Comedy': 3});

  for (final emby in [false, true]) {
    test(emby ? 'an Emby scan' : 'a Jellyfin scan', () async {
      final j = library.jellyfin(emby: emby);
      final direct = LibraryIndex.fromJellyfinItems(seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies);
      final isolated = await IndexBuilder.jellyfin(seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies);
      expect(saved(isolated), saved(direct));
      expect(isolated.scanNotes, direct.scanNotes);
      expect(isolated.scanNotes, isNotEmpty, reason: 'the fixture merges shows');
    });
  }

  test('a Plex scan', () async {
    final p = library.plex();
    final direct = libraryIndexFromPlex(shows: p.shows, episodes: p.episodes, movies: p.movies);
    final isolated = await IndexBuilder.plex(shows: p.shows, episodes: p.episodes, movies: p.movies);
    expect(saved(isolated), saved(direct));
    expect(isolated.scanNotes, direct.scanNotes);
  });

  test('a saved index, read (and re-keyed) in the worker', () async {
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_index_builder');
    addTearDown(() => dir.delete(recursive: true));
    final legacy = library.legacyIndex(fetchedAt: DateTime(2026));
    final file = File('${dir.path}/library.json')..writeAsStringSync(jsonEncode(legacy.toJson()));
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

    final rekeyed = (await IndexBuilder.saved(file.path, rekey: true))!;
    final direct = LibraryIndex.fromJson(json).rekeyed();
    expect(jsonEncode(rekeyed.toJson()), jsonEncode(direct.toJson()));
    expect(rekeyed.scanNotes, direct.scanNotes);
    expect(jsonEncode((await IndexBuilder.saved(file.path))!.toJson()), jsonEncode(LibraryIndex.fromJson(json).toJson()));

    // Missing or unreadable: null, as AppStorage.readJson gives.
    expect(await IndexBuilder.saved('${dir.path}/none.json'), isNull);
    File('${dir.path}/bad.json').writeAsStringSync('{not json');
    expect(await IndexBuilder.saved('${dir.path}/bad.json'), isNull);
    File('${dir.path}/list.json').writeAsStringSync('[]');
    expect(await IndexBuilder.saved('${dir.path}/list.json'), isNull);
  });

  test('an index in use, re-keyed', () async {
    final legacy = library.legacyIndex(fetchedAt: DateTime(2026));
    // Its lazy lookups are built before it is sent.
    legacy.episodesBySeries;
    legacy.seriesByKey;
    final isolated = await IndexBuilder.rekeyed(legacy);
    expect(jsonEncode(isolated.toJson()), jsonEncode(legacy.rekeyed().toJson()));
    expect(isolated.scanNotes, legacy.rekeyed().scanNotes);
  });

  test('pools reach the worker', () async {
    final j = library.jellyfin();
    final ads = [
      for (var i = 0; i < 20; i++)
        {'Id': 'ad-$i', 'Name': 'Ad $i', 'Type': 'Video', 'RunTimeTicks': 30 * 10000000, 'LocationType': 'FileSystem'},
    ];
    final pools = {for (final a in ads) a['Id']! as String: ['pool-1', 'pool-2']};
    final direct = LibraryIndex.fromJellyfinItems(
        seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies, commercialItems: ads, poolsByItem: pools);
    final isolated = await IndexBuilder.jellyfin(
        seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies, commercialItems: ads, poolsByItem: pools);
    expect(saved(isolated), saved(direct));
    expect(isolated.commercials.first.poolIds, ['pool-1', 'pool-2']);
  });

  test('an error in the worker reaches the caller', () async {
    await expectLater(
        IndexBuilder.jellyfin(seriesItems: [
          {'Id': 7, 'Name': 'Not a string id'},
        ], episodeItems: const [], movieItems: const []),
        throwsA(isA<RemoteError>()));
  });

  test('scan notes are never saved', () {
    final j = library.jellyfin();
    final index = LibraryIndex.fromJellyfinItems(seriesItems: j.series, episodeItems: j.episodes, movieItems: j.movies);
    expect(index.scanNotes, isNotEmpty);
    expect(jsonEncode(index.toJson()), isNot(contains('merged')));
  });
}
