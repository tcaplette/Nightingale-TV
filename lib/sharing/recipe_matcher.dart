import 'dart:isolate';

import '../channels/program_block.dart';
import '../library/library_index.dart';
import 'channel_recipe.dart';

/// A recipe rebuilt from the receiver's library: its programs as the
/// receiver's item ids, in the recipe's order, and how many matched.
class RecipeMatch {
  const RecipeMatch({
    required this.playlist,
    required this.blockPlaylists,
    required this.blockLineups,
    required this.matched,
    required this.total,
  });

  final List<String> playlist;

  /// Per recipe block, in its order.
  final List<List<String>> blockPlaylists;
  final List<List<LineupSlot>> blockLineups;
  final int matched;
  final int total;

  bool get none => matched == 0;
}

/// Matches a [ChannelRecipe] against a library (channel-sharing D3):
/// - shows by a shared provider id, else by the media-servers "same show"
///   rule (equal cleaned name, and equal years or one missing), unless a
///   provider gives them different ids;
/// - episodes by their matched show's season and episode number, or by
///   cleaned title within the show when they have no numbers;
/// - movies by a shared provider id, else by equal cleaned title and equal
///   year. A movie without a year never matches by title.
///
/// Pure: the same recipe and library always give the same match.
class RecipeMatcher {
  RecipeMatcher(this.library);

  final LibraryIndex library;

  /// Above this many programs, [run] matches in another isolate.
  static const isolateAbove = 2000;

  /// [recipe] matched against [library], off the main isolate for big
  /// recipes (as `IndexBuilder` scans).
  static Future<RecipeMatch> run(ChannelRecipe recipe, LibraryIndex library) async {
    if (recipe.total <= isolateAbove) return RecipeMatcher(library).match(recipe);
    return Isolate.run(() => RecipeMatcher(library).match(recipe));
  }

  late final Map<String, String> _showByProvider = {
    for (final s in library.series)
      for (final p in s.providerIds) p: s.key,
  };

  late final Map<String, List<SeriesEntry>> _showsByName = () {
    final map = <String, List<SeriesEntry>>{};
    for (final s in library.series) {
      if (s.isUnknown) continue;
      map.putIfAbsent(ShowIdentity.of(s.name, year: s.year).key, () => []).add(s);
    }
    return map;
  }();

  late final Map<String, Map<(int, int), String>> _episodesByNumber = () {
    final map = <String, Map<(int, int), String>>{};
    for (final e in library.episodes) {
      final key = e.seriesKey, season = e.season, episode = e.episode;
      if (key == null || season == null || episode == null) continue;
      map.putIfAbsent(key, () => {}).putIfAbsent((season, episode), () => e.id);
    }
    return map;
  }();

  late final Map<String, Map<String, String>> _episodesByTitle = () {
    final map = <String, Map<String, String>>{};
    for (final e in library.episodes) {
      final key = e.seriesKey;
      if (key == null) continue;
      map.putIfAbsent(key, () => {}).putIfAbsent(cleanTitle(e.title), () => e.id);
    }
    return map;
  }();

  late final Map<String, MediaEntry> _movieByProvider = {
    for (final m in library.movies.reversed)
      for (final p in m.providerIds) p: m,
  };

  late final Map<String, String> _movieByTitle = () {
    final map = <String, String>{};
    for (final m in library.movies) {
      if (m.year == null) continue;
      map.putIfAbsent('${cleanTitle(m.title)}|${m.year}', () => m.id);
    }
    return map;
  }();

  /// A title for comparing: lower case, `&` as "and", punctuation as
  /// spaces, single spaces.
  static String cleanTitle(String t) => t
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  /// The library's show key for [show], or null.
  String? showKey(RecipeShow show) {
    for (final p in show.ids) {
      if (_showByProvider[p] case final key?) return key;
    }
    final identity = ShowIdentity.of(show.name, year: show.year);
    final candidates = _showsByName[identity.key] ?? const <SeriesEntry>[];
    bool usable(SeriesEntry s) => ShowIdentity.providersAgree(show.ids, s.providerIds) != false;
    final year = identity.year;
    return (candidates.where((s) => usable(s) && year != null && s.year == year).firstOrNull ??
            candidates.where((s) => usable(s) && (year == null || s.year == null)).firstOrNull)
        ?.key;
  }

  /// The receiver's item for [item], or null.
  String? itemId(RecipeItem item, List<String?> showKeys) {
    if (item.isMovie) {
      for (final p in item.ids) {
        if (_movieByProvider[p] case final m?) return m.id;
      }
      if (item.year == null) return null;
      final id = _movieByTitle['${cleanTitle(item.title)}|${item.year}'];
      // Known to the same provider under another id: a different movie.
      if (id != null && item.ids.isNotEmpty) {
        final m = library[id]!;
        if (ShowIdentity.providersAgree(item.ids, m.providerIds) == false) return null;
      }
      return id;
    }
    final show = item.show!;
    final key = show >= 0 && show < showKeys.length ? showKeys[show] : null;
    if (key == null) return null;
    final season = item.season, episode = item.episode;
    if (season != null && episode != null) return _episodesByNumber[key]?[(season, episode)];
    return _episodesByTitle[key]?[cleanTitle(item.title)];
  }

  RecipeMatch match(ChannelRecipe recipe) {
    final keys = [for (final s in recipe.shows) showKey(s)];
    var matched = 0;
    List<String> ids(List<RecipeItem> items) {
      final out = <String>[];
      for (final i in items) {
        if (itemId(i, keys) case final id?) {
          out.add(id);
          matched++;
        }
      }
      return out;
    }

    final playlist = ids(recipe.items);
    final blockPlaylists = [for (final b in recipe.blocks) ids(b.items)];
    final lineups = [
      for (final b in recipe.blocks)
        [
          for (final l in b.lineup)
            if (l.show >= 0 && l.show < keys.length && keys[l.show] != null)
              LineupSlot(seriesKey: keys[l.show]!, count: l.count),
        ],
    ];
    return RecipeMatch(
      playlist: playlist,
      blockPlaylists: blockPlaylists,
      blockLineups: lineups,
      matched: matched,
      total: recipe.total,
    );
  }
}
