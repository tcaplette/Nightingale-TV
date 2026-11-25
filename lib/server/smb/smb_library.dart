import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'smb_names.dart';
import 'smb_nfo.dart';
import 'smb_share.dart';

/// What a mapped folder holds (smb-sources, "Mapping folders to content
/// types").
enum SmbFolderType {
  tvShows('tvshows'),
  movies('movies'),
  music('music'),
  musicVideos('musicvideos'),
  homeVideos('homevideos'),
  commercials('homevideos'),
  bumpers('homevideos');

  const SmbFolderType(this.collectionType);

  /// In Jellyfin's terms (`ServerLibrary.collectionType`).
  final String collectionType;

  /// Its files fill breaks, and never air as programs.
  bool get isPool => this == commercials || this == bumpers;

  static SmbFolderType? fromName(Object? name) => values.where((t) => t.name == name).firstOrNull;

  /// The type a folder's name usually means; null for no suggestion.
  static SmbFolderType? suggested(String folder) {
    final n = folder.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
    bool any(Iterable<String> names) => names.contains(n);
    if (any(const ['commercials', 'commercial', 'ads', 'adverts', 'advertisements', 'tv commercials', 'retro commercials'])) return commercials;
    if (any(const ['bumpers', 'bumper', 'idents', 'station idents', 'station ids', 'interstitials'])) return bumpers;
    if (any(const ['music videos', 'musicvideos', 'music video', 'mvs'])) return musicVideos;
    if (any(const ['home videos', 'homevideos', 'home movies', 'family videos', 'home video', 'camcorder', 'personal videos'])) return homeVideos;
    if (any(const ['tv', 'tv shows', 'tvshows', 'shows', 'series', 'tv series', 'television', 'serien', 'séries', 'anime', 'cartoons', 'kids tv'])) {
      return tvShows;
    }
    if (any(const ['movies', 'movie', 'films', 'film', 'filme', 'peliculas', 'películas', 'kids movies', '4k movies', 'movies 4k'])) return movies;
    if (any(const ['music', 'musik', 'musique', 'música', 'musica', 'songs', 'albums'])) return music;
    return null;
  }
}

/// One mapped folder, by its path in the share (`''` is all of it).
class SmbMapping {
  const SmbMapping(this.path, this.type);

  final String path;
  final SmbFolderType type;

  Map<String, Object?> toJson() => {'path': path, 'type': type.name};

  static SmbMapping? fromJson(Object? j) => switch (j) {
        {'path': final String path, 'type': final Object? type} =>
          SmbFolderType.fromName(type) == null ? null : SmbMapping(path, SmbFolderType.fromName(type)!),
        _ => null,
      };

  @override
  bool operator ==(Object other) => other is SmbMapping && other.path == path && other.type == type;

  @override
  int get hashCode => Object.hash(path, type);
}

/// The id of the file or folder at [path] (design D4): the same on every
/// device, and saying nothing of the path.
String smbIdOf(String path) => sha256.convert(utf8.encode(path)).toString().substring(0, 20);

/// Whether [path] is [folder] or inside it.
bool smbInside(String path, String folder) => folder.isEmpty || path == folder || path.startsWith('$folder/');

/// A subtitle file beside a video.
class SmbSubtitleFile {
  const SmbSubtitleFile({required this.path, required this.size, required this.modified, required this.name});

  final String path;
  final int size;
  final int modified;
  final SmbSubtitleName name;

  Map<String, Object?> toJson() => {
        'path': path,
        'size': size,
        'm': modified,
        'codec': name.codec,
        'lang': ?name.language,
        'tag': ?name.tag,
        'title': ?name.title,
        if (name.forced) 'forced': true,
        if (name.isDefault) 'default': true,
      };

  factory SmbSubtitleFile.fromJson(Map<String, Object?> j) => SmbSubtitleFile(
        path: j['path'] as String,
        size: j['size'] as int? ?? 0,
        modified: j['m'] as int? ?? 0,
        name: SmbSubtitleName(
          codec: j['codec'] as String,
          language: j['lang'] as String?,
          tag: j['tag'] as String?,
          title: j['title'] as String?,
          forced: j['forced'] == true,
          isDefault: j['default'] == true,
        ),
      );
}

/// An image file.
class SmbImage {
  const SmbImage(this.path, this.size, this.modified);

  final String path;
  final int size;
  final int modified;

  String get id => smbIdOf(path);

  List<Object?> toJson() => [path, size, modified];

