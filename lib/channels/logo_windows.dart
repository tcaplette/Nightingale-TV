import '../library/library_index.dart';
import 'channel.dart';
import 'schedule.dart';

/// A stretch of time the channel logo shows.
typedef LogoWindow = ({DateTime start, DateTime end});

/// How long the logo shows from each program part's start and each quarter
/// hour, in Now and then mode.
const logoWindowLength = Duration(seconds: 20);

/// How long the logo takes to fade in or out.
const logoFade = Duration(milliseconds: 500);

/// The logo's opacity.
const logoOpacity = 0.7;

/// Where the logo sits in a [width]×[height] frame (channel-logo spec): a
/// box 7.5% of the height tall and at most 2.5 times as wide, inside a 5%
/// title-safe margin. At 1080p: 81 px tall, 96 px from the right, 54 px from
/// the bottom. The TV and exported streams both use it.
({double right, double bottom, double height, double maxWidth}) logoBox(double width, double height) {
  final box = height * 0.075;
  return (right: width * 0.05, bottom: height * 0.05, height: box, maxWidth: box * 2.5);
}

/// When the logo shows during [segments] (from [ChannelSchedule.playbackAt],
/// in order), clipped to [from, to) (channel-logo spec):
/// - [LogoMode.always]: throughout every program part;
/// - [LogoMode.nowAndThen]: for [logoWindowLength] from each part's start
///   (the program's start and each return from a break) and from each
///   quarter hour on the clock (:00, :15, :30, :45) within a part;
/// - [LogoMode.off]: never.
///
/// Never during breaks, off the air, or on songs. Worked out from the
/// schedule and the clock alone, so the TV and every exported stream agree.
List<LogoWindow> logoWindows(LogoMode mode, Iterable<ScheduledProgram> segments, DateTime from, DateTime to) {
  if (mode == LogoMode.off) return const [];
  final windows = <LogoWindow>[];
  void add(DateTime start, DateTime end) {
    final s = start.isBefore(from) ? from : start;
    final e = end.isAfter(to) ? to : end;
    if (!s.isBefore(e)) return;
    if (windows.isNotEmpty && !s.isAfter(windows.last.end)) {
      if (e.isAfter(windows.last.end)) windows.last = (start: windows.last.start, end: e);
      return;
    }
    windows.add((start: s, end: e));
  }

  for (final part in segments) {
    final item = part.item;
    if (item == null || part.isBreak || item.kind == MediaKind.commercial || item.kind == MediaKind.song) continue;
    if (!part.end.isAfter(from) || !part.start.isBefore(to)) continue;
    if (mode == LogoMode.always) {
      add(part.start, part.end);
      continue;
    }
    DateTime capped(DateTime t) {
      final end = t.add(logoWindowLength);
      return end.isAfter(part.end) ? part.end : end;
    }

    add(part.start, capped(part.start));
    for (var q = nextQuarterHour(part.start); q.isBefore(part.end); q = q.add(const Duration(minutes: 15))) {
      add(q, capped(q));
    }
  }
  return windows;
}

/// The first quarter hour on the clock at or after [t].
DateTime nextQuarterHour(DateTime t) {
  final floor = DateTime(t.year, t.month, t.day, t.hour, t.minute ~/ 15 * 15);
  return floor == t ? t : floor.add(const Duration(minutes: 15));
}

/// What [schedule] plays from [from] to [to], segment by segment.
List<ScheduledProgram> playbackSegmentsBetween(ChannelSchedule schedule, DateTime from, DateTime to) {
  final result = <ScheduledProgram>[];
  var t = from;
  while (t.isBefore(to)) {
    final segment = schedule.playbackAt(t);
    result.add(segment);
    if (!segment.end.isAfter(t)) break;
    t = segment.end;
  }
  return result;
}
