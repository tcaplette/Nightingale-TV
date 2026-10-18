import '../commercials/analysis/break_points.dart';
import '../commercials/break_plan.dart';
import '../commercials/break_sources.dart';
import '../library/library_index.dart';
import 'channel.dart';
import 'channel_generator.dart';
import 'program_block.dart';
import 'slot_layout.dart';

/// How long an item occupies the schedule.
typedef SlotLength = Duration Function(MediaEntry item);

Duration _runtimeOnly(MediaEntry item) => item.runtime;

/// One slot in a channel's timeline, or (from [ChannelSchedule.playbackAt])
/// one segment of it: a part of the show, a commercial, the station ID.
class ScheduledProgram {
  ScheduledProgram({
    required this.item,
    required this.start,
    required this.end,
    DateTime? layoutStart,
    Duration? itemFrom,
    this.blockTitle,
    this.isIdent = false,
    this.role,
    this.program,
  })  : layoutStart = layoutStart ?? start,
        itemFrom = itemFrom ?? start.difference(layoutStart ?? start);

  /// Null while the channel is off the air or showing its station ID. A
  /// commercial clip during breaks.
  final MediaEntry? item;
  final DateTime start;
  final DateTime end;

  /// Where the program's whole slot starts. Later than [start] only when
  /// the slot was cut short at the front, e.g. resuming after a programming
  /// block.
  final DateTime layoutStart;

  /// Position in [item]'s video ([MediaEntry.sourceId]) at [start]. For a
  /// whole slot from [ChannelSchedule.programAt], the position if the slot
  /// had no breaks.
  final Duration itemFrom;

  /// The station ID card that fills the last seconds of a break.
  final bool isIdent;

  /// Which break this segment is part of; null for the program itself.
  final BreakRole? role;

  /// During a break: the program the break belongs to.
  final MediaEntry? program;

  /// The programming block this slot belongs to, if any.
  final String? blockTitle;

  bool get isOffAir => item == null && !isIdent;

  /// A commercial break (or its station ID) rather than the program.
  bool get isBreak => role != null;

  bool get isCommercial => item?.kind == MediaKind.commercial;

  /// How far into its whole slot this starts.
  Duration get slotOffset => start.difference(layoutStart);

  Duration get duration => end.difference(start);

  /// Where in [item]'s video this ends.
  Duration get itemTo => itemFrom + duration;

  String get title => item?.guideTitle ?? 'Off Air';

  /// Episode code + title, or "Movie · year".
  String get subtitle => item?.subtitle ?? 'This channel is off the air';

  /// Second line in guide cells: the episode title for episodes.
  String get detail {
    final i = item;
    if (i == null) return '';
    return i.kind == MediaKind.episode ? i.title : i.subtitle;
  }

  bool isOnAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// How far into the slot [t] is (clamped to the slot).
  Duration offsetAt(DateTime t) {
    final d = t.difference(start);
    if (d.isNegative) return Duration.zero;
    return d > duration ? duration : d;
  }

  /// Where playback of [item]'s video should be at [t].
  Duration positionAt(DateTime t) => itemFrom + offsetAt(t);
}

/// A channel's regular programming: the playlist loops forever starting at
/// [Channel.anchor], so "what's on" is pure arithmetic on the clock.
class LoopSchedule {
  LoopSchedule._(this._items, this._offsets, this._anchor, this._cycle);

  /// Items from the playlist that still exist in the library.
  final List<MediaEntry> _items;

  /// _offsets[i] = start of item i within one loop, in microseconds.
  final List<int> _offsets;
  final DateTime _anchor;

  /// Length of one loop in microseconds.
  final int _cycle;

  /// [slotOf] gives each program's slot (its runtime plus its breaks).
  static LoopSchedule? build(Channel channel, LibraryIndex library, {SlotLength slotOf = _runtimeOnly}) {
    final items = <MediaEntry>[];
    for (final id in channel.playlist) {
      final item = library[id];
      if (item != null && item.kind != MediaKind.commercial) items.add(item);
    }
    if (items.isEmpty) return null;
    final offsets = <int>[];
    var total = 0;
    for (final item in items) {
      offsets.add(total);
      total += slotOf(item).inMicroseconds;
    }
    return LoopSchedule._(items, offsets, channel.anchor, total);
  }

  Duration get loopLength => Duration(microseconds: _cycle);

  /// Where in the loop the [index]th program's slot starts.
  Duration offsetOf(int index) => Duration(microseconds: _offsets[index]);

