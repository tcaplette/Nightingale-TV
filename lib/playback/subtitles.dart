import '../server/languages.dart';
import '../server/media_server.dart';

/// The track captions show for a program (subtitles spec, "Saved caption
/// preference"), from its [tracks]: with captions on,
/// 1. a track in [preferred] (an ISO 639 code) that isn't forced, the
///    default-flagged one first, then embedded before external;
/// 2. otherwise the default-flagged track;
/// 3. otherwise one in [device] (the device's language);
/// 4. otherwise the first.
///
/// A forced track (signs and foreign dialogue only) is taken in step 1 only
/// when no other track in [preferred] matches, and in the later steps only
/// when there is nothing else. Null when there are no tracks.
SubtitleTrack? chooseSubtitle(List<SubtitleTrack> tracks, {String? preferred, String? device}) {
  if (tracks.isEmpty) return null;
  final want = normalizeLanguage(preferred);
  final local = normalizeLanguage(device);

  // In the server's order, the default first, then embedded before external.
  int rank(SubtitleTrack t) => (t.isDefault ? 0 : 2) + (t.isExternal ? 1 : 0);
  List<SubtitleTrack> ranked(Iterable<SubtitleTrack> ts) {
    final list = ts.toList();
    final order = {for (final (i, t) in list.indexed) t: i};
    return list..sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : order[a]!.compareTo(order[b]!));
  }

  final unforced = [for (final t in tracks) if (!t.isForced) t];
  if (want != null) {
    final matching = [for (final t in tracks) if (t.language == want) t];
    final full = ranked(matching.where((t) => !t.isForced));
    if (full.isNotEmpty) return full.first;
    final forced = ranked(matching);
    if (forced.isNotEmpty) return forced.first;
  }
  final pool = unforced.isEmpty ? tracks : unforced;
  final flagged = pool.where((t) => t.isDefault).firstOrNull;
  if (flagged != null) return flagged;
  if (local != null) {
    final inLocal = ranked(pool.where((t) => t.language == local));
    if (inLocal.isNotEmpty) return inLocal.first;
  }
  return pool.first;
}

/// [track] as the captions picker lists it: "English", "English (SDH)",
/// "Spanish · External", "Japanese · Forced".
String subtitleLabel(SubtitleTrack track) {
  final language = languageName(track.language);
  final title = track.title;
  // A title that only repeats the language adds nothing.
  final extra = title != null && title.toLowerCase() != language?.toLowerCase() ? title : null;
  final name = switch ((language, extra)) {
    (final l?, final e?) => '$l ($e)',
    (final l?, null) => l,
    (null, final e?) => e,
    (null, null) => 'Unknown language',
  };
  return [
    name,
    if (track.isExternal) 'External',
    if (track.isForced) 'Forced',
  ].join(' · ');
}

/// What a player shows as subtitles (null: none). Equal choices are the
/// same on screen, so a player can skip setting one again.
sealed class SubtitleChoice {
  const SubtitleChoice();
}

/// A subtitle track inside the stream: the [position]th of its subtitle
/// tracks (0 for the first), in [language] (ISO 639-2) when known, which a
/// player matches by when it lists the tracks differently.
final class EmbeddedSubtitle extends SubtitleChoice {
  const EmbeddedSubtitle(this.position, {this.language});

  final int position;
  final String? language;

  @override
  bool operator ==(Object other) => other is EmbeddedSubtitle && other.position == position && other.language == language;

  @override
  int get hashCode => Object.hash(position, language);

  @override
  String toString() => 'embedded #$position ${language ?? '-'}';
}

/// A text track loaded beside the stream from [uri], with [headers] (the
/// server's auth), in [format] (`srt`, `vtt` or `ass`).
final class SideLoadedSubtitle extends SubtitleChoice {
  const SideLoadedSubtitle(this.uri, {required this.headers, required this.format, this.language, this.label});

  final Uri uri;
  final Map<String, String> headers;
  final String format;
  final String? language;
  final String? label;

  @override
  bool operator ==(Object other) => other is SideLoadedSubtitle && other.uri == uri && other.format == format;

  @override
  int get hashCode => Object.hash(uri, format);

  @override
  String toString() => 'side-loaded $format ${language ?? '-'}';
}

/// A live stream's own captions (CEA-608/708, or its default track), as the
/// on/off toggle has always shown them.
final class StreamCaptions extends SubtitleChoice {
  const StreamCaptions();

  @override
  bool operator ==(Object other) => other is StreamCaptions;

  @override
  int get hashCode => 7;

  @override
  String toString() => 'stream captions';
}
