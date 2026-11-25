import 'package:flutter/foundation.dart';

import '../channels/schedule.dart';
import '../library/library_index.dart';
import 'channel_recipe.dart';
import 'recipe_matcher.dart';
import '../l10n/tr.dart';

/// The id a home video goes by in a party: it matches nothing.
const homeVideoId = 'home:video';

/// One program as a party timeline carries it (watch-together D1): a
/// channel-sharing recipe item, an episode with its show. Nothing of the
/// host's server travels: provider ids, names and numbers only.
@immutable
class PartyItem {
  const PartyItem(this.item, [this.show]);

  /// The item; an episode's `show` index is 0, into [show].
  final RecipeItem item;
  final RecipeShow? show;

  /// The show's name for an episode, the movie's title.
  String get title => item.isMovie ? item.title : (show?.name ?? item.title);

  Duration get runtime => item.runtime;

  /// [e] from [library] as a party item; null for anything but an episode
  /// with a show or a movie.
  static PartyItem? of(MediaEntry e, LibraryIndex library) {
    // A home video goes as "Home video", with nothing of its own.
    if (e.isHome) return PartyItem(RecipeItem.movie(ids: const [homeVideoId], title: tr.smbHomeVideo, runtime: e.runtime));
    switch (e.kind) {
      case MediaKind.episode:
        final key = e.seriesKey;
        if (key == null) return null;
        final s = library.seriesByKey[key];
        return PartyItem(
          RecipeItem.episode(show: 0, season: e.season, episode: e.episode, title: e.title, runtime: e.runtime),
          RecipeShow(ids: [...?s?.providerIds], name: s?.name ?? e.seriesName ?? key.split('|').first, year: s?.year),
        );
      case MediaKind.movie:
        return PartyItem(RecipeItem.movie(ids: [...e.providerIds], title: e.title, year: e.year, runtime: e.runtime));
      default:
        return null;
    }
  }

  /// This library's copy, matched as channel-sharing matches programs.
  String? matchIn(RecipeMatcher matcher) =>
      matcher.itemId(item, [if (show case final s?) matcher.showKey(s)]);

  /// The same program (for change detection).
  String get key => '${show?.ids.join(',')}|${show?.name}|${item.ids.join(',')}|${item.season}|${item.episode}|${item.title}|${item.year}';

  Map<String, Object?> toJson() => {...item.toJson()..remove('s'), if (show case final s?) 'show': s.toJson()};

  static PartyItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final show = json['show'];
    final item = RecipeItem.fromJson({...json, if (show is Map) 's': 0});
    if (item == null) return null;
    return PartyItem(item, show is Map ? RecipeShow.fromJson(Map<String, Object?>.from(show)) : null);
  }
}

/// A break window on the party clock (D5).
@immutable
class PartyBreak {
  const PartyBreak(this.startMs, this.lengthMs);

  final int startMs;
  final int lengthMs;

  int get endMs => startMs + lengthMs;

  Map<String, Object?> toJson() => {'startMs': startMs, 'lengthMs': lengthMs};

  static PartyBreak? fromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['startMs'], l = json['lengthMs'];
    if (s is! num || l is! num || l <= 0) return null;
    return PartyBreak(s.toInt(), l.toInt());
  }
}

/// Who did what, carried by the timeline the action caused (D4).
typedef PartyBy = ({String user, String kind});

/// The host's timeline (D1). All times are backend milliseconds since the
/// epoch, as they play with the host's current shift: position is
/// `partyNow − anchorMs` until the break, `partyNow − anchorMs − length`
/// after it, where partyNow is the backend clock while playing and
/// [pausedAt] while paused.
@immutable
class PartyTimeline {
  const PartyTimeline({
    this.seq = 0,
    required this.item,
    required this.title,
    required this.anchorMs,
    this.playing = true,
    this.pausedAt,
    this.brk,
    this.next,
    this.by,
    this.sentMs = 0,
  });

  final int seq;

  /// Null while the host's channel is off the air.
  final PartyItem? item;
  final String title;
  final int anchorMs;
  final bool playing;
  final int? pausedAt;
  final PartyBreak? brk;
  final PartyItem? next;
  final PartyBy? by;
  final int sentMs;

  int partyNow(int backendNow) => playing ? backendNow : (pausedAt ?? backendNow);

