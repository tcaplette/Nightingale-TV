import '../library/library_index.dart';
import '../playback/playback_diagnostics.dart';
import 'channel.dart';
import 'premiere_settings.dart';

export 'premiere_settings.dart';

/// One premiere slot on a channel: its episodes, back to back.
class PremiereAiring {
  PremiereAiring(this.start, this.episodes, this.slots);

  final DateTime start;
  final List<MediaEntry> episodes;

  /// Each episode's slot length (its runtime plus its breaks).
  final List<Duration> slots;

  DateTime get end => start.add(slots.fold(Duration.zero, (a, b) => a + b));
}

/// Episode-premieres planning for one profile: which episodes are new, and
/// each show's home channel. [forChannel] gives one channel's slots.
class PremierePlan {
  PremierePlan._(this.settings, this._showsByChannel, this.homeOf);

  /// An episode is new this long after Jellyfin added it.
  static const newFor = Duration(days: 14);

  /// A slot holds episodes while it stays within this (the first always
  /// goes in).
  static const maxLength = Duration(hours: 2);

  static const title = 'New Episodes';

  final PremiereSettings settings;

  /// Each channel's homed shows: their candidate episodes in airing order.
  final Map<String, Map<String, List<MediaEntry>>> _showsByChannel;

  /// Each show's home channel id, by [showOf] (the show's name: Jellyfin can
  /// list one show under several series, which the library may keep apart).
  final Map<String, String> homeOf;

  /// Which show [e] belongs to, for premieres.
  static String showOf(MediaEntry e) => (e.seriesName ?? e.seriesKey ?? '').trim().toLowerCase();

  /// Null when premieres are off, or there's nothing to premiere.
  ///
  /// [visible] is the profile's visible channels. A show's home is the one
  /// that has premieres on, isn't music or block-only, plays the show, and
  /// plays the fewest shows; on a tie, the lowest number.
  static PremierePlan? build(LibraryIndex library, List<Channel> visible, PremiereSettings settings) {
    if (!settings.enabled || settings.days.isEmpty) return null;
    // Every episode that has ever been, or is, new.
    final candidates = <String, List<MediaEntry>>{};
    for (final e in library.episodes) {
      if (e.added == null || e.availableAt == null || e.seriesKey == null) continue;
      candidates.putIfAbsent(showOf(e), () => []).add(e);
    }
    if (candidates.isEmpty) return null;
    final eligible = [
      for (final c in visible)
        if (c.premieres && !c.blockOnly && !c.isMusic) c,
    ]..sort((a, b) => a.number.compareTo(b.number));
    final showsOf = <Channel, Set<String>>{};
    for (final c in eligible) {
      showsOf[c] = {
        for (final id in c.playlist)
          if (library[id] case final item? when item.kind == MediaKind.episode) showOf(item),
      };
    }
    final homeOf = <String, String>{};
    final byChannel = <String, Map<String, List<MediaEntry>>>{};
    for (final entry in candidates.entries) {
      Channel? home;
      for (final c in eligible) {
        if (!showsOf[c]!.contains(entry.key)) continue;
        if (home == null || showsOf[c]!.length < showsOf[home]!.length) home = c;
      }
      if (home == null) continue;
      homeOf[entry.key] = home.id;
      byChannel.putIfAbsent(home.id, () => {})[entry.key] = entry.value..sort(LibraryIndex.compareEpisodes);
    }
    if (homeOf.isEmpty) return null;
    return PremierePlan._(settings, byChannel, homeOf);
  }

  /// [channel]'s premiere slots, or null if no show premieres there.
  /// [slotOf] gives each episode's slot under the channel's break plan;
  /// [blocked] says whether a slot would overlap one of its programming
  /// blocks.
  ChannelPremieres? forChannel(Channel channel,
      {required Duration Function(MediaEntry) slotOf, required bool Function(DateTime start, DateTime end) blocked}) {
    final shows = _showsByChannel[channel.id];
    if (shows == null) return null;
    return ChannelPremieres._(settings, channel.name, shows, slotOf, blocked);
  }
}

/// One channel's premiere slots, found by replaying them from the first
/// day any of its episodes was available (cached, so this stays cheap).
/// Each slot depends only on episodes' times and airing order, so every
/// rebuild finds the same slots.
class ChannelPremieres {
  ChannelPremieres._(this._settings, this._channelName, this._shows, this._slotOf, this._blocked)
      : _events = ([
          for (final eps in _shows.values)
            for (final e in eps) e.availableAt!,
        ]..sort());

