import '../l10n/tr.dart';

/// How a channel lays out commercial breaks: off, laid out by Nightingale TV
/// broadcast-style, or set up role by role.
enum BreakMode {
  off,
  automatic,
  custom;

  String get label => switch (this) {
        off => tr.off,
        automatic => tr.automatic,
        custom => tr.custom,
      };
}

/// The parts of a slot that hold commercials (the ErsatzTV / Tunarr
/// convention).
enum BreakRole {
  /// Before the program.
  pre,

  /// At break points inside the program.
  mid,

  /// After the program.
  post,

  /// Pads the slot out to the next clock boundary.
  tail;

  String get label => switch (this) {
        pre => tr.preRoll,
        mid => tr.midRoll,
        post => tr.postRoll,
        tail => tr.tail,
      };
}

/// The settings of a Custom plan. Every role is a length (not a count of
/// ads), so a slot's length never depends on which clips exist.
class CustomRoles {
  const CustomRoles({
    this.preRoll = Duration.zero,
    this.midInterval,
    this.midLength = const Duration(minutes: 2),
    this.postRoll = Duration.zero,
    this.tailGrid = const Duration(minutes: 30),
    this.prePool,
    this.midPool,
    this.postPool,
    this.tailPool,
    this.bumperPool,
    this.noBumpers = false,
  });

  final Duration preRoll;

  /// A mid-roll break every this often; null for no mid-rolls.
  final Duration? midInterval;
  final Duration midLength;
  final Duration postRoll;

  /// Pads each slot to the next multiple of this (one of
  /// [tailGridChoices]), so programs start on the hour or half hour.
  final Duration tailGrid;

  /// Pool ids per role; null means all pools.
  final String? prePool;
  final String? midPool;
  final String? postPool;
  final String? tailPool;

  /// The bumper pool framing breaks; null means all bumper pools.
  final String? bumperPool;

  /// This plan's breaks have no bumpers.
  final bool noBumpers;

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

