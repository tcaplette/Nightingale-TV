import 'dart:math';

import '../commercials/break_plan.dart';
import '../library/library_index.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/profile.dart';
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

/// Merges the many spellings music metadata uses for the same genre
/// ("Hip Hop/Rap" and "Rap" are Hip-Hop).
String normalizeMusicGenre(String raw) {
  final g = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const map = {
    'hip hop': 'Hip-Hop',
    'hip-hop': 'Hip-Hop',
    'hiphop': 'Hip-Hop',
    'rap': 'Hip-Hop',
    'hip hop/rap': 'Hip-Hop',
    'hip-hop/rap': 'Hip-Hop',
    'rap/hip hop': 'Hip-Hop',
    'r&b': 'R&B',
    'rnb': 'R&B',
    'r and b': 'R&B',
    'r & b': 'R&B',
    'rhythm and blues': 'R&B',
    'rhythm & blues': 'R&B',
    'r&b/soul': 'R&B',
    'soul': 'Soul',
    'rock': 'Rock',
    'classic rock': 'Rock',
    'rock & roll': 'Rock',
    "rock 'n' roll": 'Rock',
    'rock and roll': 'Rock',
    'hard rock': 'Rock',
    'alternative': 'Alternative',
    'alternative rock': 'Alternative',
    'alt rock': 'Alternative',
    'alt-rock': 'Alternative',
    'indie': 'Indie',
    'indie rock': 'Indie',
    'indie pop': 'Indie',
    'pop': 'Pop',
    'pop rock': 'Pop',
    'dance': 'Dance',
    'dance-pop': 'Dance',
    'dance pop': 'Dance',
    'electronic': 'Electronic',
    'electronica': 'Electronic',
    'edm': 'Electronic',
    'metal': 'Metal',
    'heavy metal': 'Metal',
    'punk': 'Punk',
    'punk rock': 'Punk',
    'country': 'Country',
    'jazz': 'Jazz',
    'blues': 'Blues',
    'classical': 'Classical',
    'reggae': 'Reggae',
    'latin': 'Latin',
    'folk': 'Folk',
    'soundtrack': 'Soundtrack',
    'soundtracks': 'Soundtrack',
    'ost': 'Soundtrack',
    'score': 'Soundtrack',
    'oldies': 'Oldies',
  };
  return map[g] ?? raw.trim();
}

/// The decade (its first year) of [year], from the 1950s to the 2020s.
int? decadeOf(int? year) {
  if (year == null || year < 1950 || year >= 2030) return null;
  return year ~/ 10 * 10;
}

