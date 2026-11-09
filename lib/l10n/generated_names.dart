import 'tr.dart';

/// Generated channel, block and genre names on screen (design D6). Saved
/// names stay English; a name that matches nothing generated is the user's
/// own and is shown as written.
final Map<String, String Function()> _channels = {
  'Kids Zone': () => tr.channelKidsZone,
  'Toon TV': () => tr.channelToonTv,
  'Laugh Track': () => tr.channelLaughTrack,
  'Family Room': () => tr.channelFamilyRoom,
  'Action TV': () => tr.channelActionTv,
  'Adventure TV': () => tr.channelAdventureTv,
  'Sci-Fi TV': () => tr.channelSciFiTv,
  'Fantasy TV': () => tr.channelFantasyTv,
  'Mystery & Thrills': () => tr.channelMysteryThrills,
  'Sci-Fi & Fantasy': () => tr.channelSciFiFantasy,
  'Mystery TV': () => tr.channelMysteryTv,
  'Drama Central': () => tr.channelDramaCentral,
  'Crime & Justice': () => tr.channelCrimeJustice,
  'Thrill TV': () => tr.channelThrillTv,
  'Fright Night': () => tr.channelFrightNight,
  'Romance TV': () => tr.channelRomanceTv,
  'Discovery Zone': () => tr.channelDiscoveryZone,
  'Music TV': () => tr.channelMusicTv,
  'Reality TV': () => tr.channelRealityTv,
  'Game Show TV': () => tr.channelGameShowTv,
  'Frontier TV': () => tr.channelFrontierTv,
  'History TV': () => tr.channelHistoryTv,
  'Sports TV': () => tr.channelSportsTv,
  'News TV': () => tr.channelNewsTv,
  'All Shows': () => tr.channelAllShows,
  'Movie Channel': () => tr.channelMovieChannel,
  'Music Videos': () => tr.channelMusicVideos,
  'Music Radio': () => tr.channelMusicRadio,
};

final Map<String, String Function()> _genres = {
  'Action': () => tr.genreAction,
  'Adventure': () => tr.genreAdventure,
  'Sci-Fi': () => tr.genreSciFi,
  'Fantasy': () => tr.genreFantasy,
  'Thriller & Mystery': () => tr.genreThrillerMystery,
  'Action & Adventure': () => tr.genreActionAdventure,
  'Sci-Fi & Fantasy': () => tr.genreSciFiFantasy,
  'Kids': () => tr.genreKids,
  'Animation': () => tr.genreAnimation,
  'Comedy': () => tr.genreComedy,
  'Family': () => tr.genreFamily,
  'Drama': () => tr.genreDrama,
  'Crime': () => tr.genreCrime,
  'Mystery': () => tr.genreMystery,
  'Thriller': () => tr.genreThriller,
  'Horror': () => tr.genreHorror,
  'Romance': () => tr.genreRomance,
  'Documentary': () => tr.genreDocumentary,
  'Music': () => tr.genreMusic,
  'Reality': () => tr.genreReality,
  'Game Shows': () => tr.genreGameShows,
  'Western': () => tr.genreWestern,
  'War': () => tr.genreWar,
  'History': () => tr.genreHistory,
  'News': () => tr.genreNews,
  'Talk': () => tr.genreTalk,
  'Soap': () => tr.genreSoap,
  'Sports': () => tr.genreSports,
  'Classical': () => tr.genreClassical,
  'Electronic': () => tr.genreElectronic,
  'Country': () => tr.genreCountry,
  'Latin': () => tr.genreLatin,
  'Soundtrack': () => tr.genreSoundtrack,
  'Oldies': () => tr.genreOldies,
  'Dance': () => tr.genreDance,
  'Folk': () => tr.genreFolk,
  'Alternative': () => tr.genreAlternative,
};

final Map<String, String Function()> _kinds = {
  'Show': () => tr.kindShow,
  'Shows': () => tr.kindShows,
  'Movies': () => tr.kindMovies,
  'Music Videos': () => tr.kindMusicVideos,
  'Radio': () => tr.kindRadio,
};

final _suffix = RegExp(r'^(.*) \((Show|Shows|Movies|Music Videos|Radio)( \d+)?\)$');

/// A genre name, translated when it's one the app knows; a server's own
/// genre (a decade, "Bollywood") stays as it came.
String displayGenre(String genre) => _genres[genre]?.call() ?? genre;

/// A leading decade ("90s", "1910s", "2000s") and the rest of a name.
final _decade = RegExp(r'^((?:19|20)?\d0s) (.+)$');

String? _generatedBase(String name) {
  if (_channels[name] case final known?) return known();
  // "90s TV", "90s Comedy TV", "80s Action Movies" (genre-decade-channels D6).
  if (_decade.firstMatch(name) case final m?) {
    final (decade, rest) = (m[1]!, m[2]!);
    if (rest == 'TV') return tr.decadeTv(decade);
    if (rest.endsWith(' TV')) return tr.decadeGenreTv(decade, displayGenre(rest.substring(0, rest.length - 3)));
    if (rest.endsWith(' Movies') && rest != 'Movies') {
      return tr.decadeGenreMovies(decade, displayGenre(rest.substring(0, rest.length - 7)));
    }
  }
  for (final (ending, build) in <(String, String Function(String))>[
    (' Music Videos', (g) => tr.genreMusicVideos(g)),
    (' Movies', (g) => tr.genreMovies(g)),
    (' Radio', (g) => tr.genreRadio(g)),
  ]) {
    if (name.endsWith(ending)) {
      return build(displayGenre(name.substring(0, name.length - ending.length)));
    }
  }
  return null;
}

/// A generated channel's name on screen. [showChannel]: named after a show,
/// so only a generated kind suffix changes.
String displayChannelName(String saved, {bool showChannel = false}) {
  final suffix = _suffix.firstMatch(saved);
  if (suffix != null) {
    final base = suffix[1]!;
    final name = showChannel ? base : _generatedBase(base) ?? base;
    final kind = _kinds[suffix[2]!]!();
    final number = suffix[3]?.trim();
    return number == null ? tr.kindSuffix(name, kind) : tr.kindSuffixNumbered(name, kind, number);
  }
  return showChannel ? saved : _generatedBase(saved) ?? saved;
}

/// A generated block's title on screen.
String displayBlockTitle(String saved) => switch (saved) {
      'Daytime' => tr.blockDaytime,
      'Movie Night' => tr.blockMovieNight,
      'New Episodes' => tr.blockNewEpisodes,
      _ => saved,
    };
