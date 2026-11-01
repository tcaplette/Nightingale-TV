import '../commercials/commercial_pool.dart';
import '../server/media_server.dart';
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

/// Another server's copy of a [MediaEntry] (multi-server): what playing it
/// needs. Its [id] is a global id (see `ServerSet`).
class MediaCopy {
  const MediaCopy({required this.id, String? sourceId, this.streamPath, this.etag, this.size})
      : sourceId = sourceId ?? id;

  final String id;
  final String sourceId;
  final String? streamPath;
  final String? etag;
  final int? size;

  Map<String, Object?> toJson() => {
        'id': id,
        if (sourceId != id) 'sourceId': sourceId,
        if (streamPath != null) 'streamPath': streamPath,
        if (etag != null) 'etag': etag,
        if (size != null) 'size': size,
      };

  factory MediaCopy.fromJson(Map<String, Object?> j) => MediaCopy(
        id: j['id'] as String,
        sourceId: j['sourceId'] as String?,
        streamPath: j['streamPath'] as String?,
        etag: j['etag'] as String?,
        size: j['size'] as int?,
      );
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
    this.streamPath,
    this.playCount = 0,
    this.providerIds = const [],
    this.alternates = const [],
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

  /// Plex only: the file's part path (`/library/parts/…`), which Plex can't
  /// build from the id. Null on Jellyfin and Emby.
  final String? streamPath;

  /// Episodes and movies: how many times the profile's user played it on
  /// the server, as of the last scan (Least watched first).
  final int playCount;

  /// The title's ids at metadata providers (`tvdb:123`, `tmdb:45`,
  /// `imdb:tt0088763`), only scanned when the profile has several servers:
  /// they decide which copies are the same title (multi-server D4).
  final List<String> providerIds;

  /// The same title's copies on other servers (multi-server), in Play from
  /// order as of the merge; empty with one server.
  final List<MediaCopy> alternates;

  /// This entry's own copy.
  MediaCopy get copy => MediaCopy(id: id, sourceId: sourceId, streamPath: streamPath, etag: etag, size: size);

  /// Every copy: this entry's own first, then [alternates].
  List<MediaCopy> get copies => [copy, ...alternates];

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

  /// This entry as merged from several servers' copies: [primary] is the
  /// copy whose id it keeps.
  MediaEntry merged({
    required MediaCopy primary,
    required List<MediaCopy> alternates,
    required int playCount,
    DateTime? added,
    List<String>? providerIds,
  }) =>
      _copy(primary: primary, alternates: alternates, playCount: playCount, added: added, providerIds: providerIds);

  /// A copy under another show key (multi-server, see [SeriesEntry.withKey]).
  MediaEntry withSeriesKey(String key) => MediaEntry(
        id: id, kind: kind, title: title, runtime: runtime, seriesKey: key, seriesId: seriesId, seriesName: seriesName,
        season: season, episode: episode, year: year, overview: overview, genres: genres, officialRating: officialRating,
        sourceId: sourceId, clipStart: clipStart, etag: etag, container: container, size: size, chapters: chapters,
        poolIds: poolIds, artist: artist, album: album, albumId: albumId, added: added, availableAt: availableAt,
        streamPath: streamPath, playCount: playCount, providerIds: providerIds, alternates: alternates);

  /// This entry as its copy [c] (multi-server): what playing that copy
  /// needs, with the rest of the entry's details.
  MediaEntry asCopy(MediaCopy c) => c.id == id ? this : _copy(primary: c, alternates: const []);

  /// A copy with every id rewritten by [id] (an added server's key prefix).
  MediaEntry withIds(String Function(String id) id) => _copy(
        primary: MediaCopy(id: id(this.id), sourceId: id(sourceId), streamPath: streamPath, etag: etag, size: size),
        seriesId: seriesId == null ? null : id(seriesId!),
        albumId: albumId == null ? null : id(albumId!),
        alternates: [
          for (final a in alternates)
            MediaCopy(id: id(a.id), sourceId: id(a.sourceId), streamPath: a.streamPath, etag: a.etag, size: a.size)
        ],
      );

