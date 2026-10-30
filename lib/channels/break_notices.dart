import '../library/library_index.dart';
import 'schedule.dart';

/// Which cut a break notice counts down to.
enum BreakNoticeKind {
  /// A commercial break is about to start.
  breakStarts,

  /// A program is about to play after a run of breaks.
  resumes,
}

/// The notice on at a moment: [kind], the cut it counts down to ([at]), and
/// for [BreakNoticeKind.resumes], the segment that plays then ([resumes]).
/// [continues] when that's the same program carrying on after a mid-roll;
/// [opensBlock] is the programming block's title when the program that
/// comes back opens one.
typedef BreakNotice = ({
  BreakNoticeKind kind,
  DateTime at,
  ScheduledProgram? resumes,
  bool continues,
  String? opensBlock,
});

/// How long before a break the "Commercial break in N" notice shows.
const breakNoticeLead = Duration(seconds: 10);

/// How long before programming resumes the "Programming resumes in N"
/// notice shows.
const resumeNoticeLead = Duration(seconds: 5);

/// The longest run of breaks walked to find where programming resumes: a
/// guard against a broken plan, as breaks are a few minutes at most.
const _longestRun = Duration(hours: 2);

/// The break notice on at [now] in [schedule], or null (break-notices
/// spec):
/// - in the last [breakNoticeLead] of a show part that a break directly
///   follows, [BreakNoticeKind.breakStarts], counting down to the break;
/// - in the last [resumeNoticeLead] of a run of breaks (a mid-roll, or a
///   post-roll and the next pre-roll) that a program follows,
///   [BreakNoticeKind.resumes], counting down to the program.
///
/// A part or run shorter than its lead gets the notice from its start.
/// Never on channels without breaks, music channels, live channels, songs
/// or off the air. Worked out from the schedule and the clock alone, like
/// the logo windows and the Up next card.
BreakNotice? breakNoticeAt(ProgramSchedule schedule, DateTime now) {
  if (!schedule.hasBreaks) return null;
  if (schedule is ChannelSchedule && schedule.musicName != null) return null;
  final segment = schedule.playbackAt(now);
  if (!_plays(segment)) return null;
  if (!segment.isBreak) {
    if (segment.end.difference(now) > breakNoticeLead) return null;
    if (!schedule.playbackAt(segment.end).isBreak) return null;
    return (kind: BreakNoticeKind.breakStarts, at: segment.end, resumes: null, continues: false, opensBlock: null);
  }
  // Walk to the end of the run of breaks.
  var end = segment.end;
  ScheduledProgram after;
  while (true) {
    if (end.difference(now) > resumeNoticeLead) return null;
    after = schedule.playbackAt(end);
    if (!after.isBreak) break;
    if (!after.end.isAfter(end) || after.end.difference(segment.start) > _longestRun) return null;
    end = after.end;
  }
  if (!_plays(after)) return null;
  // A pre-roll belongs to the slot after it, so compare with what played
  // before the run.
  final before = _before(schedule, segment);
  final continues = before.item?.id == after.item!.id && before.layoutStart == after.layoutStart;
  final block = after.blockTitle;
  return (
    kind: BreakNoticeKind.resumes,
    at: end,
    resumes: after,
    continues: continues,
    opensBlock: !continues && block != null && block != before.blockTitle ? block : null,
  );
}

/// What played before the run of breaks [segment] is in: the program the
/// run follows, or off the air.
ScheduledProgram _before(ProgramSchedule schedule, ScheduledProgram segment) {
  var p = segment;
  while (p.isBreak) {
    final prev = schedule.playbackAt(p.start.subtract(const Duration(microseconds: 1)));
    if (!prev.start.isBefore(p.start) || segment.end.difference(prev.start) > _longestRun) return prev;
    p = prev;
  }
  return p;
}

/// Whether [segment] is something on air that a notice can be about: not
/// off the air, a live airing or a song.
bool _plays(ScheduledProgram segment) {
  final item = segment.item;
  return item != null && !segment.isLive && item.kind != MediaKind.song;
}
