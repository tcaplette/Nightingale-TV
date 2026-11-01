import 'library_index.dart';

/// Merges several servers' indexes into one library (multi-server D4).
///
/// [parts] are in Play from order, each already holding global ids. The
/// same title on several servers becomes one entry:
/// - when both copies have provider ids, a shared one decides (and none
///   shared means different titles);
/// - otherwise episodes match on show key, season and episode number,
///   movies on title and year, songs on artist, album and title, music
///   videos on artist and title. Episodes without numbers and movies without
///   a year never match;
/// - commercials never merge.
///
/// A merged entry keeps the id it had in [previous] while that copy exists,
/// else the first copy's; the others become its alternates. Its play count
/// is the highest copy's and its added date the earliest.
LibraryIndex mergeLibraries(List<LibraryIndex> parts, {LibraryIndex? previous, DateTime? fetchedAt}) {
  if (parts.length == 1 && previous == null) return parts.single;
  parts = _sameShows(parts);
  final kept = {
    if (previous != null)
      for (final e in [...previous.episodes, ...previous.movies, ...previous.songs, ...previous.musicVideos]) e.id,
  };

  final series = <String, SeriesEntry>{};
  for (final part in parts) {
    for (final s in part.series) {
      final existing = series[s.key];
      if (existing == null) {
        series[s.key] = s;
      } else {
        // Artwork from the first copy with a logo.
        final useNew = !existing.hasLogo && s.hasLogo;
        series[s.key] = existing.withId(useNew ? s.id : existing.id,
            hasLogo: existing.hasLogo || s.hasLogo, genres: {...existing.genres, ...s.genres}.toList());
      }
    }
  }

  List<MediaEntry> merge(List<MediaEntry> Function(LibraryIndex) of, String? Function(MediaEntry) ruleKey) {
    final groups = <List<MediaEntry>>[];
    final byProvider = <String, int>{};
    final byRule = <String, int>{};
    for (final part in parts) {
      for (final e in of(part)) {
        int? group;
        for (final p in e.providerIds) {
          group ??= byProvider[p];
        }
        if (group == null) {
          final rule = ruleKey(e);
          final candidate = rule == null ? null : byRule[rule];
          // Both known to providers, under different ids: not the same title.
          if (candidate != null && !_disagree(groups[candidate], e)) group = candidate;
        }
        // One copy per server in a group: a server's own duplicates were
        // already settled by its scan.
        if (group != null && groups[group].any((c) => _key(c.id) == _key(e.id))) group = null;
        if (group == null) {
          group = groups.length;
          groups.add([e]);
          if (ruleKey(e) case final rule?) byRule.putIfAbsent(rule, () => group!);
        } else {
          groups[group].add(e);
        }
        for (final p in e.providerIds) {
          byProvider.putIfAbsent(p, () => group!);
        }
      }
    }
    return [for (final g in groups) _one(g, kept)];
  }

  final rootsByItem = <String, List<String>>{};
  final episodes = merge((p) => p.episodes, (e) {
    if (e.seriesKey == null || e.season == null || e.episode == null) return null;
    return '${e.seriesKey}|${e.season}|${e.episode}';
  });
  final movies = merge((p) => p.movies, (m) => m.year == null ? null : '${_norm(m.title)}|${m.year}');
  final songs = merge((p) => p.songs, (s) => s.artist == null ? null : '${_norm(s.artist!)}|${_norm(s.album ?? '')}|${_norm(s.title)}');
  final musicVideos = merge((p) => p.musicVideos, (m) => m.artist == null ? null : '${_norm(m.artist!)}|${_norm(m.title)}');

  // Roots stay per server; a merged item is under every root any copy is.
  final primaryOf = <String, String>{
    for (final e in [...episodes, ...movies])
      for (final c in e.copies) c.id: e.id,
  };
  for (final part in parts) {
    part.rootsByItem.forEach((id, roots) {
      final primary = primaryOf[id] ?? id;
      final list = rootsByItem.putIfAbsent(primary, () => []);
      for (final r in roots) {
        if (!list.contains(r)) list.add(r);
      }
    });
  }
  final withEpisodes = {for (final e in episodes) e.seriesKey};
  return LibraryIndex(
    series: [for (final s in series.values) if (withEpisodes.contains(s.key)) s],
    episodes: episodes,
    movies: movies,
    commercials: [for (final p in parts) ...p.commercials],
    songs: songs,
    musicVideos: musicVideos,
    fetchedAt: fetchedAt ?? DateTime.now(),
    rootsByItem: rootsByItem,
    roots: {for (final p in parts) ...p.roots},
    missingRoots: {for (final p in parts) ...p.missingRoots},
  );
}

