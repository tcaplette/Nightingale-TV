import '../commercials/analysis/break_points.dart';
import '../commercials/break_plan.dart';
import '../commercials/break_sources.dart';
import '../library/library_index.dart';
import 'channel.dart';
import 'premieres.dart';
import 'program_block.dart';
import 'slot_layout.dart';

/// How long an item occupies the schedule.
typedef SlotLength = Duration Function(MediaEntry item);

Duration _runtimeOnly(MediaEntry item) => item.runtime;

/// Under breaks, programs this long or longer start on the hour or half
/// hour; shorter ones on the quarter hour (clock-aligned-slots).
bool _fullLength(MediaEntry item) => item.runtime >= BreakPlan.automaticShortUnder;

const _halfHour = Duration(minutes: 30);

bool _onHalfHour(DateTime t) =>
    t.minute % 30 == 0 && t.second == 0 && t.millisecond == 0 && t.microsecond == 0;

/// The first half hour at or after [t].
DateTime _nextHalfHour(DateTime t) =>
    _onHalfHour(t) ? t : DateTime(t.year, t.month, t.day, t.hour, (t.minute ~/ 30 + 1) * 30);

/// Each of [slots]' padding (clock-aligned-slots): a short (under 12
/// minutes) whose slot would end off the half hour before a full-length
/// program pads to the half hour. Offsets count from a start on the half
/// hour. With [wrap], the list loops, and its last short pads whenever the
/// list has a full-length program, so every loop is whole half hours.
List<Duration> _shortPads(List<MediaEntry> items, List<Duration> slots, {required bool wrap}) {
  final anyLong = items.any(_fullLength);
  final pads = List.filled(items.length, Duration.zero);
  var end = 0;
  final grid = _halfHour.inMicroseconds;
  for (var i = 0; i < items.length; i++) {
    end += slots[i].inMicroseconds;
    final nextLong = i + 1 < items.length ? _fullLength(items[i + 1]) : wrap && anyLong;
    if (_fullLength(items[i]) || !nextLong || end % grid == 0) continue;
    final padded = (end + grid - 1) ~/ grid * grid;
    pads[i] = Duration(microseconds: padded - end);
    end = padded;
  }
  return pads;
}

/// One slot in a channel's timeline, or (from [ChannelSchedule.playbackAt])
/// one segment of it: a part of the show or a commercial.
class ScheduledProgram {
  ScheduledProgram({
    required this.item,
    required this.start,
    required this.end,
    DateTime? layoutStart,
    Duration? itemFrom,
    this.blockTitle,
    this.role,
    this.program,
    this.isPremiere = false,
    this.label,
    this.songs,
    this.isLive = false,
    this.offline = false,
    this.endsEarly = false,
    this.pad = Duration.zero,
  })  : layoutStart = layoutStart ?? start,
        itemFrom = itemFrom ?? start.difference(layoutStart ?? start);

  /// Null while the channel is off the air. A commercial clip during
  /// breaks.
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

  /// Which break this segment is part of; null for the program itself.
  final BreakRole? role;

  /// During a break: the program the break belongs to.
  final MediaEntry? program;

  /// The programming block this slot belongs to, if any ("New Episodes"
  /// for a premiere slot).
  final String? blockTitle;

  /// A new episode premiering (episode-premieres).
  final bool isPremiere;

  /// A music channel's hour-long guide cell: titled [label] (the channel's
  /// name), holding the hour's [songs] in order; [item] is the first.
  final String? label;
  final List<ScheduledProgram>? songs;

  /// An airing on a live channel (from its source's guide, or the
  /// "No guide information" hour where it has none).
  final bool isLive;

  /// A slot tail showing the channel's offline card (slot-duration): no
  /// [item], but not Off Air.
  final bool offline;

  /// Truncate cuts this program at its slot's end.
  final bool endsEarly;

  /// Time added to the slot's tail beyond its plan, so the next program
  /// starts on the half hour (clock-aligned-slots).
  final Duration pad;

  /// This slot ending at [end], its tail grown by the difference.
  ScheduledProgram paddedTo(DateTime end) => ScheduledProgram(
        item: item,
        start: start,
        end: end,
        layoutStart: layoutStart,
        itemFrom: itemFrom,
        blockTitle: blockTitle,
        isPremiere: isPremiere,
        endsEarly: endsEarly,
        pad: pad + end.difference(this.end),
      );

