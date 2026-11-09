import 'dart:math';

import '../commercials/break_plan.dart';
import '../library/library_index.dart';
import '../playback/playback_diagnostics.dart';
import '../profiles/profile.dart';
import 'channel.dart';
import 'program_block.dart';

/// The merged genre of thrillers, mysteries and suspense (genres-and-decades).
const thrillerAndMystery = 'Thriller & Mystery';

/// The genres one server tag counts as (genres-and-decades D1): the many
/// spellings providers use merge, and a combined tag ("Action & Adventure",
/// "Sci-Fi & Fantasy") counts as both of its genres.
Set<String> genresOf(String raw) {
  final g = raw.trim().toLowerCase();
  const map = <String, List<String>>{
    'action': ['Action'],
    'adventure': ['Adventure'],
    'action & adventure': ['Action', 'Adventure'],
    'action and adventure': ['Action', 'Adventure'],
    'science fiction': ['Sci-Fi'],
    'sci-fi': ['Sci-Fi'],
    'fantasy': ['Fantasy'],
    'sci-fi & fantasy': ['Sci-Fi', 'Fantasy'],
    'science fiction & fantasy': ['Sci-Fi', 'Fantasy'],
    'children': ['Kids'],
    'kids': ['Kids'],
    'animation': ['Animation'],
    'anime': ['Animation'],
    'comedy': ['Comedy'],
    'sitcom': ['Comedy'],
    'family': ['Family'],
    'drama': ['Drama'],
    'crime': ['Crime'],
    'mystery': [thrillerAndMystery],
    'thriller': [thrillerAndMystery],
    'suspense': [thrillerAndMystery],
    'horror': ['Horror'],
    'romance': ['Romance'],
    'documentary': ['Documentary'],
    'music': ['Music'],
    'musical': ['Music'],
    'reality': ['Reality'],
    'game show': ['Game Shows'],
    'western': ['Western'],
    'war': ['War'],
    'history': ['History'],
    'news': ['News'],
    'talk': ['Talk'],
    'soap': ['Soap'],
    'sport': ['Sports'],
    'sports': ['Sports'],
  };
  final mapped = map[g];
  if (mapped != null) return {...mapped};
  final kept = raw.trim();
  return kept.isEmpty ? {} : {kept};
}

/// A title's genres: every genre its [tags] count as, in the order the
/// server first lists them.
Set<String> titleGenres(Iterable<String> tags) => {for (final t in tags) ...genresOf(t)};

