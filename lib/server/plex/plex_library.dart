import '../../library/library_index.dart';

/// Builds an index from Plex section listings (design D6): shows (`type=2`),
/// episodes (`type=4`), movies (`type=1`), tracks (`type=10`) and music
/// videos, plus the videos of commercial pools ([poolsByItem]). The same
/// rules as for Jellyfin: a show's items merge into one show
/// ([ShowIndexer]), programs under 30 seconds are left out, pool contents
/// never air as programs.
LibraryIndex libraryIndexFromPlex({
  List<Map<String, Object?>> shows = const [],
  List<Map<String, Object?>> episodes = const [],
  List<Map<String, Object?>> movies = const [],
  List<Map<String, Object?>> commercials = const [],
  List<Map<String, Object?>> tracks = const [],
  List<Map<String, Object?>> musicVideos = const [],
  Map<String, List<String>> poolsByItem = const {},
  DateTime? fetchedAt,
}) {
  bool inPool(Map<String, Object?> item) => poolsByItem.containsKey(_id(item));

  final playable = [
    for (final e in episodes)
      if (_runtime(e) != null && !inPool(e)) e,
  ];
  String? showIdOf(Map<String, Object?> e) => switch ('${e['grandparentRatingKey'] ?? ''}') { '' => null, final id => id };
  // The server's items for one show become one show, as on Jellyfin.
  final indexed = ShowIndexer([
    for (final s in shows)
      ShowItem(
          id: _id(s),
          name: s['title'] as String? ?? SeriesEntry.unknownName,
          year: _int(s['year']),
          genres: _tags(s['Genre']),
          officialRating: s['contentRating'] as String?,
          hasLogo: plexHasLogo(s),
          providerIds: plexProviderIds(s['Guid'])),
  ], [
    for (final e in playable)
      (
        showId: showIdOf(e),
        showName: e['grandparentTitle'] as String?,
        season: _int(e['parentIndex']),
        number: _int(e['index']),
        title: '${e['title']}',
      ),
  ]);

  final episodeEntries = <MediaEntry>[];
  for (final (i, e) in playable.indexed) {
    final show = indexed.episodes[i];
    if (show == null) continue;
    final number = _int(e['index']);
    episodeEntries.add(_entry(e, MediaKind.episode, _runtime(e)!,
        title: LibraryIndex.cleanEpisodeTitle(e['title'] as String? ?? '', episode: number),
        seriesKey: show.key,
        seriesId: showIdOf(e),
        seriesName: show.name,
        season: show.season,
        episode: number,
        added: _epoch(e['addedAt']),
        playCount: _int(e['viewCount']) ?? 0));
  }

  final movieEntries = <MediaEntry>[];
  final seenMovies = <String>{};
  for (final m in movies) {
    final runtime = _runtime(m);
    if (runtime == null || inPool(m)) continue;
    final name = m['title'] as String? ?? 'Movie';
    if (!seenMovies.add('${name.toLowerCase()}|${m['year']}')) continue;
    movieEntries.add(_entry(m, MediaKind.movie, runtime,
        title: name,
        genres: _tags(m['Genre']),
        officialRating: m['contentRating'] as String?,
        playCount: _int(m['viewCount']) ?? 0));
  }

  final commercialEntries = <MediaEntry>[];
  final seenCommercials = <String>{};
  for (final c in commercials) {
    final ms = _int(c['duration']);
    if (ms == null) continue;
    final runtime = Duration(milliseconds: ms);
    if (runtime < LibraryIndex.minClip) continue;
    if (!seenCommercials.add(_id(c))) continue;
    commercialEntries.add(_entry(c, MediaKind.commercial, runtime,
        title: c['title'] as String? ?? 'Commercial', poolIds: poolsByItem[_id(c)] ?? const []));
  }

  List<MediaEntry> music(List<Map<String, Object?>> items, MediaKind kind) {
    final result = <MediaEntry>[];
    final seen = <String>{};
    for (final m in items) {
      final ms = _int(m['duration']);
      if (ms == null || ms <= 0 || inPool(m) || !seen.add(_id(m))) continue;
      final name = m['title'] as String? ?? (kind == MediaKind.song ? 'Song' : 'Music video');
      // A track's own artist when it differs from the album's.
      final tagged = (m['originalTitle'] as String?) ?? m['grandparentTitle'] as String?;
      final named = tagged == null ? LibraryIndex.splitMusicName(name) : null;
      result.add(_entry(m, kind, Duration(milliseconds: ms),
          title: named?.title ?? name,
          year: _int(m['parentYear']),
          genres: _tags(m['Genre']),
          officialRating: m['contentRating'] as String?,
          artist: tagged ?? named?.artist,
          album: kind == MediaKind.song ? m['parentTitle'] as String? : null,
          albumId: kind == MediaKind.song ? m['parentRatingKey']?.toString() : null,
          chapters: false));
    }
    return result;
  }

  return LibraryIndex(
    series: indexed.series,
    episodes: episodeEntries,
    movies: movieEntries,
    commercials: commercialEntries,
    songs: music(tracks, MediaKind.song),
    musicVideos: music(musicVideos, MediaKind.musicVideo),
    fetchedAt: fetchedAt ?? DateTime.now(),
  );
}