  /// The program's position at [backendNow] (none during the break).
  Duration positionAt(int backendNow) {
    final t = partyNow(backendNow);
    final b = brk;
    var ms = t - anchorMs;
    if (b != null && t >= b.endMs) ms -= b.lengthMs;
    if (b != null && t >= b.startMs && t < b.endMs) ms = b.startMs - anchorMs;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  PartyTimeline copyWith({int? seq, PartyBy? Function()? by, int? sentMs}) => PartyTimeline(
        seq: seq ?? this.seq,
        item: item,
        title: title,
        anchorMs: anchorMs,
        playing: playing,
        pausedAt: pausedAt,
        brk: brk,
        next: next,
        by: by == null ? this.by : by(),
        sentMs: sentMs ?? this.sentMs,
      );

  /// The same timeline but for the time it was worked out: what's on, where
  /// and how it plays, within [tolerance] (anchors drift by milliseconds
  /// between readings).
  bool sameAs(PartyTimeline? o, {int tolerance = 300}) {
    if (o == null) return false;
    if (item?.key != o.item?.key || next?.key != o.next?.key || playing != o.playing) return false;
    bool near(int a, int b) => (a - b).abs() <= tolerance;
    final b = brk, ob = o.brk;
    if ((b == null) != (ob == null)) return false;
    if (b != null && (!near(b.startMs - anchorMs, ob!.startMs - o.anchorMs) || !near(b.lengthMs, ob.lengthMs))) return false;
    if (playing) return near(anchorMs, o.anchorMs);
    return near(pausedAt! - anchorMs, o.pausedAt! - o.anchorMs);
  }

  Map<String, Object?> toJson() => {
        'v': 1,
        'seq': seq,
        'item': item?.toJson(),
        'title': title,
        'anchorMs': anchorMs,
        'playing': playing,
        'pausedAt': pausedAt,
        'break': brk?.toJson(),
        'next': next?.toJson(),
        'by': by == null ? null : {'user': by!.user, 'kind': by!.kind},
        'sentMs': sentMs,
      };

  /// Null for something that isn't a timeline.
  static PartyTimeline? fromJson(Object? json) {
    if (json is! Map) return null;
    final anchor = json['anchorMs'];
    if (anchor is! num) return null;
    final by = json['by'];
    final playing = json['playing'] != false;
    final pausedAt = (json['pausedAt'] as num?)?.toInt();
    if (!playing && pausedAt == null) return null;
    return PartyTimeline(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      item: PartyItem.fromJson(json['item']),
      title: json['title'] as String? ?? '',
      anchorMs: anchor.toInt(),
      playing: playing,
      pausedAt: pausedAt,
      brk: PartyBreak.fromJson(json['break']),
      next: PartyItem.fromJson(json['next']),
      by: by is Map && by['user'] is String && by['kind'] is String ? (user: by['user'] as String, kind: by['kind'] as String) : null,
      sentMs: (json['sentMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Longest break window looked for: beyond it, the channel is off the air.
const _maxWindow = Duration(minutes: 15);

/// A break piece: a commercial, a bumper, a tail, or nothing between.
bool _breakPiece(ScheduledProgram s) => s.isBreak || s.item == null;

/// The run of break pieces starting at [from], up to the next part of a
/// program; null when none starts there or it runs past [_maxWindow].
({DateTime start, Duration length})? _windowFrom(ProgramSchedule schedule, DateTime from) {
  var t = from;
  for (var i = 0; i < 200; i++) {
    final s = schedule.playbackAt(t);
    if (!_breakPiece(s)) break;
    if (!s.end.isAfter(t)) return null;
    t = s.end;
    if (t.difference(from) > _maxWindow) return null;
  }
  return t.isAfter(from) ? (start: from, length: t.difference(from)) : null;
}

/// Where the run of break pieces that [segment] is in starts.
DateTime _windowStart(ProgramSchedule schedule, ScheduledProgram segment) {
  var t = segment.start;
  for (var i = 0; i < 200; i++) {
    final s = schedule.playbackAt(t.subtract(const Duration(milliseconds: 1)));
    if (!_breakPiece(s) || !s.end.isAtSameMomentAs(t) || segment.start.difference(s.start) > _maxWindow) break;
    t = s.start;
  }
  return t;
}

/// The host's timeline as its tuner stands (D1), without seq or by.
///
/// [view] is the tuner's viewing time, [wall] this device's clock, [offset]
/// the backend clock less this one: a viewing time [v] plays at backend time
/// `v + (wall − view) + offset`.
PartyTimeline hostTimeline({
  required ProgramSchedule schedule,
  required ScheduledProgram program,
  required ScheduledProgram segment,
  required DateTime view,
  required DateTime wall,
  required bool paused,
  required Duration offset,
  required LibraryIndex library,
}) {
  final shift = wall.difference(view) + offset;
  int at(DateTime v) => v.add(shift).millisecondsSinceEpoch;
  final show = program.item;
  var item = show == null ? null : PartyItem.of(show, library);
  int anchor;
  PartyBreak? brk;
  if (!_breakPiece(segment) && segment.item?.id == show?.id) {
    // A part of the program: its position now, and the break after it.
    anchor = at(segment.start) - segment.itemFrom.inMilliseconds;
    final w = _windowFrom(schedule, segment.end);
    if (w != null) brk = PartyBreak(at(w.start), w.length.inMilliseconds);
  } else if (_breakPiece(segment) && (segment.isBreak || segment.offline)) {
    // In a break: the whole window, and where the program stood at its start.
    final start = _windowStart(schedule, segment);
    final w = _windowFrom(schedule, start);
    final before = schedule.playbackAt(start.subtract(const Duration(milliseconds: 1)));
    final stood = !_breakPiece(before) && before.item?.id == show?.id ? before.itemTo : Duration.zero;
    anchor = at(start) - stood.inMilliseconds;
    if (w != null) brk = PartyBreak(at(w.start), w.length.inMilliseconds);
  } else {
    // Off the air.
    item = null;
    anchor = at(segment.start);
  }
  // The program after this one, past anything without a program.
  PartyItem? next;
  var n = schedule.next(program);
  for (var i = 0; i < 4 && n.item == null && n.end.difference(program.end) < _maxWindow; i++) {
    n = schedule.next(n);
  }
  if (n.item case final e?) next = PartyItem.of(e, library);
  return PartyTimeline(
    item: item,
    title: item?.title ?? '',
    anchorMs: anchor,
    playing: !paused,
    pausedAt: paused ? at(view) : null,
    brk: brk,
    next: next,
  );
}
