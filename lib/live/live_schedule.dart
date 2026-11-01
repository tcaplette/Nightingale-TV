import '../channels/schedule.dart';
import '../library/library_index.dart';
import 'live_data.dart';

/// A live channel's schedule, from its source's guide (live-tv-sources D2):
/// each programme is one slot (and one segment: no breaks), and gaps are
/// hour-long "No guide information" cells on the clock hour.
class LiveSchedule implements ProgramSchedule {
  LiveSchedule({required this.channelId, required this.channelName, List<LiveProgramme> programmes = const []})
      : _slots = [
          for (final p in [...programmes]..sort((a, b) => a.start.compareTo(b.start)))
            if (p.end.isAfter(p.start)) _slot(channelId, p),
        ];

  final String channelId;
  final String channelName;
  final List<ScheduledProgram> _slots;

  static const noGuide = 'No guide information';

  /// Where the guide data ends; null with none.
  DateTime? get guideUntil => _slots.isEmpty ? null : _slots.last.end;

  static ScheduledProgram _slot(String channelId, LiveProgramme p) => ScheduledProgram(
        item: MediaEntry(
          id: '$channelId@${p.start.millisecondsSinceEpoch}',
          kind: p.isMovie ? MediaKind.movie : MediaKind.episode,
          // An episode's guide title is its show; its own title the episode's.
          title: p.isMovie ? p.title : (p.subtitle ?? ''),
          seriesName: p.isMovie ? null : p.title,
          season: p.season,
          episode: p.episode,
          year: p.year,
          overview: p.description,
          genres: p.categories,
          officialRating: p.rating,
          runtime: p.duration,
          sourceId: channelId,
        ),
        start: p.start,
        end: p.end,
        isPremiere: p.isNew,
        isLive: true,
      );

  ScheduledProgram _gap(DateTime start, DateTime end) => ScheduledProgram(
        item: MediaEntry(
          id: '$channelId@gap${start.millisecondsSinceEpoch}',
          kind: MediaKind.episode,
          title: noGuide,
          seriesName: channelName,
          runtime: end.difference(start),
          sourceId: channelId,
        ),
        start: start,
        end: end,
        isLive: true,
      );

  /// The last slot starting at or before [t], by binary search; -1 if none.
  int _indexAt(DateTime t) {
    var lo = 0, hi = _slots.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_slots[mid].start.isAfter(t)) {
        hi = mid - 1;
      } else {
        found = mid;
        lo = mid + 1;
      }
    }
    return found;
  }

  @override
  ScheduledProgram programAt(DateTime t) {
    final i = _indexAt(t);
    if (i >= 0 && _slots[i].isOnAt(t)) return _slots[i];
    // A gap: the clock hour around t, cut at the programmes on either side.
    final hour = t.subtract(Duration(
        minutes: t.minute, seconds: t.second, milliseconds: t.millisecond, microseconds: t.microsecond));
    final nextHour = hour.add(const Duration(hours: 1));
    final before = i >= 0 ? _slots[i].end : null;
    final after = i + 1 < _slots.length ? _slots[i + 1].start : null;
    final start = before != null && before.isAfter(hour) ? before : hour;
    final end = after != null && after.isBefore(nextHour) ? after : nextHour;
    return _gap(start, end);
  }

  @override
  ScheduledProgram playbackAt(DateTime t) => programAt(t);

  @override
  ScheduledProgram next(ScheduledProgram p) => programAt(p.end);

  @override
  List<ScheduledProgram> programsBetween(DateTime from, DateTime to) {
    final result = <ScheduledProgram>[];
    for (var p = programAt(from); p.start.isBefore(to); p = next(p)) {
      result.add(p);
    }
    return result;
  }

  @override
  ScheduledProgram guideProgramAt(DateTime t) => programAt(t);

  @override
  List<ScheduledProgram> guideProgramsBetween(DateTime from, DateTime to) => programsBetween(from, to);

  @override
  ({String title, DateTime start})? nextBlockAiring(DateTime t) => null;

  @override
  bool isLastPart(ScheduledProgram slot, ScheduledProgram segment) => true;

  @override
  DateTime? programEndAt(DateTime t) {
    final slot = programAt(t);
    return slot.item?.title == noGuide ? null : slot.end;
  }

  @override
  bool get hasBreaks => false;
}
