import '../commercials/commercial_pool.dart';
import '../jellyfin/jellyfin_client.dart';
import '../profiles/profile.dart';

enum MediaKind {
  episode,
  movie,

  /// A commercial, bumper or station ident from a commercials library.
  commercial,
}

/// One playable video, flattened from Jellyfin's item JSON.
class MediaEntry {
  const MediaEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.runtime,
    this.seriesKey,
    this.seriesId,
    this.seriesName,
    this.season,
    this.episode,
    this.year,
    this.overview,
    this.genres = const [],
    this.officialRating,
    String? sourceId,
    this.clipStart,
    this.etag,
    this.chapters = const [],
    this.poolIds = const [],
  }) : sourceId = sourceId ?? id;

  final String id;
  final MediaKind kind;
  final String title;
  final Duration runtime;

  /// Deduplicated series identity (see [SeriesEntry.key]); null for movies.
  final String? seriesKey;
  final String? seriesId;
  final String? seriesName;
  final int? season;
  final int? episode;
  final int? year;
  final String? overview;

  /// Movies only. Episodes inherit their series' genres.
  final List<String> genres;
  final String? officialRating;

  /// The Jellyfin item that holds the video: [id] for whole items, the reel
  /// for a clip cut from one.
  final String sourceId;

  /// Where a clip starts inside [sourceId]; null for whole items.
  final Duration? clipStart;

  /// Jellyfin's Etag, which changes when the file is replaced.
  final String? etag;

  /// Chapter start times, in order.
  final List<Duration> chapters;

  /// The commercial pools this item belongs to (commercials only).
  final List<String> poolIds;

  /// A clip cut from a longer video, rather than a whole Jellyfin item.
  bool get isClip => clipStart != null;

  /// Position in [sourceId] where this entry's own time starts.
  Duration get sourceStart => clipStart ?? Duration.zero;

  /// A copy with a different [poolIds].
  MediaEntry withPools(List<String> pools) => MediaEntry(
        id: id,
        kind: kind,
        title: title,
        runtime: runtime,
        seriesKey: seriesKey,
        seriesId: seriesId,
        seriesName: seriesName,
        season: season,
        episode: episode,
        year: year,
        overview: overview,
        genres: genres,
        officialRating: officialRating,
        sourceId: sourceId,
        clipStart: clipStart,
        etag: etag,
        chapters: chapters,
        poolIds: pools,
      );

  /// Title shown in the guide: the show name for episodes.
  String get guideTitle => kind == MediaKind.episode ? (seriesName ?? title) : title;

  /// "S3 · E12 · Episode title" for episodes, year for movies.
  String get subtitle {
    if (kind == MediaKind.commercial) return 'Commercial';
    if (kind == MediaKind.movie) return year != null ? 'Movie · $year' : 'Movie';
    final code = [
      if (season != null) 'S$season',
      if (episode != null) 'E$episode',
    ].join(' · ');
    return code.isEmpty ? title : '$code · $title';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'runtimeMs': runtime.inMilliseconds,
        if (seriesKey != null) 'seriesKey': seriesKey,
        if (seriesId != null) 'seriesId': seriesId,
        if (seriesName != null) 'seriesName': seriesName,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (year != null) 'year': year,
        if (overview != null) 'overview': overview,
        if (genres.isNotEmpty) 'genres': genres,
        if (officialRating != null) 'rating': officialRating,
        if (sourceId != id) 'sourceId': sourceId,
        if (clipStart != null) 'clipStartMs': clipStart!.inMilliseconds,
        if (etag != null) 'etag': etag,
        if (chapters.isNotEmpty) 'chaptersMs': [for (final c in chapters) c.inMilliseconds],
        if (poolIds.isNotEmpty) 'poolIds': poolIds,
      };

  /// Files written before clips, chapters and pools existed load with the
  /// defaults: a whole item, no chapters, no pools.
  factory MediaEntry.fromJson(Map<String, Object?> j) => MediaEntry(
        id: j['id'] as String,
        kind: MediaKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        runtime: Duration(milliseconds: j['runtimeMs'] as int),
        seriesKey: j['seriesKey'] as String?,
        seriesId: j['seriesId'] as String?,
        seriesName: j['seriesName'] as String?,
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        year: j['year'] as int?,
        overview: j['overview'] as String?,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        officialRating: j['rating'] as String?,
        sourceId: j['sourceId'] as String?,
        clipStart: switch (j['clipStartMs']) { final int ms => Duration(milliseconds: ms), _ => null },
        etag: j['etag'] as String?,
        chapters: [
          for (final ms in (j['chaptersMs'] as List? ?? const []).cast<int>()) Duration(milliseconds: ms)
        ],
        poolIds: (j['poolIds'] as List?)?.cast<String>() ?? const [],
      );
}