/// "50s" … "90s", then "2000s", "2010s", "2020s".
String decadeName(int decade) => decade < 2000 ? '${decade % 100}s' : '${decade}s';

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
    this.minMusicVideos = 40,
    this.minSongs = 150,
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

  /// What each genre or decade music channel needs at least, so a tagged
  /// library doesn't spawn dozens of near-empty channels. "Music Videos" and
  /// "Music Radio" need only one.
  final int minMusicVideos;
  final int minSongs;
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
    var number = 1;

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
        // Automatic breaks pad slots for shows; a padded 3-minute song isn't radio.
        commercialPlan: source.isMusic ? BreakPlan.off : null,
      ));
    }

    if (library.series.length > 1) {
      add('auto:all-shows', 'All Shows', const ChannelIcon.builtin('tv'),
          const ChannelSource(), PlaybackOrder.random);
    }

    // Marathon channels for the biggest shows. Those shows air there (and
    // on All Shows), leaving the genre channels to the others.
    int episodesOf(String show) => library.episodesBySeries[show]?.length ?? 0;
    final bigShows = (library.series.where((s) => !s.isUnknown && episodesOf(s.key) >= options.minEpisodesForShowChannel).toList()
          ..sort((a, b) => episodesOf(b.key).compareTo(episodesOf(a.key))))
        .take(options.maxShowChannels)
        .toList();
    final marathon = {for (final s in bigShows) s.key};

    // Genre channels, biggest first, skipping near-duplicates.
    final showsByGenre = <String, Set<String>>{};
    for (final s in library.series) {
      for (final g in s.genres.map(normalizeGenre)) {
        showsByGenre.putIfAbsent(g, () => {}).add(s.key);
      }
    }
    int episodeCount(Set<String> shows) => shows.fold(0, (n, k) => n + episodesOf(k));
    final genres = showsByGenre.entries
        .where((e) =>
            e.value.length >= options.minSeriesPerGenre &&
            episodeCount(e.value) >= options.minEpisodesPerGenre &&
            // A genre covering every show is just "All Shows" again.
            e.value.length < library.series.length)
        .toList()
      ..sort((a, b) => episodeCount(b.value).compareTo(episodeCount(a.value)));
    final usedShowSets = <Set<String>>[];
    final candidates = <String>[];
    for (final g in genres) {
      if (usedShowSets.any((used) => _jaccard(used, g.value) >= options.overlapThreshold)) continue;
      usedShowSets.add(g.value);
      candidates.add(g.key);
    }
    // Each show airs on one genre channel; a genre left without enough of
    // its own gives way.
    final showsOf = {for (final g in candidates) g: showsByGenre[g]!.difference(marathon)};
    final genreShows = _pickAndShare(candidates, candidates.length, showsOf, episodesOf,
        (shows) => shows.length < options.minSeriesPerGenre || episodeCount(shows) < options.minEpisodesPerGenre);
    for (final MapEntry(key: g, value: mine) in genreShows.entries) {
      final style = _genreStyle[g] ?? (g, 'live_tv');
      add('auto:genre:$g', style.$1, ChannelIcon.builtin(style.$2),
          ChannelSource(genres: [g], excluded: _sorted(showsByGenre[g]!.difference(mine))), PlaybackOrder.cyclic);
    }

    for (final s in bigShows) {
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

    // Movie channels: every movie, then the biggest genres, each movie on
    // one of them.
    if (library.movies.length >= options.minMoviesForMovieChannel) {
      add('auto:movies', 'Movie Channel', const ChannelIcon.builtin('movie'),
          const ChannelSource(includeEpisodes: false, includeMovies: true), PlaybackOrder.random);
      final moviesByGenre = <String, Set<String>>{};
      for (final m in library.movies) {
        for (final g in m.genres.map(normalizeGenre)) {
          moviesByGenre.putIfAbsent(g, () => {}).add(m.id);
        }
      }
      final movieGenres = [
        for (final e in moviesByGenre.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)))
          if (e.value.length >= options.minMoviesPerMovieGenre && e.value.length < library.movies.length) e.key,
      ];
      final shared = _pickAndShare(movieGenres, 3, moviesByGenre, (_) => 1,
          (movies) => movies.length < options.minMoviesPerMovieGenre);
      for (final MapEntry(key: g, value: mine) in shared.entries) {
        add(
            'auto:movies:$g',
            '$g Movies',
            ChannelIcon.builtin(_genreStyle[g]?.$2 ?? 'local_movies'),
            ChannelSource(
                genres: [g],
                includeEpisodes: false,
                includeMovies: true,
                excluded: _sorted(moviesByGenre[g]!.difference(mine))),
            PlaybackOrder.random);
      }
    }

    // Music channels: all, then the biggest genres and decades.
    void music(List<MediaEntry> items, {required bool videos}) {
      final min = videos ? options.minMusicVideos : options.minSongs;
      if (items.isEmpty) return;
      final kind = videos ? 'music-videos' : 'radio';
      final icon = ChannelIcon.builtin(videos ? 'music_video' : 'radio');
      String named(String what) => videos ? '$what Music Videos' : '$what Radio';
      ChannelSource source({List<String> genres = const [], List<int> decades = const []}) => ChannelSource(
          genres: genres,
          decades: decades,
          includeEpisodes: false,
          includeSongs: !videos,
          includeMusicVideos: videos);
      final used = <Set<String>>[
        {for (final m in items) m.id}
      ];
      add('auto:$kind', videos ? 'Music Videos' : 'Music Radio', icon, source(), PlaybackOrder.random);
      final byGenre = <String, Set<String>>{};
      final byDecade = <int, Set<String>>{};
      for (final m in items) {
        for (final g in m.genres.map(normalizeMusicGenre)) {
          byGenre.putIfAbsent(g, () => {}).add(m.id);
        }
        if (decadeOf(m.year) case final d?) byDecade.putIfAbsent(d, () => {}).add(m.id);
      }
      void pick<K>(Map<K, Set<String>> groups, int max, void Function(K key) addChannel) {
        final big = groups.entries.where((e) => e.value.length >= min).toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        var added = 0;
        for (final e in big) {
          if (added == max) break;
          if (used.any((u) => _jaccard(u, e.value) >= options.overlapThreshold)) continue;
          used.add(e.value);
          addChannel(e.key);
          added++;
        }
      }

      pick(byGenre, videos ? 3 : 4,
          (g) => add('auto:$kind:genre:$g', named(g), icon, source(genres: [g]), PlaybackOrder.random));
      pick(byDecade, 3,
          (d) => add('auto:$kind:decade:$d', named(decadeName(d)), icon, source(decades: [d]), PlaybackOrder.random));
    }

    final before = channels.length;
    music(library.musicVideos, videos: true);
    music(library.songs, videos: false);
    PlaybackDiagnostics.note('MUSIC', '${library.musicVideos.length} music videos, ${library.songs.length} songs: '
        '${[for (final c in channels.skip(before)) '${c.name} (${c.playlist.length})'].join(', ')}');
    nameApart(library, channels);
    return channels;
  }

  /// Gives generated [channels] that share a name their own (lineup-dedup
  /// D4): the first channel of the name that isn't a show's keeps it (one
  /// in [keep], the lineup's own, when there is one), the others add their
  /// kind ("Name (Show)"), or a show's year next to a show of the same name.
  static void nameApart(LibraryIndex library, List<Channel> channels, {Set<String> keep = const {}}) {
    final byName = <String, List<Channel>>{};
    for (final c in channels) {
      byName.putIfAbsent(c.name.toLowerCase(), () => []).add(c);
    }
    final taken = byName.keys.toSet();
    bool isShow(Channel c) => c.id.startsWith('auto:show:');
    for (final group in byName.values.where((g) => g.length > 1)) {
      final kept = group.where((c) => keep.contains(c.id)).firstOrNull ??
          group.where((c) => !isShow(c)).firstOrNull ??
          group.first;
      for (final c in group) {
        if (c == kept || keep.contains(c.id)) continue;
        final year = isShow(c) && isShow(kept) ? library.seriesByKey[c.source.seriesKeys.firstOrNull]?.year : null;
        final label = year?.toString() ?? _kindOf(c);
        var name = '${c.name} ($label)';
        for (var n = 2; taken.contains(name.toLowerCase()); n++) {
          name = '${c.name} ($label $n)';
        }
        taken.add(name.toLowerCase());
        c.name = name;
      }
    }
  }

  static String _kindOf(Channel c) => switch (c.id) {
        final id when id.startsWith('auto:show:') => 'Show',
        final id when id.startsWith('auto:movies') => 'Movies',
        final id when id.startsWith('auto:music-videos') => 'Music Videos',
        final id when id.startsWith('auto:radio') => 'Radio',
        _ => 'Shows',
      };

  static double _jaccard(Set<String> a, Set<String> b) =>
      a.intersection(b).length / a.union(b).length;

  static List<String> _sorted(Iterable<String> ids) => [...ids]..sort();

  /// Spreads the library over [channels]' generated genre channels again,
  /// as a refresh does: each show airs on one show genre channel (none,
  /// when it has a show channel of its own), each movie on one movie genre
  /// channel. Sets their [ChannelSource.excluded]. Hidden channels count
  /// too, after the visible ones: they take what no visible channel has.
  ///
  /// A genre channel left under [GeneratorOptions]' minimums, as [generate]
  /// applies them, is thin: its titles go to the other channels of its
  /// genres and it plays nothing. Returns the thin channels' ids.
  static Set<String> spreadTitles(LibraryIndex library, List<Channel> channels,
      {GeneratorOptions options = const GeneratorOptions()}) {
    List<Channel> generated(String prefix) => [
          for (final c in channels)
            if (c.auto && !c.isLive && c.id.startsWith(prefix) && c.source.genres.isNotEmpty) c,
        ]..sort((a, b) => a.number.compareTo(b.number));
    int episodesOf(String show) => library.episodesBySeries[show]?.length ?? 0;
    // Shows big enough for their own channel air there instead.
    final marathon = {
      for (final c in channels)
        if (c.auto && c.id.startsWith('auto:show:'))
          for (final k in c.source.seriesKeys)
            if (library.seriesByKey[k] case final s? when !s.isUnknown && episodesOf(k) >= options.minEpisodesForShowChannel)
              k,
    };
    final thin = <String>{};
    void spread(List<Channel> genreChannels, Map<String, Set<String>> titlesOf, Set<String> skip,
        int Function(String) size, bool Function(Set<String>) tooThin) {
      final owned = {...skip};
      for (final hidden in [false, true]) {
        final group = [for (final c in genreChannels) if (c.hidden == hidden) c];
        final shared = _pickAndShare([for (final c in group) c.id], group.length,
            {for (final c in group) c.id: titlesOf[c.id]!.difference(owned)}, size, tooThin);
        for (final c in group) {
          final mine = shared[c.id];
          if (mine == null) thin.add(c.id);
          owned.addAll(mine ?? const {});
          c.source = c.source.copyWith(excluded: _sorted(titlesOf[c.id]!.difference(mine ?? const {})));
        }
      }
    }

    final showChannels = generated('auto:genre:');
    spread(showChannels, {
      for (final c in showChannels)
        c.id: {
          for (final s in library.series)
            if (s.genres.map(normalizeGenre).any(c.source.genres.contains)) s.key,
        },
    }, marathon, episodesOf,
        (shows) =>
            shows.length < options.minSeriesPerGenre ||
            shows.fold(0, (n, k) => n + episodesOf(k)) < options.minEpisodesPerGenre);
    final movieChannels = generated('auto:movies:');
    spread(movieChannels, {
      for (final c in movieChannels)
        c.id: {
          for (final m in library.movies)
            if (m.genres.map(normalizeGenre).any(c.source.genres.contains)) m.id,
        },
    }, const {}, (_) => 1, (movies) => movies.length < options.minMoviesPerMovieGenre);
    return thin;
  }

  /// Picks up to [max] of [candidates] (best first) and shares their
  /// titles ([titlesOf]) between them (see [_share]). A pick left [thin]
  /// gives way to the next candidate. Returns each pick's titles, in
  /// [candidates]' order.
  static Map<String, Set<String>> _pickAndShare(List<String> candidates, int max, Map<String, Set<String>> titlesOf,
      int Function(String) size, bool Function(Set<String>) thin) {
    final left = [...candidates];
    while (true) {
      final picked = left.take(max).toList();
      final shared = _share(picked, titlesOf, size);
      String? thinnest;
      int weight(String g) => shared[g]!.fold(0, (n, t) => n + size(t));
      for (final g in picked) {
        if (thin(shared[g]!) && (thinnest == null || weight(g) < weight(thinnest))) thinnest = g;
      }
      if (thinnest == null) return shared;
      left.remove(thinnest);
    }
  }

  /// Gives each title one of [channels] it is in ([titlesOf]), so that no
  /// two channels play the same title. Titles in the fewest channels go
  /// first, the biggest ([size]) first among those, each to a channel with
  /// nothing yet, else the one with the least so far; ties go to the
  /// earlier channel. Returns each channel's titles, in [channels]' order.
  static Map<String, Set<String>> _share(
      List<String> channels, Map<String, Set<String>> titlesOf, int Function(String) size) {
    final fits = <String, List<String>>{};
    for (final c in channels) {
      for (final t in titlesOf[c] ?? const <String>{}) {
        fits.putIfAbsent(t, () => []).add(c);
      }
    }
    final titles = fits.keys.toList()
      ..sort((a, b) {
        final byFits = fits[a]!.length.compareTo(fits[b]!.length);
        if (byFits != 0) return byFits;
        final bySize = size(b).compareTo(size(a));
        return bySize != 0 ? bySize : a.compareTo(b);
      });
    final shared = {for (final c in channels) c: <String>{}};
    final load = {for (final c in channels) c: 0};
    for (final t in titles) {
      var best = fits[t]!.first;
      for (final c in fits[t]!.skip(1)) {
        final (emptyC, emptyBest) = (shared[c]!.isEmpty, shared[best]!.isEmpty);
        if (emptyC != emptyBest ? emptyC : load[c]! < load[best]!) best = c;
      }
      shared[best]!.add(t);
      load[best] = load[best]! + size(t);
    }
    return shared;
  }
}