  MediaEntry _copy(
          {List<String>? poolIds,
          DateTime? availableAt,
          bool clearAvailableAt = false,
          MediaCopy? primary,
          List<MediaCopy>? alternates,
          int? playCount,
          DateTime? added,
          List<String>? providerIds,
          String? seriesId,
          String? albumId}) =>
      MediaEntry(
        id: primary?.id ?? id,
        kind: kind,
        title: title,
        runtime: runtime,
        seriesKey: seriesKey,
        seriesId: seriesId ?? this.seriesId,
        seriesName: seriesName,
        season: season,
        episode: episode,
        year: year,
        overview: overview,
        genres: genres,
        officialRating: officialRating,
        sourceId: primary?.sourceId ?? sourceId,
        clipStart: clipStart,
        etag: primary == null ? etag : primary.etag,
        container: container,
        size: primary == null ? size : primary.size,
        chapters: chapters,
        poolIds: poolIds ?? this.poolIds,
        artist: artist,
        album: album,
        albumId: albumId ?? this.albumId,
        added: added ?? this.added,
        availableAt: clearAvailableAt ? null : availableAt ?? this.availableAt,
        streamPath: primary == null ? streamPath : primary.streamPath,
        playCount: playCount ?? this.playCount,
        providerIds: providerIds ?? this.providerIds,
        alternates: alternates ?? this.alternates,
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
        if (streamPath != null) 'streamPath': streamPath,
        if (playCount != 0) 'plays': playCount,
        if (providerIds.isNotEmpty) 'providerIds': providerIds,
        if (alternates.isNotEmpty) 'alternates': [for (final a in alternates) a.toJson()],
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
        streamPath: j['streamPath'] as String?,
        playCount: j['plays'] as int? ?? 0,
        providerIds: (j['providerIds'] as List?)?.cast<String>() ?? const [],
        alternates: [
          for (final a in (j['alternates'] as List? ?? const []).cast<Map<String, Object?>>()) MediaCopy.fromJson(a)
        ],
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

  /// A copy under another [key] (multi-server: the same show, its year known
  /// on another server).
  SeriesEntry withKey(String key) => SeriesEntry(
      key: key, id: id, name: name, year: year, genres: genres, officialRating: officialRating, hasLogo: hasLogo);

  /// A copy with another artwork [id] (multi-server).
  SeriesEntry withId(String id, {bool? hasLogo, List<String>? genres}) => SeriesEntry(
        key: key,
        id: id,
        name: name,
        year: year,
        genres: genres ?? this.genres,
        officialRating: officialRating,
        hasLogo: hasLogo ?? this.hasLogo,
      );

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
    this.rootsByItem = const {},
    this.roots = const {},
    this.missingRoots = const {},
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

  /// The channel and block source roots (see [ChannelSource.roots]) each
  /// episode or movie is under, by item id (custom-channels D3).
  final Map<String, List<String>> rootsByItem;

  /// The roots resolved into [rootsByItem]; a root not in it hasn't been
  /// asked about yet (added since, or saved before roots existed).
  final Set<String> roots;

  /// Resolved roots the server had nothing under, or no longer has.
  final Set<String> missingRoots;
  final DateTime fetchedAt;
  final Map<String, MediaEntry> _byId;

  /// The episodes and movies under each root, in no order.
  late final Map<String, Set<String>> itemsByRoot = () {
    final map = <String, Set<String>>{};
    rootsByItem.forEach((id, roots) {
      for (final r in roots) {
        map.putIfAbsent(r, () => {}).add(id);
      }
    });
    return map;
  }();

  /// This index with [found] (the programs under each of [resolved]'s
  /// roots) merged in: those roots' old membership is replaced.
  LibraryIndex withRoots(Map<String, Set<String>> found, {Set<String> missing = const {}}) {
    final resolved = found.keys.toSet();
    final byItem = <String, List<String>>{
      for (final e in rootsByItem.entries)
        if (e.value.where((r) => !resolved.contains(r)).toList() case final keep when keep.isNotEmpty) e.key: keep,
    };
    found.forEach((root, ids) {
      for (final copy in ids) {
        // Another server's copy counts for the entry holding it.
        final id = primaryIdOf(copy);
        final kind = this[id]?.kind;
        if (kind != MediaKind.episode && kind != MediaKind.movie) continue;
        final list = byItem.putIfAbsent(id, () => []);
        if (!list.contains(root)) list.add(root);
      }
    });
    return _with(
      rootsByItem: byItem,
      roots: {...roots, ...resolved},
      missingRoots: {...missingRoots.difference(resolved), ...missing},
    );
  }

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
    final kept = [
      ...episodes.where((e) => shows.contains(e.seriesKey)),
      ...movies.where((m) => allowed(m.officialRating)),
    ];
    final keptIds = {for (final e in kept) e.id};
    return LibraryIndex(
      series: series.where((s) => shows.contains(s.key)).toList(),
      episodes: [for (final e in kept) if (e.kind == MediaKind.episode) e],
      movies: [for (final m in kept) if (m.kind == MediaKind.movie) m],
      commercials: commercials,
      songs: songs.where((m) => allowed(m.officialRating)).toList(),
      musicVideos: musicVideos.where((m) => allowed(m.officialRating)).toList(),
      fetchedAt: fetchedAt,
      // Whatever a root holds, nothing over the limit plays (D15).
      rootsByItem: {
        for (final e in rootsByItem.entries)
          if (keptIds.contains(e.key)) e.key: e.value,
      },
      roots: roots,
      missingRoots: missingRoots,
    );
  }