class SeriesEntry {
  const SeriesEntry({
    required this.key,
    required this.id,
    required this.name,
    this.year,
    this.genres = const [],
    this.officialRating,
    this.hasLogo = false,
  });

  /// Jellyfin can list the same show as several Series items (one per
  /// library folder); `name|year` merges them.
  final String key;

  /// Representative Jellyfin id, used for artwork.
  final String id;
  final String name;
  final int? year;
  final List<String> genres;
  final String? officialRating;
  final bool hasLogo;

  static String keyFor(String name, int? year) => '${name.trim().toLowerCase()}|${year ?? ''}';

  Map<String, Object?> toJson() => {
        'key': key,
        'id': id,
        'name': name,
        if (year != null) 'year': year,
        if (genres.isNotEmpty) 'genres': genres,
        if (officialRating != null) 'rating': officialRating,
        if (hasLogo) 'hasLogo': true,
      };

  factory SeriesEntry.fromJson(Map<String, Object?> j) => SeriesEntry(
        key: j['key'] as String,
        id: j['id'] as String,
        name: j['name'] as String,
        year: j['year'] as int?,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        officialRating: j['rating'] as String?,
        hasLogo: j['hasLogo'] as bool? ?? false,
      );
}

/// Snapshot of the playable parts of the user's libraries.
class LibraryIndex {
  LibraryIndex({
    required this.series,
    required this.episodes,
    required this.movies,
    required this.fetchedAt,
    this.commercials = const [],
  }) : _byId = {for (final e in [...episodes, ...movies, ...commercials]) e.id: e};

  final List<SeriesEntry> series;
  final List<MediaEntry> episodes;
  final List<MediaEntry> movies;

  /// Videos from commercial pools (see [MediaEntry.poolIds]): short ones are
  /// clips, long ones are reels to split. Never part of a channel's own
  /// programming.
  final List<MediaEntry> commercials;
  final DateTime fetchedAt;
  final Map<String, MediaEntry> _byId;

  static final empty =
      LibraryIndex(series: const [], episodes: const [], movies: const [], fetchedAt: DateTime(0));

  bool get isEmpty => episodes.isEmpty && movies.isEmpty;

  /// Only what's rated at most [maxRank] (see [ratingRank]). Episodes go by
  /// their show's rating; anything unrated is left out.
  LibraryIndex restrictedTo(int maxRank) {
    bool allowed(String? rating) {
      final rank = ratingRank(rating);
      return rank != null && rank <= maxRank;
    }

    final shows = {for (final s in series) if (allowed(s.officialRating)) s.key};
    return LibraryIndex(
      series: series.where((s) => shows.contains(s.key)).toList(),
      episodes: episodes.where((e) => shows.contains(e.seriesKey)).toList(),
      movies: movies.where((m) => allowed(m.officialRating)).toList(),
      commercials: commercials,
      fetchedAt: fetchedAt,
    );
  }

  MediaEntry? operator [](String id) => _byId[id];

  late final Map<String, SeriesEntry> seriesByKey = {for (final s in series) s.key: s};