  /// The loop position of the first time [itemId] airs, if it's in the loop.
  int? indexOf(String itemId) {
    final i = _items.indexWhere((e) => e.id == itemId);
    return i < 0 ? null : i;
  }

  /// The program airing at [t].
  ScheduledProgram programAt(DateTime t) {
    final elapsed = t.difference(_anchor).inMicroseconds;
    final loop = elapsed ~/ _cycle - (elapsed < 0 && elapsed % _cycle != 0 ? 1 : 0);
    final within = elapsed - loop * _cycle;
    return _program(loop, _indexAt(within));
  }

  ScheduledProgram _program(int loop, int index) {
    final start = _anchor.add(Duration(microseconds: loop * _cycle + _offsets[index]));
    final next = index + 1 < _offsets.length ? _offsets[index + 1] : _cycle;
    return ScheduledProgram(
      item: _items[index],
      start: start,
      end: start.add(Duration(microseconds: next - _offsets[index])),
    );
  }

  /// Binary search for the item whose slot contains [within].
  int _indexAt(int within) {
    var lo = 0, hi = _offsets.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_offsets[mid] <= within) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

typedef Airing = ({DateTime start, DateTime end});

/// Lays out a [ProgramBlock]'s airings. Airing n starts the playlist where
/// airing n-1 stopped; programs are worked out by replaying airings from the
/// block's anchor (cached, so this stays cheap).
class BlockSchedule {
  BlockSchedule._(this.block, this._items, this._slotOf);

  final ProgramBlock block;
  final List<MediaEntry> _items;
  final SlotLength _slotOf;

  /// Airings replayed so far (from the anchor), and the playlist cursor at
  /// the start of each.
  final _airings = <Airing>[];
  final _cursors = <int>[];
  DateTime? _scannedThrough;
  final _filled = <DateTime, (List<ScheduledProgram>, int)>{};

  /// [slotOf] gives each program's slot (its runtime plus its breaks).
  static BlockSchedule? build(ProgramBlock block, LibraryIndex library, {SlotLength slotOf = _runtimeOnly}) {
    if (!block.enabled || block.days.isEmpty) return null;
    final items = [
      for (final id in block.playlist)
        if (library[id] case final item?
            when item.runtime > Duration.zero && item.kind != MediaKind.commercial)
          item,
    ];
    return items.isEmpty ? null : BlockSchedule._(block, items, slotOf);
  }

  /// Airings overlapping [from, to), in order.
  List<Airing> airingsBetween(DateTime from, DateTime to) {
    final result = <Airing>[];
    // Start a day early to catch airings running past midnight.
    for (var d = DateTime(from.year, from.month, from.day - 1);
        d.isBefore(to);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.isBefore(block.anchor)) continue;
      final w = block.windowOn(d);
      if (w != null && w.start.isBefore(to) && w.end.isAfter(from)) result.add(w);
    }
    return result;
  }

  Airing? airingAt(DateTime t) {
    for (final a in airingsBetween(t, t.add(const Duration(microseconds: 1)))) {
      if (!t.isBefore(a.start) && t.isBefore(a.end)) return a;
    }
    return null;
  }

  /// The program on during [airing] at [t].
  ScheduledProgram programAt(Airing airing, DateTime t) {
    final programs = _fillAt(airing, _cursorAt(airing)).$1;
    return programs.lastWhere((p) => !p.start.isAfter(t), orElse: () => programs.first);
  }

  (List<ScheduledProgram>, int) _fillAt(Airing airing, int cursor) =>
      _filled.putIfAbsent(airing.start, () => _fill(airing, cursor));

  /// Replays airings from the anchor up to [airing] to find where in the
  /// playlist it starts.
  int _cursorAt(Airing airing) {
    final target = DateTime(airing.start.year, airing.start.month, airing.start.day);
    var d = _scannedThrough ??
        DateTime(block.anchor.year, block.anchor.month, block.anchor.day - 1);
    while (d.isBefore(target)) {
      d = DateTime(d.year, d.month, d.day + 1);
      final w = block.windowOn(d);
      if (w == null) continue;
      _cursors.add(_airings.isEmpty ? 0 : _fillAt(_airings.last, _cursors.last).$2);
      _airings.add(w);
    }
    if (_scannedThrough == null || d.isAfter(_scannedThrough!)) _scannedThrough = d;
    final i = _airings.indexWhere((a) => a.start == airing.start);
    return i < 0 ? 0 : _cursors[i];
  }

