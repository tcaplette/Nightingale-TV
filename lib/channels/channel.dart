import '../commercials/break_plan.dart';

/// How a channel's playlist is ordered.
enum PlaybackOrder {
  /// Episodes play in airing order; shows take turns.
  cyclic,

  /// Seeded shuffle that avoids the same show twice in a row.
  random;

  String get label => switch (this) {
        cyclic => 'In order (shows take turns)',
        random => 'Shuffled',
      };
}

/// When a channel's logo shows in the corner of the picture (channel-logo).
enum LogoMode {
  always,

  /// For 20 seconds from each program part's start and each quarter hour.
  nowAndThen,
  off;

  String get label => switch (this) {
        always => 'Always',
        nowAndThen => 'Now and then',
        off => 'Off',
      };

  static LogoMode? parse(Object? name) => LogoMode.values.where((m) => m.name == name).firstOrNull;
}

enum ChannelIconKind {
  /// A Material icon from the built-in catalog (`value` = catalog key).
  builtin,

  /// A generic station badge with text (`value` = text).
  badge,

  /// A show's Jellyfin logo (`value` = Jellyfin item id).
  jellyfin,

  /// A user-uploaded image in the logos folder (`value` = file name).
  custom,

  /// An image at a URL (`value`): a Live TV source's channel logo. Sent
  /// with the server's sign-in when it's on the profile's server.
  remote,
}

enum BadgeShape { roundedSquare, circle, oval, shield }

class ChannelIcon {
  const ChannelIcon({
    required this.kind,
    required this.value,
    this.color = 0xFFFFD23F,
    this.shape = BadgeShape.roundedSquare,
  });

  const ChannelIcon.builtin(String key, {int color = 0xFFFFD23F})
      : this(kind: ChannelIconKind.builtin, value: key, color: color);

  final ChannelIconKind kind;
  final String value;

  /// ARGB. Icon tint for builtins, background for badges.
  final int color;
  final BadgeShape shape;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'value': value,
        'color': color,
        if (kind == ChannelIconKind.badge) 'shape': shape.name,
      };

  factory ChannelIcon.fromJson(Map<String, Object?> j) => ChannelIcon(
        kind: ChannelIconKind.values.byName(j['kind'] as String),
        value: j['value'] as String,
        color: j['color'] as int? ?? 0xFFFFD23F,
        shape: BadgeShape.values.byName(j['shape'] as String? ?? BadgeShape.roundedSquare.name),
      );
}

/// Where a live channel comes from (live-tv-sources): its Live TV source
/// and its key there, which survives refreshes.
class LiveRef {
  const LiveRef({required this.sourceId, required this.key, this.sourceNumber});

  final String sourceId;
  final String key;

  /// The source's own channel number ("2.1"), shown beside the name.
  final String? sourceNumber;

  /// The channel id of [key] on [sourceId].
  static String channelId(String sourceId, String key) => 'live:$sourceId:$key';
}

/// What content a channel draws from. Kept so channels can be refreshed when
/// the library changes.
class ChannelSource {
  const ChannelSource({
    this.genres = const [],
    this.seriesKeys = const [],
    this.includeEpisodes = true,
    this.includeMovies = false,
    this.includeSongs = false,
    this.includeMusicVideos = false,
    this.decades = const [],
  });

  /// Normalized genre names (see `normalizeGenre`). Empty = any genre.
  final List<String> genres;

  /// Specific shows. When non-empty, only these shows are used.
  final List<String> seriesKeys;
  final bool includeEpisodes;
  final bool includeMovies;
  final bool includeSongs;
  final bool includeMusicVideos;

  /// Music only: the decades (first year, e.g. 1980) to play. Empty = any.
  final List<int> decades;

  /// Plays songs or music videos.
  bool get isMusic => includeSongs || includeMusicVideos;

  Map<String, Object?> toJson() => {
        if (genres.isNotEmpty) 'genres': genres,
        if (seriesKeys.isNotEmpty) 'seriesKeys': seriesKeys,
        'episodes': includeEpisodes,
        'movies': includeMovies,
        if (includeSongs) 'songs': true,
        if (includeMusicVideos) 'musicVideos': true,
        if (decades.isNotEmpty) 'decades': decades,
      };

