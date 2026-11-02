import '../commercials/break_plan.dart';
import '../library/pool_root.dart';
import 'retro.dart';

/// How a channel's playlist is ordered.
enum PlaybackOrder {
  /// Episodes play in airing order; shows take turns.
  cyclic,

  /// Seeded shuffle that avoids the same show twice in a row.
  random,

  /// Seeded shuffle weighted by play count: what's been played least comes
  /// up sooner (custom-channels D4).
  weighted;

  String get label => switch (this) {
        cyclic => 'In order (shows take turns)',
        random => 'Shuffled',
        weighted => 'Least watched first',
      };

  /// Orders saved by a newer version that this one doesn't know read as
  /// [random].
  static PlaybackOrder parse(Object? name) => values.where((o) => o.name == name).firstOrNull ?? random;
}

/// The program on the air when a channel's slot length changed: it keeps its
/// position, in a slot of its own up to a clock boundary, and the loop goes on
/// from there on the clock (slot-duration).
class SlotCarry {
  const SlotCarry({required this.itemId, required this.start, required this.end});

  final String itemId;

  /// Where the program's slot started, and the clock boundary it ends on.
  final DateTime start;
  final DateTime end;

  Map<String, Object?> toJson() => {
        'item': itemId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      };

  static SlotCarry? fromJson(Object? j) => j is Map<String, Object?>
      ? SlotCarry(
          itemId: j['item'] as String,
          start: DateTime.parse(j['start'] as String).toLocal(),
          end: DateTime.parse(j['end'] as String).toLocal())
      : null;
}

/// What fills the rest of a slot on a channel with a slot length
/// (slot-duration).
enum TailMode {
  /// Clips from a commercial pool; the offline card when there are none.
  filler,

  /// The channel's offline card.
  offline,

  /// Every program gets exactly one slot: longer ones are cut at its end,
  /// shorter ones padded with filler.
  truncate;

  String get label => switch (this) {
        filler => 'Filler',
        offline => 'Offline image',
        truncate => 'Truncate',
      };

  static TailMode? parse(Object? name) => values.where((m) => m.name == name).firstOrNull;
}

/// A channel's slot length and what fills each slot's rest (custom-channels
/// D6). Programs start on multiples of [length] after the anchor, which
/// sits on the clock.
class SlotRule {
  const SlotRule({required this.length, this.tail = TailMode.filler, this.poolId, this.offlineImage});

  final Duration length;
  final TailMode tail;

  /// The pool filler comes from (filler and truncate); null for all pools.
  final String? poolId;

  /// A file in the custom logos folder; null for the default card.
  final String? offlineImage;

