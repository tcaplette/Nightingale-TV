import 'dart:math';

import 'channel.dart';
import '../ui/format.dart';
import '../l10n/tr.dart';

/// A calendar day without a year, for seasonal ranges that repeat yearly.
class MonthDay implements Comparable<MonthDay> {
  const MonthDay(this.month, this.day);

  factory MonthDay.of(DateTime d) => MonthDay(d.month, d.day);

  factory MonthDay.parse(String s) {
    final parts = s.split('-');
    return MonthDay(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int month;
  final int day;

  static int daysIn(int month) => const [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];

  int get _ordinal => month * 32 + day;

  /// Steps by [days], wrapping across months and the year end.
  MonthDay addDays(int days) {
    // 2024 is a leap year, so Feb 29 is reachable.
    final d = DateTime(2024, month, day + days);
    return MonthDay(d.month, d.day);
  }

  MonthDay addMonths(int months) {
    final m = (month - 1 + months) % 12 + 1;
    return MonthDay(m, min(day, daysIn(m)));
  }

  @override
  int compareTo(MonthDay other) => _ordinal - other._ordinal;

  @override
  bool operator ==(Object other) => other is MonthDay && other._ordinal == _ordinal;

  @override
  int get hashCode => _ordinal;

  String toJson() => '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() {
    return formatMonthDay(month, day);
  }
}

/// One spot in a block's lineup: [count] episodes of a show, back to back.
class LineupSlot {
  LineupSlot({required this.seriesKey, this.count = 1});

  static const maxCount = 4;

  /// The show ([SeriesEntry.key]).
  final String seriesKey;
  int count;

  Map<String, Object?> toJson() => {'series': seriesKey, 'count': count};

  factory LineupSlot.fromJson(Map<String, Object?> j) =>
      LineupSlot(seriesKey: j['series'] as String, count: j['count'] as int? ?? 1);
}

/// The part of a genre channel's day a generated block fills
/// (cable-dayparts).
enum Daypart {
  /// 6 AM–6 PM: two-episode stacks of the channel's shows.
  daytime,

  /// 6 PM–midnight: the channel's movies.
  evening;

  static Daypart? parse(Object? name) => values.asNameMap()[name];
}

/// A titled stretch of programming ("Saturday Morning Cartoons") that takes
/// over a channel on chosen days within a time window, optionally only
/// during a yearly date range ("Christmas Specials", Dec 1–25).
///
/// A block plays either a mix ([source] in [order]) or, when it has a
/// [lineup], its shows in that order. Either way each airing picks up where
/// the previous one stopped, so a show continues week to week.
class ProgramBlock {
  ProgramBlock({
    required this.id,
    required this.title,
    required this.channelId,
    required this.days,
    required this.startMinute,
    required this.endMinute,
    required this.source,
    required this.order,
    required this.playlist,
    required this.anchor,
    this.seasonStart,
    this.seasonEnd,
    this.enabled = true,
    List<LineupSlot>? lineup,
    this.generated,
  }) : lineup = lineup ?? [];

  final String id;
  String title;
  String channelId;

  /// [DateTime.weekday] values (1 = Monday … 7 = Sunday) the block airs on.
  Set<int> days;

  /// Minutes after local midnight. An end at or before the start means the
  /// block runs past midnight into the next day.
  int startMinute;
  int endMinute;

  /// Optional yearly date range (inclusive); may wrap the year end.
  MonthDay? seasonStart;
  MonthDay? seasonEnd;

  /// What a mix plays, and in what order. Kept while a lineup is used, so
  /// switching back restores it.
  ChannelSource source;
  PlaybackOrder order;

  /// Shows in the order they air each time; empty for a mix. Each airing
  /// plays every slot's next episodes, then starts the lineup over if time
  /// is left.
  List<LineupSlot> lineup;

  /// Jellyfin item ids in play order. For a lineup, every episode of its
  /// shows, each show's in airing order.
  List<String> playlist;

  /// Local midnight of the day airings are counted from. Reset when the
  /// content changes, so the new lineup starts from its first episode.
  DateTime anchor;
  bool enabled;

  /// Made by the lineup ("From the lineup"), which rebuilds it at every
  /// refresh; null once the user edits it, or for the user's own blocks.
  Daypart? generated;

  bool get hasSeason => seasonStart != null && seasonEnd != null;

  bool get hasLineup => lineup.isNotEmpty;

  /// Length of one airing (DST changes aside).
  Duration get length {
    final minutes = (endMinute - startMinute) % (24 * 60);
    return Duration(minutes: minutes == 0 ? 24 * 60 : minutes);
  }

  bool inSeason(DateTime date) {
    if (!hasSeason) return true;
    final md = MonthDay.of(date);
    final s = seasonStart!, e = seasonEnd!;
    return s.compareTo(e) <= 0
        ? md.compareTo(s) >= 0 && md.compareTo(e) <= 0
        : md.compareTo(s) >= 0 || md.compareTo(e) <= 0;
  }