  factory ChannelSource.fromJson(Map<String, Object?> j) => ChannelSource(
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        seriesKeys: (j['seriesKeys'] as List?)?.cast<String>() ?? const [],
        includeEpisodes: j['episodes'] as bool? ?? true,
        includeMovies: j['movies'] as bool? ?? false,
        includeSongs: j['songs'] as bool? ?? false,
        includeMusicVideos: j['musicVideos'] as bool? ?? false,
        decades: (j['decades'] as List?)?.cast<int>() ?? const [],
      );
}

class Channel {
  Channel({
    required this.id,
    required this.number,
    required this.name,
    required this.icon,
    required this.source,
    required this.order,
    required this.playlist,
    required this.anchor,
    this.hidden = false,
    this.favorite = false,
    this.auto = true,
    this.blockOnly = false,
    this.commercialPlan,
    this.logoMode,
    this.premieres = true,
    this.live,
  });

  /// A live channel (live-tv-sources): it plays its source's stream and has
  /// no playlist. Live channels are saved with their source, never in
  /// `channels.json`.
  factory Channel.live({
    required LiveRef ref,
    required int number,
    required String name,
    required ChannelIcon icon,
    bool hidden = false,
    bool favorite = false,
    LogoMode? logoMode = LogoMode.off,
  }) =>
      Channel(
        id: LiveRef.channelId(ref.sourceId, ref.key),
        number: number,
        name: name,
        icon: icon,
        source: const ChannelSource(includeEpisodes: false),
        order: PlaybackOrder.cyclic,
        playlist: const [],
        anchor: DateTime.fromMillisecondsSinceEpoch(0),
        hidden: hidden,
        favorite: favorite,
        auto: false,
        logoMode: logoMode,
        premieres: false,
        live: ref,
      );

  final String id;
  int number;
  String name;
  ChannelIcon icon;
  ChannelSource source;
  PlaybackOrder order;

  /// Jellyfin item ids in play order. The schedule loops through it forever.
  List<String> playlist;

  /// When the playlist's first loop started. Together with [playlist] this
  /// fixes the schedule, so every launch shows the same thing "on air".
  DateTime anchor;
  bool hidden;
  bool favorite;

  /// Created by the generator (vs. by the user).
  bool auto;

  /// Exists only to carry programming blocks; off the air between them.
  bool blockOnly;

  /// This channel's own break plan; null follows the main setting.
  BreakPlan? commercialPlan;

  /// This channel's own logo setting; null follows the main setting.
  LogoMode? logoMode;

  /// Can be a show's home channel for new episode premieres.
  bool premieres;

  /// Set for a live channel: where its stream comes from.
  final LiveRef? live;

  bool get isLive => live != null;

  /// A music channel (songs or music videos).
  bool get isMusic => source.isMusic;

  Map<String, Object?> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'icon': icon.toJson(),
        'source': source.toJson(),
        'order': order.name,
        'playlist': playlist,
        'anchor': anchor.toUtc().toIso8601String(),
        'hidden': hidden,
        'favorite': favorite,
        'auto': auto,
        if (blockOnly) 'blockOnly': true,
        if (commercialPlan != null) 'commercialPlan': commercialPlan!.toJson(),
        // Read by versions from before break plans, so a downgrade keeps
        // roughly the same setting.
        if (commercialPlan != null) 'commercials': !commercialPlan!.isOff,
        if (logoMode != null) 'logoMode': logoMode!.name,
        if (!premieres) 'premieres': false,
      };

  factory Channel.fromJson(Map<String, Object?> j) => Channel(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String,
        icon: ChannelIcon.fromJson(j['icon'] as Map<String, Object?>),
        source: ChannelSource.fromJson(j['source'] as Map<String, Object?>),
        order: PlaybackOrder.values.byName(j['order'] as String),
        playlist: (j['playlist'] as List).cast<String>(),
        // Saved in UTC; schedules and the guide work in local time.
        anchor: DateTime.parse(j['anchor'] as String).toLocal(),
        hidden: j['hidden'] as bool? ?? false,
        favorite: j['favorite'] as bool? ?? false,
        auto: j['auto'] as bool? ?? true,
        blockOnly: j['blockOnly'] as bool? ?? false,
        commercialPlan: switch ((j['commercialPlan'], j['commercials'])) {
          (final Map<String, Object?> plan, _) => BreakPlan.fromJson(plan),
          // Saved before break plans: "Always on" / "Always off".
          (_, true) => BreakPlan.legacy,
          (_, false) => BreakPlan.off,
          _ => null,
        },
        logoMode: LogoMode.parse(j['logoMode']),
        premieres: j['premieres'] as bool? ?? true,
      );
}