  static const tailGridChoices = [
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  /// [grid] as one of [tailGridChoices]: saved plans with no padding, or
  /// the quarter hour, pad to the half hour (clock-aligned-slots).
  static Duration tailGridOf(Duration? grid) =>
      grid != null && grid >= const Duration(minutes: 60) ? const Duration(minutes: 60) : const Duration(minutes: 30);

  String? poolFor(BreakRole role) => switch (role) {
        BreakRole.pre => prePool,
        BreakRole.mid => midPool,
        BreakRole.post => postPool,
        BreakRole.tail => tailPool,
      };

  CustomRoles copyWith({
    Duration? preRoll,
    Duration? Function()? midInterval,
    Duration? midLength,
    Duration? postRoll,
    Duration? tailGrid,
  }) =>
      CustomRoles(
        preRoll: preRoll ?? this.preRoll,
        midInterval: midInterval != null ? midInterval() : this.midInterval,
        midLength: midLength ?? this.midLength,
        postRoll: postRoll ?? this.postRoll,
        tailGrid: tailGrid ?? this.tailGrid,
        prePool: prePool,
        midPool: midPool,
        postPool: postPool,
        tailPool: tailPool,
        bumperPool: bumperPool,
        noBumpers: noBumpers,
      );

  /// A copy drawing [role]'s clips from [poolId] (null: all pools).
  CustomRoles withPool(BreakRole role, String? poolId) => CustomRoles(
        preRoll: preRoll,
        midInterval: midInterval,
        midLength: midLength,
        postRoll: postRoll,
        tailGrid: tailGrid,
        prePool: role == BreakRole.pre ? poolId : prePool,
        midPool: role == BreakRole.mid ? poolId : midPool,
        postPool: role == BreakRole.post ? poolId : postPool,
        tailPool: role == BreakRole.tail ? poolId : tailPool,
        bumperPool: bumperPool,
        noBumpers: noBumpers,
      );

  /// A copy framing breaks with [poolId]'s bumpers (null: all bumper pools),
  /// or with [none], with no bumpers.
  CustomRoles withBumpers(String? poolId, {bool none = false}) => CustomRoles(
        preRoll: preRoll,
        midInterval: midInterval,
        midLength: midLength,
        postRoll: postRoll,
        tailGrid: tailGrid,
        prePool: prePool,
        midPool: midPool,
        postPool: postPool,
        tailPool: tailPool,
        bumperPool: none ? null : poolId,
        noBumpers: none,
      );

  /// A copy where every role that drew from [poolId] uses all pools, and
  /// bumpers from it use all bumper pools.
  CustomRoles withoutPool(String poolId) {
    var roles = this;
    for (final role in BreakRole.values) {
      if (poolFor(role) == poolId) roles = roles.withPool(role, null);
    }
    return bumperPool == poolId ? roles.withBumpers(null) : roles;
  }

  Map<String, Object?> toJson() => {
        'preMs': preRoll.inMilliseconds,
        if (midInterval != null) 'midIntervalMs': midInterval!.inMilliseconds,
        'midMs': midLength.inMilliseconds,
        'postMs': postRoll.inMilliseconds,
        'tailMs': tailGrid.inMilliseconds,
        'pools': {
          for (final role in BreakRole.values)
            if (poolFor(role) != null) role.name: poolFor(role),
          if (bumperPool != null) 'bumpers': bumperPool,
        },
        if (noBumpers) 'noBumpers': true,
      };

  /// Plans saved with a fallback (`fallback`, `pools.fallback`) load with it
  /// ignored: breaks fill to the second, so nothing is left for one.
  factory CustomRoles.fromJson(Map<String, Object?> j) {
    Duration? ms(String key) => switch (j[key]) { final int v => Duration(milliseconds: v), _ => null };
    final pools = (j['pools'] as Map?)?.cast<String, Object?>() ?? const {};
    String? pool(BreakRole role) => pools[role.name] as String?;
    return CustomRoles(
      preRoll: ms('preMs') ?? Duration.zero,
      midInterval: ms('midIntervalMs'),
      midLength: ms('midMs') ?? const Duration(minutes: 2),
      postRoll: ms('postMs') ?? Duration.zero,
      tailGrid: tailGridOf(ms('tailMs')),
      prePool: pool(BreakRole.pre),
      midPool: pool(BreakRole.mid),
      postPool: pool(BreakRole.post),
      tailPool: pool(BreakRole.tail),
      bumperPool: pools['bumpers'] as String?,
      noBumpers: j['noBumpers'] == true,
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
      other.prePool == prePool &&
      other.midPool == midPool &&
      other.postPool == postPool &&
      other.tailPool == tailPool &&
      other.bumperPool == bumperPool &&
      other.noBumpers == noBumpers;

  @override
  int get hashCode => Object.hash(
      preRoll, midInterval, midLength, postRoll, tailGrid, prePool, midPool, postPool, tailPool, bumperPool, noBumpers);
}

/// A break plan: the mode, plus the Custom settings (kept while another mode
/// is chosen, so switching back to Custom restores them).
class BreakPlan {
  const BreakPlan({required this.mode, this.roles = const CustomRoles()});

  static const off = BreakPlan(mode: BreakMode.off);
  static const automatic = BreakPlan(mode: BreakMode.automatic);

  /// Breaks as they worked before break plans: nothing before, during or
  /// after the program, padded from all pools, now to the half hour.
  static const legacy = BreakPlan(mode: BreakMode.custom, roles: CustomRoles());

  final BreakMode mode;
  final CustomRoles roles;

  bool get isOff => mode == BreakMode.off;

  BreakPlan withMode(BreakMode m) => BreakPlan(mode: m, roles: roles);
  BreakPlan withRoles(CustomRoles r) => BreakPlan(mode: mode, roles: r);

  /// The roles in effect: the Custom settings, or Automatic's (every role
  /// from all pools).
  CustomRoles get effectiveRoles => mode == BreakMode.custom ? roles : const CustomRoles();

  /// The clock boundary a channel's anchor lines up on, so its slots stay on
  /// the clock; null when slots aren't padded to one.
  Duration? get alignment => switch (mode) {
        BreakMode.off => null,
        BreakMode.automatic => automaticGrid,
        BreakMode.custom => roles.tailGrid,
      };

  /// The commercial pools whose clips this plan can play (null in the set:
  /// all pools). Bumpers alone never make a break, so they don't count.
  Set<String?> get poolsUsed {
    if (mode == BreakMode.off) return const {};
    if (mode == BreakMode.automatic) return const {null};
    final r = roles;
    return {
      if (r.preRoll > Duration.zero) r.prePool,
      if (r.midInterval != null) r.midPool,
      if (r.postRoll > Duration.zero) r.postPool,
      r.tailPool,
    };
  }

  // ---- Automatic -----------------------------------------------------------

  /// Slots round up to the half hour, shorts to the quarter hour; more
  /// mid-rolls keep every break within [automaticMaxBreak].
  static const automaticGrid = Duration(minutes: 30);
  static const automaticShortGrid = Duration(minutes: 15);

  /// Programs shorter than this start from [automaticShortGrid].
  static const automaticShortUnder = Duration(minutes: 12);
  static const automaticInterval = Duration(minutes: 10);
  static const automaticLongInterval = Duration(minutes: 12);

  /// Programs longer than this use [automaticLongInterval].
  static const automaticLongOver = Duration(minutes: 60);

  /// The least ad time in a slot, added to the runtime before rounding up.
  static const automaticMinAdTime = Duration(seconds: 30);
  static const automaticPreRoll = Duration(seconds: 15);

  /// Share of the ad time (after the pre-roll) that goes to mid-rolls.
  static const automaticMidShare = 0.8;
  static const automaticMaxMid = Duration(minutes: 4);
  static const automaticMinMid = Duration(seconds: 30);

  /// No break is planned longer than this.
  static const automaticMaxBreak = Duration(minutes: 5);

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
    this.offlineTail = false,
    this.cutAt,
    this.ruled = false,
  });

  /// No breaks: the slot is the program.
  const SlotPlan.none(this.runtime)
      : preRoll = Duration.zero,
        midCount = 0,
        midLength = Duration.zero,
        postRoll = Duration.zero,
        tail = Duration.zero,
        roles = const CustomRoles(),
        offlineTail = false,
        cutAt = null,
        ruled = false;

  final Duration runtime;
  final Duration preRoll;
  final int midCount;
  final Duration midLength;
  final Duration postRoll;

  /// Padding after the post-roll, up to the clock boundary.
  final Duration tail;

  /// Which pools the roles draw from.
  final CustomRoles roles;

  /// The [tail] shows the channel's offline card instead of clips.
  final bool offlineTail;

  /// Truncate: the slot ends here, cutting the program and its breaks.
  final Duration? cutAt;

  /// Made by [withRule]: a tail with no clips shows the offline card.
  final bool ruled;

  /// The cut comes before the program's end ("Ends early"), not just in
  /// its post-roll.
  bool get endsEarly => cutAt != null && cutAt! < runtime + preRoll + midLength * midCount;

  /// This slot under a channel's slot length (custom-channels D7): Filler
  /// and Offline image round the slot, without the plan's own tail, up to
  /// the next multiple of [length], the rest a tail of clips from
  /// [poolId] (all pools when null) or the offline card; Truncate makes
  /// it exactly [length], padding as Filler does or cutting at its end.
  SlotPlan withRule({required Duration length, required bool offline, required bool truncate, String? poolId}) {
    final filled = slotLength - tail;
    final cut = truncate && filled > length;
    final rest = cut
        ? Duration.zero
        : truncate
            ? length - filled
            : _roundUp(filled, length) - filled;
    return SlotPlan(
      runtime: runtime,
      preRoll: preRoll,
      midCount: midCount,
      midLength: midLength,
      postRoll: postRoll,
      tail: rest,
      roles: roles.withPool(BreakRole.tail, poolId),
      offlineTail: offline,
      cutAt: cut ? length : null,
      ruled: true,
    );
  }

  /// This slot with [extra] more tail (clock-aligned-slots).
  SlotPlan padded(Duration extra) => SlotPlan(
        runtime: runtime,
        preRoll: preRoll,
        midCount: midCount,
        midLength: midLength,
        postRoll: postRoll,
        tail: tail + extra,
        roles: roles,
        offlineTail: offlineTail,
        cutAt: cutAt == null ? null : cutAt! + extra,
        ruled: ruled,
      );

  /// The same slot with no break inside the program: the mid-roll time
  /// goes to the post-roll (songs and music videos break only between them).
  SlotPlan withoutMidRolls() => midCount == 0
      ? this
      : SlotPlan(
          runtime: runtime,
          preRoll: preRoll,
          midCount: 0,
          midLength: Duration.zero,
          postRoll: postRoll + midLength * midCount,
          tail: tail,
          roles: roles,
          offlineTail: offlineTail,
          cutAt: cutAt,
          ruled: ruled,
        );

  Duration get adTime => preRoll + midLength * midCount + postRoll + tail;
  Duration get slotLength => cutAt ?? runtime + adTime;
  bool get hasBreaks => adTime > Duration.zero;
}

/// Works out [runtime]'s slot under [plan].
SlotPlan resolve(BreakPlan plan, Duration runtime) {
  if (runtime <= Duration.zero) return SlotPlan.none(runtime);
  switch (plan.mode) {
    case BreakMode.off:
      return SlotPlan.none(runtime);
    case BreakMode.automatic:
      final interval =
          runtime > BreakPlan.automaticLongOver ? BreakPlan.automaticLongInterval : BreakPlan.automaticInterval;
      final mids = midRollCount(runtime, interval);
      final grid = runtime >= BreakPlan.automaticShortUnder ? BreakPlan.automaticGrid : BreakPlan.automaticShortGrid;
      final slot = _roundUp(runtime + BreakPlan.automaticMinAdTime, grid);
      // The slot stays on the clock; more mid-rolls keep breaks short.
      for (var more = mids;; more++) {
        final split = _automaticSplit(plan, runtime, slot, more);
        if (split != null) return split;
      }
    case BreakMode.custom:
      final r = plan.roles;
      final mids = r.midInterval == null ? 0 : midRollCount(runtime, r.midInterval!);
      final filled = runtime + r.preRoll + r.midLength * mids + r.postRoll;
      return SlotPlan(
        runtime: runtime,
        preRoll: r.preRoll,
        midCount: mids,
        midLength: mids == 0 ? Duration.zero : r.midLength,
        postRoll: r.postRoll,
        tail: _roundUp(filled, r.tailGrid) - filled,
        roles: r,
      );
  }
}

/// Splits an Automatic [slot]'s ad time: the pre-roll, [mids] mid-rolls
/// taking [BreakPlan.automaticMidShare] of the rest, the post-roll the
/// remainder. Null when a break would be over [BreakPlan.automaticMaxBreak].
SlotPlan? _automaticSplit(BreakPlan plan, Duration runtime, Duration slot, int mids) {
  const step = BreakPlan.automaticStep, maxBreak = BreakPlan.automaticMaxBreak;
  final ads = slot - runtime;
  final pre = ads < BreakPlan.automaticPreRoll ? ads : BreakPlan.automaticPreRoll;
  final remaining = ads - pre;
  final midTime = remaining.inMicroseconds * BreakPlan.automaticMidShare;
  // A mid-roll is at least 30 s: fewer of them when the time is short.
  final minMid = BreakPlan.automaticMinMid.inMicroseconds;
  var count = mids;
  if (count > 0 && midTime / count < minMid) count = midTime ~/ minMid;
  var mid = Duration.zero;
  if (count > 0) {
    final share = Duration(microseconds: midTime ~/ count);
    mid = _roundDown(share < BreakPlan.automaticMaxMid ? share : BreakPlan.automaticMaxMid, step);
    // A long post-roll is spread over the mid-rolls.
    while (remaining - mid * count > maxBreak && mid + step <= maxBreak && mid + step <= remaining ~/ count) {
      mid += step;
    }
  }
  final post = remaining - mid * count;
  if (post > maxBreak || mid > maxBreak) return null;
  return SlotPlan(
    runtime: runtime,
    preRoll: pre,
    midCount: count,
    midLength: mid,
    postRoll: post,
    tail: Duration.zero,
    roles: plan.effectiveRoles,
  );
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