  /// Whether an airing starts on [date] (the start day decides, even for
  /// blocks that run past midnight).
  bool airsOn(DateTime date) => days.contains(date.weekday) && inSeason(date);

  /// The airing that starts on [date], if any.
  ({DateTime start, DateTime end})? windowOn(DateTime date) {
    if (!airsOn(date)) return null;
    final start = DateTime(date.year, date.month, date.day, startMinute ~/ 60, startMinute % 60);
    final endDay = endMinute <= startMinute ? date.day + 1 : date.day;
    final end = DateTime(date.year, date.month, endDay, endMinute ~/ 60, endMinute % 60);
    return (start: start, end: end);
  }

  ProgramBlock copy() => ProgramBlock.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'channelId': channelId,
        'days': days.toList()..sort(),
        'start': startMinute,
        'end': endMinute,
        if (seasonStart != null) 'seasonStart': seasonStart!.toJson(),
        if (seasonEnd != null) 'seasonEnd': seasonEnd!.toJson(),
        'source': source.toJson(),
        'order': order.name,
        if (lineup.isNotEmpty) 'lineup': [for (final s in lineup) s.toJson()],
        'playlist': playlist,
        'anchor': anchor.toIso8601String(),
        'enabled': enabled,
        if (generated != null) 'generated': generated!.name,
      };

  factory ProgramBlock.fromJson(Map<String, Object?> j) => ProgramBlock(
        id: j['id'] as String,
        title: j['title'] as String,
        channelId: j['channelId'] as String,
        days: (j['days'] as List).cast<int>().toSet(),
        startMinute: j['start'] as int,
        endMinute: j['end'] as int,
        seasonStart: j['seasonStart'] == null ? null : MonthDay.parse(j['seasonStart'] as String),
        seasonEnd: j['seasonEnd'] == null ? null : MonthDay.parse(j['seasonEnd'] as String),
        source: ChannelSource.fromJson(j['source'] as Map<String, Object?>),
        order: PlaybackOrder.parse(j['order']),
        lineup: [
          for (final s in (j['lineup'] as List?)?.cast<Map<String, Object?>>() ?? const <Map<String, Object?>>[])
            LineupSlot.fromJson(s),
        ],
        playlist: (j['playlist'] as List).cast<String>(),
        anchor: DateTime.parse(j['anchor'] as String).toLocal(),
        enabled: j['enabled'] as bool? ?? true,
        generated: Daypart.parse(j['generated']),
      );
}

/// "Every day", "Weekdays", "Weekends", or "Sat" / "Mon, Wed, Fri".
String describeDays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.every((d) => d <= 5)) return 'Weekdays';
  if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
  return [for (var d = 1; d <= 7; d++) if (days.contains(d)) weekdayName(d)].join(', ');
}

/// Whether [a] and [b] would ever be on the same channel at the same time.
bool blocksOverlap(ProgramBlock a, ProgramBlock b) {
  if (a.channelId != b.channelId || a.days.isEmpty || b.days.isEmpty) return false;
  // Eight years cover every weekday/date combination, including Feb 29.
  for (var d = DateTime(2024); d.year < 2032; d = DateTime(d.year, d.month, d.day + 1)) {
    final wa = a.windowOn(d);
    if (wa == null) continue;
    for (final offset in const [-1, 0, 1]) {
      final wb = b.windowOn(DateTime(d.year, d.month, d.day + offset));
      if (wb != null && wa.start.isBefore(wb.end) && wb.start.isBefore(wa.end)) return true;
    }
  }
  return false;
}

/// The late-night shortcut's title, days, times and minimum rating
/// (late-night-drift D4), applied to [block] in place.
ProgramBlock lateNightDefaults(ProgramBlock block) => block
  ..title = tr.lateNightTitle
  ..days = {1, 2, 3, 4, 5, 6, 7}
  ..startMinute = 23 * 60
  ..endMinute = 4 * 60
  ..source = block.source.copyWith(ratingFloor: () => RatingFloor.mature);

/// Whether the shortcut copies [channel]'s source and order: a music, live
/// or block-only channel has nothing suitable.
bool lateNightCopies(Channel channel) => !channel.isMusic && !channel.isLive && !channel.blockOnly;

/// What a late-night block on [channel] plays: the channel's own source,
/// TV-MA and up, or nothing picked when it has no usable source.
ChannelSource lateNightSource(Channel channel) => lateNightCopies(channel)
    ? channel.source.copyWith(ratingFloor: () => RatingFloor.mature)
    : const ChannelSource(includeEpisodes: false, ratingFloor: RatingFloor.mature);

/// The order of a late-night block on [channel]: the channel's own, or
/// [fallback] when it has no usable source.
PlaybackOrder lateNightOrder(Channel channel, PlaybackOrder fallback) =>
    lateNightCopies(channel) ? channel.order : fallback;