  static SmbImage? fromJson(Object? j) => switch (j) {
        [final String path, final int size, final int modified] => SmbImage(path, size, modified),
        _ => null,
      };
}

/// A show of a share: a folder, or the name files of a folder share.
class SmbShow {
  const SmbShow({
    required this.id,
    required this.name,
    this.year,
    this.ids = const [],
    this.genres = const [],
    this.rating,
    this.poster,
    this.logo,
    this.home = false,
  });

  final String id;
  final String name;
  final int? year;
  final List<String> ids;
  final List<String> genres;
  final String? rating;
  final SmbImage? poster;
  final SmbImage? logo;

  /// A folder of home videos.
  final bool home;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'year': ?year,
        if (ids.isNotEmpty) 'ids': ids,
        if (genres.isNotEmpty) 'genres': genres,
        'rating': ?rating,
        'poster': ?poster?.toJson(),
        'logo': ?logo?.toJson(),
        if (home) 'home': true,
      };

  factory SmbShow.fromJson(Map<String, Object?> j) => SmbShow(
        id: j['id'] as String,
        name: j['name'] as String,
        year: j['year'] as int?,
        ids: (j['ids'] as List?)?.cast<String>() ?? const [],
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        rating: j['rating'] as String?,
        poster: SmbImage.fromJson(j['poster']),
        logo: SmbImage.fromJson(j['logo']),
        home: j['home'] == true,
      );
}

/// A video or song of a share, as its names and `.nfo` describe it.
class SmbItem {
  const SmbItem({
    required this.id,
    required this.path,
    required this.type,
    required this.size,
    required this.modified,
    required this.title,
    this.created,
    this.showId,
    this.season,
    this.episode,
    this.year,
    this.plot,
    this.genres = const [],
    this.rating,
    this.ids = const [],
    this.runtime,
    this.poster,
    this.subtitles = const [],
    this.artist,
    this.album,
    this.albumId,
  });

  final String id;
  final String path;
  final SmbFolderType type;
  final int size;

  /// Milliseconds since the epoch.
  final int modified;
  final int? created;
  final String title;
  final String? showId;
  final int? season;
  final int? episode;
  final int? year;
  final String? plot;
  final List<String> genres;
  final String? rating;
  final List<String> ids;

  /// What its `.nfo` says it lasts, used until the file is read.
  final Duration? runtime;
  final SmbImage? poster;
  final List<SmbSubtitleFile> subtitles;
  final String? artist;
  final String? album;
  final String? albumId;

  String get name => path.split('/').last;
  String get folder => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
  String get container => SmbNames.extension(name);
  String get etag => '$size-$modified';

  SmbItem withId(String id) => SmbItem(
      id: id, path: path, type: type, size: size, modified: modified, created: created, title: title, showId: showId,
      season: season, episode: episode, year: year, plot: plot, genres: genres, rating: rating, ids: ids, runtime: runtime,
      poster: poster, subtitles: subtitles, artist: artist, album: album, albumId: albumId);

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'type': type.name,
        'size': size,
        'm': modified,
        'c': ?created,
        'title': title,
        'show': ?showId,
        'season': ?season,
        'episode': ?episode,
        'year': ?year,
        'plot': ?plot,
        if (genres.isNotEmpty) 'genres': genres,
        'rating': ?rating,
        if (ids.isNotEmpty) 'ids': ids,
        if (runtime != null) 'runtimeMs': runtime!.inMilliseconds,
        'poster': ?poster?.toJson(),
        if (subtitles.isNotEmpty) 'subs': [for (final s in subtitles) s.toJson()],
        'artist': ?artist,
        'album': ?album,
        'albumId': ?albumId,
      };

  factory SmbItem.fromJson(Map<String, Object?> j) => SmbItem(
        id: j['id'] as String,
        path: j['path'] as String,
        type: SmbFolderType.fromName(j['type'])!,
        size: j['size'] as int,
        modified: j['m'] as int,
        created: j['c'] as int?,
        title: j['title'] as String,
        showId: j['show'] as String?,
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        year: j['year'] as int?,
        plot: j['plot'] as String?,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        rating: j['rating'] as String?,
        ids: (j['ids'] as List?)?.cast<String>() ?? const [],
        runtime: switch (j['runtimeMs']) { final int ms => Duration(milliseconds: ms), _ => null },
        poster: SmbImage.fromJson(j['poster']),
        subtitles: [for (final s in (j['subs'] as List? ?? const []).cast<Map<String, Object?>>()) SmbSubtitleFile.fromJson(s)],
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        albumId: j['albumId'] as String?,
      );
}