/// A music channel's playlist holds at most this many items: a fixed
/// sample, about 150 hours of songs.
const maxMusicPlaylist = 3000;

/// The [maxMusicPlaylist] items of [items] a music channel seeded with
/// [seed] keeps: the same ones for the same library, every time.
List<MediaEntry> musicSample(List<MediaEntry> items, int seed) {
  if (items.length <= maxMusicPlaylist) return items;
  final keyed = [for (final m in items) (stableHash('$seed|${m.id}'), m)]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final k in keyed.take(maxMusicPlaylist)) k.$2];
}

/// Resolves [source] against the library and orders it.
List<String> buildPlaylist(LibraryIndex library, ChannelSource source, PlaybackOrder order,
    {required int seed}) {
  final genres = source.genres.toSet();
  final excluded = source.excluded.toSet();
  bool genreMatch(Iterable<String> itemGenres) =>
      genres.isEmpty || itemGenres.map(normalizeGenre).any(genres.contains);

  if (source.isMusic) {
    final decades = source.decades.toSet();
    bool wanted(MediaEntry m) =>
        (genres.isEmpty || m.genres.map(normalizeMusicGenre).any(genres.contains)) &&
        (decades.isEmpty || decades.contains(decadeOf(m.year)));
    final items = musicSample([
      if (source.includeMusicVideos) ...library.musicVideos.where(wanted),
      if (source.includeSongs) ...library.songs.where(wanted),
    ], seed);
    // Music always shuffles, never the same artist twice in a row.
    return [for (final e in _spreadShuffle(items, Random(seed))) e.id];
  }

  // With roots, the other choices add to them (custom-channels D2): roots
  // alone play only the roots, and an empty genre list no longer means
  // every show.
  final rooted = <String>{for (final r in source.roots) ...?library.itemsByRoot[r.itemId]};
  final byRootOnly = source.roots.isNotEmpty;
  // A minimum rating narrows everything, roots and picked shows included;
  // episodes go by their show's rating (late-night-drift D2).
  final floor = source.ratingFloor;
  bool rated(String? rating) {
    if (floor == null) return true;
    final rank = ratingRank(rating);
    return rank != null && rank >= floor.rank;
  }

  final shows = <String, List<MediaEntry>>{};
  for (final s in library.series) {
    if (!rated(s.officialRating)) continue;
    final eps = library.episodesBySeries[s.key];
    if (eps == null || eps.isEmpty) continue;
    final whole = source.includeEpisodes &&
        (source.seriesKeys.isNotEmpty
            ? source.seriesKeys.contains(s.key)
            : !(byRootOnly && genres.isEmpty) && !excluded.contains(s.key) && genreMatch(s.genres));
    final picked = whole ? eps : [for (final e in eps) if (rooted.contains(e.id)) e];
    if (picked.isNotEmpty) shows[s.key] = picked;
  }
  final movies = [
    for (final m in library.movies)
      if (((source.includeMovies && genreMatch(m.genres) && !excluded.contains(m.id)) || rooted.contains(m.id)) &&
          rated(m.officialRating))
        m,
  ];

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
    case PlaybackOrder.weighted:
      ordered = _spread(_weightedShuffle([for (final eps in shows.values) ...eps, ...movies], rng));
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

/// A weighted random order (Efraimidis–Spirakis): each item's key is
/// `u^(1/w)` with `w = 1 / (1 + plays)` and `u` from [rng] in [items]'
/// order, highest key first. Every item is in it once; less played ones
/// tend to come earlier.
List<MediaEntry> _weightedShuffle(List<MediaEntry> items, Random rng) {
  final keyed = [
    for (final e in items) (pow(rng.nextDouble(), 1 + e.playCount).toDouble(), e),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final k in keyed) k.$2];
}

