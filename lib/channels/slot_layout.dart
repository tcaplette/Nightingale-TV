import 'dart:math';
import 'dart:typed_data';

import '../commercials/analysis/break_points.dart';
import '../commercials/analysis/detections.dart';
import '../commercials/break_plan.dart';
import '../commercials/break_sources.dart';
import '../library/library_index.dart';

/// One piece of a slot: a part of the show or a commercial clip. Times are
/// offsets from the start of the (uncut) slot.
class LayoutSegment {
  const LayoutSegment({
    required this.from,
    required this.to,
    this.role,
    this.item,
    this.itemFrom = Duration.zero,
  });

  final Duration from;
  final Duration to;

  /// Null for a part of the show.
  final BreakRole? role;

  /// The program for show parts, the clip for commercials. Null only for
  /// a slot's last break when no pool had a single clip at its time.
  final MediaEntry? item;

  /// Where in [item]'s video ([MediaEntry.sourceId]) this segment starts.
  final Duration itemFrom;

  bool get isShow => role == null;
  Duration get length => to - from;
}

/// How one program's slot plays: pre-roll, show part, mid-roll, show part,
/// …, post-roll, tail. The same inputs always give the same layout.
class SlotLayout {
  SlotLayout._(this.segments);

  final List<LayoutSegment> segments;

  /// Where BREAKFILL lines go (the diagnostics log), when set.
  static void Function(String line)? log;

  Duration get length => segments.isEmpty ? Duration.zero : segments.last.to;

  /// Lays out [item] under [plan] for a slot starting at [layoutStart].
  ///
  /// Mid-rolls go at the points [info] allows; Commercial segments in the
  /// program are skipped, their length added to the break at their start.
  /// Each break is filled from its role's pool in [clips] (all pools when
  /// that one has none), shuffled with a seed made from [seed] (the channel)
  /// and the break's start, with the clips adding up closest to its length
  /// (see [_fill]). A break that falls short shortens, and the next break
  /// makes up for it; the slot's last break reaches its end exactly, its
  /// last clip cut short by the excess.
  factory SlotLayout.build({
    required MediaEntry item,
    required SlotPlan plan,
    required DateTime layoutStart,
    required ProgramBreakInfo info,
    required ClipSource clips,
    required int seed,
  }) {
    final runtime = item.runtime;
    final roles = plan.roles;
    // The slot in order: show parts (by position in the show) and breaks (by
    // planned length).
    final pieces = <({BreakRole? role, Duration from, Duration to})>[];

    void fill(BreakRole role, Duration length) {
      if (length > Duration.zero) pieces.add((role: role, from: Duration.zero, to: length));
    }

    void show(Duration from, Duration to) {
      if (to > from) pieces.add((role: null, from: from, to: to));
    }

    // Where the show stops: the chosen points, plus each skipped segment.
    final skips = _mergedSkips(info.skips, runtime);
    final stops = <Duration, ({Duration ads, Duration resume})>{};
    void stopAt(Duration at, Duration ads, Duration resume) {
      final old = stops[at];
      stops[at] = old == null
          ? (ads: ads, resume: resume)
          : (ads: old.ads + ads, resume: resume > old.resume ? resume : old.resume);
    }

    for (final s in skips) {
      stopAt(s.start, s.length, s.end);
    }
    for (final p in plan.midCount > 0 ? BreakPointFinder.choose(runtime, plan.midCount, info) : const <Duration>[]) {
      // A point inside a skipped segment moves to where it starts.
      final inside = skips.where((s) => s.contains(p)).firstOrNull;
      final at = inside?.start ?? p;
      stopAt(at, plan.midLength, inside?.end ?? at);
    }

    fill(BreakRole.pre, plan.preRoll);
    var position = Duration.zero;
    for (final at in stops.keys.toList()..sort()) {
      final stop = stops[at]!;
      if (at < position) {
        // Inside a stretch already skipped: only its ad time remains.
        fill(BreakRole.mid, stop.ads);
        if (stop.resume > position) position = stop.resume;
        continue;
      }
      show(position, at);
      fill(BreakRole.mid, stop.ads);
      position = stop.resume > at ? stop.resume : at;
    }
    show(position, runtime);
    fill(BreakRole.post, plan.postRoll);
    fill(BreakRole.tail, plan.tail);

    final last = pieces.lastIndexWhere((p) => p.role != null);
    final segments = <LayoutSegment>[];
    final used = <String>{};
    var t = Duration.zero, carry = Duration.zero;
    for (final (i, p) in pieces.indexed) {
      final role = p.role;
      if (role == null) {
        segments.add(LayoutSegment(from: t, to: t + (p.to - p.from), item: item, itemFrom: p.from));
        t += p.to - p.from;
        continue;
      }
      final target = p.to + carry;
      final filled = _fill(segments, role, t, target, i == last, layoutStart, clips, roles, seed, used, item.title);
      carry = target - filled;
      t += filled;
    }
    return SlotLayout._(segments);
  }