/// What a scan of a share found, as saved.
class SmbScan {
  SmbScan({required this.items, required this.shows, this.ids = const {}, this.nfos = const {}, this.albums = const {}});

  static final empty = SmbScan(items: const [], shows: const []);

  final List<SmbItem> items;
  final List<SmbShow> shows;

  /// Ids of files that aren't their path's own: moved ones keep theirs.
  final Map<String, String> ids;

  /// `.nfo` files already read, by path: their size, modified time and what
  /// they say (null for a broken one).
  final Map<String, (int, int, SmbNfo?)> nfos;

  /// Albums' covers, by album id.
  final Map<String, SmbImage> albums;

  late final Map<String, SmbItem> byId = {for (final i in items) i.id: i};
  late final Map<String, SmbShow> showById = {for (final s in shows) s.id: s};

  Map<String, Object?> toJson() => {
        'version': 1,
        'items': [for (final i in items) i.toJson()],
        'shows': [for (final s in shows) s.toJson()],
        'ids': ids,
        'nfos': [
          for (final e in nfos.entries) [e.key, e.value.$1, e.value.$2, e.value.$3?.toJson()]
        ],
        'albums': {for (final e in albums.entries) e.key: e.value.toJson()},
      };

  factory SmbScan.fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['version'] != 1) return empty;
    return SmbScan(
      items: [for (final i in (json['items'] as List).cast<Map<String, Object?>>()) SmbItem.fromJson(i)],
      shows: [for (final s in (json['shows'] as List).cast<Map<String, Object?>>()) SmbShow.fromJson(s)],
      ids: (json['ids'] as Map).cast<String, String>(),
      nfos: {
        for (final n in (json['nfos'] as List).cast<List<Object?>>())
          n[0] as String: (
            n[1] as int,
            n[2] as int,
            n[3] == null ? null : SmbNfo.fromJson(n[3] as Map<String, Object?>),
          ),
      },
      albums: {
        for (final e in (json['albums'] as Map? ?? const {}).cast<String, Object?>().entries) e.key: ?SmbImage.fromJson(e.value),
      },
    );
  }
}

/// Lists a share's mapped folders and works out what they hold (design D5).
class SmbScanner {
  SmbScanner(this._share, this._mappings, {SmbScan? previous, Map<String, String> sharedIds = const {}, this.onFolder})
      : _previous = previous ?? SmbScan.empty,
        _knownIds = {...sharedIds, ...?previous?.ids};

  final SmbShare _share;
  final List<SmbMapping> _mappings;
  final SmbScan _previous;

  /// Ids that aren't their path's own, known before this scan.
  final Map<String, String> _knownIds;

  /// Called as each folder is listed.
  final void Function(int folders, int files)? onFolder;

  /// Folders listed at once.
  static const atOnce = 4;

  /// An `.nfo` larger than this isn't one.
  static const _nfoLimit = 1 << 20;

  final _items = <SmbItem>[];
  final _shows = <String, SmbShow>{};
  final _nfos = <String, (int, int, SmbNfo?)>{};
  final _albums = <String, SmbImage>{};

  /// Folders that couldn't be listed: what was in them stays.
  final _unread = <String>[];
  int _folders = 0;

  Future<SmbScan> scan() async {
    final roots = {for (final m in _mappings) m.path};
    for (final mapping in _mappings) {
      final folders = <String, _Listing>{};
      await _walk(mapping, roots, folders);
      await _read(mapping, folders);
    }
    if (_unread.isNotEmpty) {
      final found = {for (final i in _items) i.path};
      for (final i in _previous.items) {
        if (found.contains(i.path) || !_unread.any((f) => smbInside(i.path, f))) continue;
        final mapping = _mappingOf(i.path);
        if (mapping == null || mapping.type != i.type) continue;
        _items.add(i);
        if (i.showId case final id?) {
          if (_previous.showById[id] case final show?) _shows.putIfAbsent(id, () => show);
        }
      }
    }
    final (items, ids) = _settleIds(_items);
    return SmbScan(items: items, shows: _shows.values.toList(), ids: ids, nfos: _nfos, albums: _albums);
  }

  /// The mapping [path] belongs to: the deepest around it.
  SmbMapping? _mappingOf(String path) {
    SmbMapping? best;
    for (final m in _mappings) {
      if (smbInside(path, m.path) && (best == null || m.path.length > best.path.length)) best = m;
    }
    return best;
  }

