/// How a channel lays out commercial breaks: off, laid out by Nightingale TV
/// broadcast-style, or set up role by role.
enum BreakMode {
  off,
  automatic,
  custom;

  String get label => switch (this) {
        off => 'Off',
        automatic => 'Automatic',
        custom => 'Custom',
      };
}

/// The five parts of a slot that hold commercials (the ErsatzTV / Tunarr
/// convention).
enum BreakRole {
  /// Before the program.
  pre,

  /// At break points inside the program.
  mid,

  /// After the program.
  post,

  /// Pads the slot out to the next clock boundary.
  tail,

  /// Whatever is left of a break when no clip fits.
  fallback;

  String get label => switch (this) {
        pre => 'Pre-roll',
        mid => 'Mid-roll',
        post => 'Post-roll',
        tail => 'Tail',
        fallback => 'Fallback',
      };
}

/// What fills the seconds of a break that no clip fits into.
enum FallbackKind {
  /// The channel's station-ID card.
  idCard,

  /// A pool clip, cut short.
  pool,
}

/// The settings of a Custom plan. Every role is a length (not a count of
/// ads), so a slot's length never depends on which clips exist.
class CustomRoles {
  const CustomRoles({
    this.preRoll = Duration.zero,
    this.midInterval,
    this.midLength = const Duration(minutes: 2),
    this.postRoll = Duration.zero,
    this.tailGrid,
    this.fallback = FallbackKind.idCard,
    this.prePool,
    this.midPool,
    this.postPool,
    this.tailPool,
    this.fallbackPool,
  });

  final Duration preRoll;

  /// A mid-roll break every this often; null for no mid-rolls.
  final Duration? midInterval;
  final Duration midLength;
  final Duration postRoll;

  /// Pads each slot to the next multiple of this; null for no tail.
  final Duration? tailGrid;
  final FallbackKind fallback;

  /// Pool ids per role; null means all pools.
  final String? prePool;
  final String? midPool;
  final String? postPool;
  final String? tailPool;
  final String? fallbackPool;

  static const preRollChoices = [
    Duration.zero,
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];

  /// Null is "off".
  static const midIntervalChoices = <Duration?>[
    null,
    Duration(minutes: 6),
    Duration(minutes: 8),
    Duration(minutes: 10),
    Duration(minutes: 12),
    Duration(minutes: 15),
  ];

