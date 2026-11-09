import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../channels/channel.dart';
import '../channels/channel_groups.dart';
import '../channels/channel_numbers.dart';
import '../data/app_storage.dart';
import '../playback/playback_diagnostics.dart';
import '../server/media_server.dart';
import 'live_cache.dart';
import 'live_data.dart';
import 'live_download.dart';
import 'live_schedule.dart';
import 'live_source.dart';
import 'live_source_files.dart';
import 'live_source_client.dart';
import '../l10n/tr.dart';

/// The server a server Live TV source plays through, while signed in to it.
typedef SignedIn = ({MediaServer client, ServerSession session});

/// A profile's Live TV sources and the live channels they bring
/// (live-tv-sources): kept in `live_sources.json`, with each source's
/// channels and guide cached, merged into the lineup by [AppState].
class LiveTvManager extends ChangeNotifier {
  LiveTvManager(this.storage, {required this.signedIn, LiveDownloader? downloader, DateTime Function()? now})
      : store = LiveSourceStore(storage),
        cache = LiveCache(storage.root),
        downloader = downloader ?? LiveDownloader(),
        _now = now ?? DateTime.now;

  final AppStorage storage;
  final LiveSourceStore store;
  final LiveCache cache;
  final LiveDownloader downloader;
  /// The profile's server [source] comes from (multi-server: each server
  /// Live TV source has its own), while signed in to it.
  final SignedIn? Function(LiveSource source) signedIn;
  final DateTime Function() _now;

  List<LiveSource> _sources = [];
  final _entries = <String, LiveCacheEntry>{};

  /// The live channels, by id, kept across rebuilds so the tuner and the
  /// guide keep the same objects.
  final _channels = <String, Channel>{};
  final _schedules = <String, LiveSchedule>{};

  List<LiveSource> get sources => List.unmodifiable(_sources);

  LiveCacheEntry entryFor(LiveSource s) => _entries.putIfAbsent(s.id, LiveCacheEntry.new);

  LiveSource? sourceById(String id) => _sources.where((s) => s.id == id).firstOrNull;

  /// The profile's server Live TV source, if it has one.
  LiveSource? get serverSource => _sources.where((s) => s.kind == LiveSourceKind.server).firstOrNull;

  /// The server Live TV source of the server with [serverId], if any.
  LiveSource? serverSourceFor(String? serverId) => _sources
      .where((s) => s.kind == LiveSourceKind.server && (s.serverId == serverId || s.serverId == null && serverId == null))
      .firstOrNull;

  Future<void> load() async {
    _sources = await store.load();
    final now = _now();
    for (final s in _sources) {
      s.forgetDeparted(now);
      _entries[s.id] = await cache.load(s.id);
    }
    _schedules.clear();
  }

  /// Whether [s]'s channels join the lineup now: always for M3U; for server
  /// Live TV, while signed in to that server.
  bool isActive(LiveSource s) {
    if (s.kind == LiveSourceKind.m3u) return true;
    final signed = signedIn(s);
    if (signed == null || signed.session.kind != s.serverKind) return false;
    final id = signed.session.serverId;
    return s.serverId == null || id == null || id == s.serverId;
  }

  LiveSourceClient? clientFor(LiveSource s) {
    if (s.kind == LiveSourceKind.m3u) {
      return M3uSource(s, store: store, downloader: downloader, tempDir: Directory('${Directory.systemTemp.path}/nightingale_live'));
    }
    if (!isActive(s)) return null;
    final tv = signedIn(s)?.client.liveTv;
    return tv == null ? null : ServerLiveSource(s, tv);
  }

  /// The source and the source's own entry for live channel [c].
  ({LiveSource source, LiveChannelInfo info})? lookup(Channel c) {
    final ref = c.live;
    if (ref == null) return null;
    final s = sourceById(ref.sourceId);
    if (s == null) return null;
    final info = entryFor(s).channels.where((i) => i.key == ref.key).firstOrNull;
    return info == null ? null : (source: s, info: info);
  }

  /// [info]'s icon unless the user picked one: its logo, or a station
  /// badge with its name's initials.
  static ChannelIcon defaultIcon(LiveChannelInfo info) => info.logo != null
      ? ChannelIcon(kind: ChannelIconKind.remote, value: info.logo!)
      : ChannelIcon(kind: ChannelIconKind.badge, value: initials(info.name), color: 0xFF2E5AAC);

