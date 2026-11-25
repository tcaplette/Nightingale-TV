import 'dart:convert';

import 'package:xml/xml.dart';

/// What a Kodi-style `.nfo` file says of a show, a movie or an episode.
class SmbNfo {
  const SmbNfo({
    this.title,
    this.year,
    this.plot,
    this.genres = const [],
    this.rating,
    this.ids = const [],
    this.season,
    this.episode,
    this.runtime,
    this.lastEpisode,
  });

  final String? title;
  final int? year;
  final String? plot;
  final List<String> genres;
  final String? rating;

  /// Provider ids (`imdb:tt0088763`).
  final List<String> ids;
  final int? season;
  final int? episode;

  /// The last episode described, in a file of several.
  final int? lastEpisode;
  final Duration? runtime;

  Map<String, Object?> toJson() => {
        'title': ?title,
        'year': ?year,
        'plot': ?plot,
        if (genres.isNotEmpty) 'genres': genres,
        'rating': ?rating,
        if (ids.isNotEmpty) 'ids': ids,
        'season': ?season,
        'episode': ?episode,
        'last': ?lastEpisode,
        if (runtime != null) 'runtimeMs': runtime!.inMilliseconds,
      };

  factory SmbNfo.fromJson(Map<String, Object?> j) => SmbNfo(
        title: j['title'] as String?,
        year: j['year'] as int?,
        plot: j['plot'] as String?,
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        rating: j['rating'] as String?,
        ids: (j['ids'] as List?)?.cast<String>() ?? const [],
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        lastEpisode: j['last'] as int?,
        runtime: switch (j['runtimeMs']) { final int ms => Duration(milliseconds: ms), _ => null },
      );

  /// Reads [bytes]; null for a file that isn't an `.nfo` of a title, or is
  /// broken. Several episodes' descriptions in one file (a file of two
  /// episodes) become one, titled with each.
  static SmbNfo? parse(List<int> bytes) {
    final String text;
    try {
      text = _decode(bytes);
    } on FormatException {
      return null;
    }
    // Kodi allows a line with a link after the XML, and several root
    // elements, neither of which is XML: each element is read on its own.
    final parts = [
      for (final m in RegExp(r'<(tvshow|movie|episodedetails|musicvideo)(?:\s[^>]*)?>.*?</\1\s*>', dotAll: true).allMatches(text))
        ?_one(m[0]!)
    ];
    if (parts.isEmpty) return null;
    final first = parts.first;
    if (parts.length == 1) return first;
    final titles = [for (final p in parts) ?p.title];
    return SmbNfo(
      title: titles.isEmpty ? null : titles.join(' / '),
      year: first.year,
      plot: first.plot,
      genres: first.genres,
      rating: first.rating,
      ids: first.ids,
      season: first.season,
      episode: first.episode,
      lastEpisode: parts.map((p) => p.episode).nonNulls.lastOrNull,
      runtime: first.runtime,
    );
  }

  static String _decode(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return String.fromCharCodes([for (var i = 2; i + 1 < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8]);
    }
    final start = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF ? 3 : 0;
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  static SmbNfo? _one(String xml) {
    final XmlElement root;
    try {
      root = XmlDocument.parse(xml).rootElement;
    } on XmlException {
      return null;
    }
    String? text(String name) {
      final t = root.getElement(name)?.innerText.trim();
      return t == null || t.isEmpty ? null : t;
    }

    int? number(String name) => int.tryParse(RegExp(r'\d+').firstMatch(text(name) ?? '')?[0] ?? '');
    int? yearOf(String? s) => switch (RegExp(r'(?:18|19|20)\d\d').firstMatch(s ?? '')?[0]) { final y? => int.parse(y), _ => null };

    final ids = <String>{};
    for (final u in root.findElements('uniqueid')) {
      final type = u.getAttribute('type')?.toLowerCase();
      _addId(ids, type, u.innerText);
    }
    for (final name in const ['tmdbid', 'tvdbid', 'imdbid', 'imdb_id']) {
      _addId(ids, name.substring(0, 4), text(name));
    }
    // Older files: one id, IMDb's by its form.
    if (text('id') case final id? when RegExp(r'^tt\d+$').hasMatch(id)) ids.add('imdb:$id');
    final minutes = number('runtime');
    final rating = text('mpaa') ?? text('certification');
    return SmbNfo(
      title: text('title'),
      year: yearOf(text('year')) ?? yearOf(text('premiered')) ?? yearOf(text('aired')) ?? yearOf(text('releasedate')),
      plot: text('plot') ?? text('outline'),
      genres: [
        for (final g in root.findElements('genre'))
          for (final part in g.innerText.split(RegExp(r'\s*[/|,]\s*')))
            if (part.trim().isNotEmpty) part.trim()
      ],
      rating: rating == null ? null : cleanRating(rating),
      ids: ids.toList(),
      season: number('season'),
      episode: number('episode'),
      runtime: minutes == null || minutes == 0 ? null : Duration(minutes: minutes),
    );
  }

  static void _addId(Set<String> ids, String? type, String? value) {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty || v == '0' || !const {'tmdb', 'tvdb', 'imdb'}.contains(type)) return;
    ids.add('$type:$v');
  }

  /// `Rated PG-13 for…`, `US:PG-13`, `US:TV-14 / GB:15` as the rating alone.
  static String? cleanRating(String raw) {
    var s = raw.trim();
    final us = RegExp(r'(?:^|[/|,]\s*)(?:US|USA)\s*:\s*([A-Za-z0-9\-]+)', caseSensitive: false).firstMatch(s);
    if (us != null) return us[1];
    s = s.replaceFirst(RegExp(r'^rated\s+', caseSensitive: false), '');
    final country = RegExp(r'^[A-Za-z]{2,3}\s*:\s*').firstMatch(s);
    if (country != null) s = s.substring(country.end);
    s = s.split(RegExp(r'\s+for\s+|\s*[/|,]\s*|\s{2,}')).first.trim();
    return s.isEmpty ? null : s;
  }
}
