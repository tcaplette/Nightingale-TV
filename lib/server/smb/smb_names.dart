import '../languages.dart';

/// What the names of files and folders of a share say (smb-sources,
/// "Scanning a share"). Pure, so a table of names tests it.
abstract final class SmbNames {
  static const videoExtensions = {
    'mkv', 'mp4', 'm4v', 'avi', 'mov', 'wmv', 'asf', 'mpg', 'mpeg', 'm2v', 'ts', 'm2ts', 'mts', 'vob', 'flv', 'f4v', //
    'webm', 'ogv', 'ogm', 'divx', 'rm', 'rmvb', '3gp', '3g2', 'wtv', 'dvr-ms', 'mxf', 'nsv', 'nuv', 'dv', 'qt', 'mk3d', 'xvid',
  };
  static const audioExtensions = {
    'mp3', 'm4a', 'm4b', 'aac', 'flac', 'ogg', 'oga', 'opus', 'wav', 'wma', 'alac', 'aiff', 'aif', 'ape', 'wv', 'mka', 'tta',
  };
  static const subtitleExtensions = {'srt', 'ass', 'ssa', 'vtt'};
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  static String extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String base(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static bool isVideo(String name) => videoExtensions.contains(extension(name));
  static bool isAudio(String name) => audioExtensions.contains(extension(name));

  // ---- What is skipped ---------------------------------------------------------

  static const _skippedFolders = {
    '@eadir', '#recycle', '@recycle', '@recently-snapshot', r'$recycle.bin', 'recycler', '.recycle', 'system volume information', //
    'lost+found', '.nightingale', '.trash', '.trashes', '.@__thumb', '@tmp', 'extrafanart', 'extrathumbs', '.actors',
    'video_ts', 'audio_ts', 'bdmv', 'certificate',
  };

  /// Extras beside a movie or show, as Kodi, Plex and Jellyfin name them.
  static const _extrasFolders = {
    'extras', 'extra', 'featurettes', 'featurette', 'trailers', 'trailer', 'behind the scenes', 'deleted scenes', 'interviews', //
    'scenes', 'shorts', 'samples', 'sample', 'bonus', 'bonus features', 'theme-music', 'backdrops', 'other', 'others',
  };

  /// A folder no scan looks into.
  static bool skipsFolder(String name, {bool hidden = false, bool extras = false}) {
    final n = name.toLowerCase();
    return hidden || n.startsWith('.') || _skippedFolders.contains(n) || extras && _extrasFolders.contains(n);
  }

  static final _sample = RegExp(r'(^|[ ._\-\[(])sample($|[ ._\-\])])', caseSensitive: false);
  static final _extraSuffix =
      RegExp(r'-(trailer|featurette|behindthescenes|deleted|interview|scene|short|sample|other|extra)$', caseSensitive: false);

  /// A video that isn't a title: a sample or an extra.
  static bool skipsVideo(String name, {bool hidden = false}) {
    final b = base(name);
    return hidden || name.startsWith('.') || _sample.hasMatch(b) || _extraSuffix.hasMatch(b);
  }

  // ---- Ids, years and clean titles ------------------------------------------------

  static final _idTag = RegExp(r'[\[{(]\s*(tmdb|tvdb|imdb)(?:id)?\s*[-=:]\s*([a-z0-9]+)\s*[\]})]', caseSensitive: false);

  /// The provider ids in [name] (`{tmdb-949}`, `[tvdbid-123]`), as the
  /// library keeps them (`tmdb:949`).
  static List<String> idsIn(String name) => [
        for (final m in _idTag.allMatches(name)) '${m[1]!.toLowerCase()}:${m[2]!.toLowerCase()}',
      ];

  static final _yearInParens = RegExp(r'[(\[]\s*((?:18|19|20)\d\d)\s*[)\]]');
  static final _bareYear = RegExp(r'(?<=\S[ ])((?:19|20)\d\d)(?=[ ]|$)');

  /// What a file was made from or encoded as, where release names start
  /// telling it.
  static final _strongTag = RegExp(
      r'(?:^|[ \-\[(])(?:480[pi]|576[pi]|720[pi]|1080[pi]|1440p|2160p|4320p|4k|uhd|x26[45]|h ?26[45]|hevc|avc|xvid|divx|av1|blu-?ray|bdrip|brrip|'
      r'bdremux|remux|web-?dl|web-?rip|hdtv|pdtv|dvd-?rip|dvdscr|hdrip|hddvd|10bit|8bit|hdr10?|dolby ?vision|aac\d?|e?ac-?3|ddp?\d|dts(?:-?hd)?|truehd|flac)'
      r'(?=$|[ \-\])])',
      caseSensitive: false);
  static final _weakTag = RegExp(
      r'(?:^|[ \-\[(])(?:web|dvd|proper|repack|internal|multi|subbed|dubbed|complete|extended|unrated|limited|amzn|nf|dsnp|hmax|hulu|atvp|dual ?audio)(?=$|[ \-\])])',
      caseSensitive: false);

  /// Dots and underscores as spaces, when the name uses them for spaces.
  static String _spaced(String s) {
    final dotted = !s.contains(' ') && RegExp(r'[^.]\.[^.]').hasMatch(s);
    var out = s.replaceAll('_', ' ');
    if (dotted) out = out.replaceAll('.', ' ');
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Whether [s] is a release name, whose spaces are dots or that says how
  /// it's encoded.
  static bool _release(String s) =>
      !s.contains(' ') && RegExp(r'[^.]\.[^.]').hasMatch(s) || _strongTag.hasMatch(_spaced(s));

  /// [s] up to its first release tag; a tag that starts it is its title
  /// ("DivX Movie").
  static String _cutTags(String s, {bool leading = false}) {
    final strong = _strongTag.allMatches(s).where((m) => leading || s.substring(0, m.start).trim().isNotEmpty).firstOrNull;
    if (strong == null) return s;
    var cut = strong.start;
    final weak = _weakTag.firstMatch(s);
    if (weak != null && weak.start < cut) cut = weak.start;
    return s.substring(0, cut);
  }

  static String _tidy(String s) => s
      .replaceAll(RegExp(r'\[[^\]]*\]|\{[^}]*\}'), ' ')
      .replaceAll(RegExp(r'\(\s*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-–_.,]+|[\s\-–_,]+$'), '')
      .replaceAll(RegExp(r'\s*[\[({]$'), '')
      .trim();

  /// A movie's or show's title and year from [name] (without an extension).
  static ({String title, int? year, List<String> ids}) title(String name) {
    final ids = idsIn(name);
    var s = _spaced(name.replaceAll(_idTag, ' '));
    int? year;
    final parens = _yearInParens.allMatches(s).lastOrNull;
    if (parens != null && s.substring(0, parens.start).trim().isNotEmpty) {
      year = int.parse(parens[1]!);
      // What comes before a year in brackets is the title, whatever words.
      final clean = _tidy(s.substring(0, parens.start));
      return (title: clean, year: year, ids: ids);
    } else if (_release(name)) {
      final tagAt = _strongTag.firstMatch(s)?.start ?? s.length;
      final bare = _bareYear.allMatches(s).where((m) => m.start <= tagAt).lastOrNull;
      if (bare != null) {
        year = int.parse(bare[1]!);
        s = s.substring(0, bare.start);
      }
    }
    final clean = _tidy(_cutTags(s));
    return (title: clean.isEmpty ? _tidy(_spaced(name)) : clean, year: year, ids: ids);
  }

  static final _disc = RegExp(r'[ ._\-]*\b(?:cd|disc|disk)[ ._\-]?(\d)\b.*$', caseSensitive: false);
  static final _generic = RegExp(r'^(?:movie|film|video|main|feature|title ?\d*|vts ?\d+ ?\d*|track ?\d*)$', caseSensitive: false);

  /// A movie file's title and year, from its name and its folders' ([folders]:
  /// those under the mapped one, outermost first). [alone]: the only movie in
  /// its folder.
  static ({String title, int? year, List<String> ids}) movie(String fileName, List<String> folders, {bool alone = false}) {
    final file = title(base(fileName).replaceFirst(_disc, ''));
    if (folders.isEmpty) return file;
    final folder = title(folders.last);
    final ids = {...file.ids, ...folder.ids}.toList();
    if (file.year != null && !_generic.hasMatch(file.title)) return (title: file.title, year: file.year, ids: ids);
    if (folder.year != null) return (title: folder.title, year: folder.year, ids: ids);
    final f = file.title.toLowerCase(), d = folder.title.toLowerCase();
    if (alone && (_generic.hasMatch(file.title) || f.contains(d) && d.length > 1)) {
      return (title: folder.title, year: folder.year, ids: ids);
    }
    return (title: file.title, year: file.year, ids: folder.ids.isNotEmpty ? ids : file.ids);
  }

  // ---- Episodes ---------------------------------------------------------------------

  static final _seasonFolder =
      RegExp(r'^(?:season|series|saison|staffel|temporada|stagione|s)[ ._\-]*(\d{1,4})\b', caseSensitive: false);
  static final _specials = RegExp(r'^(?:specials?|season 0+)$', caseSensitive: false);
  static final _discFolder = RegExp(r'^(?:disc|disk|dvd|cd|vol(?:ume)?)[ ._\-]*\d+$', caseSensitive: false);

  /// The season a folder names; 0 for specials, null when it names none.
  static int? seasonOf(String folder) {
    final f = folder.trim();
    if (_specials.hasMatch(f)) return 0;
    final m = _seasonFolder.firstMatch(f);
    return m == null ? null : int.parse(m[1]!);
  }

  static bool _insideShow(String folder) => seasonOf(folder) != null || _discFolder.hasMatch(folder.trim());

  static final _sxe = RegExp(
      r'(?:^|[^a-z0-9])s(\d{1,4})[ ._\-]{0,2}e(\d{1,4})((?:[ ._]?-?[ ._]?e\d{1,4}|-\d{1,3}(?![\dpi]))*)(?![0-9])',
      caseSensitive: false);
  static final _x = RegExp(r'(?:^|[^a-z0-9])(\d{1,2})x(\d{2,3})((?:-?x\d{2,3}|-\d{2,3}(?![\dpi]))*)(?![0-9a-z])', caseSensitive: false);
  static final _date = RegExp(r'(?:^|[^0-9])((?:19|20)\d\d)[ ._\-](0[1-9]|1[0-2])[ ._\-](0[1-9]|[12]\d|3[01])(?![0-9])');
  static final _words = RegExp(r'season[ ._\-]*(\d{1,2})[ ._\-]*(?:,|-)?[ ._\-]*episode[ ._\-]*(\d{1,4})', caseSensitive: false);
  static final _e = RegExp(r'(?:^|[^a-z0-9])(?:e|ep|episode)[ ._\-]{0,2}(\d{1,4})(?![0-9a-z])', caseSensitive: false);
  static final _leading = RegExp(r'^(\d{1,3})(?=$|[ ._\-])');

  /// An episode file, from its name and its folders' ([folders]: those under
  /// the mapped one, outermost first). [root]: the mapped folder's own name,
  /// for a file with no show folder and no show in its name.
  static SmbEpisodeName episode(String fileName, List<String> folders, {required String root}) {
    final name = base(fileName);
    // The show's folder: the nearest that isn't a season or a disc.
    String? showFolder;
    int? folderSeason;
    for (final f in folders.reversed) {
      folderSeason ??= seasonOf(f);
      if (_insideShow(f)) continue;
      showFolder = f;
      break;
    }
    if (folders.isEmpty || showFolder == null) folderSeason ??= seasonOf(root);

    int? season, number, last, date;
    Match? at;
    if (_sxe.firstMatch(name) case final m?) {
      (season, number, last, at) = (int.parse(m[1]!), int.parse(m[2]!), _lastNumber(m[3]!), m);
    } else if (_x.firstMatch(name) case final m?) {
      (season, number, last, at) = (int.parse(m[1]!), int.parse(m[2]!), _lastNumber(m[3]!), m);
    } else if (_words.firstMatch(name) case final m?) {
      (season, number, at) = (int.parse(m[1]!), int.parse(m[2]!), m);
    } else if (_date.firstMatch(name) case final m?) {
      date = int.parse(m[2]!) * 100 + int.parse(m[3]!);
      // A show by the day: its year is the season, and the day the number,
      // which keeps its airing order.
      (season, number, at) = (int.parse(m[1]!), date, m);
    } else if (_e.firstMatch(name) case final m?) {
      (season, number, at) = (folderSeason ?? 1, int.parse(m[1]!), m);
    } else if (folderSeason != null) {
      if (_leading.firstMatch(name) case final m?) (season, number, at) = (folderSeason, int.parse(m[1]!), m);
    }
    season ??= folderSeason;
    if (last != null && (number == null || last <= number || last - number > 20)) last = null;

    final before = at == null ? '' : _tidy(_spaced(name.substring(0, at.start)));
    final show = title(showFolder ?? (before.isNotEmpty ? before : (_insideShow(root) ? 'Unknown show' : root)));
    final after = at == null ? _episodeTitle(name, show.title) : _episodeTitle(name.substring(at.end), null);
    String episodeName;
    if (after.isNotEmpty) {
      episodeName = after;
    } else if (date != null) {
      episodeName = '${at!.group(1)}-${at.group(2)}-${at.group(3)}';
    } else if (number != null) {
      episodeName = [for (var n = number; n <= (last ?? number); n++) 'Episode $n'].join(' / ');
    } else {
      episodeName = _tidy(_spaced(name));
    }
    return SmbEpisodeName(
      show: show.title,
      showYear: show.year,
      showFolder: showFolder,
      ids: show.ids,
      season: season,
      episode: number,
      lastEpisode: last,
      title: episodeName,
    );
  }

  static int? _lastNumber(String tail) {
    final numbers = RegExp(r'\d+').allMatches(tail).map((m) => int.parse(m[0]!)).toList();
    return numbers.isEmpty ? null : numbers.reduce((a, b) => a > b ? a : b);
  }

  static String _episodeTitle(String raw, String? show) {
    var s = raw.replaceAll(_idTag, ' ');
    // Dots for spaces whether or not a space is left in this half of it.
    if (RegExp(r'[^.\s]\.[^.\s]').hasMatch(s) && !s.trim().contains(' ')) s = s.replaceAll('.', ' ');
    // What follows an episode's number is no title when it's a tag.
    s = _cutTags(s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' '), leading: true);
    s = _tidy(s.replaceAll(RegExp(r'^[\s.\-–]+'), ''));
    if (show != null && s.toLowerCase().startsWith(show.toLowerCase())) {
      final rest = _tidy(s.substring(show.length));
      if (rest.isNotEmpty) s = rest;
    }
    return s;
  }

  // ---- Music -----------------------------------------------------------------------

  /// A song's artist, album and title from its place, until its tags are
  /// read.
  static ({String? artist, String? album, int? year, String title}) song(String fileName, List<String> folders) {
    final name = _spaced(base(fileName)).replaceFirst(RegExp(r'^\d{1,3}(?:[ .\-]+)'), '');
    final album = folders.isEmpty ? null : title(folders.last);
    final artist = folders.length >= 2 ? _tidy(folders[folders.length - 2]) : null;
    return (
      artist: artist,
      album: album?.title,
      year: album?.year,
      title: name.trim().isEmpty ? base(fileName) : _tidy(name),
    );
  }

  // ---- Subtitle files ------------------------------------------------------------------

  /// What subtitle file [name] says when it's beside video [video]
  /// (`Movie.en.forced.srt` beside `Movie.mkv`); null when it isn't its.
  static SmbSubtitleName? subtitle(String name, String video) {
    final ext = extension(name);
    if (!subtitleExtensions.contains(ext)) return null;
    final b = base(name), v = base(video);
    if (b.toLowerCase() != v.toLowerCase() && !b.toLowerCase().startsWith('${v.toLowerCase()}.')) return null;
    String? language, tag, label;
    var forced = false, isDefault = false, sdh = false;
    for (final part in b.length > v.length ? b.substring(v.length + 1).split('.') : const <String>[]) {
      switch (part.trim().toLowerCase()) {
        case '':
          break;
        case 'forced' || 'foreign':
          forced = true;
        case 'default':
          isDefault = true;
        case 'sdh' || 'cc' || 'hi':
          sdh = true;
        case final p:
          final known = language == null ? normalizeLanguage(p) : null;
          if (known != null && RegExp(r'^[a-z]{2,3}(-[a-z0-9]{2,8})*$').hasMatch(p) && languageName(known) != null) {
            language = known;
            tag = part.trim();
          } else {
            label = label == null ? part.trim() : '$label ${part.trim()}';
          }
      }
    }
    return SmbSubtitleName(
        language: language,
        tag: tag,
        title: label ?? (sdh ? 'SDH' : null),
        forced: forced,
        isDefault: isDefault,
        codec: switch (ext) { 'srt' => 'subrip', final e => e });
  }
}

class SmbEpisodeName {
  const SmbEpisodeName({
    required this.show,
    required this.title,
    this.showYear,
    this.showFolder,
    this.ids = const [],
    this.season,
    this.episode,
    this.lastEpisode,
  });

  final String show;
  final int? showYear;

  /// The folder that names the show; null when the file name does.
  final String? showFolder;

  /// The show's provider ids.
  final List<String> ids;
  final int? season;
  final int? episode;

  /// The last one in a file of several.
  final int? lastEpisode;
  final String title;
}

class SmbSubtitleName {
  const SmbSubtitleName(
      {required this.codec, this.language, this.tag, this.title, this.forced = false, this.isDefault = false});

  final String codec;
  final String? language;

  /// The language as the name wrote it.
  final String? tag;
  final String? title;
  final bool forced;
  final bool isDefault;
}