/// Saved genre names from before the 12 major genres, converted
/// (genres-and-decades D2): "Action & Adventure" is Action and Adventure,
/// "Sci-Fi & Fantasy" is Sci-Fi and Fantasy, Thriller and Mystery are
/// Thriller & Mystery. Without old names, [saved] comes back as it was.
List<String> migrateGenres(List<String> saved) {
  const old = {
    'Action & Adventure': ['Action', 'Adventure'],
    'Sci-Fi & Fantasy': ['Sci-Fi', 'Fantasy'],
    'Thriller': [thrillerAndMystery],
    'Mystery': [thrillerAndMystery],
  };
  if (!saved.any(old.containsKey)) return saved;
  return {for (final g in saved) ...(old[g] ?? [g])}.toList()..sort();
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

/// The decade (its first year) of [year], from the 1900s to the 2090s.
int? decadeOf(int? year) {
  if (year == null || year < 1900 || year >= 2100) return null;
  return year ~/ 10 * 10;
}

/// "1900s" and "1910s", then "20s" … "90s", then "2000s", "2010s" …
String decadeName(int decade) => decade >= 1920 && decade < 2000 ? '${decade % 100}s' : '${decade}s';

/// [item]'s decade: a movie's or song's by its year, an episode's by its
/// own year, or its show's when it has none (genres-and-decades).
int? itemDecade(LibraryIndex library, MediaEntry item) =>
    decadeOf(item.year ?? library.seriesByKey[item.seriesKey]?.year);

/// Cable-style names and icons for genre channels.
const _genreStyle = <String, (String name, String icon)>{
  'Kids': ('Kids Zone', 'child_care'),
  'Animation': ('Toon TV', 'animation'),
  'Comedy': ('Laugh Track', 'theater_comedy'),
  'Family': ('Family Room', 'family_restroom'),
  'Action': ('Action TV', 'bolt'),
  'Adventure': ('Adventure TV', 'public'),
  'Sci-Fi': ('Sci-Fi TV', 'rocket_launch'),
  'Fantasy': ('Fantasy TV', 'castle'),
  thrillerAndMystery: ('Mystery & Thrills', 'search'),
  'Drama': ('Drama Central', 'theaters'),
  'Crime': ('Crime & Justice', 'local_police'),
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
    this.minSeriesPerCombo = 3,
    this.minEpisodesPerCombo = 60,
    this.minMoviesPerCombo = 25,
    this.maxCombosPerSide = 4,
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

  /// What a movie genre or decade channel, or a genre channel's Evening,
  /// needs at least.
  final int minMoviesPerMovieGenre;

  /// What a decade + genre channel needs at least: shows and their
  /// episodes on the show side, movies on the movie side.
  final int minSeriesPerCombo;
  final int minEpisodesPerCombo;
  final int minMoviesPerCombo;

  /// At most this many decade + genre channels for shows, and as many for
  /// movies.
  final int maxCombosPerSide;

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

    // Show genre, decade and decade + genre channels (genre-decade-channels
    // D5), from the shows without a marathon channel: each holds every one
    // of its shows, episodes going by their own decade.
    final shown = [for (final s in library.series) if (!marathon.contains(s.key)) s];
    final showEpisodes = <String, Set<String>>{};
    final showsOfGenre = <String, Set<String>>{};
    final showsOfDecade = <int, Set<String>>{};
    final episodesOfDecade = <int, Set<String>>{};
    final episodesOfPair = <(int, String), Set<String>>{};
    final showsOfPair = <(int, String), Set<String>>{};
    for (final s in shown) {
      final eps = library.episodesBySeries[s.key] ?? const [];
      if (eps.isEmpty) continue;
      showEpisodes[s.key] = {for (final e in eps) e.id};
      final genres = titleGenres(s.genres);
      for (final g in genres) {
        showsOfGenre.putIfAbsent(g, () => {}).add(s.key);
      }
      for (final e in eps) {
        final d = decadeOf(e.year ?? s.year);
        if (d == null) continue;
        episodesOfDecade.putIfAbsent(d, () => {}).add(e.id);
        showsOfDecade.putIfAbsent(d, () => {}).add(s.key);
        for (final g in genres) {
          episodesOfPair.putIfAbsent((d, g), () => {}).add(e.id);
          showsOfPair.putIfAbsent((d, g), () => {}).add(s.key);
        }
      }
    }
    Set<String> episodesOfShows(Set<String> shows) => {for (final k in shows) ...?showEpisodes[k]};
    final allEpisodes = episodesOfShows(showEpisodes.keys.toSet());
    final showGenreSets = {
      for (final MapEntry(key: g, value: shows) in showsOfGenre.entries)
        if (shows.length >= options.minSeriesPerGenre &&
            // A genre covering every show is just "All Shows" again.
            shows.length < showEpisodes.length)
          g: episodesOfShows(shows),
    };
    final showGenres = _choose(
        {
          for (final e in showGenreSets.entries)
            if (e.value.length >= options.minEpisodesPerGenre) e.key: e.value
        },
        _bySize,
        const [],
        options.overlapThreshold);
    final showDecades = _choose(
        {
          for (final e in episodesOfDecade.entries)
            if (showsOfDecade[e.key]!.length >= options.minSeriesPerGenre &&
                e.value.length >= options.minEpisodesPerGenre)
              e.key: e.value
        },
        (a, b) => a.key.compareTo(b.key),
        [if (library.series.length > 1) allEpisodes, ...showGenres.values],
        options.overlapThreshold);
    final showPairs = _pairs(
        {
          for (final e in episodesOfPair.entries)
            if (showGenres.containsKey(e.key.$2) &&
                showDecades.containsKey(e.key.$1) &&
                showsOfPair[e.key]!.length >= options.minSeriesPerCombo &&
                e.value.length >= options.minEpisodesPerCombo)
              e.key: e.value
        },
        showGenres,
        showDecades,
        options);
    final skipMarathon = _sorted(marathon);
    for (final g in showGenres.keys) {
      final style = _genreStyle[g] ?? (g, 'live_tv');
      add('auto:genre:$g', style.$1, ChannelIcon.builtin(style.$2),
          ChannelSource(genres: [g], excluded: skipMarathon), PlaybackOrder.cyclic);
    }
    for (final d in showDecades.keys) {
      add('auto:decade:$d', '${decadeName(d)} TV', const ChannelIcon.builtin('tv'),
          ChannelSource(decades: [d], excluded: skipMarathon), PlaybackOrder.cyclic);
    }
    for (final (d, g) in showPairs.keys) {
      add('auto:decade:$d:$g', '${decadeName(d)} $g TV', ChannelIcon.builtin(_genreStyle[g]?.$2 ?? 'live_tv'),
          ChannelSource(genres: [g], decades: [d], excluded: skipMarathon), PlaybackOrder.cyclic);
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

    // Movie Channel, then movie genre, decade and decade + genre channels,
    // each holding every movie it matches; the show genre channels'
    // evenings play their genre's movies too (cable-dayparts).
    if (library.movies.length >= options.minMoviesForMovieChannel) {
      add('auto:movies', 'Movie Channel', const ChannelIcon.builtin('movie'),
          const ChannelSource(includeEpisodes: false, includeMovies: true), PlaybackOrder.random);
      final moviesOfGenre = <String, Set<String>>{};
      final moviesOfDecade = <int, Set<String>>{};
      final moviesOfPair = <(int, String), Set<String>>{};
      for (final m in library.movies) {
        final genres = titleGenres(m.genres);
        for (final g in genres) {
          moviesOfGenre.putIfAbsent(g, () => {}).add(m.id);
        }
        final d = decadeOf(m.year);
        if (d == null) continue;
        moviesOfDecade.putIfAbsent(d, () => {}).add(m.id);
        for (final g in genres) {
          moviesOfPair.putIfAbsent((d, g), () => {}).add(m.id);
        }
      }
      final everyMovie = {for (final m in library.movies) m.id};
      final movieGenres = _choose(
          {
            for (final e in moviesOfGenre.entries)
              if (e.value.length >= options.minMoviesPerMovieGenre && e.value.length < everyMovie.length)
                e.key: e.value
          },
          _bySize,
          const [],
          options.overlapThreshold);
      final movieDecades = _choose(
          {
            for (final e in moviesOfDecade.entries)
              if (e.value.length >= options.minMoviesPerMovieGenre) e.key: e.value
          },
          (a, b) => a.key.compareTo(b.key),
          [everyMovie, ...movieGenres.values],
          options.overlapThreshold);
      final moviePairs = _pairs(
          {
            for (final e in moviesOfPair.entries)
              if (movieGenres.containsKey(e.key.$2) &&
                  movieDecades.containsKey(e.key.$1) &&
                  e.value.length >= options.minMoviesPerCombo)
                e.key: e.value
          },
          movieGenres,
          movieDecades,
          options);
      ChannelSource movies({List<String> genres = const [], List<int> decades = const []}) =>
          ChannelSource(genres: genres, decades: decades, includeEpisodes: false, includeMovies: true);
      for (final g in movieGenres.keys) {
        add('auto:movies:$g', '$g Movies', ChannelIcon.builtin(_genreStyle[g]?.$2 ?? 'local_movies'),
            movies(genres: [g]), PlaybackOrder.random);
      }
      for (final d in movieDecades.keys) {
        add('auto:movies:decade:$d', '${decadeName(d)} Movies', const ChannelIcon.builtin('local_movies'),
            movies(decades: [d]), PlaybackOrder.random);
      }
      for (final (d, g) in moviePairs.keys) {
        add('auto:movies:decade:$d:$g', '${decadeName(d)} $g Movies',
            ChannelIcon.builtin(_genreStyle[g]?.$2 ?? 'local_movies'), movies(genres: [g], decades: [d]),
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
    PlaybackDiagnostics.note('LINEUP', 'generated: ${[for (final c in channels) '${c.number} ${c.name} (${c.playlist.length})'].join(', ')}');
    blocks = dayparts(library, channels, anchor: anchor, planOf: planOf, options: options);
    return channels;
  }

  static const daytimeStart = 6 * 60, eveningStart = 18 * 60, eveningEnd = 0;

  /// The id of [channelId]'s generated [part] block.
  static String daypartId(String channelId, Daypart part) => 'lineup:${part.name}:$channelId';

  /// Whether [c] is a generated show genre channel, the only kind with
  /// dayparts.
  static bool isGenreChannel(Channel c) => c.auto && !c.isLive && c.id.startsWith('auto:genre:');

  /// The Daytime and Evening blocks (cable-dayparts) of [channels]'
  /// generated genre channels, airing from [anchor]. A channel's Evening
  /// plays every movie of its genre (genre-decade-channels D7); one whose
  /// genre has fewer than [GeneratorOptions.minMoviesPerMovieGenre] gets
  /// none.
  ///
  /// Daytime is a lineup of two-episode stacks of the channel's shows, the
  /// most episodes first, as many as fit 12 hours by their average slot
  /// under [planOf]'s plan (at least one).
  static List<ProgramBlock> dayparts(LibraryIndex library, List<Channel> channels,
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

      final id = daypartId(c.id, Daypart.evening);
      final source = ChannelSource(genres: c.source.genres, includeEpisodes: false, includeMovies: true);
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

  /// Biggest first, ties by key.
  static int _bySize(MapEntry<String, Set<String>> a, MapEntry<String, Set<String>> b) {
    final bySize = b.value.length.compareTo(a.value.length);
    return bySize != 0 ? bySize : a.key.compareTo(b.key);
  }

  /// The [groups] (each a channel's titles) that get a channel, taken in
  /// [order]: a group overlapping [earlier] channels' titles or an already
  /// taken group by [threshold] or more (Jaccard) is skipped. Keeps
  /// [order].
  static Map<K, Set<String>> _choose<K>(Map<K, Set<String>> groups,
      int Function(MapEntry<K, Set<String>> a, MapEntry<K, Set<String>> b) order, List<Set<String>> earlier,
      double threshold) {
    final used = [...earlier];
    final taken = <K, Set<String>>{};
    for (final e in groups.entries.toList()..sort(order)) {
      if (used.any((u) => _jaccard(u, e.value) >= threshold)) continue;
      used.add(e.value);
      taken[e.key] = e.value;
    }
    return taken;
  }

  /// The decade + genre [pairs] that get a channel: biggest first, at most
  /// [GeneratorOptions.maxCombosPerSide], skipping a pair that overlaps its
  /// genre's channel ([genres]) or its decade's ([decades]) by the overlap
  /// threshold.
  static Map<(int, String), Set<String>> _pairs(Map<(int, String), Set<String>> pairs,
      Map<String, Set<String>> genres, Map<int, Set<String>> decades, GeneratorOptions options) {
    final sorted = pairs.entries.toList()
      ..sort((a, b) {
        final bySize = b.value.length.compareTo(a.value.length);
        if (bySize != 0) return bySize;
        final byDecade = a.key.$1.compareTo(b.key.$1);
        return byDecade != 0 ? byDecade : a.key.$2.compareTo(b.key.$2);
      });
    final taken = <(int, String), Set<String>>{};
    for (final e in sorted) {
      if (taken.length == options.maxCombosPerSide) break;
      final (d, g) = e.key;
      if (_jaccard(genres[g]!, e.value) >= options.overlapThreshold ||
          _jaccard(decades[d]!, e.value) >= options.overlapThreshold) {
        continue;
      }
      taken[e.key] = e.value;
    }
    return taken;
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

  /// Whether [c] is a generated show or movie genre, decade or decade +
  /// genre channel: the kinds with minimums of their own.
  static bool isGroupChannel(Channel c) =>
      c.auto &&
      !c.isLive &&
      (c.id.startsWith('auto:genre:') || c.id.startsWith('auto:decade:') || c.id.startsWith('auto:movies:'));

  /// Whether [c] is a decade + genre channel.
  static bool isPairChannel(Channel c) => c.source.decades.isNotEmpty && c.source.genres.isNotEmpty;

  /// Fits [channels]' generated channels to the library again, as a
  /// refresh does (genre-decade-channels D4, D8): a show with a marathon
  /// channel of its own airs only there, so All Shows and the show genre,
  /// decade and decade + genre channels skip it ([ChannelSource.excluded]);
  /// every other title airs on every channel it matches.
  ///
  /// Returns the ids of the genre, decade and decade + genre channels left
  /// under [GeneratorOptions]' minimums, as [generate] applies them: they
  /// retire, or aren't added.
  static Set<String> spreadTitles(LibraryIndex library, List<Channel> channels,
      {GeneratorOptions options = const GeneratorOptions()}) {
    int episodesOf(String show) => library.episodesBySeries[show]?.length ?? 0;
    final marathon = _sorted({
      for (final c in channels)
        if (c.auto && c.id.startsWith('auto:show:'))
          for (final k in c.source.seriesKeys)
            if (library.seriesByKey[k] case final s? when !s.isUnknown && episodesOf(k) >= options.minEpisodesForShowChannel)
              k,
    });
    final thin = <String>{};
    for (final c in channels) {
      if (!c.auto || c.isLive) continue;
      if (c.id == 'auto:all-shows') c.source = c.source.copyWith(excluded: marathon);
      if (!isGroupChannel(c)) continue;
      final pair = isPairChannel(c);
      if (c.id.startsWith('auto:movies:')) {
        c.source = c.source.copyWith(excluded: const []);
        final movies = _select(library, c.source).movies.length;
        if (movies < (pair ? options.minMoviesPerCombo : options.minMoviesPerMovieGenre)) thin.add(c.id);
      } else {
        c.source = c.source.copyWith(excluded: marathon);
        final shows = _select(library, c.source).shows;
        final episodes = shows.values.fold(0, (n, eps) => n + eps.length);
        if (shows.length < (pair ? options.minSeriesPerCombo : options.minSeriesPerGenre) ||
            episodes < (pair ? options.minEpisodesPerCombo : options.minEpisodesPerGenre)) {
          thin.add(c.id);
        }
      }
    }
    return thin;
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
  if (source.isMusic) {
    final genres = source.genres.toSet();
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

  final (:shows, :movies) = _select(library, source);
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

/// The episodes (by show, in airing order) and movies a show-and-movie
/// [source] plays, unordered.
({Map<String, List<MediaEntry>> shows, List<MediaEntry> movies}) _select(LibraryIndex library, ChannelSource source) {
  final genres = source.genres.toSet();
  final excluded = source.excluded.toSet();
  bool genreMatch(Iterable<String> itemGenres) => genres.isEmpty || titleGenres(itemGenres).any(genres.contains);
  // Decades narrow every choice, picked shows and roots included; an
  // episode goes by its own year, else its show's (genre-decade-channels D3).
  final decades = source.decades.toSet();
  bool decadeMatch(int? year) => decades.isEmpty || decades.contains(decadeOf(year));

  // With roots, the other choices add to them (custom-channels D2): roots
  // alone play only the roots, and no genre or decade no longer means
  // every show.
  final rooted = <String>{for (final r in source.roots) ...?library.itemsByRoot[r.itemId]};
  final byRootOnly = source.roots.isNotEmpty && genres.isEmpty && decades.isEmpty;
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
            : !byRootOnly && !excluded.contains(s.key) && genreMatch(s.genres));
    final picked = [
      for (final e in eps)
        if ((whole || rooted.contains(e.id)) && decadeMatch(e.year ?? s.year)) e,
    ];
    if (picked.isNotEmpty) shows[s.key] = picked;
  }
  final movies = [
    for (final m in library.movies)
      if (((source.includeMovies && genreMatch(m.genres) && !excluded.contains(m.id)) || rooted.contains(m.id)) &&
          rated(m.officialRating) &&
          decadeMatch(m.year))
        m,
  ];
  return (shows: shows, movies: movies);
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
