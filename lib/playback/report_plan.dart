import '../channels/schedule.dart';
import '../library/library_index.dart';

/// One viewing of a program as Jellyfin is told about it: a program's slot
/// on a channel, across all its show parts.
typedef Viewing = ({String channelId, String itemId, DateTime layoutStart});

/// The viewing [segment] is part of, if it is a part of a program (not a
/// break, a commercial, music or off the air). Music is never reported: hours
/// of radio would flood play counts and "recently played".
Viewing? viewingOf(String channelId, ScheduledProgram segment) {
  final item = segment.item;
  if (segment.isBreak || item == null || item.kind == MediaKind.commercial || item.isMusic) return null;
  return (channelId: channelId, itemId: item.id, layoutStart: segment.layoutStart);
}

/// What happens to the playback report when [next] starts playing.
enum ReportStep {
  /// Same viewing (the next part, or a break inside it): carry on.
  keep,

  /// A new viewing starts; there was none.
  start,

  /// The viewing ends and a new one starts.
  finishAndStart,

  /// The viewing ends (a break in another slot, off air).
  finish,

  /// Nothing to report.
  none,
}

/// Decides what [next] means for the [active] viewing on [channelId].
ReportStep reportStep(Viewing? active, String channelId, ScheduledProgram next) {
  final key = viewingOf(channelId, next);
  if (key != null) {
    if (key == active) return ReportStep.keep;
    return active == null ? ReportStep.start : ReportStep.finishAndStart;
  }
  if (active == null) return ReportStep.none;
  // A break inside the program's own slot is part of
  // the viewing.
  final inSameSlot = next.isBreak &&
      channelId == active.channelId &&
      next.program?.id == active.itemId &&
      next.layoutStart == active.layoutStart;
  return inSameSlot ? ReportStep.keep : ReportStep.finish;
}

/// Watched far enough to count as watched (the end credits may be missed).
const watchedShare = 0.9;

/// The position to report when a viewing of [program] stops, having got
/// to [reached]: where it got to when it was watched to the end (or nearly),
/// otherwise 0, so channel surfing doesn't fill "Continue Watching".
Duration stoppedPosition(MediaEntry program, Duration reached) =>
    reached.inMilliseconds >= program.runtime.inMilliseconds * watchedShare ? reached : Duration.zero;
