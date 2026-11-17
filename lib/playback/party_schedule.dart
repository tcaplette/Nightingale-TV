import '../channels/schedule.dart';
import '../channels/slot_layout.dart';
import '../commercials/break_plan.dart';
import '../commercials/break_sources.dart';
import '../library/library_index.dart';

/// A watch party guest's schedule (watch-together D2, D5, D6): the host's
/// program from this library's copy, at the host's position, with the
/// host's break window filled from this member's own commercials, then the
/// host's next program. Times are this device's clock: the timeline's
/// backend times less the clock offset.
///
/// The tuner plays it like any schedule, so opening at a position,
/// preloading the next segment and the break hand-overs work as on a
/// channel. Every new timeline makes a new one.
class PartySchedule implements ProgramSchedule {
  PartySchedule({
    required this.anchor,
    required this.item,
    required this.title,
    required this.hostRuntime,
    this.breakStart,
    this.breakLength = Duration.zero,
    this.nextItem,
    this.nextTitle,
    this.nextHostRuntime = Duration.zero,
    this.clips = const NoClips(),
    this.roles = const CustomRoles(),
    this.seed = 0,
  });

  /// When position 0 of the program plays (before any break in it).
  final DateTime anchor;

  /// This library's copy; null when it has none ("Not on your servers").
  final MediaEntry? item;
  final String title;

  /// The host copy's runtime: where the host's program ends, whatever the
  /// length of this copy.
  final Duration hostRuntime;

  /// The host's break window, if one is coming or on.
  final DateTime? breakStart;
  final Duration breakLength;

  final MediaEntry? nextItem;
  final String? nextTitle;
  final Duration nextHostRuntime;

  final ClipSource clips;
  final CustomRoles roles;
  final int seed;

  /// A break that came this close to the program's end is its post-roll:
  /// the next program follows it.
  static const _postRollMargin = Duration(seconds: 2);

  DateTime? get breakEnd => breakStart?.add(breakLength);

  Duration get _runtime => hostRuntime > Duration.zero ? hostRuntime : (item?.runtime ?? Duration.zero);

  /// The break comes after the program has played to its end.
  bool get _postRoll => breakStart != null && !breakStart!.isBefore(anchor.add(_runtime - _postRollMargin));

  /// When the host's program ends (its break inside it included).
  DateTime get programEnd {
    final end = anchor.add(_runtime);
    return breakStart != null && !_postRoll ? end.add(breakLength) : end;
  }

  /// When the next program starts: after the post-roll window, or at the
  /// program's end.
  DateTime get nextStart => _postRoll ? breakEnd! : programEnd;

  DateTime get nextEnd => nextStart.add(nextHostRuntime > Duration.zero ? nextHostRuntime : (nextItem?.runtime ?? Duration.zero));

  late final List<LayoutSegment> _fill = breakStart == null
      ? const []
      : SlotLayout.fillBreak(length: breakLength, start: breakStart!, clips: clips, roles: roles, seed: seed);

  /// The title of the program a member doesn't have, while it's on at [t].
  String? missingAt(DateTime t) {
    final b = breakStart, e = breakEnd;
    if (b != null && !t.isBefore(b) && t.isBefore(e!)) return null;
    if (t.isBefore(nextStart)) return item == null ? title : null;
    if (t.isBefore(nextEnd)) return nextItem == null && nextTitle != null ? nextTitle : null;
    return null;
  }

  @override
  bool get hasBreaks => breakStart != null;

  @override
  ScheduledProgram playbackAt(DateTime t) {
    final b = breakStart, e = breakEnd;
    if (b != null && !t.isBefore(b) && t.isBefore(e!)) return _breakAt(b, t);
    if (t.isBefore(nextStart)) return _partAt(t);
    final n = nextItem, start = nextStart, end = nextEnd;
    if (t.isBefore(end)) {
      if (n == null) return ScheduledProgram(item: null, start: start, end: end, label: nextTitle);
      final to = start.add(n.runtime);
      if (t.isBefore(to)) return ScheduledProgram(item: n, start: start, end: to, itemFrom: Duration.zero);
      return _gap(to, end);
    }
    // Past what the timeline knows: waiting for the host's next one.
    return _gap(end, t.add(const Duration(hours: 1)));
  }