String _norm(String s) => s.trim().toLowerCase();

/// [parts] with a show listed without a year on one server keyed as the
/// same-named show with a year on another (one server's metadata knows the
/// year, the other's doesn't), so their episodes match. The main server's
/// key wins, else the first part's; shows with two different years stay
/// apart.
List<LibraryIndex> _sameShows(List<LibraryIndex> parts) {
  String name(String key) => key.substring(0, key.lastIndexOf('|'));
  bool yearless(String key) => key.endsWith('|');
  final keyOf = <String, String>{};
  // The main server's part (ids without a key) first.
  final ranked = [...parts]..sort((a, b) => (_isMain(a) ? 0 : 1).compareTo(_isMain(b) ? 0 : 1));
  for (final part in ranked) {
    for (final s in part.series) {
      final n = name(s.key);
      final known = keyOf[n];
      if (known == null || yearless(known) && !yearless(s.key) && !ranked.first.series.any((x) => x.key == known)) {
        keyOf[n] = s.key;
      }
    }
  }
  String canonical(String key) {
    final known = keyOf[name(key)];
    if (known == null || known == key) return key;
    // Only a missing year is filled in; two different years are two shows.
    return yearless(key) || yearless(known) ? known : key;
  }

  return [
    for (final part in parts)
      if (part.series.every((s) => canonical(s.key) == s.key))
        part
      else
        LibraryIndex(
          series: [for (final s in part.series) s.withKey(canonical(s.key))],
          episodes: [for (final e in part.episodes) e.seriesKey == null ? e : e.withSeriesKey(canonical(e.seriesKey!))],
          movies: part.movies,
          commercials: part.commercials,
          songs: part.songs,
          musicVideos: part.musicVideos,
          fetchedAt: part.fetchedAt,
          rootsByItem: part.rootsByItem,
          roots: part.roots,
          missingRoots: part.missingRoots,
        )
  ];
}

bool _isMain(LibraryIndex part) =>
    [...part.episodes, ...part.movies, ...part.series.map((s) => s.id)].map((e) => e is MediaEntry ? e.id : e as String).any((id) => !id.contains('~'));

String _key(String id) {
  final i = id.indexOf('~');
  return i < 0 ? '' : id.substring(0, i);
}

/// Every copy in [group] that has provider ids shares none with [e]'s.
bool _disagree(List<MediaEntry> group, MediaEntry e) {
  if (e.providerIds.isEmpty) return false;
  final mine = e.providerIds.toSet();
  final known = [for (final c in group) if (c.providerIds.isNotEmpty) c];
  return known.isNotEmpty && known.every((c) => !c.providerIds.any(mine.contains));
}

/// One entry from a group of copies (in Play from order).
MediaEntry _one(List<MediaEntry> group, Set<String> kept) {
  if (group.length == 1) return group.single;
  final primary = group.firstWhere((e) => kept.contains(e.id), orElse: () => group.first);
  final added = [for (final e in group) ?e.added]..sort();
  return primary.merged(
    primary: primary.copy,
    alternates: [for (final e in group) if (!identical(e, primary)) e.copy],
    playCount: group.map((e) => e.playCount).reduce((a, b) => a > b ? a : b),
    added: added.firstOrNull,
    providerIds: {for (final e in group) ...e.providerIds}.toList(),
  );
}
