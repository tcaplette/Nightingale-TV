import 'package:intl/intl.dart';

import '../channels/program_block.dart';
import '../l10n/tr.dart';

bool get _english => currentLanguage == 'en';

/// [pattern] of `intl`'s date formats, in the current language.
String _dated(String pattern, DateTime t) {
  languageDataReady; // Loads the data, on first use, if no entry point has.
  return DateFormat(pattern, currentLanguage).format(t);
}

String _noDot(String s) => s.replaceAll('.', '');

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _englishDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _englishMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Mon"… for [DateTime.weekday] 1–7, in the current language.
String weekdayName(int weekday) =>
    _english ? _englishDays[weekday - 1] : _capitalized(_noDot(_dated('E', DateTime(2024, 1, weekday))));

/// "Jan"… for months 1–12, in the current language.
String monthName(int month) =>
    _english ? _englishMonths[month - 1] : _capitalized(_noDot(_dated('MMM', DateTime(2024, month, 15))));

/// "Dec 1" (English), "1. Dez" (German), "1 déc" (French)…
String formatMonthDay(int month, int day) {
  if (_english) return '${monthName(month)} $day';
  // In a sentence, as the language writes it: only German capitalizes months.
  final name = _noDot(_dated('MMM', DateTime(2024, month, 15)));
  return currentLanguage == 'de' ? '$day. $name' : '$day $name';
}

/// English: "9:05 PM" as ever. Otherwise the 24-hour clock.
String formatTime(DateTime t, {bool withPeriod = true}) {
  if (!_english) return _dated('HH:mm', t);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return withPeriod ? '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}' : '$h:$m';
}

/// "7:30 – 8:00 PM", or "11:30 AM – 12:15 PM" across noon/midnight;
/// "19:30 – 20:00" off English.
String formatRange(DateTime start, DateTime end) {
  final samePeriod = _english && (start.hour < 12) == (end.hour < 12);
  return '${formatTime(start, withPeriod: !samePeriod)} – ${formatTime(end)}';
}

/// "MON OCT 18"; "MO 18. OKT" in German, "LUN 18 OCT" in French.
String formatDate(DateTime t) {
  if (_english) return '${_englishDays[t.weekday - 1].toUpperCase()} ${_englishMonths[t.month - 1].toUpperCase()} ${t.day}';
  final day = weekdayName(t.weekday).toUpperCase();
  final month = monthName(t.month).toUpperCase();
  return currentLanguage == 'de' ? '$day ${t.day}. $month' : '$day ${t.day} $month';
}

/// "1 hr 5 min", "22 min", "under a minute".
String formatMinutes(Duration d) {
  final minutes = (d.inSeconds / 60).round();
  if (minutes < 1) return tr.underAMinute;
  if (minutes < 60) return tr.min(minutes);
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? tr.hr(h) : tr.hrMin(h, m);
}

/// "12:34", or "1:02:34" from an hour up.
String formatClockSpan(Duration d) {
  final seconds = d.isNegative ? 0 : d.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds ~/ 60 % 60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// How far behind the schedule a viewer is: "12:34 behind".
String formatBehind(Duration d) => tr.behind(formatClockSpan(d));

/// Start of the half hour containing [t].
DateTime floorToHalfHour(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);

/// "Oct 18, 9:05 PM".
String formatMoment(DateTime t) => tr.dateAtTime(formatMonthDay(t.month, t.day), formatTime(t));

/// "today 9:05 PM", "yesterday 9:05 PM", or [formatMoment] for older times.
String formatRecent(DateTime t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final days = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (days == 0) return tr.today(formatTime(t));
  if (days == 1) return tr.yesterday(formatTime(t));
  return formatMoment(t);
}

/// "7:00 AM" for [minute] minutes after midnight.
String formatClockMinute(int minute) => formatTime(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));

/// "Sat · 7:00 AM – 12:00 PM · Dec 1 – Dec 25"
String describeBlock(ProgramBlock b) => [
      describeDays(b.days),
      '${formatClockMinute(b.startMinute)} – ${formatClockMinute(b.endMinute)}',
      if (b.hasSeason) '${b.seasonStart} – ${b.seasonEnd}',
      if (!b.hasLineup && b.source.ratingFloor != null) b.source.ratingFloor!.label,
    ].join('  ·  ');

/// What the Blocks screens call a block the lineup made (cable-dayparts).
String get fromTheLineupLabel => tr.fromTheLineup;

/// …and what they say of editing one.
String get fromTheLineupNote => tr.madeFromThis;

/// What the banner and info say of a program Truncate cuts (slot-duration).
String get endsEarlyLabel => tr.endsEarly;