  static const midLengthChoices = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(seconds: 90),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 4),
  ];

  static const postRollChoices = [
    Duration.zero,
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 4),
    Duration(minutes: 5),
  ];

  /// Null is "none".
  static const tailGridChoices = <Duration?>[
    null,
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  String? poolFor(BreakRole role) => switch (role) {
        BreakRole.pre => prePool,
        BreakRole.mid => midPool,
        BreakRole.post => postPool,
        BreakRole.tail => tailPool,
        BreakRole.fallback => fallbackPool,
      };

  CustomRoles copyWith({
    Duration? preRoll,
    Duration? Function()? midInterval,
    Duration? midLength,
    Duration? postRoll,
    Duration? Function()? tailGrid,
    FallbackKind? fallback,
  }) =>
      CustomRoles(
        preRoll: preRoll ?? this.preRoll,
        midInterval: midInterval != null ? midInterval() : this.midInterval,
        midLength: midLength ?? this.midLength,
        postRoll: postRoll ?? this.postRoll,
        tailGrid: tailGrid != null ? tailGrid() : this.tailGrid,
        fallback: fallback ?? this.fallback,
        prePool: prePool,
        midPool: midPool,
        postPool: postPool,
        tailPool: tailPool,
        fallbackPool: fallbackPool,
      );

  /// A copy drawing [role]'s clips from [poolId] (null: all pools).
  CustomRoles withPool(BreakRole role, String? poolId) => CustomRoles(
        preRoll: preRoll,
        midInterval: midInterval,
        midLength: midLength,
        postRoll: postRoll,
        tailGrid: tailGrid,
        fallback: fallback,
        prePool: role == BreakRole.pre ? poolId : prePool,
        midPool: role == BreakRole.mid ? poolId : midPool,
        postPool: role == BreakRole.post ? poolId : postPool,
        tailPool: role == BreakRole.tail ? poolId : tailPool,
        fallbackPool: role == BreakRole.fallback ? poolId : fallbackPool,
      );

  /// A copy where every role that drew from [poolId] uses all pools.
  CustomRoles withoutPool(String poolId) {
    var roles = this;
    for (final role in BreakRole.values) {
      if (poolFor(role) == poolId) roles = roles.withPool(role, null);
    }
    return roles;
  }

  Map<String, Object?> toJson() => {
        'preMs': preRoll.inMilliseconds,
        if (midInterval != null) 'midIntervalMs': midInterval!.inMilliseconds,
        'midMs': midLength.inMilliseconds,
        'postMs': postRoll.inMilliseconds,
        if (tailGrid != null) 'tailMs': tailGrid!.inMilliseconds,
        'fallback': fallback.name,
        'pools': {
          for (final role in BreakRole.values)
            if (poolFor(role) != null) role.name: poolFor(role),
        },
      };

  factory CustomRoles.fromJson(Map<String, Object?> j) {
    Duration? ms(String key) => switch (j[key]) { final int v => Duration(milliseconds: v), _ => null };
    final pools = (j['pools'] as Map?)?.cast<String, Object?>() ?? const {};
    String? pool(BreakRole role) => pools[role.name] as String?;
    return CustomRoles(
      preRoll: ms('preMs') ?? Duration.zero,
      midInterval: ms('midIntervalMs'),
      midLength: ms('midMs') ?? const Duration(minutes: 2),
      postRoll: ms('postMs') ?? Duration.zero,
      tailGrid: ms('tailMs'),
      fallback: FallbackKind.values.asNameMap()[j['fallback']] ?? FallbackKind.idCard,
      prePool: pool(BreakRole.pre),
      midPool: pool(BreakRole.mid),
      postPool: pool(BreakRole.post),
      tailPool: pool(BreakRole.tail),
      fallbackPool: pool(BreakRole.fallback),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomRoles &&
      other.preRoll == preRoll &&
      other.midInterval == midInterval &&
      other.midLength == midLength &&
      other.postRoll == postRoll &&
      other.tailGrid == tailGrid &&
      other.fallback == fallback &&
      other.prePool == prePool &&
      other.midPool == midPool &&
      other.postPool == postPool &&
      other.tailPool == tailPool &&
      other.fallbackPool == fallbackPool;

  @override
  int get hashCode => Object.hash(preRoll, midInterval, midLength, postRoll, tailGrid, fallback, prePool,
      midPool, postPool, tailPool, fallbackPool);
}

/// A break plan: the mode, plus the Custom settings (kept while another mode
/// is chosen, so switching back to Custom restores them).
class BreakPlan {
  const BreakPlan({required this.mode, this.roles = const CustomRoles()});

  static const off = BreakPlan(mode: BreakMode.off);
  static const automatic = BreakPlan(mode: BreakMode.automatic);

  /// Breaks as they worked before break plans: nothing before, during or
  /// after the program, padded to the quarter hour from all pools, with the
  /// station ID for the last seconds.
  static const legacy = BreakPlan(
    mode: BreakMode.custom,
    roles: CustomRoles(tailGrid: Duration(minutes: 15)),
  );

  final BreakMode mode;
  final CustomRoles roles;

  bool get isOff => mode == BreakMode.off;

  BreakPlan withMode(BreakMode m) => BreakPlan(mode: m, roles: roles);
  BreakPlan withRoles(CustomRoles r) => BreakPlan(mode: mode, roles: r);

  /// The roles in effect: the Custom settings, or Automatic's (every role
  /// from all pools, the station ID as fallback).
  CustomRoles get effectiveRoles => mode == BreakMode.custom ? roles : const CustomRoles();

  /// The clock boundary a channel's anchor lines up on, so its slots stay on
  /// the clock; null when slots aren't padded to one.
  Duration? get alignment => switch (mode) {
        BreakMode.off => null,
        BreakMode.automatic => automaticGrid,
        BreakMode.custom => roles.tailGrid,
      };

  /// The pools whose clips this plan can play (null in the set: all pools).
  Set<String?> get poolsUsed {
    if (mode == BreakMode.off) return const {};
    if (mode == BreakMode.automatic) return const {null};
    final r = roles;
    return {
      if (r.preRoll > Duration.zero) r.prePool,
      if (r.midInterval != null) r.midPool,
      if (r.postRoll > Duration.zero) r.postPool,
      if (r.tailGrid != null) r.tailPool,
      if (r.fallback == FallbackKind.pool) r.fallbackPool,
    };
  }

  // ---- Automatic -----------------------------------------------------------

  static const automaticGrid = Duration(minutes: 30);
  static const automaticShortGrid = Duration(minutes: 15);

  /// Programs shorter than this use [automaticShortGrid].
  static const automaticShortUnder = Duration(minutes: 12);
  static const automaticInterval = Duration(minutes: 10);
  static const automaticLongInterval = Duration(minutes: 12);

  /// Programs longer than this use [automaticLongInterval].
  static const automaticLongOver = Duration(minutes: 60);

  /// Ad time reserved for each mid-roll, plus [automaticBaseAdTime] once,
  /// before rounding up to the grid.
  static const automaticAdTimePerMid = Duration(minutes: 1);
  static const automaticBaseAdTime = Duration(minutes: 1);
  static const automaticPreRoll = Duration(seconds: 15);

  /// Share of the ad time (after the pre-roll) that goes to mid-rolls.
  static const automaticMidShare = 0.8;
  static const automaticMaxMid = Duration(minutes: 4);

  /// Mid-roll lengths are rounded down to this.
  static const automaticStep = Duration(seconds: 15);

  Map<String, Object?> toJson() => {'mode': mode.name, 'roles': roles.toJson()};

  factory BreakPlan.fromJson(Map<String, Object?> j) => BreakPlan(
        mode: BreakMode.values.asNameMap()[j['mode']] ?? BreakMode.off,
        roles: switch (j['roles']) {
          final Map<String, Object?> r => CustomRoles.fromJson(r),
          _ => const CustomRoles(),
        },
      );

  @override
  bool operator ==(Object other) => other is BreakPlan && other.mode == mode && other.roles == roles;

  @override
  int get hashCode => Object.hash(mode, roles);
}

/// How one program's slot divides up under a plan. Depends only on the
/// program's runtime and the plan, so the guide never shifts when analysis
/// finishes or clips change.
class SlotPlan {
  const SlotPlan({
    required this.runtime,
    required this.preRoll,
    required this.midCount,
    required this.midLength,
    required this.postRoll,
    required this.tail,
    required this.roles,
  });

  /// No breaks: the slot is the program.
  const SlotPlan.none(this.runtime)
      : preRoll = Duration.zero,
        midCount = 0,
        midLength = Duration.zero,
        postRoll = Duration.zero,
        tail = Duration.zero,
        roles = const CustomRoles();

  final Duration runtime;
  final Duration preRoll;
  final int midCount;
  final Duration midLength;
  final Duration postRoll;

  /// Padding after the post-roll, up to the clock boundary.
  final Duration tail;

  /// Which pools the roles draw from, and the fallback.
  final CustomRoles roles;

  Duration get adTime => preRoll + midLength * midCount + postRoll + tail;
  Duration get slotLength => runtime + adTime;
  bool get hasBreaks => adTime > Duration.zero;
}

/// Works out [runtime]'s slot under [plan].
SlotPlan resolve(BreakPlan plan, Duration runtime) {
  if (runtime <= Duration.zero) return SlotPlan.none(runtime);
  switch (plan.mode) {
    case BreakMode.off:
      return SlotPlan.none(runtime);
    case BreakMode.automatic:
      final grid = runtime < BreakPlan.automaticShortUnder ? BreakPlan.automaticShortGrid : BreakPlan.automaticGrid;
      final interval =
          runtime > BreakPlan.automaticLongOver ? BreakPlan.automaticLongInterval : BreakPlan.automaticInterval;
      final mids = midRollCount(runtime, interval);
      final slot = _roundUp(runtime + BreakPlan.automaticAdTimePerMid * mids + BreakPlan.automaticBaseAdTime, grid);
      const pre = BreakPlan.automaticPreRoll;
      final remaining = slot - runtime - pre;
      var mid = Duration.zero;
      if (mids > 0) {
        final share = Duration(microseconds: (remaining.inMicroseconds * BreakPlan.automaticMidShare) ~/ mids);
        mid = _roundDown(share < BreakPlan.automaticMaxMid ? share : BreakPlan.automaticMaxMid, BreakPlan.automaticStep);
      }
      return SlotPlan(
        runtime: runtime,
        preRoll: pre,
        midCount: mids,
        midLength: mid,
        postRoll: remaining - mid * mids,
        tail: Duration.zero,
        roles: plan.effectiveRoles,
      );
    case BreakMode.custom:
      final r = plan.roles;
      final mids = r.midInterval == null ? 0 : midRollCount(runtime, r.midInterval!);
      final filled = runtime + r.preRoll + r.midLength * mids + r.postRoll;
      final grid = r.tailGrid;
      return SlotPlan(
        runtime: runtime,
        preRoll: r.preRoll,
        midCount: mids,
        midLength: mids == 0 ? Duration.zero : r.midLength,
        postRoll: r.postRoll,
        tail: grid == null ? Duration.zero : _roundUp(filled, grid) - filled,
        roles: r,
      );
  }
}

/// One mid-roll fewer than [runtime] / [interval], rounded up.
int midRollCount(Duration runtime, Duration interval) {
  final n = (runtime.inMicroseconds + interval.inMicroseconds - 1) ~/ interval.inMicroseconds - 1;
  return n < 0 ? 0 : n;
}

Duration _roundUp(Duration d, Duration grid) =>
    Duration(microseconds: (d.inMicroseconds + grid.inMicroseconds - 1) ~/ grid.inMicroseconds * grid.inMicroseconds);

Duration _roundDown(Duration d, Duration step) =>
    Duration(microseconds: d.inMicroseconds ~/ step.inMicroseconds * step.inMicroseconds);
