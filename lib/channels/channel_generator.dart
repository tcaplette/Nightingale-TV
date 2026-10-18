import 'dart:math';

import '../library/library_index.dart';
import 'channel.dart';

/// Merges the many spellings metadata providers use for the same genre.
String normalizeGenre(String raw) {
  final g = raw.trim().toLowerCase();
  const map = {
    'action': 'Action & Adventure',
    'adventure': 'Action & Adventure',
    'action & adventure': 'Action & Adventure',
    'action and adventure': 'Action & Adventure',
    'science fiction': 'Sci-Fi & Fantasy',
    'sci-fi': 'Sci-Fi & Fantasy',
    'sci-fi & fantasy': 'Sci-Fi & Fantasy',
    'fantasy': 'Sci-Fi & Fantasy',
    'children': 'Kids',
    'kids': 'Kids',
    'animation': 'Animation',
    'anime': 'Animation',
    'comedy': 'Comedy',
    'sitcom': 'Comedy',
    'family': 'Family',
    'drama': 'Drama',
    'crime': 'Crime',
    'mystery': 'Mystery',
    'thriller': 'Thriller',
    'suspense': 'Thriller',
    'horror': 'Horror',
    'romance': 'Romance',
    'documentary': 'Documentary',
    'music': 'Music',
    'musical': 'Music',
    'reality': 'Reality',
    'game show': 'Game Shows',
    'western': 'Western',
    'war': 'War',
    'history': 'History',
    'news': 'News',
    'talk': 'Talk',
    'soap': 'Soap',
    'sport': 'Sports',
    'sports': 'Sports',
  };
  return map[g] ?? raw.trim();
}

/// Cable-style names and icons for genre channels.
const _genreStyle = <String, (String name, String icon)>{
  'Kids': ('Kids Zone', 'child_care'),
  'Animation': ('Toon TV', 'animation'),
  'Comedy': ('Laugh Track', 'theater_comedy'),
  'Family': ('Family Room', 'family_restroom'),
  'Action & Adventure': ('Adventure TV', 'bolt'),
  'Sci-Fi & Fantasy': ('Sci-Fi & Fantasy', 'rocket_launch'),
  'Mystery': ('Mystery TV', 'search'),
  'Drama': ('Drama Central', 'theaters'),
  'Crime': ('Crime & Justice', 'local_police'),
  'Thriller': ('Thrill TV', 'visibility'),
  'Horror': ('Fright Night', 'nightlight'),
  'Romance': ('Romance TV', 'favorite'),
  'Documentary': ('Discovery Zone', 'explore'),
  'Music': ('Music TV', 'music_note'),
  'Reality': ('Reality TV', 'videocam'),
  'Game Shows': ('Game Show TV', 'casino'),
  'Western': ('Frontier TV', 'landscape'),
  'History': ('History TV', 'account_balance'),
  'Sports': ('Sports TV', 'sports_football'),
  'News': ('News TV', 'newspaper'),
};

class GeneratorOptions {
  const GeneratorOptions({
    this.minSeriesPerGenre = 2,
    this.minEpisodesPerGenre = 30,
    this.minEpisodesForShowChannel = 60,
    this.maxShowChannels = 6,
    this.minMoviesForMovieChannel = 5,
    this.minMoviesPerMovieGenre = 12,
    this.overlapThreshold = 0.85,
  });

  final int minSeriesPerGenre;
  final int minEpisodesPerGenre;
  final int minEpisodesForShowChannel;
  final int maxShowChannels;
  final int minMoviesForMovieChannel;
  final int minMoviesPerMovieGenre;

  /// Skip a genre channel whose shows overlap an earlier one this much
  /// (Jaccard index). Small libraries tag the same shows with many genres.
  final double overlapThreshold;
}

/// Builds the default lineup from the library, the way a cable company
/// would: a mix channel, genre channels, show marathons, movie channels.
class ChannelGenerator {
  ChannelGenerator(this.library, {this.options = const GeneratorOptions(), DateTime? anchor})
      : anchor = anchor ?? _defaultAnchor();

  final LibraryIndex library;
  final GeneratorOptions options;
  final DateTime anchor;