  /// Fills one airing starting at playlist position [cursor]. Returns the
  /// programs and the cursor for the next airing.
  (List<ScheduledProgram>, int) _fill(Airing airing, int cursor) {
    final n = _items.length;
    final programs = <ScheduledProgram>[];
    final windowLength = airing.end.difference(airing.start);
    var t = airing.start;
    // Adds [item]'s slot at t, cut short by the block's end.
    void add(MediaEntry item) {
      final slotEnd = t.add(_slotOf(item));
      final end = slotEnd.isAfter(airing.end) ? airing.end : slotEnd;
      programs.add(ScheduledProgram(item: item, start: t, end: end, blockTitle: block.title));
      t = end;
    }

    while (t.isBefore(airing.end)) {
      final remaining = airing.end.difference(t);
      final next = _items[cursor % n];
      if (_slotOf(next) <= remaining) {
        add(next);
        cursor++;
        continue;
      }
      // The next program won't fit before the block ends. Fill with the most
      // recent rerun that does, so the next program airs in full next time.
      MediaEntry? filler;
      for (var i = 1; i < n; i++) {
        final candidate = _items[(cursor - i) % n];
        if (_slotOf(candidate) <= remaining) {
          filler = candidate;
          break;
        }
      }
      if (filler != null) {
        add(filler);
        continue;
      }
      // Nothing fits: the block ends on time, cutting this program short.
      add(next);
      // A program longer than the whole block would otherwise air forever.
      if (_slotOf(next) > windowLength) cursor++;
    }
    return (programs, cursor);
  }
}

/// A channel's commercial breaks: its plan (already Off when its pools have
/// no clips), where clips come from, and where programs can break.
class BreakContext {
  const BreakContext({required this.plan, this.clips = const NoClips(), this.points = const ChapterPoints()});

  static const none = BreakContext(plan: BreakPlan.off);

  final BreakPlan plan;
  final ClipSource clips;
  final BreakPointSource points;
}

/// Everything on a channel: programming blocks during their windows, the
/// channel's regular loop around them, and "Off Air" for block-only
/// channels outside their blocks.
class ChannelSchedule {
  ChannelSchedule._(this.loop, this.blocks, this.breaks, this._seed, this._slotPlans);

  /// The regular programming; null for block-only channels.
  final LoopSchedule? loop;
  final List<BlockSchedule> blocks;
  final BreakContext breaks;
  final int _seed;
  final Map<Duration, SlotPlan> _slotPlans;
  final _layouts = <(String, DateTime), SlotLayout>{};

  bool get hasBreaks => !breaks.plan.isOff;

  /// Builds [channel]'s schedule; programs get [breaks]' plan, in blocks
  /// too.
  static ChannelSchedule? build(Channel channel, LibraryIndex library,
      [List<ProgramBlock> allBlocks = const [], BreakContext breaks = BreakContext.none]) {
    final plans = <Duration, SlotPlan>{};
    SlotPlan planOf(Duration runtime) => plans.putIfAbsent(runtime, () => resolve(breaks.plan, runtime));
    Duration slotOf(MediaEntry item) => planOf(item.runtime).slotLength;
    final loop = LoopSchedule.build(channel, library, slotOf: slotOf);
    final blocks = [
      for (final b in allBlocks)
        if (b.channelId == channel.id) ?BlockSchedule.build(b, library, slotOf: slotOf),
    ];
    if (loop == null && blocks.isEmpty) return null;
    return ChannelSchedule._(loop, blocks, breaks, stableHash(channel.id), plans);
  }

  /// [item]'s slot under this channel's plan.
  SlotPlan slotPlanFor(MediaEntry item) =>
      _slotPlans.putIfAbsent(item.runtime, () => resolve(breaks.plan, item.runtime));