  late final Map<String, List<MediaEntry>> episodesBySeries = () {
    final map = <String, List<MediaEntry>>{};
    for (final e in episodes) {
      map.putIfAbsent(e.seriesKey!, () => []).add(e);
    }
    for (final list in map.values) {
      list.sort(compareEpisodes);
    }
    return map;
  }();

  /// Airing order: season, then episode. Specials (season 0) go last.
  static int compareEpisodes(MediaEntry a, MediaEntry b) {
    int seasonRank(int? s) => s == null || s == 0 ? 1 << 20 : s;
    final bySeason = seasonRank(a.season).compareTo(seasonRank(b.season));
    if (bySeason != 0) return bySeason;
    final byEpisode = (a.episode ?? 1 << 20).compareTo(b.episode ?? 1 << 20);
    return byEpisode != 0 ? byEpisode : a.title.compareTo(b.title);
  }

  Map<String, Object?> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'series': [for (final s in series) s.toJson()],
        'episodes': [for (final e in episodes) e.toJson()],
        'movies': [for (final m in movies) m.toJson()],
        'commercials': [for (final c in commercials) c.toJson()],
      };

  factory LibraryIndex.fromJson(Map<String, Object?> j) => LibraryIndex(
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        series: [
          for (final s in (j['series'] as List).cast<Map<String, Object?>>()) SeriesEntry.fromJson(s)
        ],
        episodes: [
          for (final e in (j['episodes'] as List).cast<Map<String, Object?>>()) MediaEntry.fromJson(e)
        ],
        movies: [
          for (final m in (j['movies'] as List).cast<Map<String, Object?>>()) MediaEntry.fromJson(m)
        ],
        commercials: [
          for (final c in ((j['commercials'] as List?) ?? const []).cast<Map<String, Object?>>())
            MediaEntry.fromJson(c)
        ],
      );

  /// Builds an index from raw Jellyfin item JSON. Pure, so it is unit-testable.
  factory LibraryIndex.fromJellyfinItems({
    required List<Map<String, Object?>> seriesItems,
    required List<Map<String, Object?>> episodeItems,
    required List<Map<String, Object?>> movieItems,
    List<Map<String, Object?>> commercialItems = const [],
    Map<String, List<String>> poolsByItem = const {},
    DateTime? fetchedAt,
  }) {
    // Pool contents never air as programs, wherever their folder is.
    bool inPool(Map<String, Object?> item) => poolsByItem.containsKey(item['Id']);
    final seriesByKey = <String, SeriesEntry>{};
    final keyBySeriesId = <String, String>{};
    for (final s in seriesItems) {
      final name = s['Name'] as String? ?? 'Unknown show';
      final year = s['ProductionYear'] as int?;
      final key = SeriesEntry.keyFor(name, year);
      keyBySeriesId[s['Id'] as String] = key;
      final imageTags = s['ImageTags'] as Map<String, Object?>? ?? const {};
      final existing = seriesByKey[key];
      if (existing != null) {
        // Merge duplicates: union genres, prefer the copy that has a logo.
        final hasLogo = imageTags.containsKey('Logo');
        seriesByKey[key] = SeriesEntry(
          key: key,
          id: !existing.hasLogo && hasLogo ? s['Id'] as String : existing.id,
          name: existing.name,
          year: year,
          genres: {...existing.genres, ..._strings(s['Genres'])}.toList(),
          officialRating: existing.officialRating ?? s['OfficialRating'] as String?,
          hasLogo: existing.hasLogo || hasLogo,
        );
        continue;
      }
      seriesByKey[key] = SeriesEntry(
        key: key,
        id: s['Id'] as String,
        name: name,
        year: year,
        genres: _strings(s['Genres']),
        officialRating: s['OfficialRating'] as String?,
        hasLogo: imageTags.containsKey('Logo'),
      );
    }

    final episodes = <MediaEntry>[];
    final seenEpisodes = <String>{};
    for (final e in episodeItems) {
      final runtime = _runtime(e);
      if (runtime == null || e['LocationType'] == 'Virtual' || inPool(e)) continue;
      final seriesId = e['SeriesId'] as String?;
      final seriesName = e['SeriesName'] as String? ?? 'Unknown show';
      final key = keyBySeriesId[seriesId] ?? SeriesEntry.keyFor(seriesName, null);
      seriesByKey.putIfAbsent(
          key, () => SeriesEntry(key: key, id: seriesId ?? key, name: seriesName));
      final season = e['ParentIndexNumber'] as int?;
      final number = e['IndexNumber'] as int?;
      // The same episode file can show up under duplicate series entries.
      final dedupe = season != null && number != null
          ? '$key|$season|$number'
          : '$key|${e['Name']}';
      if (!seenEpisodes.add(dedupe)) continue;
      episodes.add(MediaEntry(
        id: e['Id'] as String,
        kind: MediaKind.episode,
        title: cleanEpisodeTitle(e['Name'] as String? ?? '', episode: number),
        runtime: runtime,
        seriesKey: key,
        seriesId: seriesId,
        seriesName: seriesByKey[key]!.name,
        season: season,
        episode: number,
        year: e['ProductionYear'] as int?,
        overview: e['Overview'] as String?,
        etag: e['Etag'] as String?,
        chapters: _chapters(e),
      ));
    }

    final movies = <MediaEntry>[];
    final seenMovies = <String>{};
    for (final m in movieItems) {
      final runtime = _runtime(m);
      if (runtime == null || m['LocationType'] == 'Virtual' || inPool(m)) continue;
      final name = m['Name'] as String? ?? 'Movie';
      if (!seenMovies.add('${name.toLowerCase()}|${m['ProductionYear']}')) continue;
      movies.add(MediaEntry(
        id: m['Id'] as String,
        kind: MediaKind.movie,
        title: name,
        runtime: runtime,
        year: m['ProductionYear'] as int?,
        overview: m['Overview'] as String?,
        genres: _strings(m['Genres']),
        officialRating: m['OfficialRating'] as String?,
        etag: m['Etag'] as String?,
        chapters: _chapters(m),
      ));
    }

    final commercials = <MediaEntry>[];
    final seenCommercials = <String>{};
    for (final c in commercialItems) {
      final ticks = c['RunTimeTicks'] as int?;
      if (ticks == null || c['LocationType'] == 'Virtual') continue;
      final runtime = Duration(microseconds: ticks ~/ 10);
      // Anything longer than a clip is a reel, split up by media analysis.
      if (runtime < minClip) continue;
      final id = c['Id'] as String;
      if (!seenCommercials.add(id)) continue;
      commercials.add(MediaEntry(
        id: id,
        kind: MediaKind.commercial,
        title: c['Name'] as String? ?? 'Commercial',
        runtime: runtime,
        year: c['ProductionYear'] as int?,
        etag: c['Etag'] as String?,
        chapters: _chapters(c),
        poolIds: poolsByItem[id] ?? const [],
      ));
    }

    // Drop series with no playable episodes (e.g. only missing-episode stubs).
    final withEpisodes = {for (final e in episodes) e.seriesKey};
    return LibraryIndex(
      series: seriesByKey.values.where((s) => withEpisodes.contains(s.key)).toList(),
      episodes: episodes,
      movies: movies,
      commercials: commercials,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  /// Episodes without metadata are named after their file, e.g.
  /// `The.Loud.House.S01E29E27-Toads.and.Tiaras` → `Toads and Tiaras`.
  static String cleanEpisodeTitle(String raw, {int? episode}) {
    final code = RegExp(r'S\d{1,2}E\d{1,3}(?:-?E\d{1,3})*', caseSensitive: false).firstMatch(raw);
    var title = raw;
    if (code != null) {
      title = raw.substring(code.end);
    } else if (!RegExp(r'\w\.\w+\.\w').hasMatch(raw)) {
      return raw.isEmpty ? (episode != null ? 'Episode $episode' : 'Episode') : raw;
    }
    title = title
        .replaceAll(RegExp(r'\.(mkv|mp4|avi|m4v)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll('+', ' / ')
        .replaceFirst(RegExp(r'^[\s\-–:]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) return episode != null ? 'Episode $episode' : 'Episode';
    return title;
  }

  /// Pool videos shorter than this are ignored.
  static const minClip = Duration(seconds: 5);

  /// Pool videos up to this long are one clip; longer ones are reels.
  static const maxClip = Duration(minutes: 3);

  static List<Duration> _chapters(Map<String, Object?> item) {
    final starts = [
      for (final c in (item['Chapters'] as List? ?? const []).cast<Map<String, Object?>>())
        if (c['StartPositionTicks'] case final int ticks) Duration(milliseconds: ticks ~/ 10000),
    ]..sort();
    return starts;
  }

  static Duration? _runtime(Map<String, Object?> item) {
    final ticks = item['RunTimeTicks'] as int?;
    // Ignore anything under 30 seconds; it's almost always bad metadata.
    if (ticks == null || ticks < 300000000) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  static List<String> _strings(Object? value) =>
      (value as List?)?.cast<String>().toList() ?? const [];
}

/// Downloads the index for every video library the user can see.
///
/// Videos under any of [pools]' folders become commercials (tagged with the
/// pools they're in) and are left out of the programs, even when their
/// folder sits inside a library of shows or movies. A library that is itself
/// a pool folder isn't scanned for programs at all.
Future<LibraryIndex> fetchLibraryIndex(JellyfinClient client,
    {List<CommercialPool> pools = const [],
    void Function(String status)? onStatus,
    void Function(List<JellyfinLibrary> libraries)? onLibraries}) async {
  final libraries = (await client.libraries()).where((l) => l.isVideo).toList();
  onLibraries?.call(libraries);
  final poolsByItem = <String, List<String>>{};
  final commercials = <String, Map<String, Object?>>{};
  final poolRoots = <String>{};
  for (final pool in pools) {
    for (final root in pool.roots) {
      poolRoots.add(root.itemId);
      onStatus?.call('Scanning ${pool.name}…');
      final items = await client.allItems({
        'ParentId': root.itemId,
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Trailer',
        'IsMissing': 'false',
        'Fields': 'Chapters,Etag',
        'EnableImages': 'false',
        'EnableUserData': 'false',
      });
      for (final item in items) {
        final id = item['Id'] as String;
        commercials[id] = item;
        final ids = poolsByItem.putIfAbsent(id, () => []);
        if (!ids.contains(pool.id)) ids.add(pool.id);
      }
    }
  }
  final series = <Map<String, Object?>>[];
  final episodes = <Map<String, Object?>>[];
  final movies = <Map<String, Object?>>[];
  for (final lib in libraries) {
    if (poolRoots.contains(lib.id)) continue;
    onStatus?.call('Scanning ${lib.name}…');
    final common = {'ParentId': lib.id, 'Recursive': 'true', 'ImageTypeLimit': 1};
    series.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'Series',
      'Fields': 'Genres,OfficialRating',
    }));
    episodes.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'Episode',
      'IsMissing': 'false',
      'Fields': 'Overview,Chapters,Etag',
      'EnableImages': 'false',
      'EnableUserData': 'false',
    }));
    movies.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'Movie',
      'Fields': 'Overview,Genres,OfficialRating,Chapters,Etag',
      'EnableImages': 'false',
      'EnableUserData': 'false',
    }));
  }
  return LibraryIndex.fromJellyfinItems(
    seriesItems: series,
    episodeItems: episodes,
    movieItems: movies,
    commercialItems: commercials.values.toList(),
    poolsByItem: poolsByItem,
  );
}