  bool get isOffAir => item == null && !offline;

  /// A music channel's hour in the guide, rather than one program.
  bool get isMusicHour => songs != null;

  /// A commercial break rather than the program.
  bool get isBreak => role != null;

  bool get isCommercial => item?.kind == MediaKind.commercial;

  /// How far into its whole slot this starts.
  Duration get slotOffset => start.difference(layoutStart);

  Duration get duration => end.difference(start);

  /// Where in [item]'s video this ends.
  Duration get itemTo => itemFrom + duration;

  String get title => label ?? item?.guideTitle ?? 'Off Air';

  /// Episode code + title, or "Movie · year".
  String get subtitle => item?.subtitle ?? 'This channel is off the air';

  /// Second line in guide cells: the episode title for episodes.
  String get detail {
    final i = item;
    if (i == null) return '';
    if (isMusicHour) return i.guideTitle;
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
  LoopSchedule._(this._items, this._offsets, this._pads, this._anchor, this._cycle);

  /// Items from the playlist that still exist in the library.
  final List<MediaEntry> _items;

  /// _offsets[i] = start of item i within one loop, in microseconds.
  final List<int> _offsets;

  /// Each slot's padding to the half hour.
  final List<Duration> _pads;
  final DateTime _anchor;

  /// Length of one loop in microseconds.
  final int _cycle;

  /// [slotOf] gives each program's slot (its runtime plus its breaks); with
  /// [align], shorts pad to the half hour before full-length programs.
  static LoopSchedule? build(Channel channel, LibraryIndex library,
      {SlotLength slotOf = _runtimeOnly, bool align = false}) {
    final items = <MediaEntry>[];
    for (final id in channel.playlist) {
      final item = library[id];
      if (item != null && item.kind != MediaKind.commercial) items.add(item);
    }
    if (items.isEmpty) return null;
    final slots = [for (final item in items) slotOf(item)];
    final pads = align ? _shortPads(items, slots, wrap: true) : List.filled(items.length, Duration.zero);
    final offsets = <int>[];
    var total = 0;
    for (var i = 0; i < items.length; i++) {
      offsets.add(total);
      total += (slots[i] + pads[i]).inMicroseconds;
    }
    return LoopSchedule._(items, offsets, pads, channel.anchor, total);
  }

  Duration get loopLength => Duration(microseconds: _cycle);

  int get length => _items.length;

  /// The [index]th program.
  MediaEntry itemAt(int index) => _items[index];

  /// The loop's episodes, in order.
  Iterable<MediaEntry> get episodes => _items.where((e) => e.kind == MediaKind.episode);

  /// Where in the loop the [index]th program's slot starts.
  Duration offsetOf(int index) => Duration(microseconds: _offsets[index]);

  /// The loop position of the first time [itemId] airs, if it's in the loop.
  int? indexOf(String itemId) {
    final i = _items.indexWhere((e) => e.id == itemId);
    return i < 0 ? null : i;
  }

  /// The program airing at [t].
  ScheduledProgram programAt(DateTime t) => slotAt(t).program;

  /// The program airing at [t], and its place in the loop.
  ({ScheduledProgram program, int index}) slotAt(DateTime t) {
    final elapsed = t.difference(_anchor).inMicroseconds;
    final loop = elapsed ~/ _cycle - (elapsed < 0 && elapsed % _cycle != 0 ? 1 : 0);
    final within = elapsed - loop * _cycle;
    final index = _indexAt(within);
    return (program: _program(loop, index), index: index);
  }

  ScheduledProgram _program(int loop, int index) {
    final start = _anchor.add(Duration(microseconds: loop * _cycle + _offsets[index]));
    final next = index + 1 < _offsets.length ? _offsets[index + 1] : _cycle;
    return ScheduledProgram(
      item: _items[index],
      start: start,
      end: start.add(Duration(microseconds: next - _offsets[index])),
      pad: _pads[index],
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

/// Lays out a [ProgramBlock]'s airings. Airing n starts where airing n-1
/// stopped; programs are worked out by replaying airings from the block's
/// anchor (cached, so this stays cheap).
class BlockSchedule {
  BlockSchedule._(this.block, this._items, this._slots, this._showCount, this._slotOf, this._align, this._extras);

  final ProgramBlock block;

  /// A mix's programs, in order.
  final List<MediaEntry> _items;

  /// A lineup's slots: the show's episodes in airing order, how many air
  /// back to back, and which entry of the cursor counts the show's
  /// episodes (shared by the slots of a show listed twice).
  final List<({List<MediaEntry> episodes, int count, int show})> _slots;
  final int _showCount;
  final SlotLength _slotOf;

  /// Shorts pad to the half hour before full-length programs.
  final bool _align;

  /// What fills a mix's last stretch when none of its programs fit (an
  /// Evening's: its channel's episodes).
  final List<MediaEntry> _extras;

  /// Airings replayed so far (from the anchor), and where each starts: the
  /// playlist position for a mix, each show's next episode for a lineup.
  final _airings = <Airing>[];
  final _cursors = <List<int>>[];
  DateTime? _scannedThrough;
  final _filled = <DateTime, (List<ScheduledProgram>, List<int>)>{};

  /// [slotOf] gives each program's slot (its runtime plus its breaks); with
  /// [align], shorts pad to the half hour before full-length programs.
  /// [extras] fill a mix's time no program of its own fits.
  static BlockSchedule? build(ProgramBlock block, LibraryIndex library,
      {SlotLength slotOf = _runtimeOnly, bool align = false, List<MediaEntry> extras = const []}) {
    if (!block.enabled || block.days.isEmpty) return null;
    final items = [
      for (final id in block.playlist)
        if (library[id] case final item?
            when item.runtime > Duration.zero && item.kind != MediaKind.commercial)
          item,
    ];
    if (items.isEmpty) return null;
    if (!block.hasLineup) return BlockSchedule._(block, items, const [], 1, slotOf, align, extras);
    // The playlist keeps each show's episodes in airing order, with new
    // ones appended, so a show's episode numbers stay put.
    final bySeries = <String, List<MediaEntry>>{};
    for (final item in items) {
      if (item.seriesKey case final key?) bySeries.putIfAbsent(key, () => []).add(item);
    }
    final shows = <String, int>{};
    final slots = [
      for (final s in block.lineup)
        if (bySeries[s.seriesKey] case final episodes? when s.count > 0)
          (episodes: episodes, count: s.count, show: shows.putIfAbsent(s.seriesKey, () => shows.length)),
    ];
    return slots.isEmpty ? null : BlockSchedule._(block, const [], slots, shows.length, slotOf, align, const []);
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
    final programs = programsIn(airing);
    return programs.lastWhere((p) => !p.start.isAfter(t), orElse: () => programs.first);
  }

  /// Everything [airing] plays, in order.
  List<ScheduledProgram> programsIn(Airing airing) => _fillAt(airing, _cursorAt(airing)).$1;

  (List<ScheduledProgram>, List<int>) _fillAt(Airing airing, List<int> cursor) => _filled.putIfAbsent(
      airing.start, () => _slots.isEmpty ? _fill(airing, cursor) : _fillLineup(airing, cursor));

  /// Replays airings from the anchor up to [airing] to find where it
  /// starts.
  List<int> _cursorAt(Airing airing) {
    final first = List.filled(_showCount, 0);
    final target = DateTime(airing.start.year, airing.start.month, airing.start.day);
    var d = _scannedThrough ??
        DateTime(block.anchor.year, block.anchor.month, block.anchor.day - 1);
    while (d.isBefore(target)) {
      d = DateTime(d.year, d.month, d.day + 1);
      final w = block.windowOn(d);
      if (w == null) continue;
      _cursors.add(_airings.isEmpty ? first : _fillAt(_airings.last, _cursors.last).$2);
      _airings.add(w);
    }
    if (_scannedThrough == null || d.isAfter(_scannedThrough!)) _scannedThrough = d;
    final i = _airings.indexWhere((a) => a.start == airing.start);
    return i < 0 ? first : _cursors[i];
  }

  /// Fills one airing of a mix starting at playlist position `cursor[0]`.
  /// Returns the programs and the cursor for the next airing.
  (List<ScheduledProgram>, List<int>) _fill(Airing airing, List<int> start) {
    var cursor = start[0];
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
      final next = _items[cursor % n];
      if (_padBefore(next, programs, t, airing.end) case final padded?) {
        t = padded;
        continue;
      }
      final remaining = airing.end.difference(t);
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
      // Then something else that fits, such as an episode after the
      // Evening's movies (cable-dayparts).
      if (_extras.isNotEmpty) {
        final from = t.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
        for (var i = 0; i < _extras.length; i++) {
          final candidate = _extras[(from + i) % _extras.length];
          if (_slotOf(candidate) <= remaining) {
            filler = candidate;
            break;
          }
        }
        if (filler != null) {
          add(filler);
          continue;
        }
      }
      // Nothing fits: the block ends on time, cutting this program short.
      add(next);
      // A program longer than the whole block would otherwise air forever.
      if (_slotOf(next) > windowLength) cursor++;
    }
    return (programs, [cursor]);
  }

  /// Fills one airing of a lineup: each slot's next episodes in turn, from
  /// the top again while time is left. [start] holds each show's next
  /// episode. Returns the programs and where the next airing starts.
  (List<ScheduledProgram>, List<int>) _fillLineup(Airing airing, List<int> start) {
    final next = [...start];
    final programs = <ScheduledProgram>[];
    final windowLength = airing.end.difference(airing.start);
    var t = airing.start;
    while (t.isBefore(airing.end)) {
      for (final slot in _slots) {
        for (var k = 0; k < slot.count && t.isBefore(airing.end); k++) {
          final item = slot.episodes[next[slot.show] % slot.episodes.length];
          if (_padBefore(item, programs, t, airing.end) case final padded?) t = padded;
          if (!t.isBefore(airing.end)) break;
          final slotEnd = t.add(_slotOf(item));
          final cut = slotEnd.isAfter(airing.end);
          programs.add(ScheduledProgram(item: item, start: t, end: cut ? airing.end : slotEnd, blockTitle: block.title));
          t = cut ? airing.end : slotEnd;
          // An episode the block's end cuts off airs in full next time,
          // unless it's longer than the whole block.
          if (!cut || _slotOf(item) > windowLength) next[slot.show]++;
        }
      }
    }
    return (programs, next);
  }

  /// When [item] is full length and would start off the half hour right
  /// after a short in [programs], pads that short's slot to the half hour
  /// (or [end]) and returns where [item] starts now.
  DateTime? _padBefore(MediaEntry item, List<ScheduledProgram> programs, DateTime t, DateTime end) {
    if (!_align || !_fullLength(item) || _onHalfHour(t) || programs.isEmpty) return null;
    final last = programs.last;
    if (last.end != t || last.item == null || _fullLength(last.item!)) return null;
    final half = _nextHalfHour(t);
    final to = half.isAfter(end) ? end : half;
    programs[programs.length - 1] = last.paddedTo(to);
    return to;
  }
}

/// What the guide, the banner, the tuner and the phone remote read of a
/// channel's schedule: a generated channel's [ChannelSchedule], or a live
/// channel's guide (live-tv-sources D2).
abstract interface class ProgramSchedule {
  /// The program airing at [t] (the whole slot).
  ScheduledProgram programAt(DateTime t);

  /// What actually plays at [t].
  ScheduledProgram playbackAt(DateTime t);

  ScheduledProgram next(ScheduledProgram p);

  /// Programs overlapping [from, to), in order.
  List<ScheduledProgram> programsBetween(DateTime from, DateTime to);

  /// What the guide shows at [t].
  ScheduledProgram guideProgramAt(DateTime t);

  /// Guide cells overlapping [from, to), in order.
  List<ScheduledProgram> guideProgramsBetween(DateTime from, DateTime to);

  /// The next programming block to start after [t], if any.
  ({String title, DateTime start})? nextBlockAiring(DateTime t);

  /// Whether [segment] is the last of [slot]'s program to air.
  bool isLastPart(ScheduledProgram slot, ScheduledProgram segment);

  /// When the program on at [t] ends (sleep-timer spec): the end of its last
  /// show part, before any post-roll. Null when nothing with a known end is
  /// on (off air, a live channel with no guide data).
  DateTime? programEndAt(DateTime t);

  bool get hasBreaks;
}

/// A channel's commercial breaks: its plan (already Off when its pools have
/// no clips), where clips come from, and where programs can break.
class BreakContext {
  const BreakContext(
      {required this.plan, this.clips = const NoClips(), this.points = const ChapterPoints(), this.slotRule});

  static const none = BreakContext(plan: BreakPlan.off);

  final BreakPlan plan;
  final ClipSource clips;
  final BreakPointSource points;

  /// The channel's slot length and tail mode, for its regular loop only
  /// (blocks and premieres keep their own layout).
  final SlotRule? slotRule;
}

/// Everything on a channel: programming blocks during their windows, the
/// channel's regular loop around them, and "Off Air" for block-only
/// channels outside their blocks.
class ChannelSchedule implements ProgramSchedule {
  ChannelSchedule._(this.loop, this.blocks, this.breaks, this._seed, this._slotPlans,
      {this.premieres, this.musicName, this.carry, this.carryItem});

  /// The program finishing its slot since the slot length changed.
  final SlotCarry? carry;
  final MediaEntry? carryItem;

  /// The regular programming; null for block-only channels.
  final LoopSchedule? loop;
  final List<BlockSchedule> blocks;

  /// New episode premiere slots, which take over like blocks (blocks come
  /// first: a slot that would overlap one doesn't air).
  final ChannelPremieres? premieres;

  /// A music channel's name: the guide shows it in hour-long cells.
  final String? musicName;
  final BreakContext breaks;
  final int _seed;
  final Map<(Duration, bool, bool), SlotPlan> _slotPlans;
  final _layouts = <(String, DateTime, bool, Duration), SlotLayout>{};

  /// With breaks and no slot length, the regular loop meets blocks on whole
  /// programs (clock-aligned-slots).
  bool get _meetsBlocks => hasBreaks && breaks.slotRule == null;

  @override
  bool get hasBreaks => !breaks.plan.isOff;

  /// Builds [channel]'s schedule; programs get [breaks]' plan, in blocks
  /// too.
  /// Premiere slots come from [premieres], the profile's plan.
  static ChannelSchedule? build(Channel channel, LibraryIndex library,
      [List<ProgramBlock> allBlocks = const [], BreakContext breaks = BreakContext.none, PremierePlan? premieres]) {
    final plans = <(Duration, bool, bool), SlotPlan>{};
    Duration slotOf(MediaEntry item) => _planOf(plans, breaks, item, ruled: false).slotLength;
    Duration loopSlotOf(MediaEntry item) => _planOf(plans, breaks, item, ruled: true).slotLength;
    final aligned = !breaks.plan.isOff;
    final loop = LoopSchedule.build(channel, library, slotOf: loopSlotOf, align: aligned && breaks.slotRule == null);
    final blocks = [
      for (final b in allBlocks)
        if (b.channelId == channel.id)
          ?BlockSchedule.build(b, library,
              slotOf: slotOf,
              align: aligned,
              extras: b.generated == Daypart.evening ? [...?loop?.episodes] : const []),
    ];
    if (loop == null && blocks.isEmpty) return null;
    final carryItem = breaks.slotRule == null || loop == null ? null : library[channel.slotCarry?.itemId ?? ''];
    return ChannelSchedule._(
      loop,
      blocks,
      breaks,
      stableHash(channel.id),
      plans,
      premieres: loop == null
          ? null
          : premieres?.forChannel(channel,
              slotOf: slotOf,
              blocked: (start, end) => blocks.any((b) => b.airingsBetween(start, end).isNotEmpty)),
      musicName: channel.isMusic ? channel.name : null,
      carry: carryItem == null ? null : channel.slotCarry,
      carryItem: carryItem,
    );
  }

  /// [item]'s slot under this channel's plan; [ruled]: in the channel's
  /// regular loop, where its slot rule applies.
  SlotPlan slotPlanFor(MediaEntry item, {bool ruled = false}) => _planOf(_slotPlans, breaks, item, ruled: ruled);

  /// [item]'s slot under [breaks]' plan (and, when [ruled], its slot rule),
  /// kept in [plans]: by runtime, and never a break inside a song or music
  /// video, only before or after it.
  static SlotPlan _planOf(Map<(Duration, bool, bool), SlotPlan> plans, BreakContext breaks, MediaEntry item,
      {required bool ruled}) {
    final rule = ruled ? breaks.slotRule : null;
    return plans.putIfAbsent((item.runtime, item.isMusic, rule != null), () {
      final slot = resolve(breaks.plan, item.runtime);
      final plain = item.isMusic ? slot.withoutMidRolls() : slot;
      return rule == null
          ? plain
          : plain.withRule(
              length: rule.length,
              offline: rule.tail == TailMode.offline,
              truncate: rule.tail == TailMode.truncate,
              poolId: rule.poolId);
    });
  }

  /// [slot]'s plan: under the slot rule in the regular loop, and exactly to
  /// its end for a program finishing its slot ([carry]); [pad] adds to its
  /// tail.
  SlotPlan _planOfSlot(MediaEntry item, DateTime layoutStart, {required bool ruled, Duration pad = Duration.zero}) {
    final c = carry, rule = breaks.slotRule;
    if (ruled && c != null && rule != null && c.itemId == item.id && c.start == layoutStart) {
      return slotPlanFor(item).withRule(
          length: c.end.difference(c.start),
          offline: rule.tail == TailMode.offline,
          truncate: true,
          poolId: rule.poolId);
    }
    final plan = slotPlanFor(item, ruled: ruled);
    return pad > Duration.zero ? plan.padded(pad) : plan;
  }

  /// The plan of [slot] (from [programAt]).
  SlotPlan slotPlanOf(ScheduledProgram slot) =>
      _planOfSlot(slot.item!, slot.layoutStart, ruled: _ruled(slot), pad: slot.pad);

  /// Whether [slot] (from [programAt]) is in the regular loop, under the
  /// slot rule.
  bool _ruled(ScheduledProgram slot) => breaks.slotRule != null && slot.blockTitle == null && !slot.isPremiere;

  /// The program airing at [t].
  @override
  ScheduledProgram programAt(DateTime t) {
    for (final b in blocks) {
      final airing = b.airingAt(t);
      if (airing != null) return b.programAt(airing, t);
    }
    if (premieres?.airingAt(t) case final airing?) return _premiereAt(airing, t);
    // Between blocks: regular programming, cut at the blocks' edges.
    var after = DateTime.fromMicrosecondsSinceEpoch(0);
    var before = DateTime(9999);
    final from = t.subtract(const Duration(days: 1)), to = t.add(const Duration(days: 1));
    void edges(Airing a) {
      if (!a.end.isAfter(t) && a.end.isAfter(after)) after = a.end;
      if (a.start.isAfter(t) && a.start.isBefore(before)) before = a.start;
    }

    for (final b in blocks) {
      b.airingsBetween(from, to).forEach(edges);
    }
    for (final a in premieres?.airingsBetween(from, to) ?? const <PremiereAiring>[]) {
      edges((start: a.start, end: a.end));
    }
    final c = carry;
    if (c != null) {
      if (!t.isBefore(c.start) && t.isBefore(c.end)) {
        return ScheduledProgram(
          item: carryItem,
          start: c.start.isAfter(after) ? c.start : after,
          end: c.end.isBefore(before) ? c.end : before,
          layoutStart: c.start,
          endsEarly: _planOfSlot(carryItem!, c.start, ruled: true).endsEarly,
        );
      }
      edges((start: c.start, end: c.end));
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
    final (program: p, :index) = loop.slotAt(t);
    final start = p.start.isAfter(after) ? p.start : after;
    final end = p.end.isBefore(before) ? p.end : before;
    if (_meetsBlocks && (start != p.start || end != p.end)) return _edgeFill(loop, index, start, end, t);
    return ScheduledProgram(
      item: p.item,
      start: start,
      end: end,
      // A program resuming after a block carries on in the same slot.
      layoutStart: p.start,
      endsEarly: breaks.slotRule != null && slotPlanFor(p.item!, ruled: true).endsEarly,
      pad: p.pad,
    );
  }

  /// What airs at [t] in [from, to): the part of loop program [index]'s
  /// slot a block's edge leaves (clock-aligned-slots). The most recent
  /// earlier loop programs whose slots fit play instead, full-length ones
  /// on the half hour; time none fits pads the last one's tail, or is a
  /// slot tail of its own.
  ScheduledProgram _edgeFill(LoopSchedule loop, int index, DateTime from, DateTime to, DateTime t) {
    final n = loop.length;
    final fills = <ScheduledProgram>[];
    var at = from;
    for (var k = 1; k < n && k <= 500 && at.isBefore(to); k++) {
      final item = loop.itemAt((index - k) % n);
      final end = at.add(slotPlanFor(item).slotLength);
      if (end.isAfter(to) || (_fullLength(item) && !_onHalfHour(at))) continue;
      fills.add(ScheduledProgram(item: item, start: at, end: end));
      at = end;
    }
    if (fills.isEmpty) return ScheduledProgram(item: null, start: from, end: to, offline: true);
    if (at.isBefore(to)) fills.last = fills.last.paddedTo(to);
    return fills.lastWhere((f) => !f.start.isAfter(t), orElse: () => fills.first);
  }

  /// The premiere on during [airing] at [t].
  ScheduledProgram _premiereAt(PremiereAiring airing, DateTime t) {
    var start = airing.start;
    for (final (i, e) in airing.episodes.indexed) {
      final end = start.add(airing.slots[i]);
      if (t.isBefore(end) || i == airing.episodes.length - 1) {
        return ScheduledProgram(item: e, start: start, end: end, blockTitle: PremierePlan.title, isPremiere: true);
      }
      start = end;
    }
    throw StateError('A premiere slot with no episodes');
  }

  /// [item]'s layout in the slot starting at [layoutStart], using what was
  /// known about its break points and clips by then, so new analysis or
  /// clips never change a slot already under way.
  SlotLayout layoutFor(MediaEntry item, DateTime layoutStart, {bool ruled = false, Duration pad = Duration.zero}) {
    if (_layouts.length > 64) _layouts.clear();
    return _layouts.putIfAbsent(
      (item.id, layoutStart, ruled, pad),
      () => SlotLayout.build(
        item: item,
        plan: _planOfSlot(item, layoutStart, ruled: ruled, pad: pad),
        layoutStart: layoutStart,
        info: breaks.points.pointsFor(item, layoutStart),
        clips: breaks.clips,
        seed: _seed,
      ),
    );
  }

  /// What actually plays at [t]: a part of the program, a commercial, or
  /// "Off Air". [programAt] gives the whole slot instead,
  /// which is what the guide shows.
  @override
  ScheduledProgram playbackAt(DateTime t) {
    final slot = programAt(t);
    final item = slot.item;
    if (item == null) return slot;
    final ruled = _ruled(slot);
    if (!_planOfSlot(item, slot.layoutStart, ruled: ruled, pad: slot.pad).hasBreaks) {
      return ScheduledProgram(
        item: item,
        start: slot.start,
        end: slot.end,
        layoutStart: slot.layoutStart,
        blockTitle: slot.blockTitle,
        isPremiere: slot.isPremiere,
        endsEarly: slot.endsEarly,
      );
    }
    final layout = layoutFor(item, slot.layoutStart, ruled: ruled, pad: slot.pad);
    final segment = layout.at(t.difference(slot.layoutStart));
    final segmentStart = slot.layoutStart.add(segment.from);
    final segmentEnd = slot.layoutStart.add(segment.to);
    final start = segmentStart.isAfter(slot.start) ? segmentStart : slot.start;
    final end = segmentEnd.isBefore(slot.end) ? segmentEnd : slot.end;
    return ScheduledProgram(
      item: segment.item,
      start: start,
      end: end,
      layoutStart: slot.layoutStart,
      itemFrom: segment.itemFrom + start.difference(segmentStart),
      role: segment.role,
      program: segment.isShow ? null : item,
      blockTitle: slot.blockTitle,
      isPremiere: slot.isPremiere,
      offline: segment.offline,
      endsEarly: slot.endsEarly,
    );
  }

  /// Whether [segment] (from [playbackAt]) is the last of [slot]'s program
  /// to air: no part of the show plays after it before the slot ends, which
  /// a programming block can make early.
  @override
  bool isLastPart(ScheduledProgram slot, ScheduledProgram segment) {
    final item = slot.item;
    if (item == null || segment.isBreak) return false;
    final ruled = _ruled(slot);
    if (!_planOfSlot(item, slot.layoutStart, ruled: ruled, pad: slot.pad).hasBreaks) return true;
    final after = segment.end.difference(slot.layoutStart);
    final until = slot.end.difference(slot.layoutStart);
    return !layoutFor(item, slot.layoutStart, ruled: ruled, pad: slot.pad)
        .segments
        .any((s) => s.isShow && s.from >= after && s.from < until);
  }

  /// On a music channel the program is the guide's cell, not the song.
  @override
  DateTime? programEndAt(DateTime t) {
    if (musicName != null) {
      final cell = guideProgramAt(t);
      return cell.item == null ? null : cell.end;
    }
    final slot = programAt(t);
    final item = slot.item;
    if (item == null) return null;
    final ruled = _ruled(slot);
    if (!_planOfSlot(item, slot.layoutStart, ruled: ruled, pad: slot.pad).hasBreaks) return slot.end;
    final until = slot.end.difference(slot.layoutStart);
    Duration? end;
    for (final s in layoutFor(item, slot.layoutStart, ruled: ruled, pad: slot.pad).segments) {
      if (s.isShow && !s.offline && s.item != null && s.from < until) end = s.to < until ? s.to : until;
    }
    return end == null ? null : slot.layoutStart.add(end);
  }

  /// Where [slot]'s show first has a picture: past any pre-roll, or the
  /// slot's start when a programming block cut its front off.
  DateTime firstPictureOf(ScheduledProgram slot) {
    final item = slot.item;
    if (item == null || slot.start.isAfter(slot.layoutStart)) return slot.start;
    final ruled = _ruled(slot);
    if (!_planOfSlot(item, slot.layoutStart, ruled: ruled, pad: slot.pad).hasBreaks) return slot.start;
    return slot.layoutStart.add(layoutFor(item, slot.layoutStart, ruled: ruled, pad: slot.pad).offsetOf(Duration.zero));
  }

  /// Where [item]'s slot in the regular loop starting at [layoutStart]
  /// reaches [position] in the program (with no breaks, the position
  /// itself).
  Duration slotOffsetOf(MediaEntry item, Duration position, DateTime layoutStart) {
    final ruled = breaks.slotRule != null;
    if (!slotPlanFor(item, ruled: ruled).hasBreaks) return position;
    return layoutFor(item, layoutStart, ruled: ruled).offsetOf(position);
  }

  /// Where [item] can break, as known at [asOf].
  ProgramBreakInfo breakInfoFor(MediaEntry item, DateTime asOf) => breaks.points.pointsFor(item, asOf);

  /// Programs overlapping [from, to), in order.
  @override
  List<ScheduledProgram> programsBetween(DateTime from, DateTime to) {
    final result = <ScheduledProgram>[];
    var p = programAt(from);
    while (p.start.isBefore(to)) {
      result.add(p);
      p = next(p);
    }
    return result;
  }

  @override
  ScheduledProgram next(ScheduledProgram p) => programAt(p.end);

  /// What the guide shows at [t]: [programAt], except on a music channel,
  /// where it's the hour-long cell (music-channels: a 3-minute song would
  /// be an unreadable cell).
  @override
  ScheduledProgram guideProgramAt(DateTime t) {
    final name = musicName;
    if (name == null) return programAt(t);
    final hour = DateTime(t.year, t.month, t.day, t.hour);
    final end = DateTime(t.year, t.month, t.day, t.hour + 1);
    final songs = programsBetween(hour, end);
    final first = songs.where((p) => !p.start.isBefore(hour)).firstOrNull ?? songs.firstOrNull;
    return ScheduledProgram(item: first?.item, start: hour, end: end, label: name, songs: songs);
  }

  /// Guide cells overlapping [from, to), in order (see [guideProgramAt]).
  @override
  List<ScheduledProgram> guideProgramsBetween(DateTime from, DateTime to) {
    if (musicName == null) return programsBetween(from, to);
    final result = <ScheduledProgram>[];
    for (var p = guideProgramAt(from); p.start.isBefore(to); p = guideProgramAt(p.end)) {
      result.add(p);
    }
    return result;
  }

  /// The next programming block to start after [t] (within about a year),
  /// e.g. for "back on the air" messages on block-only channels.
  @override
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