  /// A copy with other root membership.
  LibraryIndex _with({Map<String, List<String>>? rootsByItem, Set<String>? roots, Set<String>? missingRoots}) =>
      LibraryIndex(
        series: series,
        episodes: episodes,
        movies: movies,
        commercials: commercials,
        songs: songs,
        musicVideos: musicVideos,
        fetchedAt: fetchedAt,
        rootsByItem: rootsByItem ?? this.rootsByItem,
        roots: roots ?? this.roots,
        missingRoots: missingRoots ?? this.missingRoots,
      );

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
      rootsByItem: rootsByItem,
      roots: roots,
      missingRoots: missingRoots,
    );
  }

  MediaEntry? operator [](String id) => _byId[id];

  /// Every copy by its id, alternates included (multi-server): what a
  /// server's client looks its own items up by.
  late final Map<String, MediaCopy> _copies = {
    for (final e in _byId.values)
      for (final c in e.copies) c.id: c,
  };

  /// The copy with [id], whichever entry holds it.
  MediaCopy? copyById(String id) => _copies[id];

  late final Map<String, String> _primaryOf = {
    for (final e in _byId.values)
      for (final a in e.alternates) a.id: e.id,
  };

  /// The id of the entry holding copy [id] ([id] itself for an entry's own).
  String primaryIdOf(String id) => _primaryOf[id] ?? id;

  /// This index with every id rewritten as an added server's (multi-server
  /// D2): [prefix] gives the global id for one of the server's own ids.
  LibraryIndex withServerKey(String Function(String id) prefix) => LibraryIndex(
        series: [for (final s in series) s.withId(prefix(s.id))],
        episodes: [for (final e in episodes) e.withIds(prefix)],
        movies: [for (final e in movies) e.withIds(prefix)],
        commercials: [for (final e in commercials) e.withIds(prefix)],
        songs: [for (final e in songs) e.withIds(prefix)],
        musicVideos: [for (final e in musicVideos) e.withIds(prefix)],
        fetchedAt: fetchedAt,
        rootsByItem: {
          for (final e in rootsByItem.entries) prefix(e.key): [for (final r in e.value) prefix(r)],
        },
        roots: {for (final r in roots) prefix(r)},
        missingRoots: {for (final r in missingRoots) prefix(r)},
      );

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
        if (roots.isNotEmpty) 'roots': roots.toList(),
        if (missingRoots.isNotEmpty) 'missingRoots': missingRoots.toList(),
        if (rootsByItem.isNotEmpty) 'rootsByItem': rootsByItem,
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
        rootsByItem: {
          for (final e in ((j['rootsByItem'] as Map?) ?? const {}).cast<String, Object?>().entries)
            e.key: (e.value as List).cast<String>(),
        },
        roots: {...((j['roots'] as List?) ?? const []).cast<String>()},
        missingRoots: {...((j['missingRoots'] as List?) ?? const []).cast<String>()},
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
        playCount: _playCount(e),
        providerIds: providerIdsOf(e['ProviderIds']),
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
        playCount: _playCount(m),
        providerIds: providerIdsOf(m['ProviderIds']),
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

  /// The providers whose ids name a title, as `tvdb:…`.
  static const providers = {'tvdb', 'tmdb', 'imdb'};

  /// Jellyfin's and Emby's `ProviderIds` (`{"Tvdb": "123"}`) as `tvdb:123`,
  /// only [providers]' ids.
  static List<String> providerIdsOf(Object? json) => [
        if (json is Map)
          for (final e in json.entries)
            if (providers.contains('${e.key}'.toLowerCase()) && '${e.value}'.trim().isNotEmpty)
              '${'${e.key}'.toLowerCase()}:${'${e.value}'.trim()}',
      ];

  /// The user's play count, from `UserData` (absent: never played). Marked
  /// played by hand, an item has no count on Emby, but it has been watched.
  static int _playCount(Map<String, Object?> item) {
    final data = item['UserData'] as Map<String, Object?>?;
    final count = (data?['PlayCount'] as num?)?.toInt() ?? 0;
    return count == 0 && data?['Played'] == true ? 1 : count;
  }

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

/// Downloads the index for every video and music library the user can see
/// on [client]'s server (see [MediaServer.fetchLibraryIndex]).
Future<LibraryIndex> fetchLibraryIndex(MediaServer client,
        {List<CommercialPool> pools = const [],
        Set<String> channelRoots = const {},
        bool providerIds = false,
        void Function(String status)? onStatus,
        void Function(List<ServerLibrary> libraries)? onLibraries}) =>
    client.fetchLibraryIndex(
        pools: pools,
        channelRoots: channelRoots,
        providerIds: providerIds,
        onStatus: onStatus,
        onLibraries: onLibraries);

/// The programs under each of [roots] on [client]'s server, for
/// [LibraryIndex.withRoots]: each root once, its ids only. A root the
/// server doesn't have, or has nothing under, is in `missing`.
Future<({Map<String, Set<String>> found, Set<String> missing})> fetchRoots(MediaServer client, Iterable<String> roots,
    {void Function(String status)? onStatus}) async {
  final found = <String, Set<String>>{};
  final missing = <String>{};
  for (final root in {...roots}) {
    List<String> ids;
    try {
      ids = await client.idsUnder(root);
    } on ServerException catch (e) {
      // Gone from the server (deleted, or another user's).
      if (e.statusCode != 400 && e.statusCode != 404) rethrow;
      ids = const [];
    }
    found[root] = ids.toSet();
    if (ids.isEmpty) missing.add(root);
  }
  return (found: found, missing: missing);
}
