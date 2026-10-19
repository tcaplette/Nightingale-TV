import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../library/library_index.dart';
import '../ui/format.dart';
import 'm3u_writer.dart';

/// How far ahead the exported guide reaches.
const xmltvSpan = Duration(hours: 72);

/// The XMLTV guide for [channels] from the start of [now]'s hour through
/// [xmltvSpan]: the same slots the TV guide shows.
String buildXmltv({
  required List<Channel> channels,
  required ChannelSchedule? Function(Channel) scheduleFor,
  required LibraryIndex library,
  required ExportUrls urls,
  required DateTime now,
}) {
  final from = DateTime(now.year, now.month, now.day, now.hour);
  final to = from.add(xmltvSpan);
  final out = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write('<!DOCTYPE tv SYSTEM "xmltv.dtd">\n')
    ..write('<tv generator-info-name="Nightingale TV">\n');
  for (final c in channels) {
    out
      ..write('  <channel id="${c.number}">\n')
      ..write('    <display-name>${xmlEscape(c.name)}</display-name>\n')
      ..write('    <display-name>${c.number} ${xmlEscape(c.name)}</display-name>\n')
      ..write('    <icon src="${xmlEscape('${urls.logo(c)}')}"/>\n')
      ..write('  </channel>\n');
  }
  for (final c in channels) {
    final schedule = scheduleFor(c);
    if (schedule == null) continue;
    for (final p in schedule.programsBetween(from, to)) {
      _programme(out, c, p, schedule, library, urls);
    }
  }
  out.write('</tv>\n');
  return out.toString();
}

void _programme(
    StringBuffer out, Channel c, ScheduledProgram p, ChannelSchedule schedule, LibraryIndex library, ExportUrls urls) {
  out.write('  <programme start="${xmltvTime(p.start)}" stop="${xmltvTime(p.end)}" channel="${c.number}">\n');
  void tag(String name, String? value) {
    if (value == null || value.trim().isEmpty) return;
    out.write('    <$name>${xmlEscape(value.trim())}</$name>\n');
  }

  final item = p.item;
  if (item == null) {
    tag('title', 'Off Air');
    final next = schedule.nextBlockAiring(p.start);
    tag('desc', next == null ? null : 'Back on the air ${_when(next.start, p.start)} with ${next.title}.');
    out.write('  </programme>\n');
    return;
  }
  final series = item.seriesKey == null ? null : library.seriesByKey[item.seriesKey];
  final isEpisode = item.kind == MediaKind.episode;
  tag('title', item.guideTitle);
  if (isEpisode) tag('sub-title', item.title);
  tag('desc', item.overview);
  for (final g in isEpisode ? series?.genres ?? const <String>[] : item.genres) {
    tag('category', g);
  }
  if (item.kind == MediaKind.movie) tag('category', 'Movie');
  tag('category', p.blockTitle);
  tag('date', '${(isEpisode ? series?.year : null) ?? item.year ?? ''}');
  final poster = isEpisode ? item.seriesId : item.id;
  if (poster != null) out.write('    <icon src="${xmlEscape('${urls.image(poster)}')}"/>\n');
  if (isEpisode) {
    final ns = '${item.season == null ? '' : item.season! - 1}.${item.episode == null ? '' : item.episode! - 1}.';
    out.write('    <episode-num system="xmltv_ns">$ns</episode-num>\n');
    if (item.season != null && item.episode != null) {
      final s = '${item.season}'.padLeft(2, '0'), e = '${item.episode}'.padLeft(2, '0');
      out.write('    <episode-num system="onscreen">S${s}E$e</episode-num>\n');
    }
    out.write('    <previously-shown/>\n');
  }
  final rating = (isEpisode ? series?.officialRating : null) ?? item.officialRating;
  if (rating != null && rating.trim().isNotEmpty) {
    out.write('    <rating>\n      <value>${xmlEscape(rating.trim())}</value>\n    </rating>\n');
  }
  out.write('  </programme>\n');
}

/// "7:00 PM", or with the date when it's not within the day.
String _when(DateTime start, DateTime from) => start.difference(from) < const Duration(hours: 20)
    ? formatTime(start)
    : '${formatDate(start)} ${formatTime(start)}';

/// XMLTV's "YYYYMMDDhhmmss ±hhmm", in local time with that moment's offset
/// (so a range across a DST change comes out right).
String xmltvTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => '$n'.padLeft(2, '0');
  final offset = l.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${l.year}${two(l.month)}${two(l.day)}${two(l.hour)}${two(l.minute)}${two(l.second)} '
      '$sign${two(minutes ~/ 60)}${two(minutes % 60)}';
}

String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
    // Characters XML 1.0 doesn't allow.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