  /// Lists every folder under [mapping] into [out], except those mapped on
  /// their own.
  Future<void> _walk(SmbMapping mapping, Set<String> roots, Map<String, _Listing> out) async {
    final queue = <String>[mapping.path];
    final running = <Future<void>>{};
    Object? failure;
    Future<void> one(String path) async {
      final List<SmbEntry> entries;
      try {
        entries = await _share.list(path);
      } on SmbException catch (e) {
        // A lost share, or a mapped folder that's gone, is another matter
        // than a folder that can't be read.
        if (e.kind == SmbErrorKind.unreachable || e.kind == SmbErrorKind.wrongSignIn) {
          failure ??= e;
        } else if (e.kind != SmbErrorKind.gone || path == mapping.path) {
          // A mapped folder that's missing (its disk isn't mounted, say)
          // keeps what it held; one deleted inside it doesn't.
          _unread.add(path);
        }
        return;
      }
      final listing = out[path] = _Listing(path);
      for (final e in entries) {
        final at = smbJoin(path, e.name);
        if (e.isFolder) {
          if (roots.contains(at) && at != mapping.path) continue;
          if (SmbNames.skipsFolder(e.name, hidden: e.hidden, extras: !mapping.type.isPool && mapping.type != SmbFolderType.homeVideos)) {
            continue;
          }
          listing.folders.add(e.name);
          queue.add(at);
        } else if (!e.name.startsWith('.') && !e.hidden) {
          listing.files.add(e);
        }
      }
      _folders++;
      onFolder?.call(_folders, _items.length);
    }

    while (queue.isNotEmpty || running.isNotEmpty) {
      while (queue.isNotEmpty && running.length < atOnce && failure == null) {
        late final Future<void> task;
        task = one(queue.removeAt(0)).whenComplete(() => running.remove(task));
        running.add(task);
      }
      if (running.isEmpty) break;
      await Future.any(running);
    }
    if (failure case final f?) throw f;
  }

  Future<void> _read(SmbMapping mapping, Map<String, _Listing> folders) async {
    final pending = <Future<void>>[];
    for (final listing in folders.values) {
      pending.add(_readFolder(mapping, listing, folders));
      if (pending.length >= atOnce) {
        await Future.wait(pending);
        pending.clear();
      }
    }
    await Future.wait(pending);
  }

  static int _ms(DateTime? t) => t?.millisecondsSinceEpoch ?? 0;

  SmbImage? _image(_Listing l, Iterable<String> bases) {
    for (final b in bases) {
      final e = l.images[b.toLowerCase()];
      if (e != null) return SmbImage(smbJoin(l.path, e.name), e.size, _ms(e.modified));
    }
    return null;
  }

  /// What `.nfo` [entry] of [l] says, read again only when it changed.
  Future<SmbNfo?> _nfo(_Listing l, SmbEntry? entry) async {
    if (entry == null || entry.size > _nfoLimit) return null;
    final path = smbJoin(l.path, entry.name);
    final modified = _ms(entry.modified);
    if (_previous.nfos[path] case (final size, final m, final nfo)? when size == entry.size && m == modified) {
      _nfos[path] = (size, m, nfo);
      return nfo;
    }
    SmbNfo? nfo;
    try {
      nfo = SmbNfo.parse(await _share.readAll(path, limit: _nfoLimit));
    } on SmbException catch (e) {
      if (e.kind == SmbErrorKind.unreachable) rethrow;
      return null;
    }
    _nfos[path] = (entry.size, modified, nfo);
    return nfo;
  }

  Future<void> _readFolder(SmbMapping mapping, _Listing l, Map<String, _Listing> all) async {
    final below = l.path == mapping.path
        ? const <String>[]
        : (mapping.path.isEmpty ? l.path : l.path.substring(mapping.path.length + 1)).split('/');
    if (mapping.type == SmbFolderType.music) {
      _readMusic(mapping, l, below);
      return;
    }
    final videos = [
      for (final e in l.files)
        if (SmbNames.isVideo(e.name) && (mapping.type == SmbFolderType.homeVideos || mapping.type.isPool || !SmbNames.skipsVideo(e.name))) e
    ];
    for (final e in videos) {
      switch (mapping.type) {
        case SmbFolderType.tvShows:
          await _episode(mapping, l, below, e, all);
        case SmbFolderType.movies:
          await _movie(mapping, l, below, e, alone: videos.length == 1);
        case SmbFolderType.musicVideos:
          await _musicVideo(mapping, l, below, e);
        case SmbFolderType.homeVideos:
          _homeVideo(mapping, l, e);
        case SmbFolderType.commercials || SmbFolderType.bumpers:
          _items.add(_item(mapping, l, e, title: SmbNames.base(e.name)));
        case SmbFolderType.music:
          break;
      }
    }
  }

