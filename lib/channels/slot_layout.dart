import 'dart:math';

import '../commercials/analysis/break_points.dart';
import '../commercials/analysis/detections.dart';
import '../commercials/break_plan.dart';
import '../commercials/break_sources.dart';
import '../library/library_index.dart';

/// One piece of a slot: a part of the show, a commercial clip, or the
/// station-ID card. Times are offsets from the start of the (uncut) slot.
class LayoutSegment {
  const LayoutSegment({
    required this.from,
    required this.to,
    this.role,
    this.item,
    this.itemFrom = Duration.zero,
    this.ident = false,
  });

  final Duration from;
  final Duration to;

  /// Null for a part of the show.
  final BreakRole? role;

  /// The program for show parts, the clip for commercials, null for the
  /// station ID.
  final MediaEntry? item;

  /// Where in [item]'s video ([MediaEntry.sourceId]) this segment starts.
  final Duration itemFrom;
  final bool ident;

  bool get isShow => role == null;
  Duration get length => to - from;
}

/// How one program's slot plays: pre-roll, show part, mid-roll, show part,
/// …, post-roll, tail. The same inputs always give the same layout.
class SlotLayout {
  SlotLayout._(this.segments);

  final List<LayoutSegment> segments;

  Duration get length => segments.isEmpty ? Duration.zero : segments.last.to;

  /// Lays out [item] under [plan] for a slot starting at [layoutStart].
  ///
  /// Mid-rolls go at the points [info] allows; Commercial segments in the
  /// program are skipped, their length added to the break at their start.
  /// Each break is filled from its role's pool in [clips], shuffled with a
  /// seed made from [seed] (the channel) and the break's start, without
  /// repeating a clip while an unused one fits. What no clip fits goes to
  /// the fallback.
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
    final segments = <LayoutSegment>[];
    var t = Duration.zero;

    void fill(BreakRole role, Duration length) {
      if (length <= Duration.zero) return;
      _fill(segments, role, t, length, layoutStart, clips, roles, seed);
      t += length;
    }

    void show(Duration from, Duration to) {
      if (to <= from) return;
      segments.add(LayoutSegment(from: t, to: t + (to - from), item: item, itemFrom: from));
      t += to - from;
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

  /// Fills [length] from [from] with [role]'s clips, then the fallback.
  static void _fill(List<LayoutSegment> out, BreakRole role, Duration from, Duration length, DateTime layoutStart,
      ClipSource clips, CustomRoles roles, int seed) {
    final start = layoutStart.add(from);
    final end = from + length;
    final bag = [...clips.clipsAt(roles.poolFor(role), start)]..shuffle(_random(seed, start));
    var t = from;
    var next = 0;
    while (t < end) {
      final remaining = end - t;
      MediaEntry? pick;
      // Walks the shuffled bag from where it left off: every clip plays
      // once before any repeats (clips skipped for being too long never fit
      // later, as the time left only shrinks).
      for (var k = 0; k < bag.length; k++) {
        final candidate = bag[(next + k) % bag.length];
        if (candidate.runtime <= remaining) {
          pick = candidate;
          next += k + 1;
          break;
        }
      }
      if (pick == null) break;
      out.add(LayoutSegment(from: t, to: t + pick.runtime, role: role, item: pick, itemFrom: pick.sourceStart));
      t += pick.runtime;
    }
    if (t >= end) return;
    final fallbackStart = layoutStart.add(t);
    final fallback = roles.fallback == FallbackKind.pool
        ? ([...clips.clipsAt(roles.fallbackPool, fallbackStart)]..shuffle(_random(seed, fallbackStart)))
        : const <MediaEntry>[];
    // Pool fallback: clips, the last cut short. Otherwise the station ID.
    for (var i = 0; t < end && fallback.isNotEmpty; i++) {
      final clip = fallback[i % fallback.length];
      final to = t + clip.runtime < end ? t + clip.runtime : end;
      out.add(LayoutSegment(from: t, to: to, role: BreakRole.fallback, item: clip, itemFrom: clip.sourceStart));
      t = to;
    }
    if (t < end) out.add(LayoutSegment(from: t, to: end, role: BreakRole.fallback, ident: true));
  }

  static Random _random(int seed, DateTime at) => Random((seed ^ at.millisecondsSinceEpoch ~/ 1000) & 0x7fffffff);
}