  final PremiereSettings _settings;
  final String _channelName;
  final Map<String, List<MediaEntry>> _shows;
  final Duration Function(MediaEntry) _slotOf;
  final bool Function(DateTime start, DateTime end) _blocked;

  /// Every episode's availableAt, in order: the days worth replaying.
  final List<DateTime> _events;

  final _premiered = <String>{};
  final _airings = <PremiereAiring>[];

  /// The last day replayed.
  DateTime? _through;

  /// Slots overlapping [from, to), in order.
  List<PremiereAiring> airingsBetween(DateTime from, DateTime to) {
    // A slot runs at most a day, so one starting the day before can reach in.
    _replayThrough(DateTime(to.year, to.month, to.day));
    return [
      for (final a in _airings)
        if (a.start.isBefore(to) && a.end.isAfter(from)) a,
    ];
  }

  PremiereAiring? airingAt(DateTime t) {
    for (final a in airingsBetween(t.subtract(const Duration(days: 1)), t.add(const Duration(microseconds: 1)))) {
      if (!t.isBefore(a.start) && t.isBefore(a.end)) return a;
    }
    return null;
  }

  DateTime _startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, _settings.startMinute ~/ 60, _settings.startMinute % 60);

  void _replayThrough(DateTime lastDay) {
    if (_events.isEmpty) return;
    DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
    DateTime after(DateTime day) => DateTime(day.year, day.month, day.day + 1);
    var day = _through == null ? dayOf(_events.first) : after(_through!);
    while (!day.isAfter(lastDay)) {
      _through = day;
      if (_settings.days.contains(day.weekday)) {
        final airing = _fill(_startOn(day));
        if (airing == null) {
          // Nothing waiting: go on from the day the next episode arrives.
          final next = _events.where((t) => t.isAfter(_startOn(day))).firstOrNull;
          if (next == null) {
            _through = lastDay;
            return;
          }
          final resume = dayOf(next);
          if (resume.isAfter(after(day))) {
            final stop = resume.isAfter(lastDay) ? after(lastDay) : resume;
            _through = DateTime(stop.year, stop.month, stop.day - 1);
            day = stop;
            continue;
          }
        } else if (_blocked(airing.start, airing.end)) {
          // A programming block comes first; these wait for the next slot.
          PlaybackDiagnostics.note('PREMIERE', '$_channelName ${airing.start}: skipped for a programming block');
        } else {
          _airings.add(airing);
          _premiered.addAll(airing.episodes.map((e) => e.id));
          if (PlaybackDiagnostics.enabled) {
            PlaybackDiagnostics.note('PREMIERE', '$_channelName ${airing.start}–${airing.end}: '
                '${[for (final e in airing.episodes) '${e.seriesName} ${e.subtitle}'].join('; ')}');
          }
        }
      }
      day = after(day);
    }
  }

  /// The slot starting at [start], or null when nothing's waiting.
  PremiereAiring? _fill(DateTime start) {
    bool waiting(MediaEntry e) =>
        !_premiered.contains(e.id) && !e.availableAt!.isAfter(start) && start.isBefore(e.added!.add(PremierePlan.newFor));
    final next = <(MediaEntry, DateTime)>[];
    for (final eps in _shows.values) {
      MediaEntry? first;
      DateTime? oldest;
      for (final e in eps) {
        if (!waiting(e)) continue;
        first ??= e;
        if (oldest == null || e.availableAt!.isBefore(oldest)) oldest = e.availableAt;
      }
      if (first != null) next.add((first, oldest!));
    }
    if (next.isEmpty) return null;
    // Shows by their oldest waiting episode, then by name.
    next.sort((a, b) {
      final byTime = a.$2.compareTo(b.$2);
      return byTime != 0 ? byTime : (a.$1.seriesName ?? '').compareTo(b.$1.seriesName ?? '');
    });
    final episodes = <MediaEntry>[];
    final slots = <Duration>[];
    var total = Duration.zero;
    for (final (e, _) in next) {
      final slot = _slotOf(e);
      if (episodes.isNotEmpty && total + slot > PremierePlan.maxLength) break;
      episodes.add(e);
      slots.add(slot);
      total += slot;
    }
    return PremiereAiring(start, episodes, slots);
  }
}