  /// The program airing at [t].
  ScheduledProgram programAt(DateTime t) {
    for (final b in blocks) {
      final airing = b.airingAt(t);
      if (airing != null) return b.programAt(airing, t);
    }
    // Between blocks: regular programming, cut at the blocks' edges.
    var after = DateTime.fromMicrosecondsSinceEpoch(0);
    var before = DateTime(9999);
    final from = t.subtract(const Duration(days: 1)), to = t.add(const Duration(days: 1));
    for (final b in blocks) {
      for (final a in b.airingsBetween(from, to)) {
        if (!a.end.isAfter(t) && a.end.isAfter(after)) after = a.end;
        if (a.start.isAfter(t) && a.start.isBefore(before)) before = a.start;
      }
    }
    final loop = this.loop;
    if (loop == null) {
      // Off the air, shown in the guide as hour-long cells.
      final hour = DateTime(t.year, t.month, t.day, t.hour);
      final nextHour = DateTime(t.year, t.month, t.day, t.hour + 1);
      return ScheduledProgram(
        item: null,
        start: hour.isAfter(after) ? hour : after,
        end: nextHour.isBefore(before) ? nextHour : before,
      );
    }
    final p = loop.programAt(t);
    return ScheduledProgram(
      item: p.item,
      start: p.start.isAfter(after) ? p.start : after,
      end: p.end.isBefore(before) ? p.end : before,
      // A program resuming after a block carries on in the same slot.
      layoutStart: p.start,
    );
  }

  /// [item]'s layout in the slot starting at [layoutStart], using what was
  /// known about its break points and clips by then, so new analysis or
  /// clips never change a slot already under way.
  SlotLayout layoutFor(MediaEntry item, DateTime layoutStart) {
    if (_layouts.length > 64) _layouts.clear();
    return _layouts.putIfAbsent(
      (item.id, layoutStart),
      () => SlotLayout.build(
        item: item,
        plan: slotPlanFor(item),
        layoutStart: layoutStart,
        info: breaks.points.pointsFor(item, layoutStart),
        clips: breaks.clips,
        seed: _seed,
      ),
    );
  }

  /// What actually plays at [t]: a part of the program, a commercial, the
  /// station ID, or "Off Air". [programAt] gives the whole slot instead,
  /// which is what the guide shows.
  ScheduledProgram playbackAt(DateTime t) {
    final slot = programAt(t);
    final item = slot.item;
    if (item == null) return slot;
    if (!slotPlanFor(item).hasBreaks) {
      return ScheduledProgram(
        item: item,
        start: slot.start,
        end: slot.end,
        layoutStart: slot.layoutStart,
        blockTitle: slot.blockTitle,
      );
    }
    final layout = layoutFor(item, slot.layoutStart);
    final segment = layout.at(t.difference(slot.layoutStart));
    final segmentStart = slot.layoutStart.add(segment.from);
    final segmentEnd = slot.layoutStart.add(segment.to);
    final start = segmentStart.isAfter(slot.start) ? segmentStart : slot.start;
    final end = segmentEnd.isBefore(slot.end) ? segmentEnd : slot.end;
    return ScheduledProgram(
      item: segment.ident ? null : segment.item,
      start: start,
      end: end,
      layoutStart: slot.layoutStart,
      itemFrom: segment.itemFrom + start.difference(segmentStart),
      isIdent: segment.ident,
      role: segment.role,
      program: segment.isShow ? null : item,
      blockTitle: slot.blockTitle,
    );
  }

  /// Where [item]'s slot starting at [layoutStart] reaches [position] in the
  /// program (with no breaks, the position itself).
  Duration slotOffsetOf(MediaEntry item, Duration position, DateTime layoutStart) {
    if (!slotPlanFor(item).hasBreaks) return position;
    return layoutFor(item, layoutStart).offsetOf(position);
  }

  /// Where [item] can break, as known at [asOf].
  ProgramBreakInfo breakInfoFor(MediaEntry item, DateTime asOf) => breaks.points.pointsFor(item, asOf);

  /// Programs overlapping [from, to), in order.
  List<ScheduledProgram> programsBetween(DateTime from, DateTime to) {
    final result = <ScheduledProgram>[];
    var p = programAt(from);
    while (p.start.isBefore(to)) {
      result.add(p);
      p = next(p);
    }
    return result;
  }

  ScheduledProgram next(ScheduledProgram p) => programAt(p.end);

  /// The next programming block to start after [t] (within about a year),
  /// e.g. for "back on the air" messages on block-only channels.
  ({String title, DateTime start})? nextBlockAiring(DateTime t) {
    ({String title, DateTime start})? best;
    for (final b in blocks) {
      final upcoming = b.airingsBetween(t, t.add(const Duration(days: 400))).where((a) => a.start.isAfter(t));
      if (upcoming.isEmpty) continue;
      final start = upcoming.first.start;
      if (best == null || start.isBefore(best.start)) best = (title: b.block.title, start: start);
    }
    return best;
  }
}
