import '../commercials/commercial_pool.dart';
import '../jellyfin/jellyfin_client.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/profile.dart';

enum MediaKind {
  episode,
  movie,

  /// A commercial, bumper or station ident from a commercials library.
  commercial,

  /// An audio track from a music library.
  song,

  /// A music video from a video library.
  musicVideo,
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
    this.container,
    this.size,
    this.chapters = const [],
    this.poolIds = const [],
    this.artist,
    this.album,
    this.albumId,
    this.added,
    this.availableAt,
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

  /// The file's container (mp4, mkv, …) and size in bytes, when Jellyfin
  /// said (the index cache's key; libraries saved before don't have them).
  final String? container;
  final int? size;

  /// Chapter start times, in order.
  final List<Duration> chapters;

  /// The commercial pools this item belongs to (commercials only).
  final List<String> poolIds;

  /// Songs and music videos: the first listed artist, else the album
  /// artist; the album and its Jellyfin id (for the album art).
  final String? artist;
  final String? album;
  final String? albumId;

  /// When Jellyfin added the item (episodes; Jellyfin's DateCreated).
  final DateTime? added;

  /// Episodes: when this profile could first know about the item, so a
  /// scan never changes a premiere airing already under way (see
  /// [LibraryIndex.withAvailability]). Null until a scan assigns it.
  final DateTime? availableAt;

  /// A song or a music video.
  bool get isMusic => kind == MediaKind.song || kind == MediaKind.musicVideo;

  /// A clip cut from a longer video, rather than a whole Jellyfin item.
  bool get isClip => clipStart != null;

  /// Position in [sourceId] where this entry's own time starts.
  Duration get sourceStart => clipStart ?? Duration.zero;

  /// A copy with a different [poolIds].
  MediaEntry withPools(List<String> pools) => _copy(poolIds: pools);

  /// A copy with a different [availableAt].
  MediaEntry withAvailableAt(DateTime? at) => _copy(availableAt: at, clearAvailableAt: at == null);

  MediaEntry _copy({List<String>? poolIds, DateTime? availableAt, bool clearAvailableAt = false}) => MediaEntry(
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
        container: container,
        size: size,
        chapters: chapters,
        poolIds: poolIds ?? this.poolIds,
        artist: artist,
        album: album,
        albumId: albumId,
        added: added,
        availableAt: clearAvailableAt ? null : availableAt ?? this.availableAt,
      );

  /// Title shown in the guide: the show name for episodes, "Artist – Song"
  /// for music.
  String get guideTitle => switch (kind) {
        MediaKind.episode => seriesName ?? title,
        MediaKind.song || MediaKind.musicVideo => artist == null ? title : '$artist – $title',
        _ => title,
      };

  /// "S3 · E12 · Episode title" for episodes, year for movies, "Album ·
  /// Year" for music.
  String get subtitle {
    if (kind == MediaKind.commercial) return 'Commercial';
    if (kind == MediaKind.movie) return year != null ? 'Movie · $year' : 'Movie';
    if (isMusic) {
      final parts = [album ?? (kind == MediaKind.musicVideo ? 'Music video' : null), ?year?.toString()];
      return parts.whereType<String>().join(' · ');
    }
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
        if (container != null) 'container': container,
        if (size != null) 'size': size,
        if (chapters.isNotEmpty) 'chaptersMs': [for (final c in chapters) c.inMilliseconds],
        if (poolIds.isNotEmpty) 'poolIds': poolIds,
        if (artist != null) 'artist': artist,
        if (album != null) 'album': album,
        if (albumId != null) 'albumId': albumId,
        if (added != null) 'added': added!.toUtc().toIso8601String(),
        if (availableAt != null) 'availableAt': availableAt!.toUtc().toIso8601String(),
      };