  static const lengths = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
    Duration(minutes: 90),
    Duration(minutes: 120),
  ];

  SlotRule copyWith({Duration? length, TailMode? tail, String? Function()? poolId, String? Function()? offlineImage}) =>
      SlotRule(
        length: length ?? this.length,
        tail: tail ?? this.tail,
        poolId: poolId != null ? poolId() : this.poolId,
        offlineImage: offlineImage != null ? offlineImage() : this.offlineImage,
      );

  Map<String, Object?> toJson() => {
        'minutes': length.inMinutes,
        'tail': tail.name,
        if (poolId != null) 'pool': poolId,
        if (offlineImage != null) 'offlineImage': offlineImage,
      };

  /// Null for a length that isn't one of [lengths].
  static SlotRule? fromJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final length = Duration(minutes: j['minutes'] as int? ?? 0);
    if (!lengths.contains(length)) return null;
    return SlotRule(
      length: length,
      tail: TailMode.parse(j['tail']) ?? TailMode.filler,
      poolId: j['pool'] as String?,
      offlineImage: j['offlineImage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SlotRule &&
      other.length == length &&
      other.tail == tail &&
      other.poolId == poolId &&
      other.offlineImage == offlineImage;

  @override
  int get hashCode => Object.hash(length, tail, poolId, offlineImage);
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
/// A block mix's minimum rating (late-night-drift D1): only items rated at
/// [rank] (see `ratingRank`) or above play. Unrated items never pass.
enum RatingFloor {
  teen(4, 'TV-14 / PG-13 and up', 'TV-14'),
  mature(5, 'TV-MA / R and up', 'TV-MA'),
  adult(6, 'NC-17 / 18 and up', 'NC-17');

  const RatingFloor(this.rank, this.label, this.shortLabel);

  final int rank;
  final String label;

  /// The lowest rating that passes, for messages ("rated TV-MA or higher").
  final String shortLabel;

  /// Null for a missing or unknown name.
  static RatingFloor? fromName(Object? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

class ChannelSource {
  const ChannelSource({
    this.genres = const [],
    this.seriesKeys = const [],
    this.includeEpisodes = true,
    this.includeMovies = false,
    this.includeSongs = false,
    this.includeMusicVideos = false,
    this.decades = const [],
    this.roots = const [],
    this.ratingFloor,
    this.excluded = const [],
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

  /// Collections, folders, shows and seasons on the server whose episodes
  /// and movies play, besides what the other choices match (custom-channels
  /// D2).
  final List<PoolRoot> roots;

  /// Blocks only: the minimum rating of what plays. Null = any rating.
  /// Music ignores it.
  final RatingFloor? ratingFloor;

  /// Generated genre channels only: the shows (series keys) and movies (ids)
  /// of the genre that air on a sibling channel instead, so each title has
  /// one genre channel (see `ChannelGenerator.spreadTitles`).
  final List<String> excluded;

  /// Plays songs or music videos.
  bool get isMusic => includeSongs || includeMusicVideos;

  /// A custom channel's or block's source with something picked: a root, a
  /// show, a genre or movies.
  bool get hasPicks =>
      roots.isNotEmpty ||
      seriesKeys.isNotEmpty ||
      includeMovies ||
      (includeEpisodes && genres.isNotEmpty);

  ChannelSource copyWith({
    List<String>? genres,
    List<String>? seriesKeys,
    bool? includeEpisodes,
    bool? includeMovies,
    List<PoolRoot>? roots,
    RatingFloor? Function()? ratingFloor,
    List<String>? excluded,
  }) =>
      ChannelSource(
        genres: genres ?? this.genres,
        seriesKeys: seriesKeys ?? this.seriesKeys,
        includeEpisodes: includeEpisodes ?? this.includeEpisodes,
        includeMovies: includeMovies ?? this.includeMovies,
        includeSongs: includeSongs,
        includeMusicVideos: includeMusicVideos,
        decades: decades,
        roots: roots ?? this.roots,
        ratingFloor: ratingFloor != null ? ratingFloor() : this.ratingFloor,
        excluded: excluded ?? this.excluded,
      );

  Map<String, Object?> toJson() => {
        if (genres.isNotEmpty) 'genres': genres,
        if (seriesKeys.isNotEmpty) 'seriesKeys': seriesKeys,
        'episodes': includeEpisodes,
        'movies': includeMovies,
        if (includeSongs) 'songs': true,
        if (includeMusicVideos) 'musicVideos': true,
        if (decades.isNotEmpty) 'decades': decades,
        if (roots.isNotEmpty) 'roots': [for (final r in roots) r.toJson()],
        if (ratingFloor != null) 'ratingFloor': ratingFloor!.name,
        if (excluded.isNotEmpty) 'excluded': excluded,
      };

  factory ChannelSource.fromJson(Map<String, Object?> j) => ChannelSource(
        genres: (j['genres'] as List?)?.cast<String>() ?? const [],
        seriesKeys: (j['seriesKeys'] as List?)?.cast<String>() ?? const [],
        includeEpisodes: j['episodes'] as bool? ?? true,
        includeMovies: j['movies'] as bool? ?? false,
        includeSongs: j['songs'] as bool? ?? false,
        includeMusicVideos: j['musicVideos'] as bool? ?? false,
        decades: (j['decades'] as List?)?.cast<int>() ?? const [],
        roots: [for (final r in (j['roots'] as List? ?? const []).cast<Map<String, Object?>>()) PoolRoot.fromJson(r)],
        ratingFloor: RatingFloor.fromName(j['ratingFloor']),
        excluded: (j['excluded'] as List?)?.cast<String>() ?? const [],
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
    this.retro = ChannelRetro.main,
    this.premieres = true,
    this.live,
    this.slotRule,
    this.slotCarry,
    this.generation = 0,
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
    ChannelRetro retro = ChannelRetro.live,
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
        retro: retro,
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

  /// This channel's own retro look; what's null follows the main setting.
  ChannelRetro retro;

  /// Can be a show's home channel for new episode premieres.
  bool premieres;

  /// Set for a live channel: where its stream comes from.
  final LiveRef? live;

  /// This channel's slot length and tail mode; null schedules each program
  /// in its own slot, as the break plan lays it out.
  SlotRule? slotRule;

  /// The program finishing its slot since the slot length changed.
  SlotCarry? slotCarry;

  /// Bumped by Reshuffle, which seeds the playlist with it (custom-channels
  /// D10).
  int generation;

  bool get isLive => live != null;

  /// A music channel (songs or music videos).
  bool get isMusic => source.isMusic;

  /// A channel the user built from a source of their own (custom-channels
  /// D1): not generated, not block-only, live or music.
  bool get isCustom => !auto && !blockOnly && !isLive && !isMusic;

  /// Plays programs around the clock, so it can have a slot length.
  bool get playsPrograms => !blockOnly && !isLive && !isMusic;

  /// The rule that applies: [slotRule] on a channel that plays programs.
  SlotRule? get effectiveSlotRule => playsPrograms ? slotRule : null;

  /// The seed of the playlist's order.
  int get seed => generation == 0 ? stableHash(id) : stableHash('$id#$generation');

  /// This channel under another [id] (lineup-dedup D3: its show's key
  /// changed), with everything else the same.
  Channel withId(String id) => Channel(
        id: id,
        number: number,
        name: name,
        icon: icon,
        source: source,
        order: order,
        playlist: playlist,
        anchor: anchor,
        hidden: hidden,
        favorite: favorite,
        auto: auto,
        blockOnly: blockOnly,
        commercialPlan: commercialPlan,
        logoMode: logoMode,
        retro: retro,
        premieres: premieres,
        live: live,
        slotRule: slotRule,
        slotCarry: slotCarry,
        generation: generation,
      );

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
        if (!retro.followsMain) 'retro': retro.toJson(),
        if (!premieres) 'premieres': false,
        if (slotRule != null) 'slot': slotRule!.toJson(),
        if (slotCarry != null) 'slotCarry': slotCarry!.toJson(),
        if (generation != 0) 'generation': generation,
      };

  factory Channel.fromJson(Map<String, Object?> j) => Channel(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String,
        icon: ChannelIcon.fromJson(j['icon'] as Map<String, Object?>),
        source: ChannelSource.fromJson(j['source'] as Map<String, Object?>),
        order: PlaybackOrder.parse(j['order']),
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
        retro: ChannelRetro.fromJson(j['retro']),
        premieres: j['premieres'] as bool? ?? true,
        slotRule: SlotRule.fromJson(j['slot']),
        slotCarry: SlotCarry.fromJson(j['slotCarry']),
        generation: j['generation'] as int? ?? 0,
      );
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