  SmbItem _item(SmbMapping mapping, _Listing l, SmbEntry e,
      {required String title,
      String? showId,
      int? season,
      int? episode,
      int? year,
      SmbNfo? nfo,
      List<String> ids = const [],
      SmbImage? poster,
      String? artist,
      String? album,
      String? albumId}) {
    final path = smbJoin(l.path, e.name);
    return SmbItem(
      id: _knownIds[path] ?? smbIdOf(path),
      path: path,
      type: mapping.type,
      size: e.size,
      modified: _ms(e.modified),
      created: (e.created ?? e.modified)?.millisecondsSinceEpoch,
      title: title,
      showId: showId,
      season: season,
      episode: episode,
      year: year,
      plot: nfo?.plot,
      genres: nfo?.genres ?? const [],
      rating: nfo?.rating,
      ids: {...?nfo?.ids, ...ids}.toList(),
      runtime: nfo?.runtime,
      poster: poster,
      subtitles: [
        for (final s in l.files)
          if (SmbNames.subtitle(s.name, e.name) case final name?)
            SmbSubtitleFile(path: smbJoin(l.path, s.name), size: s.size, modified: _ms(s.modified), name: name)
      ],
      artist: artist,
      album: album,
      albumId: albumId,
    );
  }

  Future<void> _episode(SmbMapping mapping, _Listing l, List<String> below, SmbEntry e, Map<String, _Listing> all) async {
    final rootName = mapping.path.split('/').last;
    final n = SmbNames.episode(e.name, below, root: rootName);
    // The show's folder, or the name its files share.
    final showFolder = n.showFolder;
    final folderPath = showFolder == null
        ? null
        : smbJoin(mapping.path, below.sublist(0, below.lastIndexOf(showFolder) + 1).join('/'));
    final showId = smbIdOf(folderPath == null ? '${mapping.path}//${n.show.toLowerCase()}' : '$folderPath/');
    if (!_shows.containsKey(showId)) {
      final home = folderPath == null ? null : all[folderPath];
      // A placeholder first: folders are read several at once.
      _shows[showId] = SmbShow(id: showId, name: n.show, year: n.showYear, ids: n.ids);
      if (home != null) {
        final nfo = await _nfo(home, home.byName['tvshow.nfo']);
        _shows[showId] = SmbShow(
          id: showId,
          name: nfo?.title ?? n.show,
          year: nfo?.year ?? n.showYear,
          ids: {...?nfo?.ids, ...n.ids}.toList(),
          genres: nfo?.genres ?? const [],
          rating: nfo?.rating,
          poster: _image(home, const ['poster', 'folder', 'cover', 'show']),
          logo: _image(home, const ['clearlogo', 'logo']),
        );
      }
    }
    final b = SmbNames.base(e.name);
    final nfo = await _nfo(l, l.byName['${b.toLowerCase()}.nfo']);
    _items.add(_item(mapping, l, e,
        title: nfo?.title ?? n.title,
        showId: showId,
        season: nfo?.season ?? n.season,
        episode: nfo?.episode ?? n.episode,
        year: nfo?.year,
        nfo: nfo,
        poster: _image(l, ['$b-thumb', b])));
  }

  Future<void> _movie(SmbMapping mapping, _Listing l, List<String> below, SmbEntry e, {required bool alone}) async {
    final b = SmbNames.base(e.name);
    final own = alone && below.isNotEmpty;
    final nfo = await _nfo(l, l.byName['${b.toLowerCase()}.nfo'] ?? (own || alone ? l.byName['movie.nfo'] : null));
    final n = SmbNames.movie(e.name, below, alone: alone);
    _items.add(_item(mapping, l, e,
        title: nfo?.title ?? n.title,
        year: nfo?.year ?? n.year,
        nfo: nfo,
        ids: n.ids,
        poster: _image(l, ['$b-poster', if (own) ...['poster', 'folder', 'cover', 'movie'], '$b-thumb', b])));
  }