  /// Files written before clips, chapters, pools, music and premieres
  /// existed load with the defaults: a whole item, no chapters, no pools, no
  /// artist or album, and no added or available times.
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
        container: j['container'] as String?,
        size: j['size'] as int?,
        chapters: [
          for (final ms in (j['chaptersMs'] as List? ?? const []).cast<int>()) Duration(milliseconds: ms)
        ],
        poolIds: (j['poolIds'] as List?)?.cast<String>() ?? const [],
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        albumId: j['albumId'] as String?,
        added: _time(j['added']),
        availableAt: _time(j['availableAt']),
      );

  static DateTime? _time(Object? s) => s is String ? DateTime.tryParse(s)?.toLocal() : null;
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
    this.songs = const [],
    this.musicVideos = const [],
  }) : _byId = {for (final e in [...episodes, ...movies, ...commercials, ...songs, ...musicVideos]) e.id: e};

  final List<SeriesEntry> series;
  final List<MediaEntry> episodes;
  final List<MediaEntry> movies;

  /// Videos from commercial pools (see [MediaEntry.poolIds]): short ones are
  /// clips, long ones are reels to split. Never part of a channel's own
  /// programming.
  final List<MediaEntry> commercials;

  /// Songs from music libraries, and music videos from video libraries.
  final List<MediaEntry> songs;
  final List<MediaEntry> musicVideos;
  final DateTime fetchedAt;
  final Map<String, MediaEntry> _byId;

  static final empty =
      LibraryIndex(series: const [], episodes: const [], movies: const [], fetchedAt: DateTime(0));

  bool get isEmpty => episodes.isEmpty && movies.isEmpty && songs.isEmpty && musicVideos.isEmpty;

  /// Only what's rated at most [maxRank] (see [ratingRank]). Episodes go by
  /// their show's rating; anything unrated is left out, music included.
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
      songs: songs.where((m) => allowed(m.officialRating)).toList(),
      musicVideos: musicVideos.where((m) => allowed(m.officialRating)).toList(),
      fetchedAt: fetchedAt,
    );
  }

  /// This index with each episode's [MediaEntry.availableAt] set from
  /// [previous] (the index this profile had before this scan, null on its
  /// first scan), as of [scanTime]:
  /// - first scan: when Jellyfin added it;
  /// - an episode [previous] had a time for keeps it;
  /// - any other: the later of when it was added and [scanTime].
  ///
  /// So a premiere airing never gains an episode after it started.
  LibraryIndex withAvailability(LibraryIndex? previous, DateTime scanTime) {
    DateTime? availableAt(MediaEntry e) {
      final added = e.added;
      if (previous == null) return added ?? scanTime;
      final known = previous[e.id]?.availableAt;
      if (known != null) return known;
      if (added == null) return scanTime;
      return added.isAfter(scanTime) ? added : scanTime;
    }

    return LibraryIndex(
      series: series,
      episodes: [for (final e in episodes) e.withAvailableAt(availableAt(e))],
      movies: movies,
      commercials: commercials,
      songs: songs,
      musicVideos: musicVideos,
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
        'songs': [for (final m in songs) m.toJson()],
        'musicVideos': [for (final m in musicVideos) m.toJson()],
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
        songs: [
          for (final m in ((j['songs'] as List?) ?? const []).cast<Map<String, Object?>>()) MediaEntry.fromJson(m)
        ],
        musicVideos: [
          for (final m in ((j['musicVideos'] as List?) ?? const []).cast<Map<String, Object?>>())
            MediaEntry.fromJson(m)
        ],
      );

  /// Builds an index from raw Jellyfin item JSON. Pure, so it is unit-testable.
  factory LibraryIndex.fromJellyfinItems({
    required List<Map<String, Object?>> seriesItems,
    required List<Map<String, Object?>> episodeItems,
    required List<Map<String, Object?>> movieItems,
    List<Map<String, Object?>> commercialItems = const [],
    List<Map<String, Object?>> songItems = const [],
    List<Map<String, Object?>> musicVideoItems = const [],
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
        container: _container(e),
        size: _size(e),
        chapters: _chapters(e),
        added: _date(e['DateCreated']),
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
        container: _container(m),
        size: _size(m),
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
        container: _container(c),
        size: _size(c),
        chapters: _chapters(c),
        poolIds: poolsByItem[id] ?? const [],
      ));
    }

    List<MediaEntry> music(List<Map<String, Object?>> items, MediaKind kind) {
      final result = <MediaEntry>[];
      final seen = <String>{};
      for (final m in items) {
        final ticks = m['RunTimeTicks'] as int?;
        if (ticks == null || ticks <= 0 || m['LocationType'] == 'Virtual' || inPool(m)) continue;
        final id = m['Id'] as String;
        if (!seen.add(id)) continue;
        final artists = _strings(m['Artists']);
        final name = m['Name'] as String? ?? (kind == MediaKind.song ? 'Song' : 'Music video');
        final tagged = artists.isNotEmpty ? artists.first : m['AlbumArtist'] as String?;
        // Untagged downloads are often named "Artist - Title [id]".
        final named = tagged == null ? splitMusicName(name) : null;
        result.add(MediaEntry(
          id: id,
          kind: kind,
          title: named?.title ?? name,
          runtime: Duration(microseconds: ticks ~/ 10),
          year: m['ProductionYear'] as int?,
          genres: _strings(m['Genres']),
          officialRating: m['OfficialRating'] as String?,
          etag: m['Etag'] as String?,
          container: _container(m),
          size: _size(m),
          artist: tagged ?? named?.artist,
          album: m['Album'] as String?,
          albumId: m['AlbumId'] as String?,
        ));
      }
      return result;
    }

    // Drop series with no playable episodes (e.g. only missing-episode stubs).
    final withEpisodes = {for (final e in episodes) e.seriesKey};
    return LibraryIndex(
      series: seriesByKey.values.where((s) => withEpisodes.contains(s.key)).toList(),
      episodes: episodes,
      movies: movies,
      commercials: commercials,
      songs: music(songItems, MediaKind.song),
      musicVideos: music(musicVideoItems, MediaKind.musicVideo),
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  static DateTime? _date(Object? s) => s is String ? DateTime.tryParse(s)?.toLocal() : null;

  /// "Len - Steal My Sunshine (Official Video) [E1fzJ_AYajA]" → (artist:
  /// "Len", title: "Steal My Sunshine"): the artist and a clean title from an
  /// untagged file's name, or null when it isn't "Artist - Title".
  static ({String artist, String title})? splitMusicName(String name) {
    final m = RegExp(r'^\s*(.+?)\s+[-–—]\s+(.+?)\s*$').firstMatch(name);
    if (m == null) return null;
    var title = m.group(2)!;
    // Video ids at the end, and "(Official Music Video)"-style notes anywhere.
    final note = RegExp(r'\s*[\[(][^\])]*(official|video|audio|lyric|hd|hq|4k|remaster|upgrade|visuali[sz]er)[^\])]*[\])]',
        caseSensitive: false);
    title = title
        .replaceFirst(RegExp(r'\s*\[[A-Za-z0-9_-]{6,}\]\s*$'), '')
        .replaceAll(note, '')
        .replaceAll(RegExp(r'\s+'), ' ');
    title = title.trim();
    final artist = m.group(1)!.trim();
    if (title.isEmpty || artist.isEmpty) return null;
    return (artist: artist, title: title);
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

  /// The container Jellyfin reports for [item] ("mkv", "mov,mp4,m4a,…").
  static String? _container(Map<String, Object?> item) => item['Container'] as String?;

  /// The file size of [item]'s first media source, when Jellyfin sent it.
  static int? _size(Map<String, Object?> item) => switch (item['MediaSources']) {
        [final Map<String, Object?> source, ...] => (source['Size'] as num?)?.toInt(),
        _ => null,
      };

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

/// Downloads the index for every video and music library the user can see:
/// shows, episodes and movies, plus music videos from the video libraries
/// and songs from the music libraries.
///
/// Videos under any of [pools]' folders become commercials (tagged with the
/// pools they're in) and are left out of the programs, even when their
/// folder sits inside a library of shows or movies. A library that is itself
/// a pool folder isn't scanned for programs at all.
Future<LibraryIndex> fetchLibraryIndex(JellyfinClient client,
    {List<CommercialPool> pools = const [],
    void Function(String status)? onStatus,
    void Function(List<JellyfinLibrary> libraries)? onLibraries}) async {
  final libraries = (await client.libraries()).where((l) => l.isVideo || l.isMusic).toList();
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
  final songs = <Map<String, Object?>>[];
  final musicVideos = <Map<String, Object?>>[];
  // Minimal fields and no images: music libraries can hold 50,000 songs.
  const musicFields = 'Genres,ProductionYear,Artists,AlbumArtist,Album,AlbumId,OfficialRating,Etag,MediaSources';
  for (final lib in libraries) {
    if (poolRoots.contains(lib.id)) continue;
    onStatus?.call('Scanning ${lib.name}…');
    final scanStart = DateTime.now();
    final common = {'ParentId': lib.id, 'Recursive': 'true', 'ImageTypeLimit': 1};
    if (lib.isMusic) {
      songs.addAll(await client.allItems({
        ...common,
        'IncludeItemTypes': 'Audio',
        'IsMissing': 'false',
        'Fields': musicFields,
        'EnableImages': 'false',
        'EnableUserData': 'false',
      }));
      PlaybackDiagnostics.note('SCAN', '${lib.name}: ${songs.length} songs so far, '
          '${DateTime.now().difference(scanStart).inMilliseconds} ms');
      continue;
    }
    series.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'Series',
      'Fields': 'Genres,OfficialRating',
    }));
    episodes.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'Episode',
      'IsMissing': 'false',
      'Fields': 'Overview,Chapters,Etag,DateCreated',
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
    musicVideos.addAll(await client.allItems({
      ...common,
      'IncludeItemTypes': 'MusicVideo',
      'IsMissing': 'false',
      'Fields': musicFields,
      'EnableImages': 'false',
      'EnableUserData': 'false',
    }));
    PlaybackDiagnostics.note('SCAN', '${lib.name}: ${DateTime.now().difference(scanStart).inMilliseconds} ms');
  }
  return LibraryIndex.fromJellyfinItems(
    seriesItems: series,
    episodeItems: episodes,
    movieItems: movies,
    commercialItems: commercials.values.toList(),
    songItems: songs,
    musicVideoItems: musicVideos,
    poolsByItem: poolsByItem,
  );
}
