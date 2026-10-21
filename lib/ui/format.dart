String formatTime(DateTime t, {bool withPeriod = true}) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return withPeriod ? '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}' : '$h:$m';
}

/// "7:30 – 8:00 PM", or "11:30 AM – 12:15 PM" across noon/midnight.
String formatRange(DateTime start, DateTime end) {
  final samePeriod = (start.hour < 12) == (end.hour < 12);
  return '${formatTime(start, withPeriod: !samePeriod)} – ${formatTime(end)}';
}

String formatDate(DateTime t) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return '${days[t.weekday - 1]} ${months[t.month - 1]} ${t.day}';
}

/// "1 hr 5 min", "22 min", "under a minute".
String formatMinutes(Duration d) {
  final minutes = (d.inSeconds / 60).round();
  if (minutes < 1) return 'under a minute';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

/// Start of the half hour containing [t].
DateTime floorToHalfHour(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);

/// "Oct 18, 9:05 PM".
String formatMoment(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[t.month - 1]} ${t.day}, ${formatTime(t)}';
}

/// "today 9:05 PM", "yesterday 9:05 PM", or [formatMoment] for older times.
String formatRecent(DateTime t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final days = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (days == 0) return 'today ${formatTime(t)}';
  if (days == 1) return 'yesterday ${formatTime(t)}';
  return formatMoment(t);
}
