import '../../library/library_index.dart';
import 'smb_library.dart';
import 'smb_probe.dart';

/// A share's scan as Jellyfin-shaped items (design D5), which the library
/// is built from as it is from Jellyfin's own. Only what can be scheduled:
/// files whose length is known and that can be played.
class SmbIndexItems {
  SmbIndexItems(SmbScan scan, Map<String, SmbProbe> probes,
      {required String serverId, Set<String> unplayable = const {}, int Function(SmbItem item)? plays}) {
    final showIds = <String>{};
    for (final i in scan.items) {
      final read = probes[i.id];
      final probe = read != null && read.matches(i.size, i.modified) ? read : null;
      final runtime = probe?.duration ?? i.runtime;
      if (runtime == null || unplayable.contains(i.id) || probe != null && probe.damaged) continue;
      final map = <String, Object?>{
        'Id': i.id,
        'Name': i.title,
        'RunTimeTicks': runtime.inMicroseconds * 10,
        'Etag': i.etag,
        'Container': i.container,
        'MediaSources': [
          {'Size': i.size}
        ],
        'ProductionYear': ?i.year,
        'Overview': ?i.plot,
        if (i.genres.isNotEmpty) 'Genres': i.genres,
        'OfficialRating': ?i.rating,
        if (i.ids.isNotEmpty) 'ProviderIds': _providerIds(i.ids),
        if (probe != null && probe.chapters.isNotEmpty)
          'Chapters': [
            for (final c in probe.chapters) {'StartPositionTicks': c.inMicroseconds * 10}
          ],
        if (i.created != null) 'DateCreated': DateTime.fromMillisecondsSinceEpoch(i.created!, isUtc: true).toIso8601String(),
        if (plays != null)
          if (plays(i) case final n when n > 0) 'UserData': {'PlayCount': n},
      };
      byId[i.id] = map;
      switch (i.type) {
        case SmbFolderType.tvShows || SmbFolderType.homeVideos:
          final show = scan.showById[i.showId];
          map['SeriesId'] = i.showId;
          map['SeriesName'] = show?.name;
          map['ParentIndexNumber'] = i.season;
          map['IndexNumber'] = i.episode;
          if (i.type == SmbFolderType.homeVideos) map[LibraryIndex.homeKey] = homeSeriesKey(serverId, i.showId!);
          if (i.showId case final id?) showIds.add(id);
          episodes.add(map);
        case SmbFolderType.movies:
          movies.add(map);
        case SmbFolderType.music:
          _music(map, i, probe);
          songs.add(map);
        case SmbFolderType.musicVideos:
          if (i.artist != null) map['Artists'] = [i.artist!];
          musicVideos.add(map);
        case SmbFolderType.commercials || SmbFolderType.bumpers:
          break;
      }
    }
    for (final s in scan.shows) {
      if (!showIds.contains(s.id)) continue;
      series.add({
        'Id': s.id,
        'Name': s.name,
        'ProductionYear': ?s.year,
        if (s.genres.isNotEmpty) 'Genres': s.genres,
        'OfficialRating': ?s.rating,
        if (s.ids.isNotEmpty) 'ProviderIds': _providerIds(s.ids),
        if (s.logo != null) 'ImageTags': {'Logo': s.logo!.id},
        if (s.home) LibraryIndex.homeKey: homeSeriesKey(serverId, s.id),
      });
    }
  }

  final series = <Map<String, Object?>>[];
  final episodes = <Map<String, Object?>>[];
  final movies = <Map<String, Object?>>[];
  final songs = <Map<String, Object?>>[];
  final musicVideos = <Map<String, Object?>>[];

  /// Every file that can be scheduled, commercials too.
  final byId = <String, Map<String, Object?>>{};

  /// A home video folder's show key: no other server's show has it.
  static String homeSeriesKey(String serverId, String showId) => '${LibraryIndex.homePrefix}$serverId:$showId';

  static Map<String, String> _providerIds(List<String> ids) => {
        for (final id in ids)
          if (id.indexOf(':') case final at when at > 0) id.substring(0, at): id.substring(at + 1)
      };

  /// Tags win over names (music).
  static void _music(Map<String, Object?> map, SmbItem i, SmbProbe? probe) {
    final tags = probe?.tags ?? const {};
    if (tags['title'] case final t?) map['Name'] = t;
    final artist = tags['artist'] ?? tags['album_artist'] ?? i.artist;
    if (artist != null) map['Artists'] = [artist];
    if (tags['album_artist'] case final a?) map['AlbumArtist'] = a;
    if (tags['album'] ?? i.album case final a?) map['Album'] = a;
    if (i.albumId case final a?) map['AlbumId'] = a;
    if (tags['genre'] case final g?) {
      map['Genres'] = [
        for (final part in g.split(RegExp(r'\s*[;/]\s*')))
          if (part.trim().isNotEmpty) part.trim()
      ];
    }
    if (RegExp(r'(?:19|20)\d\d').firstMatch(tags['date'] ?? '')?[0] case final y?) map['ProductionYear'] = int.parse(y);
  }
}
