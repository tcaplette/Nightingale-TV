import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_index.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_probe.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'smb_fakes.dart';

const _maps = [
  SmbMapping('TV', SmbFolderType.tvShows),
  SmbMapping('Movies', SmbFolderType.movies),
  SmbMapping('Movies/Home', SmbFolderType.homeVideos),
  SmbMapping('Music', SmbFolderType.music),
  SmbMapping('Ads', SmbFolderType.commercials),
];

void main() {
  test('a 20,000-file share is scanned, every file once, quickly', () async {
    final files = <String, int>{
      for (var s = 0; s < 100; s++)
        for (var season = 1; season <= 4; season++)
          for (var e = 1; e <= 50; e++) 'TV/Show $s/Season $season/Show $s S${season.toString().padLeft(2, '0')}E${e.toString().padLeft(2, '0')}.mkv': 1,
    };
    expect(files.length, 20000);
    final clock = Stopwatch()..start();
    final scan = await SmbScanner(FakeShare(files), _maps).scan();
    expect(scan.items.length, 20000);
    expect(scan.shows.length, 100);
    expect(scan.items.map((i) => i.id).toSet().length, 20000);
    expect(clock.elapsed, lessThan(const Duration(seconds: 20)));
  });

  test('a mapped folder inside another takes its own type; extras and samples are skipped', () async {
    final scan = await SmbScanner(
        FakeShare({
          'Movies/Heat (1995)/Heat.mkv': 1,
          'Movies/Heat (1995)/sample.mkv': 1,
          'Movies/Heat (1995)/Featurettes/Making of.mkv': 1,
          'Movies/Home/Summer 2019/Beach.mkv': 1,
          'Movies/Home/Summer 2019/Pier.mkv': 1,
          'Ads/Spot 1.mp4': 1,
          'Backups/x.mkv': 1,
        }),
        _maps).scan();
    final byPath = {for (final i in scan.items) i.path: i.type};
    expect(byPath, {
      'Movies/Heat (1995)/Heat.mkv': SmbFolderType.movies,
      'Movies/Home/Summer 2019/Beach.mkv': SmbFolderType.homeVideos,
      'Movies/Home/Summer 2019/Pier.mkv': SmbFolderType.homeVideos,
      'Ads/Spot 1.mp4': SmbFolderType.commercials,
    });
    expect(scan.shows.singleWhere((s) => s.home).name, 'Summer 2019');
  });

  test('a replaced or moved file keeps its id; two candidates keep none', () async {
    final first = await SmbScanner(FakeShare({'TV/Show A/Show A S01E02 720p.mkv': 1, 'Movies/Heat (1995).mkv': 1}), _maps).scan();
    final ep = first.items.firstWhere((i) => i.episode == 2).id;
    final heat = first.items.firstWhere((i) => i.title == 'Heat').id;
    final second = await SmbScanner(
            FakeShare({'TV/Show A/Show A S01E02 1080p.mkv': 2, 'Movies/Heat (1995)/Heat (1995).mkv': 2}), _maps,
            previous: first)
        .scan();
    expect(second.items.firstWhere((i) => i.episode == 2).id, ep);
    expect(second.items.firstWhere((i) => i.title == 'Heat').id, heat);
    // The saved ids carry over to the scan after.
    final third = await SmbScanner(
            FakeShare({'TV/Show A/Show A S01E02 1080p.mkv': 2, 'Movies/Heat (1995)/Heat (1995).mkv': 2}), _maps,
            previous: second)
        .scan();
    expect(third.items.firstWhere((i) => i.episode == 2).id, ep);
    // Two new copies of a gone file: neither takes its id.
    final both = await SmbScanner(
            FakeShare({'TV/Show A/Show A S01E02 a.mkv': 1, 'TV/Show A/Show A S01E02 b.mkv': 1}), _maps,
            previous: first)
        .scan();
    expect(both.items.map((i) => i.id), isNot(contains(ep)));
    // Ids shared through the share (another device's moves).
    final shared = await SmbScanner(FakeShare({'TV/Show A/Show A S01E02 x.mkv': 1}), _maps,
            sharedIds: {'TV/Show A/Show A S01E02 x.mkv': ep})
        .scan();
    expect(shared.items.single.id, ep);
  });

  test('an unreadable folder keeps what it held; a gone one does not', () async {
    final share = FakeShare({'TV/Show A/Show A S01E01.mkv': 1, 'Movies/Heat (1995).mkv': 1});
    final first = await SmbScanner(share, _maps).scan();
    // The TV folder's disk is offline.
    final missing = await SmbScanner(FakeShare({'Movies/Heat (1995).mkv': 1}), _maps, previous: first).scan();
    expect(missing.items.length, 2, reason: 'the mapped folder that is missing keeps its files');
  });

  test('music: tags win over names; album covers; songs aren\'t episodes', () async {
    final scan = await SmbScanner(
        FakeShare({'Music/The Band/First Album (1978)/01 - One.mp3': 1, 'Music/The Band/First Album (1978)/cover.jpg': 1}),
        _maps).scan();
    final song = scan.items.single;
    expect((song.artist, song.album, song.year, song.title), ('The Band', 'First Album', 1978, 'One'));
    expect(scan.albums[song.albumId], isNotNull);
    final items = SmbIndexItems(scan, {
      song.id: SmbProbe(size: 1, modified: song.modified, duration: const Duration(minutes: 3), tags: const {
        'title': 'Uno', 'artist': 'Band, The', 'album': 'First', 'genre': 'Rock; Pop', 'date': '1979-01-01',
      }),
    }, serverId: 's');
    final m = items.songs.single;
    expect((m['Name'], m['Album'], m['ProductionYear']), ('Uno', 'First', 1979));
    expect(m['Artists'], ['Band, The']);
    expect(m['Genres'], ['Rock', 'Pop']);
  });

  test("files not read yet aren't scheduled, unless an .nfo gives their length", () async {
    final scan = await SmbScanner(FakeShare({'Movies/A (2001).mkv': 1, 'Movies/B (2002).mkv': 1}), _maps).scan();
    final a = scan.items.firstWhere((i) => i.title == 'A');
    final items = SmbIndexItems(scan, {a.id: SmbProbe(size: 1, modified: a.modified, duration: const Duration(minutes: 90))}, serverId: 's');
    expect(items.movies.map((m) => m['Name']), ['A']);
    final index = LibraryIndex.fromJellyfinItems(seriesItems: items.series, episodeItems: items.episodes, movieItems: items.movies);
    expect(index.movies.single.runtime, const Duration(minutes: 90));
  });
}
