import 'dart:math';

import '../commercials/break_plan.dart';
import '../library/library_index.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/profile.dart';
import 'channel.dart';
import 'program_block.dart';

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
    this.showsPerShowChannel = 8,
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

  /// One show channel for every this many named shows (cable-lineup D2),
  /// up to [maxShowChannels].
  final int showsPerShowChannel;
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

  /// How many show channels [library] has room for: one per
  /// [showsPerShowChannel] named shows, at most [maxShowChannels].
  int showChannelCap(LibraryIndex library) =>
      min(maxShowChannels, library.series.where((s) => !s.isUnknown).length ~/ showsPerShowChannel);
}

/// Builds the default lineup from the library, the way a cable company
/// would: a mix channel, genre channels, show marathons, movie channels.
class ChannelGenerator {
  ChannelGenerator(this.library, {this.options = const GeneratorOptions(), DateTime? anchor, this.planOf})
      : anchor = anchor ?? _defaultAnchor();

  final LibraryIndex library;
  final GeneratorOptions options;
  final DateTime anchor;

  /// The break plan a channel will air with, which sizes its Daytime
  /// lineup; slots are runtimes without it.
  final BreakPlan Function(Channel channel)? planOf;

  /// The generated Daytime and Evening blocks of the last [generate].
  List<ProgramBlock> blocks = const [];

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

    // Marathon channels for the biggest shows, one per 8 named shows. Those
    // shows air only there, leaving the genre channels and All Shows to the
    // others.
    int episodesOf(String show) => library.episodesBySeries[show]?.length ?? 0;
    final bigShows = (library.series.where((s) => !s.isUnknown && episodesOf(s.key) >= options.minEpisodesForShowChannel).toList()
          ..sort((a, b) => episodesOf(b.key).compareTo(episodesOf(a.key))))
        .take(options.showChannelCap(library))
        .toList();
    final marathon = {for (final s in bigShows) s.key};

    if (library.series.length > 1) {
      add('auto:all-shows', 'All Shows', const ChannelIcon.builtin('tv'),
          ChannelSource(excluded: _sorted(marathon)), PlaybackOrder.random);
    }

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
    // Each show airs on the channel of its first listed genre; a genre left
    // without enough of its own gives way.
    final showsOf = {for (final g in candidates) g: showsByGenre[g]!.difference(marathon)};
    final genreShows = _pickAndShare(candidates, candidates.length, showsOf, episodesOf,
        (shows) => shows.length < options.minSeriesPerGenre || episodeCount(shows) < options.minEpisodesPerGenre,
        rank: (show, g) => _rank(library.seriesByKey[show]!.genres, [g]));
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

    // Movies go to the evenings of the genre channels of their first listed
    // genre (cable-lineup D5); an evening needs 12 of its own.
    final moviesByGenre = <String, Set<String>>{};
    for (final m in library.movies) {
      for (final g in m.genres.map(normalizeGenre)) {
        moviesByGenre.putIfAbsent(g, () => {}).add(m.id);
      }
    }
    final movieGenresOf = {for (final m in library.movies) m.id: m.genres};
    int movieRank(String movie, String g) => _rank(movieGenresOf[movie]!, [g]);
    bool fewMovies(Set<String> movies) => movies.length < options.minMoviesPerMovieGenre;
    final made = {for (final c in channels) c.id};
    final showGenres = [for (final g in genreShows.keys) if (made.contains('auto:genre:$g')) g];
    final evenings = _pickAndShare(showGenres, showGenres.length,
        {for (final g in showGenres) g: moviesByGenre[g] ?? const {}}, (_) => 1, fewMovies,
        rank: movieRank);
    final homed = {for (final movies in evenings.values) ...movies};