  Future<void> _musicVideo(SmbMapping mapping, _Listing l, List<String> below, SmbEntry e) async {
    final b = SmbNames.base(e.name);
    final nfo = await _nfo(l, l.byName['${b.toLowerCase()}.nfo']);
    // "Artist - Title" names are split by the library; others belong to
    // their folder's artist.
    final named = RegExp(r'\s[-–—]\s').hasMatch(b);
    _items.add(_item(mapping, l, e,
        title: nfo?.title ?? b,
        year: nfo?.year,
        nfo: nfo,
        artist: named || below.isEmpty ? null : below.first,
        poster: _image(l, ['$b-poster', '$b-thumb', b])));
  }

  void _homeVideo(SmbMapping mapping, _Listing l, SmbEntry e) {
    final showId = smbIdOf('${l.path}/');
    _shows.putIfAbsent(
        showId,
        () => SmbShow(
              id: showId,
              name: l.path.isEmpty ? 'Home videos' : l.path.split('/').last,
              home: true,
              poster: _image(l, const ['poster', 'folder', 'cover']),
            ));
    final b = SmbNames.base(e.name);
    _items.add(_item(mapping, l, e, title: b, showId: showId, poster: _image(l, ['$b-poster', '$b-thumb', b])));
  }

  void _readMusic(SmbMapping mapping, _Listing l, List<String> below) {
    final songs = [for (final e in l.files) if (SmbNames.isAudio(e.name)) e];
    if (songs.isEmpty) return;
    final albumId = smbIdOf('${l.path}/');
    if (_image(l, const ['cover', 'folder', 'front', 'album', 'albumart', 'poster']) case final cover?) _albums[albumId] = cover;
    for (final e in songs) {
      final n = SmbNames.song(e.name, below);
      _items.add(_item(mapping, l, e, title: n.title, year: n.year, artist: n.artist, album: n.album, albumId: albumId));
    }
  }

  /// Every file's id (design D4): a file that is the only new one of a title
  /// whose only file is gone takes that file's id; and no two files share
  /// one.
  (List<SmbItem>, Map<String, String>) _settleIds(List<SmbItem> items) {
    final now = {for (final i in items) i.path};
    final before = {for (final i in _previous.items) i.path};
    final shows = {..._previous.showById, ..._shows};
    String? key(SmbItem i) => switch (i.type) {
          SmbFolderType.tvShows when i.season != null && i.episode != null =>
            'e|${(shows[i.showId]?.name ?? '').toLowerCase()}|${i.season}|${i.episode}',
          SmbFolderType.movies => 'm|${i.title.toLowerCase()}|${i.year ?? ''}',
          _ => null,
        };
    final lost = <String, List<SmbItem>>{}, found = <String, List<SmbItem>>{};
    // A title that still has a file where it was hasn't moved.
    final stayed = <String>{};
    for (final i in _previous.items) {
      final k = key(i);
      if (k == null) continue;
      if (now.contains(i.path)) {
        stayed.add(k);
      } else {
        lost.putIfAbsent(k, () => []).add(i);
      }
    }
    for (final i in items) {
      final k = key(i);
      if (k != null && !before.contains(i.path) && !_knownIds.containsKey(i.path)) found.putIfAbsent(k, () => []).add(i);
    }
    final moved = <String, String>{};
    for (final e in lost.entries) {
      if (stayed.contains(e.key)) continue;
      if ((e.value, found[e.key]) case ([final from], [final to])) moved[to.path] = from.id;
    }
    final ids = <String, String>{};
    final taken = <String>{};
    final out = <SmbItem>[];
    // Files that already have an id keep it before new ones get theirs.
    final ordered = [
      for (final i in items) if (before.contains(i.path) || _knownIds.containsKey(i.path) || moved.containsKey(i.path)) i,
      for (final i in items) if (!before.contains(i.path) && !_knownIds.containsKey(i.path) && !moved.containsKey(i.path)) i,
    ];
    for (final i in ordered) {
      var id = moved[i.path] ?? i.id;
      for (var n = 2; taken.contains(id); n++) {
        id = smbIdOf('${i.path}#$n');
      }
      taken.add(id);
      if (id != smbIdOf(i.path)) ids[i.path] = id;
      out.add(id == i.id ? i : i.withId(id));
    }
    return (out, ids);
  }
}

/// One folder's files, as listed.
class _Listing {
  _Listing(this.path);

  final String path;
  final folders = <String>[];
  final files = <SmbEntry>[];

  late final Map<String, SmbEntry> byName = {for (final f in files) f.name.toLowerCase(): f};

  /// Image files by their name without an extension, lower case.
  late final Map<String, SmbEntry> images = {
    for (final f in files)
      if (SmbNames.imageExtensions.contains(SmbNames.extension(f.name))) SmbNames.base(f.name).toLowerCase(): f,
  };
}