  static String initials(String name) {
    final words = name.split(RegExp(r'[\s\-_/]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 4)).toUpperCase();
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }

  /// The live channels to merge into the lineup: every chosen channel of an
  /// active source that the source still lists.
  List<Channel> lineupChannels() {
    final keep = <String>{};
    final out = <Channel>[];
    for (final s in _sources) {
      if (!isActive(s)) continue;
      final infos = {for (final i in entryFor(s).channels) i.key: i};
      for (final e in s.chosen.entries) {
        final info = infos[e.key];
        if (info == null) continue;
        final id = LiveRef.channelId(s.id, e.key);
        final settings = e.value;
        final ref = LiveRef(sourceId: s.id, key: e.key, sourceNumber: info.number);
        final ch = _channels.putIfAbsent(
            id, () => Channel.live(ref: ref, number: settings.number, name: info.name, icon: defaultIcon(info)));
        ch
          ..number = settings.number
          ..name = settings.name ?? info.name
          ..icon = settings.icon ?? defaultIcon(info)
          ..hidden = settings.hidden
          ..favorite = settings.favorite
          ..logoMode = settings.logoMode
          ..retro = settings.retro;
        keep.add(id);
        out.add(ch);
      }
    }
    _channels.removeWhere((id, _) => !keep.contains(id));
    return out;
  }

  /// Live channel [c]'s schedule from its cached guide.
  LiveSchedule scheduleFor(Channel c) => _schedules.putIfAbsent(c.id, () {
        final ref = c.live!;
        final s = sourceById(ref.sourceId);
        return LiveSchedule(
          channelId: c.id,
          channelName: c.name,
          programmes: s == null ? const [] : entryFor(s).guide[ref.key] ?? const [],
        );
      });

  /// Writes what the user changed on live channels (number, name, icon,
  /// logo setting, hidden, favorite) back to their sources, and saves.
  Future<void> saveFrom(Iterable<Channel> channels) async {
    takeEdits(channels);
    await saveIfEdited();
  }

  /// Takes what the user changed on live channels into their sources'
  /// settings, in memory; true when something changed (to be saved).
  bool takeEdits(Iterable<Channel> channels) {
    var changed = false;
    for (final c in channels) {
      final found = lookup(c);
      final settings = found?.source.chosen[c.live!.key];
      if (found == null || settings == null) continue;
      final name = c.name == found.info.name ? null : c.name;
      final icon = _sameIcon(c.icon, defaultIcon(found.info)) ? null : c.icon;
      if (settings.number != c.number ||
          settings.name != name ||
          !_sameIcon(settings.icon, icon) ||
          settings.hidden != c.hidden ||
          settings.favorite != c.favorite ||
          settings.logoMode != c.logoMode ||
          settings.retro != c.retro) {
        settings
          ..number = c.number
          ..name = name
          ..icon = icon
          ..hidden = c.hidden
          ..favorite = c.favorite
          ..logoMode = c.logoMode
          ..retro = c.retro;
        changed = true;
      }
      if (_schedules[c.id]?.channelName != c.name) _schedules.remove(c.id);
    }
    _unsaved |= changed;
    return changed;
  }

  bool _unsaved = false;

  static bool _sameIcon(ChannelIcon? a, ChannelIcon? b) =>
      a == null || b == null ? a == b : a.toJson().toString() == b.toJson().toString();

  Future<void> save() {
    _unsaved = false;
    return store.save(_sources);
  }

  /// Saves edits [takeEdits] took, if any are unsaved.
  Future<void> saveIfEdited() => _unsaved ? save() : Future.value();

  // ---- Sources ---------------------------------------------------------------

  /// Adds [source] with the [channels] it was read with (cached at once).
  Future<void> addSource(LiveSource source, List<LiveChannelInfo> channels) async {
    _sources = [..._sources, source];
    final entry = entryFor(source)
      ..channels = channels
      ..state.channelsAt = _now();
    await cache.saveChannels(source.id, entry.channels);
    await cache.saveState(source.id, entry.state);
    await save();
    notifyListeners();
  }

  /// Removes [source], its channels from [groups], its cache and its files.
  /// True when [groups] changed.
  Future<bool> removeSource(LiveSource source, List<ChannelGroup> groups) async {
    final ids = {for (final k in source.chosen.keys) LiveRef.channelId(source.id, k)};
    final changed = _leaveGroups(ids, groups);
    _sources = [for (final s in _sources) if (s.id != source.id) s];
    _entries.remove(source.id);
    _schedules.removeWhere((id, _) => id.startsWith('live:${source.id}:'));
    await cache.delete(source.id);
    await store.deleteFiles(source);
    await save();
    notifyListeners();
    return changed;
  }

  static bool _leaveGroups(Set<String> ids, List<ChannelGroup> groups) {
    var changed = false;
    for (final g in groups) {
      final before = g.channelIds.length;
      g.channelIds = [for (final id in g.channelIds) if (!ids.contains(id)) id];
      changed |= g.channelIds.length != before;
    }
    return changed;
  }

  /// Which of a new source's [channels] start chosen: all of up to
  /// [LiveSource.chooseAllUpTo], none of more.
  static Set<String> defaultChoice(List<LiveChannelInfo> channels) =>
      channels.length <= LiveSource.chooseAllUpTo ? {for (final c in channels) c.key} : {};

  /// Makes [keys] [source]'s chosen channels. New ones are numbered in
  /// source order (D7): a source's first channels from the first multiple
  /// of 100 above every number in [taken], later ones from the source's
  /// lowest number up, each the next number nobody holds. Channels no
  /// longer chosen leave [groups]. True when [groups] changed.
  Future<bool> choose(LiveSource source, Set<String> keys,
      {required Set<int> taken, required List<ChannelGroup> groups}) async {
    final dropped = {for (final k in source.chosen.keys) if (!keys.contains(k)) k};
    for (final k in dropped) {
      source.chosen.remove(k);
    }
    final changed = _leaveGroups({for (final k in dropped) LiveRef.channelId(source.id, k)}, groups);
    final infos = [
      for (final i in entryFor(source).channels)
        if (keys.contains(i.key) && !source.chosen.containsKey(i.key)) i,
    ]..sort(compareSourceOrder);
    if (infos.isNotEmpty) {
      final used = {...taken, for (final c in source.chosen.values) c.number};
      var next = source.chosen.isEmpty
          ? ChannelNumbers.liveBlockStart(used)
          : source.chosen.values.map((c) => c.number).reduce((a, b) => a < b ? a : b);
      for (final info in infos) {
        // A channel that left and came back keeps what it had.
        final back = source.departed.remove(info.key);
        final settings = back?.settings ?? LiveChannelSettings(number: 0);
        final number = back != null && !used.contains(back.settings.number)
            ? back.settings.number
            : ChannelNumbers.nextFree(used, from: next);
        settings.number = number;
        used.add(number);
        if (back == null) next = number + 1;
        source.chosen[info.key] = settings;
      }
    }
    _schedules.clear();
    await save();
    notifyListeners();
    return changed;
  }

  // ---- Refreshing --------------------------------------------------------------

  /// Sources refreshing now.
  final _refreshing = <String>{};

  bool isRefreshing(LiveSource s) => _refreshing.contains(s.id);

  /// Refreshes [source]'s channel list and/or guide (live-tv-sources
  /// "Refreshing and caching"). The cache is kept on failure, and the
  /// error recorded on the source. Channels that left the source leave
  /// the lineup and [groups], remembered for 30 days; ones that came back
  /// return with their number, favorite and groups. [taken] is every
  /// number in use. True when [groups] changed.
  Future<bool> refresh(LiveSource source,
      {bool channels = true,
      bool guide = true,
      required Set<int> Function() taken,
      required List<ChannelGroup> groups,
      Duration? window}) async {
    final client = clientFor(source);
    if (client == null || !_refreshing.add(source.id)) return false;
    final entry = entryFor(source);
    final now = _now();
    var groupsChanged = false;
    notifyListeners();
    try {
      if (channels) {
        final guideBefore = (source.guideUrl, source.guideFile);
        final fresh = await client.fetchChannels();
        final hadGuide = {for (final c in entry.channels) if (c.hasGuide) c.key};
        entry.channels = [for (final c in fresh) hadGuide.contains(c.key) ? c.copyWith(hasGuide: true) : c];
        groupsChanged |= await _applyChannelList(source, taken: taken(), groups: groups, now: now);
        entry.state.channelsAt = now;
        await cache.saveChannels(source.id, entry.channels);
        if (guideBefore != (source.guideUrl, source.guideFile)) await save();
        PlaybackDiagnostics.note('LIVE', '${source.kind.name} ${source.id}: ${fresh.length} channels');
      }
      if (guide) {
        final span = window ?? (source.kind == LiveSourceKind.server ? const Duration(hours: 24) : M3uSource.guideHorizon);
        final g = await client.fetchGuide(entry.channels, source.chosen.keys.toSet(), now, now.add(span));
        // Server data fetched further ahead (the guide scrolled there) is kept.
        final until = now.add(span);
        entry.guide = {
          for (final key in {...g.programmes.keys, ...entry.guide.keys})
            if ([...?g.programmes[key], ...?entry.guide[key]?.where((p) => !p.start.isBefore(until))] case final l
                when l.isNotEmpty)
              key: l,
        };
        if (g.index != null) {
          entry.guideIndex = g.index!;
          await cache.saveGuideIndex(source.id, entry.guideIndex);
        }
        entry.channels = [for (final c in entry.channels) c.copyWith(hasGuide: g.withGuide.contains(c.key) || (g.index == null && c.hasGuide))];
        await cache.saveChannels(source.id, entry.channels);
        await cache.saveGuide(source.id, entry.guide);
        entry.state.guideAt = now;
        _schedules.removeWhere((id, _) => id.startsWith('live:${source.id}:'));
      }
      entry.state
        ..failures = 0
        ..lastError = null
        ..errorAt = null;
    } on LiveSourceException catch (e) {
      entry.state
        ..failures += 1
        ..lastError = e.message
        ..errorAt = now;
      PlaybackDiagnostics.note('LIVE', '${source.id} refresh failed: ${e.message}${e.detail == null ? '' : ' (${e.detail})'}');
    } on Object catch (e) {
      // Anything else (the cache can't be written, say) is on the
      // source's row too, never on the TV.
      entry.state
        ..failures += 1
        ..lastError = tr.couldntRefresh(source.name)
        ..errorAt = now;
      debugPrint('Live TV refresh of ${source.id} failed: $e');
    } finally {
      try {
        await cache.saveState(source.id, entry.state);
      } on Object catch (e) {
        debugPrint('Live TV: could not save refresh state: $e');
      }
      _refreshing.remove(source.id);
      notifyListeners();
    }
    return groupsChanged;
  }

  /// A server source's guide fetched on to [until], if what's loaded ends
  /// before it (the guide was scrolled there).
  Future<void> extendGuide(LiveSource source, DateTime until) async {
    if (source.kind != LiveSourceKind.server || _refreshing.contains(source.id)) return;
    final entry = entryFor(source);
    final loaded = entry.guide.values.expand((l) => l).fold<DateTime?>(
        null, (t, p) => t == null || p.end.isAfter(t) ? p.end : t);
    final from = loaded ?? _now();
    if (!from.isBefore(until)) return;
    final client = clientFor(source);
    if (client == null) return;
    _refreshing.add(source.id);
    try {
      final g = await client.fetchGuide(entry.channels, source.chosen.keys.toSet(), from, until.add(ServerLiveSource.guideWindow));
      for (final e in g.programmes.entries) {
        final list = [...?entry.guide[e.key], ...e.value.where((p) => !p.start.isBefore(from))]
          ..sort((a, b) => a.start.compareTo(b.start));
        entry.guide[e.key] = list;
      }
      await cache.saveGuide(source.id, entry.guide);
      _schedules.removeWhere((id, _) => id.startsWith('live:${source.id}:'));
    } on Object catch (e) {
      debugPrint('Live guide ahead: $e');
    } finally {
      _refreshing.remove(source.id);
      notifyListeners();
    }
  }

  /// Departures and returns after [source]'s channel list changed.
  Future<bool> _applyChannelList(LiveSource source,
      {required Set<int> taken, required List<ChannelGroup> groups, required DateTime now}) async {
    final present = {for (final c in entryFor(source).channels) c.key};
    var changed = false;
    for (final key in [...source.chosen.keys]) {
      if (present.contains(key)) continue;
      final id = LiveRef.channelId(source.id, key);
      final memberOf = [for (final g in groups) if (g.channelIds.contains(id)) g.id];
      source.departed[key] = DepartedChannel(settings: source.chosen.remove(key)!, groupIds: memberOf, leftAt: now);
      changed |= _leaveGroups({id}, groups);
    }
    final used = {...taken};
    for (final key in [...source.departed.keys]) {
      if (!present.contains(key)) continue;
      final back = source.departed.remove(key)!;
      final settings = back.settings;
      // Its number, unless someone took it meanwhile.
      if (used.contains(settings.number)) settings.number = ChannelNumbers.nextFree(used, from: settings.number);
      used.add(settings.number);
      source.chosen[key] = settings;
      final id = LiveRef.channelId(source.id, key);
      for (final g in groups) {
        if (back.groupIds.contains(g.id) && !g.channelIds.contains(id)) {
          g.channelIds = [...g.channelIds, id];
          changed = true;
        }
      }
    }
    source.forgetDeparted(now);
    await save();
    return changed;
  }

  bool _disposed = false;

  /// A refresh can finish after the profile closed; nobody's listening.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    downloader.close();
    super.dispose();
  }
}