/// Shuffle, then nudge items so the same show (or, for music, artist)
/// rarely airs back-to-back.
List<MediaEntry> _spreadShuffle(List<MediaEntry> items, Random rng) => _spread([...items]..shuffle(rng));

/// Nudges items of [list] (in place) so the same show (or, for music,
/// artist) rarely airs back-to-back.
List<MediaEntry> _spread(List<MediaEntry> list) {
  String groupOf(MediaEntry e) => e.seriesKey ?? (e.isMusic && e.artist != null ? 'artist:${e.artist}' : e.id);
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
  // Music: an artist left back-to-back at the end moves to the first place
  // earlier on between two other artists.
  for (var i = list.length - 1; i > 0; i--) {
    if (!list[i].isMusic || groupOf(list[i]) != groupOf(list[i - 1])) continue;
    final group = groupOf(list[i]);
    for (var j = 1; j < i - 1; j++) {
      if (groupOf(list[j - 1]) != group && groupOf(list[j]) != group) {
        list.insert(j, list.removeAt(i));
        i++;
        break;
      }
    }
  }
  return list;
}

/// [loop] with [added] worked in from index [start] on, wrapping around: a
/// new item, then a few old ones (three, fewer when there are many new
/// ones), so new items air from [start] and keep turning up rather than
/// waiting for the end of the loop. The result starts at [start]; a loop
/// has no start of its own.
List<String> spliceNew(List<String> loop, List<String> added, int start) {
  if (loop.isEmpty) return [...added];
  final gap = (loop.length ~/ (added.length + 1)).clamp(1, 3);
  final from = start % loop.length;
  final old = [...loop.sublist(from), ...loop.sublist(0, from)];
  final out = <String>[];
  var next = 0;
  for (var i = 0; i < old.length; i++) {
    if (i % gap == 0 && next < added.length) out.add(added[next++]);
    out.add(old[i]);
  }
  return out..addAll(added.skip(next));
}