    // Movie channels: every movie, then the biggest genres of the movies
    // with no evening, each movie on one of them.
    if (library.movies.length >= options.minMoviesForMovieChannel) {
      add('auto:movies', 'Movie Channel', const ChannelIcon.builtin('movie'),
          const ChannelSource(includeEpisodes: false, includeMovies: true), PlaybackOrder.random);
      final unhomed = {for (final e in moviesByGenre.entries) e.key: e.value.difference(homed)};
      final movieGenres = [
        for (final e in unhomed.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)))
          if (e.value.length >= options.minMoviesPerMovieGenre && e.value.length < library.movies.length) e.key,
      ];
      final shared = _pickAndShare(movieGenres, 3, unhomed, (_) => 1, fewMovies, rank: movieRank);
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
    blocks = dayparts(library, channels, {for (final e in evenings.entries) 'auto:genre:${e.key}': e.value},
        anchor: anchor, planOf: planOf, options: options);
    return channels;
  }

  static const daytimeStart = 6 * 60, eveningStart = 18 * 60, eveningEnd = 0;

  /// The id of [channelId]'s generated [part] block.
  static String daypartId(String channelId, Daypart part) => 'lineup:${part.name}:$channelId';

  /// Whether [c] is a generated show genre channel, the only kind with
  /// dayparts.
  static bool isGenreChannel(Channel c) => c.auto && !c.isLive && c.id.startsWith('auto:genre:');

  /// The Daytime and Evening blocks (cable-dayparts) of [channels]'
  /// generated genre channels, airing from [anchor]. [evenings] holds each
  /// channel's own movies (by id), as [spreadTitles] shares them; a channel
  /// with fewer than [GeneratorOptions.minMoviesPerMovieGenre] gets no
  /// Evening.
  ///
  /// Daytime is a lineup of two-episode stacks of the channel's shows, the
  /// most episodes first, as many as fit 12 hours by their average slot
  /// under [planOf]'s plan (at least one).
  static List<ProgramBlock> dayparts(LibraryIndex library, List<Channel> channels, Map<String, Set<String>> evenings,
      {required DateTime anchor, BreakPlan Function(Channel channel)? planOf, GeneratorOptions options = const GeneratorOptions()}) {
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    const everyDay = {1, 2, 3, 4, 5, 6, 7};
    final blocks = <ProgramBlock>[];
    for (final c in channels) {
      if (!isGenreChannel(c)) continue;
      final plan = planOf?.call(c) ?? BreakPlan.off;
      final shows = {for (final id in c.playlist) ?library[id]?.seriesKey};
      int episodesOf(String show) => library.episodesBySeries[show]?.length ?? 0;
      final biggest = [for (final k in shows) if (episodesOf(k) > 0) k]
        ..sort((a, b) {
          final bySize = episodesOf(b).compareTo(episodesOf(a));
          return bySize != 0 ? bySize : a.compareTo(b);
        });
      Duration averageSlot(String show) {
        final eps = library.episodesBySeries[show]!;
        final total = eps.fold(0, (n, e) => n + resolve(plan, e.runtime).slotLength.inMicroseconds);
        return Duration(microseconds: total ~/ eps.length);
      }

      final lineup = <String>[];
      var used = Duration.zero;
      const daytime = Duration(hours: 12);
      for (final show in biggest) {
        final stack = averageSlot(show) * 2;
        if (lineup.isNotEmpty && used + stack > daytime) break;
        lineup.add(show);
        used += stack;
      }
      if (lineup.isNotEmpty) {
        blocks.add(ProgramBlock(
          id: daypartId(c.id, Daypart.daytime),
          title: 'Daytime',
          channelId: c.id,
          days: {...everyDay},
          startMinute: daytimeStart,
          endMinute: eveningStart,
          source: c.source,
          order: c.order,
          lineup: [for (final k in lineup) LineupSlot(seriesKey: k, count: 2)],
          playlist: [
            for (final k in lineup)
              for (final e in library.episodesBySeries[k]!) e.id,
          ],
          anchor: day,
          generated: Daypart.daytime,
        ));
      }

      final movies = evenings[c.id] ?? const <String>{};
      if (movies.length < options.minMoviesPerMovieGenre) continue;
      final id = daypartId(c.id, Daypart.evening);
      final source = ChannelSource(
          genres: c.source.genres,
          includeEpisodes: false,
          includeMovies: true,
          excluded: _sorted({
            for (final m in library.movies)
              if (!movies.contains(m.id) && m.genres.map(normalizeGenre).any(c.source.genres.contains)) m.id,
          }));
      final playlist = buildPlaylist(library, source, PlaybackOrder.random, seed: stableHash(id));
      if (playlist.length < options.minMoviesPerMovieGenre) continue;
      blocks.add(ProgramBlock(
        id: id,
        title: 'Movie Night',
        channelId: c.id,
        days: {...everyDay},
        startMinute: eveningStart,
        endMinute: eveningEnd,
        source: source,
        order: PlaybackOrder.random,
        playlist: playlist,
        anchor: day,
        generated: Daypart.evening,
      ));
    }
    return blocks;
  }

  /// Where [channelGenres] first comes in [titleGenres] (a title's genres
  /// as the server lists them); past the end when it doesn't.
  static int _rank(List<String> titleGenres, List<String> channelGenres) {
    for (final (i, g) in titleGenres.indexed) {
      if (channelGenres.contains(normalizeGenre(g))) return i;
    }
    return titleGenres.length;
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

  /// Spreads the library over [channels]' generated channels again, as a
  /// refresh does: each show airs on one show genre channel (none, when it
  /// has a show channel of its own, and then not on All Shows either), each
  /// movie in one genre channel's evening or on one movie genre channel.
  /// Titles go to the channel of their first listed genre (cable-lineup
  /// D3). Sets the channels' [ChannelSource.excluded]. Hidden channels
  /// count too, after the visible ones: they take what no visible channel
  /// has.
  ///
  /// A genre channel left under [GeneratorOptions]' minimums, as [generate]
  /// applies them, is thin: its titles go to the other channels of its
  /// genres and it plays nothing. Returns the thin channels' ids, and each
  /// show genre channel's own movies when it has enough for an evening.
  static ({Set<String> thin, Map<String, Set<String>> evenings}) spreadTitles(
      LibraryIndex library, List<Channel> channels,
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
    for (final c in channels) {
      if (c.auto && c.id == 'auto:all-shows') c.source = c.source.copyWith(excluded: _sorted(marathon));
    }
    final genresOf = {
      for (final s in library.series) s.key: s.genres,
      for (final m in library.movies) m.id: m.genres,
    };
    final channelGenres = {for (final c in channels) c.id: c.source.genres};
    int rank(String title, String channel) => _rank(genresOf[title] ?? const [], channelGenres[channel]!);
    final thin = <String>{};
    // Each channel's titles, visible channels first; a channel missing
    // from it got too few.
    Map<String, Set<String>> spread(List<Channel> genreChannels, Map<String, Set<String>> titlesOf, Set<String> skip,
        int Function(String) size, bool Function(Set<String>) tooThin) {
      final owned = {...skip};
      final result = <String, Set<String>>{};
      for (final hidden in [false, true]) {
        final group = [for (final c in genreChannels) if (c.hidden == hidden) c];
        final shared = _pickAndShare([for (final c in group) c.id], group.length,
            {for (final c in group) c.id: titlesOf[c.id]!.difference(owned)}, size, tooThin,
            rank: rank);
        for (final c in group) {
          final mine = shared[c.id];
          if (mine == null) continue;
          owned.addAll(mine);
          result[c.id] = mine;
        }
      }
      return result;
    }

    Set<String> moviesOf(Channel c) => {
          for (final m in library.movies)
            if (m.genres.map(normalizeGenre).any(c.source.genres.contains)) m.id,
        };
    bool fewMovies(Set<String> movies) => movies.length < options.minMoviesPerMovieGenre;

    final showChannels = generated('auto:genre:');
    final showTitles = {
      for (final c in showChannels)
        c.id: {
          for (final s in library.series)
            if (s.genres.map(normalizeGenre).any(c.source.genres.contains)) s.key,
        },
    };
    final shows = spread(showChannels, showTitles, marathon, episodesOf,
        (shows) =>
            shows.length < options.minSeriesPerGenre ||
            shows.fold(0, (n, k) => n + episodesOf(k)) < options.minEpisodesPerGenre);
    for (final c in showChannels) {
      final mine = shows[c.id];
      if (mine == null) thin.add(c.id);
      c.source = c.source.copyWith(excluded: _sorted(showTitles[c.id]!.difference(mine ?? const {})));
    }
    final open = [for (final c in showChannels) if (!thin.contains(c.id)) c];
    final evenings = spread(open, {for (final c in open) c.id: moviesOf(c)}, const {}, (_) => 1, fewMovies);
    final movieChannels = generated('auto:movies:');
    final movieTitles = {for (final c in movieChannels) c.id: moviesOf(c)};
    final movies = spread(movieChannels, movieTitles, {for (final m in evenings.values) ...m}, (_) => 1, fewMovies);
    for (final c in movieChannels) {
      final mine = movies[c.id];
      if (mine == null) thin.add(c.id);
      c.source = c.source.copyWith(excluded: _sorted(movieTitles[c.id]!.difference(mine ?? const {})));
    }
    return (thin: thin, evenings: evenings);
  }

  /// Picks up to [max] of [candidates] (best first) and shares their
  /// titles ([titlesOf]) between them (see [_share]). A pick left [thin]
  /// gives way to the next candidate. Returns each pick's titles, in
  /// [candidates]' order.
  static Map<String, Set<String>> _pickAndShare(List<String> candidates, int max, Map<String, Set<String>> titlesOf,
      int Function(String) size, bool Function(Set<String>) thin,
      {required int Function(String title, String channel) rank}) {
    final left = [...candidates];
    while (true) {
      final picked = left.take(max).toList();
      final shared = _share(picked, titlesOf, size, rank);
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
  /// two channels play the same title: the one [rank] puts first (the
  /// title's first listed genre). Among equals, titles in the fewest
  /// channels go first, the biggest ([size]) first among those, each to a
  /// channel with nothing yet, else the one with the least so far; ties go
  /// to the earlier channel. Returns each channel's titles, in [channels]'
  /// order.
  static Map<String, Set<String>> _share(List<String> channels, Map<String, Set<String>> titlesOf,
      int Function(String) size, int Function(String title, String channel) rank) {
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
        final byRank = rank(t, c).compareTo(rank(t, best));
        if (byRank != 0) {
          if (byRank < 0) best = c;
          continue;
        }
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