/// Whether a Plex item has a clear logo (listed in its `Image` array).
bool plexHasLogo(Map<String, Object?> item) => [
      for (final i in (item['Image'] as List? ?? const []).cast<Map<String, Object?>>()) i['type']
    ].contains('clearLogo');

MediaEntry _entry(Map<String, Object?> item, MediaKind kind, Duration runtime,
    {required String title,
    String? seriesKey,
    String? seriesId,
    String? seriesName,
    int? season,
    int? episode,
    int? year,
    List<String> genres = const [],
    String? officialRating,
    String? artist,
    String? album,
    String? albumId,
    List<String> poolIds = const [],
    DateTime? added,
    int playCount = 0,
    bool chapters = true}) {
  final media = _first(item['Media']);
  final part = _first(media?['Part']);
  return MediaEntry(
    id: _id(item),
    kind: kind,
    title: title,
    runtime: runtime,
    seriesKey: seriesKey,
    seriesId: seriesId,
    seriesName: seriesName,
    season: season,
    episode: episode,
    year: year ?? _int(item['year']),
    overview: switch (item['summary']) { final String s when s.isNotEmpty => s, _ => null },
    genres: genres,
    officialRating: officialRating,
    // The part id changes when the file is replaced; updatedAt when Plex
    // re-reads it.
    etag: part == null ? null : '${part['id']}-${item['updatedAt'] ?? ''}',
    container: (part?['container'] ?? media?['container']) as String?,
    size: _int(part?['size']),
    chapters: chapters ? plexChapters(item) : const [],
    poolIds: poolIds,
    artist: artist,
    album: album,
    albumId: albumId,
    added: added,
    streamPath: part?['key'] as String?,
    playCount: playCount,
    providerIds: plexProviderIds(item['Guid']),
  );
}

/// The `Guid` array Plex lists with `includeGuids=1` (`imdb://tt…`,
/// `tmdb://…`, `tvdb://…`) as `imdb:tt…` (see [LibraryIndex.providerIdsOf]).
List<String> plexProviderIds(Object? guids) => [
      for (final g in (guids as List? ?? const []).whereType<Map<String, Object?>>())
        if (RegExp(r'^(\w+)://(.+)$').firstMatch('${g['id']}') case final m?
            when LibraryIndex.providers.contains(m[1]!.toLowerCase()))
          '${m[1]!.toLowerCase()}:${m[2]}',
    ];

/// Chapter starts, in order, from an item's `Chapter` array.
List<Duration> plexChapters(Map<String, Object?> item) => [
      for (final c in (item['Chapter'] as List? ?? const []).cast<Map<String, Object?>>())
        if (_int(c['startTimeOffset']) case final ms?) Duration(milliseconds: ms),
    ]..sort();

String _id(Map<String, Object?> item) => '${item['ratingKey']}';

Map<String, Object?>? _first(Object? list) => switch (list) {
      [final Map<String, Object?> m, ...] => m,
      _ => null,
    };

int? _int(Object? v) => switch (v) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };

DateTime? _epoch(Object? seconds) {
  final s = _int(seconds);
  return s == null ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
}

Duration? _runtime(Map<String, Object?> item) {
  final ms = _int(item['duration']);
  // Ignore anything under 30 seconds; it's almost always bad metadata.
  if (ms == null || ms < 30000) return null;
  return Duration(milliseconds: ms);
}

List<String> _tags(Object? value) => [
      for (final t in (value as List? ?? const []).cast<Map<String, Object?>>())
        if (t['tag'] case final String tag) tag,
    ];