  /// A moment with nothing to show: the offline card.
  static ScheduledProgram _gap(DateTime from, DateTime to) =>
      ScheduledProgram(item: null, start: from, end: to.isAfter(from) ? to : from.add(const Duration(seconds: 1)), offline: true);

  ScheduledProgram _partAt(DateTime t) {
    final i = item;
    final start = anchor, end = nextStart;
    if (i == null) return ScheduledProgram(item: null, start: start, end: end, label: title);
    if (t.isBefore(start)) return _gap(t, start);
    final b = breakStart, e = breakEnd;
    if (b != null && !_postRoll && !t.isBefore(e!)) {
      // After the break: the program goes on from where it stopped.
      final from = b.difference(anchor);
      final to = e.add(i.runtime - from);
      if (t.isBefore(to)) return ScheduledProgram(item: i, start: e, end: to.isAfter(end) ? end : to, itemFrom: from);
      return _gap(to, end);
    }
    final partEnd = b != null && b.isBefore(start.add(i.runtime)) ? b : start.add(i.runtime);
    if (t.isBefore(partEnd)) {
      return ScheduledProgram(item: i, start: start, end: partEnd.isAfter(end) ? end : partEnd, itemFrom: Duration.zero);
    }
    // This copy is shorter than the host's.
    return _gap(partEnd, b != null && b.isAfter(partEnd) ? b : end);
  }

  ScheduledProgram _breakAt(DateTime b, DateTime t) {
    final offset = t.difference(b);
    final s = _fill.where((s) => offset >= s.from && offset < s.to).firstOrNull ?? _fill.lastOrNull;
    if (s == null) return ScheduledProgram(item: null, start: b, end: breakEnd!, role: BreakRole.mid, offline: true);
    return ScheduledProgram(
      item: s.item,
      start: b.add(s.from),
      end: b.add(s.to),
      itemFrom: s.itemFrom,
      role: s.role ?? BreakRole.mid,
      program: item,
      offline: s.offline || s.item == null,
    );
  }

  @override
  ScheduledProgram programAt(DateTime t) {
    if (t.isBefore(nextStart)) {
      return ScheduledProgram(item: item, start: anchor.isBefore(t) ? anchor : t, end: nextStart, label: item == null ? title : null);
    }
    if (t.isBefore(nextEnd)) {
      return ScheduledProgram(item: nextItem, start: nextStart, end: nextEnd, label: nextItem == null ? nextTitle : null);
    }
    return ScheduledProgram(item: null, start: nextEnd, end: t.add(const Duration(hours: 1)), offline: true);
  }

  @override
  ScheduledProgram next(ScheduledProgram p) => programAt(p.end);

  @override
  List<ScheduledProgram> programsBetween(DateTime from, DateTime to) {
    final out = <ScheduledProgram>[];
    var p = programAt(from);
    for (var i = 0; i < 8 && p.start.isBefore(to); i++) {
      out.add(p);
      if (!p.end.isAfter(p.start)) break;
      p = programAt(p.end);
    }
    return out;
  }

  @override
  ScheduledProgram guideProgramAt(DateTime t) => programAt(t);

  @override
  List<ScheduledProgram> guideProgramsBetween(DateTime from, DateTime to) => programsBetween(from, to);

  @override
  ({String title, DateTime start})? nextBlockAiring(DateTime t) => null;

  @override
  bool isLastPart(ScheduledProgram slot, ScheduledProgram segment) {
    if (segment.isBreak) return false;
    final b = breakStart;
    return b == null || _postRoll || !segment.end.isAtSameMomentAs(b);
  }

  @override
  DateTime? programEndAt(DateTime t) => t.isBefore(nextStart) ? (item == null ? null : programEnd) : null;
}