  /// The segment playing [offset] into the slot (the last one past its end).
  LayoutSegment at(Duration offset) {
    var lo = 0, hi = segments.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (segments[mid].from <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return segments[lo];
  }

  /// The slot offset at which the show reaches [position]; a position in a
  /// skipped stretch maps to where the show resumes.
  Duration offsetOf(Duration position) {
    for (final s in segments) {
      if (!s.isShow) continue;
      final end = s.itemFrom + s.length;
      if (position < s.itemFrom) return s.from;
      if (position < end) return s.from + (position - s.itemFrom);
    }
    final last = segments.lastWhere((s) => s.isShow, orElse: () => segments.last);
    return last.to;
  }

  static List<Span> _mergedSkips(List<Span> skips, Duration runtime) {
    final sorted = [
      for (final s in skips)
        if (s.end > Duration.zero && s.start < runtime)
          Span(s.start < Duration.zero ? Duration.zero : s.start, s.end > runtime ? runtime : s.end),
    ]..sort();
    final merged = <Span>[];
    for (final s in sorted) {
      if (merged.isNotEmpty && s.start <= merged.last.end) {
        final last = merged.removeLast();
        merged.add(Span(last.start, s.end > last.end ? s.end : last.end));
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  /// Fills a break of [target] from [from] with [role]'s clips and returns
  /// how long it is: up to [target] (any shortfall is the caller's to carry),
  /// or for the slot's [last] break exactly [target], its last clip cut by
  /// the excess. Clips in [used] (already in the slot) repeat only when the
  /// others can't get within 1 s.
  static Duration _fill(List<LayoutSegment> out, BreakRole role, Duration from, Duration target, bool last,
      DateTime layoutStart, ClipSource clips, CustomRoles roles, int seed, Set<String> used, String program) {
    final start = layoutStart.add(from);
    final end = from + target;
    final poolId = roles.poolFor(role);
    var pool = clips.clipsAt(poolId, start);
    if (pool.isEmpty && poolId != null) pool = clips.clipsAt(null, start);
    final bag = [for (final c in pool) if (c.runtime > Duration.zero) c]..shuffle(_random(seed, start));
    final picks = _bestFit(bag, target, used, reach: last);
    var t = from, full = Duration.zero, repeats = 0;
    for (final clip in picks) {
      if (t >= end) break;
      final to = t + clip.runtime < end ? t + clip.runtime : end;
      out.add(LayoutSegment(from: t, to: to, role: role, item: clip, itemFrom: clip.sourceStart));
      if (!used.add(clip.id)) repeats++;
      full += clip.runtime;
      t = to;
    }
    if (last && t < end) {
      // No pool has a clip at this time (a plan with none airs as Off).
      out.add(LayoutSegment(from: t, to: end, role: role));
      t = end;
    }
    final filled = t - from;
    log?.call('${start.toIso8601String()} "$program" ${role.name} target ${_secs(target)} total ${_secs(full)} '
        '${last ? 'trimmed ${_secs(full - filled)}' : 'carried ${_secs(target - filled)}'} '
        'clips ${picks.length} repeats $repeats pool ${bag.length}');
    return filled;
  }

  static String _secs(Duration d) => (d.inMicroseconds / 1e6).toStringAsFixed(3);

  /// How close a fill must get before used clips may repeat.
  static const _close = Duration(seconds: 1);

  /// The clips from [bag] whose lengths add up closest to [target]: the most
  /// that stays within it, or with [reach] the least that reaches it. Clips
  /// in [used] come in only when the others can't get within 1 s, and then
  /// clips may repeat. Ties go to clips earlier in [bag]; the picks keep
  /// bag order.
  static List<MediaEntry> _bestFit(List<MediaEntry> bag, Duration target, Set<String> used, {required bool reach}) {
    if (bag.isEmpty || target <= Duration.zero) return const [];
    final fresh = [for (final c in bag) if (!used.contains(c.id)) c];
    final first = _subsetSum(fresh, target, reach);
    if (first != null && _off(first, target) <= _close) return first;
    // Unused clips first, then the rest, as many times over as reaching the
    // target takes.
    final again = [...fresh, for (final c in bag) if (used.contains(c.id)) c];
    final total = again.fold(0, (t, c) => t + c.runtime.inMicroseconds);
    final copies = target.inMicroseconds ~/ total + 1;
    final second = _subsetSum([for (var i = 0; i < copies; i++) ...again], target, reach);
    if (first == null || second == null) return first ?? second ?? const [];
    return _off(second, target) < _off(first, target) ? second : first;
  }

  static Duration _off(List<MediaEntry> picks, Duration target) =>
      (picks.fold(Duration.zero, (t, c) => t + c.runtime) - target).abs();

  /// Lengths are matched in steps of this (0.1 s), in microseconds.
  static const _unit = 100000;

  /// Subset-sum over [clips]: the subset adding up to the most within
  /// [target], or with [reach] the least at or past it (null if none does).
  /// Of the subsets with that total, the one taking the earliest clips.
  static List<MediaEntry>? _subsetSum(List<MediaEntry> clips, Duration target, bool reach) {
    final n = clips.length;
    // Rounded so the exact total can't land on the wrong side of the target.
    final w = [
      for (final c in clips)
        reach ? max(1, c.runtime.inMicroseconds ~/ _unit) : (c.runtime.inMicroseconds + _unit - 1) ~/ _unit,
    ];
    final goal = reach ? (target.inMicroseconds + _unit - 1) ~/ _unit : target.inMicroseconds ~/ _unit;
    // Reaching the goal never takes more than one clip past it.
    final size = goal + 1 + (reach ? w.fold<int>(0, max) : 0);
    final words = (size + 31) >> 5;
    // Row i: the totals clips i… can make, one bit per total.
    final rows = Uint32List((n + 1) * words);
    rows[n * words] = 1;
    for (var i = n - 1; i >= 0; i--) {
      final src = (i + 1) * words, dst = i * words, whole = w[i] >> 5, bits = w[i] & 31;
      for (var j = 0; j < words; j++) {
        var v = rows[src + j];
        final k = j - whole;
        if (k >= 0) {
          v |= rows[src + k] << bits;
          if (bits > 0 && k > 0) v |= rows[src + k - 1] >> (32 - bits);
        }
        rows[dst + j] = v;
      }
    }
    bool can(int i, int total) => total >= 0 && (rows[i * words + (total >> 5)] >> (total & 31)) & 1 == 1;
    int? best;
    if (reach) {
      for (var k = goal; k < size && best == null; k++) {
        if (can(0, k)) best = k;
      }
    } else {
      for (var k = goal; k >= 0 && best == null; k--) {
        if (can(0, k)) best = k;
      }
    }
    if (best == null) return null;
    final picks = <MediaEntry>[];
    for (var i = 0, left = best; i < n && left > 0; i++) {
      if (can(i + 1, left - w[i])) {
        picks.add(clips[i]);
        left -= w[i];
      }
    }
    return picks;
  }

  static Random _random(int seed, DateTime at) => Random((seed ^ at.millisecondsSinceEpoch ~/ 1000) & 0x7fffffff);
}