  /// Local midnight today, so the lineup "started" at a tidy time.
  static DateTime _defaultAnchor() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<Channel> generate() {
    final channels = <Channel>[];
    var number = 2;

    void add(String id, String name, ChannelIcon icon, ChannelSource source, PlaybackOrder order) {
      final playlist = buildPlaylist(library, source, order, seed: stableHash(id));
      if (playlist.isEmpty) return;
      channels.add(Channel(
        id: id,
        number: number++,
        name: name,
        icon: icon,
        source: source,
        order: order,
        playlist: playlist,
        anchor: anchor,
      ));
    }

    if (library.series.length > 1) {
      add('auto:all-shows', 'All Shows', const ChannelIcon.builtin('tv'),
          const ChannelSource(), PlaybackOrder.random);
    }

    // Genre channels, biggest first, skipping near-duplicates.
    final showsByGenre = <String, Set<String>>{};
    for (final s in library.series) {
      for (final g in s.genres.map(normalizeGenre)) {
        showsByGenre.putIfAbsent(g, () => {}).add(s.key);
      }
    }
    int episodeCount(Set<String> shows) =>
        shows.fold(0, (n, k) => n + (library.episodesBySeries[k]?.length ?? 0));
    final genres = showsByGenre.entries
        .where((e) =>
            e.value.length >= options.minSeriesPerGenre &&
            episodeCount(e.value) >= options.minEpisodesPerGenre &&
            // A genre covering every show is just "All Shows" again.
            e.value.length < library.series.length)
        .toList()
      ..sort((a, b) => episodeCount(b.value).compareTo(episodeCount(a.value)));
    final usedShowSets = <Set<String>>[];
    for (final g in genres) {
      if (usedShowSets.any((used) => _jaccard(used, g.value) >= options.overlapThreshold)) continue;
      usedShowSets.add(g.value);
      final style = _genreStyle[g.key] ?? (g.key, 'live_tv');
      add('auto:genre:${g.key}', style.$1, ChannelIcon.builtin(style.$2),
          ChannelSource(genres: [g.key]), PlaybackOrder.cyclic);
    }

    // Marathon channels for the biggest shows.
    final bigShows = library.series
        .where((s) =>
            (library.episodesBySeries[s.key]?.length ?? 0) >= options.minEpisodesForShowChannel)
        .toList()
      ..sort((a, b) => library.episodesBySeries[b.key]!.length
          .compareTo(library.episodesBySeries[a.key]!.length));
    for (final s in bigShows.take(options.maxShowChannels)) {
      add(
        'auto:show:${s.key}',
        s.name,
        s.hasLogo
            ? ChannelIcon(kind: ChannelIconKind.jellyfin, value: s.id)
            : const ChannelIcon.builtin('live_tv'),
        ChannelSource(seriesKeys: [s.key]),
        PlaybackOrder.cyclic,
      );
    }

    // Movie channels.
    if (library.movies.length >= options.minMoviesForMovieChannel) {
      add('auto:movies', 'Movie Channel', const ChannelIcon.builtin('movie'),
          const ChannelSource(includeEpisodes: false, includeMovies: true), PlaybackOrder.random);
      final moviesByGenre = <String, int>{};
      for (final m in library.movies) {
        for (final g in m.genres.map(normalizeGenre).toSet()) {
          moviesByGenre[g] = (moviesByGenre[g] ?? 0) + 1;
        }
      }
      final movieGenres = moviesByGenre.entries
          .where((e) =>
              e.value >= options.minMoviesPerMovieGenre && e.value < library.movies.length)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final g in movieGenres.take(3)) {
        add('auto:movies:${g.key}', '${g.key} Movies',
            ChannelIcon.builtin(_genreStyle[g.key]?.$2 ?? 'local_movies'),
            ChannelSource(genres: [g.key], includeEpisodes: false, includeMovies: true),
            PlaybackOrder.random);
      }
    }
    return channels;
  }

  static double _jaccard(Set<String> a, Set<String> b) =>
      a.intersection(b).length / a.union(b).length;
}

/// FNV-1a; unlike String.hashCode it is stable across runs and SDK versions,
/// so regenerating a channel gives the same lineup.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Resolves [source] against the library and orders it.
List<String> buildPlaylist(LibraryIndex library, ChannelSource source, PlaybackOrder order,
    {required int seed}) {
  final genres = source.genres.toSet();
  bool genreMatch(Iterable<String> itemGenres) =>
      genres.isEmpty || itemGenres.map(normalizeGenre).any(genres.contains);

  final shows = <String, List<MediaEntry>>{};
  if (source.includeEpisodes) {
    for (final s in library.series) {
      final wanted = source.seriesKeys.isNotEmpty
          ? source.seriesKeys.contains(s.key)
          : genreMatch(s.genres);
      final eps = library.episodesBySeries[s.key];
      if (wanted && eps != null && eps.isNotEmpty) shows[s.key] = eps;
    }
  }
  final movies = source.includeMovies
      ? library.movies.where((m) => genreMatch(m.genres)).toList()
      : const <MediaEntry>[];

  final rng = Random(seed);
  final List<MediaEntry> ordered;
  switch (order) {
    case PlaybackOrder.cyclic:
      ordered = _interleave(shows, rng);
      // Movies have no airing order; slot them in shuffled.
      if (movies.isNotEmpty) {
        final shuffled = [...movies]..shuffle(rng);
        ordered.addAll(shuffled);
      }
    case PlaybackOrder.random:
      ordered = _spreadShuffle([for (final eps in shows.values) ...eps, ...movies], rng);
  }
  return [for (final e in ordered) e.id];
}

/// Spreads each show's episodes evenly across the loop, in airing order.
/// A 175-episode show and a 6-episode show both play every episode exactly
/// once per loop, with the short show's episodes spaced out rather than
/// bunched up or endlessly repeated.
List<MediaEntry> _interleave(Map<String, List<MediaEntry>> shows, Random rng) {
  final keyed = <(double, double, MediaEntry)>[];
  for (final eps in shows.values) {
    final phase = rng.nextDouble();
    for (var i = 0; i < eps.length; i++) {
      keyed.add(((i + phase) / eps.length, rng.nextDouble(), eps[i]));
    }
  }
  keyed.sort((a, b) {
    final byPosition = a.$1.compareTo(b.$1);
    return byPosition != 0 ? byPosition : a.$2.compareTo(b.$2);
  });
  return [for (final k in keyed) k.$3];
}

/// Shuffle, then nudge items so the same show rarely airs back-to-back.
List<MediaEntry> _spreadShuffle(List<MediaEntry> items, Random rng) {
  final list = [...items]..shuffle(rng);
  String groupOf(MediaEntry e) => e.seriesKey ?? e.id;
  for (var i = 1; i < list.length; i++) {
    if (groupOf(list[i]) != groupOf(list[i - 1])) continue;
    for (var j = i + 1; j < list.length; j++) {
      if (groupOf(list[j]) != groupOf(list[i - 1])) {
        final t = list[i];
        list[i] = list[j];
        list[j] = t;
        break;
      }
    }
  }
  return list;
}
