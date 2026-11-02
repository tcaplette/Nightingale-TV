import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show Client;

import 'backup/backup_archive.dart';
import 'channels/channel.dart';
import 'channels/retro.dart';
export 'channels/retro.dart';
import 'channels/channel_generator.dart';
import 'channels/show_key_remap.dart';
import 'channels/channel_groups.dart';
import 'channels/channel_groups.dart' as channel_groups show m3uGroupFor;
import 'channels/channel_numbers.dart';
import 'channels/premieres.dart';
import 'channels/program_block.dart';
import 'channels/schedule.dart';
import 'commercials/analysis/analysis_cache.dart';
import 'commercials/analysis/detections.dart';
import 'commercials/analysis/ffmpeg_runner.dart';
import 'commercials/analysis/media_analyzer.dart';
import 'commercials/analysis/server_analysis.dart';
import 'commercials/analysis/stream_proxy.dart';
import 'commercials/break_plan.dart';
import 'commercials/break_sources.dart';
import 'commercials/commercial_catalog.dart';
import 'commercials/commercial_pool.dart';
import 'data/app_storage.dart';
import 'icons/custom_icons.dart';
import 'library/library_index.dart';
import 'library/library_merge.dart';
import 'live/live_data.dart';
import 'live/live_download.dart';
import 'live/live_refresher.dart';
import 'live/live_source.dart';
import 'live/live_source_files.dart';
import 'live/live_source_client.dart';
import 'live/live_tv_manager.dart';
import 'platform/platform_info.dart';
import 'playback/android_device_profile.dart';
import 'playback/playback_diagnostics.dart';
import 'server/live_tv.dart';
import 'server/media_server.dart';
import 'server/plex/plex_account.dart';
import 'server/plex/plex_client.dart';
import 'server/plex/plex_connections.dart';
import 'server/server_clients.dart';
import 'server/server_set.dart';
import 'ui/format.dart';

/// A choice for the maximum streaming bitrate: Original (no [kbps]) or a
/// fixed cap.
typedef BitratePreset = ({String label, int? kbps});

/// A playback decision kept for the session: the conversion's URL template
/// (null: direct play), and whether that conversion keeps the video (a
/// direct stream).
typedef Decision = ({Uri? template, bool directStream});

/// A `PlaybackInfo` request's outcome: the decision, or what went wrong.
typedef _Asked = ({Decision? decision, Object? error, StackTrace? stack});

/// "Transcode only if needed": off unless the user turns it on. Per PC, not
/// per profile, since it's about this machine and its network.
class PlaybackSettings {
  /// A fixed [maxKbps] cap, or Original when it's null.
  const PlaybackSettings(
      {this.transcodeIfNeeded = false,
      this.maxKbps,
      this.volumeLeveling = false,
      this.breakNotices = true,
      this.pauseAndRewind = true,
      this.onScreenClock = false});

  /// A setting never saved: transcoding and leveling off, with Original
  /// chosen; break notices on.
  static const off = PlaybackSettings();

  /// Convert a program when it's over the cap or won't direct-play.
  final bool transcodeIfNeeded;

  /// The fixed cap in kbps, kept while the toggle is off; null is Original
  /// (no limit).
  final int? maxKbps;

  /// Even out loudness between programs and commercials as they play.
  final bool volumeLeveling;

  /// Count down before commercials start and before the program comes back.
  final bool breakNotices;

  /// Pause, skip and restart on generated channels (timeshift).
  final bool pauseAndRewind;

  /// Show the time of day in the corner of the picture.
  final bool onScreenClock;

  /// In this order, Original first.
  static const presets = <BitratePreset>[
    (label: 'Original (no limit)', kbps: null),
    (label: '40 Mbps · 4K', kbps: 40000),
    (label: '20 Mbps · 1080p high', kbps: 20000),
    (label: '12 Mbps · 1080p', kbps: 12000),
    (label: '8 Mbps · 1080p', kbps: 8000),
    (label: '4 Mbps · 720p', kbps: 4000),
  ];

  /// The preset cap at or below [kbps], never below the lowest (4 Mbps).
  static int capAtOrBelow(num kbps) {
    final caps = [for (final p in presets) ?p.kbps];
    return caps.firstWhere((c) => c <= kbps, orElse: () => caps.last);
  }

  BitratePreset get preset => presets.firstWhere((p) => p.kbps == maxKbps);

  /// The cap in effect, in kbps: the chosen cap, or null when off or
  /// Original. Nothing observed during playback lowers it.
  int? capKbps() => transcodeIfNeeded ? maxKbps : null;

  /// Whether playback decisions made under [other] still hold: everything
  /// but [breakNotices], [pauseAndRewind] and [onScreenClock], which change no
  /// decision, is the same.
  bool decidesLike(PlaybackSettings other) =>
      copyWith(
          breakNotices: other.breakNotices,
          pauseAndRewind: other.pauseAndRewind,
          onScreenClock: other.onScreenClock) ==
      other;

  PlaybackSettings copyWith(
          {bool? transcodeIfNeeded,
          BitratePreset? bitrate,
          bool? volumeLeveling,
          bool? breakNotices,
          bool? pauseAndRewind,
          bool? onScreenClock}) =>
      PlaybackSettings(
        transcodeIfNeeded: transcodeIfNeeded ?? this.transcodeIfNeeded,
        maxKbps: bitrate == null ? maxKbps : bitrate.kbps,
        volumeLeveling: volumeLeveling ?? this.volumeLeveling,
        breakNotices: breakNotices ?? this.breakNotices,
        pauseAndRewind: pauseAndRewind ?? this.pauseAndRewind,
        onScreenClock: onScreenClock ?? this.onScreenClock,
      );

  Map<String, Object?> toJson() => {
        'transcodeIfNeeded': transcodeIfNeeded,
        'bitrate': maxKbps ?? 'original',
        'volumeLeveling': volumeLeveling,
        'breakNotices': breakNotices,
        'pauseAndRewind': pauseAndRewind,
        'onScreenClock': onScreenClock,
      };

  /// A missing or unreadable setting is off with Original chosen. A saved
  /// "auto" (removed) is Original, with the toggle as it was; a saved cap
  /// snaps to the preset at or below it (4 Mbps for anything lower). Saved
  /// before Auto (as `maxBitrateMbps`), the same rules apply. Volume
  /// leveling is off unless saved as on; break notices and pause and rewind
  /// are on unless saved as off; the on-screen clock is off unless saved as
  /// on.
  factory PlaybackSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return off;
    final on = json['transcodeIfNeeded'] == true;
    final leveling = json['volumeLeveling'] == true;
    final notices = json['breakNotices'] != false;
    final rewind = json['pauseAndRewind'] != false;
    final clock = json['onScreenClock'] == true;
    final bitrate = json['bitrate'];
    if (bitrate is num) {
      return PlaybackSettings(
          transcodeIfNeeded: on,
          maxKbps: capAtOrBelow(bitrate),
          volumeLeveling: leveling,
          breakNotices: notices,
          pauseAndRewind: rewind,
          onScreenClock: clock);
    }
    if (!json.containsKey('bitrate')) {
      if (json['maxBitrateMbps'] case final num mbps) {
        return PlaybackSettings(
            transcodeIfNeeded: on,
            maxKbps: capAtOrBelow(mbps * 1000),
            volumeLeveling: leveling,
            breakNotices: notices,
            pauseAndRewind: rewind,
            onScreenClock: clock);
      }
    }
    return PlaybackSettings(
        transcodeIfNeeded: on,
        volumeLeveling: leveling,
        breakNotices: notices,
        pauseAndRewind: rewind,
        onScreenClock: clock);
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSettings &&
      other.transcodeIfNeeded == transcodeIfNeeded &&
      other.maxKbps == maxKbps &&
      other.volumeLeveling == volumeLeveling &&
      other.breakNotices == breakNotices &&
      other.pauseAndRewind == pauseAndRewind &&
      other.onScreenClock == onScreenClock;

  @override
  int get hashCode =>
      Object.hash(transcodeIfNeeded, maxKbps, volumeLeveling, breakNotices, pauseAndRewind, onScreenClock);

  @override
  String toString() => 'PlaybackSettings(${transcodeIfNeeded ? 'on' : 'off'}, ${preset.label}, '
      'leveling ${volumeLeveling ? 'on' : 'off'}, notices ${breakNotices ? 'on' : 'off'}, rewind ${pauseAndRewind ? 'on' : 'off'}, '
      'clock ${onScreenClock ? 'on' : 'off'})';
}

/// What the TV is doing, as far as bandwidth goes.
enum PlaybackActivity {
  /// Nothing is streaming (idle, off air, standby, error).
  none,

  /// A stream is opening.
  tuning,

  /// A segment is playing.
  playing,
}

/// The analyzer's download budget while the TV plays, whatever the
/// setting: nothing while a stream opens; while one plays, a quarter of the
/// cap in effect, or with no cap, of the playing file's average bitrate
/// ([fileBitsPerSecond]), paused until that's known. Unlimited otherwise.
Budget analyzerBudget(PlaybackActivity activity, PlaybackSettings playback, {int? fileBitsPerSecond}) {
  switch (activity) {
    case PlaybackActivity.tuning:
      return const Budget.paused();
    case PlaybackActivity.none:
      return const Budget.unlimited();
    case PlaybackActivity.playing:
      final cap = playback.capKbps();
      final rate = cap == null ? fileBitsPerSecond : cap * 1000;
      // A quarter of it, in bytes per second.
      return rate == null ? const Budget.paused() : Budget.limited(rate ~/ 4 ~/ 8);
  }
}

class AppSettings {
  AppSettings({
    required this.installId,
    this.commercialPlan = BreakPlan.off,
    List<CommercialPool>? commercialPools,
    this.lastChannelId,
    this.playback = PlaybackSettings.off,
    this.migrated = false,
    this.logoMode = LogoMode.nowAndThen,
    this.retro = const RetroSettings(),
    List<ChannelGroup>? groups,
    List<String>? guideTabs,
    Set<String>? hiddenTabs,
    this.guideTab,
    this.premieres = const PremiereSettings(),
    this.lineupVersion = 0,
  })  : commercialPools = commercialPools ?? [],
        groups = groups ?? [],
        guideTabs = guideTabs ?? [...GuideTabs.defaultOrder],
        hiddenTabs = hiddenTabs ?? {};

  /// Random per-install id; Jellyfin's DeviceId.
  final String installId;

  /// The main break plan; channels can have their own. Breaks only happen
  /// once a pool the plan uses has clips.
  BreakPlan commercialPlan;

  /// Where commercials come from.
  List<CommercialPool> commercialPools;
  String? lastChannelId;

  /// Transcode only if needed (off by default).
  PlaybackSettings playback;

  /// Loaded from an older format; save to finish upgrading it.
  final bool migrated;

  /// The main channel logo setting; channels can have their own.
  LogoMode logoMode;

  /// The main retro look and the Custom CRT style; channels can have their
  /// own look.
  RetroSettings retro;

  /// The profile's own channel groups, and the guide's tabs: their order
  /// (built-in ids and group ids), the hidden ones, and the one picked last.
  List<ChannelGroup> groups;
  List<String> guideTabs;
  Set<String> hiddenTabs;
  String? guideTab;

  /// The nightly new episode premiere slot.
  PremiereSettings premieres;

  /// Which one-time lineup cleanups have run: 0 for a lineup made before
  /// show identity, [currentLineupVersion] once cleaned up (lineup-dedup D7).
  int lineupVersion;

  static const currentLineupVersion = 1;

  /// The pool settings from before break plans became, with an id that's
  /// the same every time the upgrade runs.
  static const legacyPoolId = 'pool-commercials';

  Map<String, Object?> toJson() => {
        'installId': installId,
        'commercialPlan': commercialPlan.toJson(),
        'commercialPools': [for (final p in commercialPools) p.toJson()],
        // Read by versions from before break plans, so a downgrade keeps
        // roughly the same setup.
        'commercialsEnabled': !commercialPlan.isOff,
        'commercialLibraryIds': {
          for (final p in commercialPools)
            for (final r in p.roots)
              if (r.isWholeLibrary) r.itemId,
        }.toList(),
        if (lastChannelId != null) 'lastChannelId': lastChannelId,
        'playback': playback.toJson(),
        'logoMode': logoMode.name,
        'retro': retro.toJson(),
        if (groups.isNotEmpty) 'groups': [for (final g in groups) g.toJson()],
        'guideTabs': guideTabs,
        if (hiddenTabs.isNotEmpty) 'hiddenTabs': hiddenTabs.toList(),
        if (guideTab != null) 'guideTab': guideTab,
        'premieres': premieres.toJson(),
        'lineupVersion': lineupVersion,
      };

  /// Jellyfin device IDs start with this.
  static const deviceIdPrefix = 'nightingaletv-';

  /// …and started with this before the app was renamed from Retro TV.
  static const legacyDeviceIdPrefix = 'retrotv-';

  /// [id] with the current prefix (unchanged if it already has it).
  static String migrateDeviceId(String id) => id.startsWith(legacyDeviceIdPrefix)
      ? deviceIdPrefix + id.substring(legacyDeviceIdPrefix.length)
      : id;

  factory AppSettings.fromJson(Map<String, Object?> j) {
    final installId = migrateDeviceId(j['installId'] as String);
    final lastChannelId = j['lastChannelId'] as String?;
    final playback = PlaybackSettings.fromJson(j['playback']);
    final groups = [
      for (final g in (j['groups'] as List? ?? const []).whereType<Map<String, Object?>>()) ChannelGroup.fromJson(g)
    ];
    AppSettings withExtras(AppSettings s) => s
      ..logoMode = LogoMode.parse(j['logoMode']) ?? LogoMode.nowAndThen
      ..retro = RetroSettings.fromJson(j['retro'])
      ..groups = groups
      ..guideTabs = GuideTabs.normalize((j['guideTabs'] as List?)?.whereType<String>().toList() ?? GuideTabs.defaultOrder, groups)
      ..hiddenTabs = {...?(j['hiddenTabs'] as List?)?.whereType<String>()}
      ..guideTab = j['guideTab'] as String?
      ..premieres = PremiereSettings.fromJson(j['premieres'])
      ..lineupVersion = j['lineupVersion'] as int? ?? 0;
    if (j['commercialPlan'] case final Map<String, Object?> plan) {
      return withExtras(AppSettings(
        installId: installId,
        commercialPlan: BreakPlan.fromJson(plan),
        commercialPools: [
          for (final p in (j['commercialPools'] as List? ?? const []).cast<Map<String, Object?>>())
            CommercialPool.fromJson(p)
        ],
        lastChannelId: lastChannelId,
        playback: playback,
      ));
    }
    // Saved before break plans: an on/off switch and whole libraries.
    final libraries = (j['commercialLibraryIds'] as List?)?.cast<String>() ?? const [];
    return withExtras(AppSettings(
      installId: installId,
      commercialPlan: j['commercialsEnabled'] == true ? BreakPlan.legacy : BreakPlan.off,
      commercialPools: [
        if (libraries.isNotEmpty)
          CommercialPool(
            id: legacyPoolId,
            name: CommercialPool.defaultName,
            // Labels are filled in from the server on the next library scan.
            roots: [for (final id in libraries) PoolRoot(itemId: id, libraryId: id, label: '')],
          ),
      ],
      lastChannelId: lastChannelId,
      playback: playback,
      migrated: j.containsKey('commercialsEnabled') || j.containsKey('commercialLibraryIds'),
    ));
  }

  static AppSettings fresh() {
    final rng = Random.secure();
    final id = List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    // A new profile's lineup is made with show identity.
    return AppSettings(installId: '$deviceIdPrefix$id', lineupVersion: currentLineupVersion);
  }
}

enum AppPhase { starting, signedOut, syncing, ready }

/// App-wide state: session, library index, channel lineup.
class AppState extends ChangeNotifier {
  AppState(this.storage,
      {this.maxRatingRank,
      this.runAnalysis = true,
      this._background = false,
      this.exportBusy,
      this.analysisAllowed,
      this.safetyBackup,
      @visibleForTesting this._sessionClient})
      : icons = CustomIconStore(storage.logosDir) {
    analysisAllowed?.addListener(_onAnalysisAllowed);
    playbackActivity.addListener(_pushBudget);
    playingBitrate.addListener(_pushBudget);
    playbackBusy.addListener(_updateAnalysisBusy);
    exportBusy?.addListener(_updateAnalysisBusy);
    _syncStaleCheck();
    live.addListener(_onLiveChanged);
  }

  // ---- Launch: background requests wait for the first picture --------------

  /// Background requests at launch (a stale library re-scan, one-time
  /// sign-in upgrades) start this long after the first picture…
  @visibleForTesting
  static Duration launchAfterPicture = const Duration(seconds: 10);

  /// …or this long after the lineup is ready if nothing has tuned by then.
  @visibleForTesting
  static Duration launchIdleWait = const Duration(seconds: 15);

  final _afterLaunch = <void Function()>[];
  bool _launchSettled = false;
  bool _launchDue = false;
  bool _launchPicture = false;
  Timer? _launchTimer;

  /// Runs [action] once the launch's tune has its picture (fast-tune spec:
  /// the stream has the network to itself while tuning).
  void _afterLaunchTune(void Function() action) {
    if (_launchSettled) {
      action();
    } else {
      _afterLaunch.add(action);
    }
  }

  /// Runs [action] once the launch's tune has its picture and background
  /// work may start (the daily backup check waits for it): that is
  /// [launchSettleDelay] after the picture.
  void afterLaunch(void Function() action) => _afterLaunchTune(action);

  static Duration get launchSettleDelay => launchAfterPicture;

  /// Starts counting once the lineup is ready.
  void _armLaunchGate() {
    if (_launchSettled || _launchTimer != null) return;
    _launchTimer = Timer(launchIdleWait, _onLaunchDue);
    playbackActivity.addListener(_onLaunchActivity);
    _onLaunchActivity();
  }

  void _onLaunchDue() {
    _launchDue = true;
    _onLaunchActivity();
  }

  void _onLaunchActivity() {
    final activity = playbackActivity.value;
    if (!_launchDue && !_launchPicture && activity == PlaybackActivity.playing) {
      _launchPicture = true;
      _launchTimer?.cancel();
      _launchTimer = Timer(launchAfterPicture, _onLaunchDue);
    }
    // A tune under way when the time comes still goes first.
    if (_launchDue && activity != PlaybackActivity.tuning) _settleLaunch();
  }

  void _settleLaunch() {
    if (_launchSettled) return;
    _launchSettled = true;
    _launchTimer?.cancel();
    playbackActivity.removeListener(_onLaunchActivity);
    final actions = [..._afterLaunch];
    _afterLaunch.clear();
    if (_closed) return;
    for (final action in actions) {
      action();
    }
  }

  /// Analyze media in the background (off in most tests), while on screen.
  final bool runAnalysis;

  /// Saves a safety backup of the household before a big change (reset,
  /// settings upgrade), named by its reason; throws when it can't be saved.
  final Future<void> Function(String reason)? safetyBackup;

  /// Builds the client for a saved sign-in at [start] (tests give a fake).
  final MediaServer Function(ServerSession session)? _sessionClient;

  /// True while Live TV export is streaming anything; analysis holds off
  /// meanwhile, as it does while the TV tunes.
  final ValueListenable<bool>? exportBusy;

  /// Server mode's turn to analyze (the household's analysis queue): media
  /// analysis runs while it's true, on screen or not. Null on the TV, where
  /// only the profile on screen analyzes.
  final ValueListenable<bool>? analysisAllowed;

  bool get _analysisAllowedNow => analysisAllowed?.value ?? !_background;

  /// What analysis is doing; [AnalyzerState.idle] when it has nothing to
  /// do or can't run, so the analysis queue can pass the turn on.
  ValueListenable<AnalyzerState> get analysisState => _analysisState;
  final _analysisState = ValueNotifier(AnalyzerState.starting);

  void _syncAnalysisIdle() {
    final analyzer = _analyzer;
    _analysisState.value = switch (phase) {
      _ when _closed || !runAnalysis => AnalyzerState.idle,
      AppPhase.signedOut => AnalyzerState.idle,
      AppPhase.starting || AppPhase.syncing => AnalyzerState.starting,
      AppPhase.ready => analyzer?.state.value ??
          (_store == null || client == null ? AnalyzerState.idle : AnalyzerState.starting),
    };
  }

  @override
  void notifyListeners() {
    _syncAnalysisIdle();
    super.notifyListeners();
  }

  void _onAnalysisAllowed() {
    if (_analysisAllowedNow) {
      _startAnalysis();
    } else {
      unawaited(_stopAnalysis().then((_) => _syncAnalysisIdle()));
    }
  }

  /// Kept loaded for Live TV export while another profile is on screen: no
  /// analysis (unless [analysisAllowed] says so), and the library is
  /// refreshed on a timer, since nobody opens this profile to trigger it.
  bool get background => _background;
  bool _background;
  Timer? _staleCheck;

  /// Kid profiles only see content rated at most this (see `ratingRank`).
  final int? maxRatingRank;

  static const _sessionFile = 'session.json';
  static const _settingsFile = 'settings.json';
  static const _libraryFile = 'library.json';
  static const _channelsFile = 'channels.json';
  static const _blocksFile = 'blocks.json';

  /// A restored profile's server and user name, until it signs in
  /// (backup-restore D6).
  static const signInHintFile = 'sign_in_hint.json';

  /// Re-scan the library in the background when the cache is older than this.
  static const libraryMaxAge = Duration(hours: 6);

  final AppStorage storage;
  final CustomIconStore icons;

  AppPhase phase = AppPhase.starting;
  String syncStatus = '';
  String? syncError;
  late AppSettings settings;

  /// The profile's servers (multi-server): the main one, whose sign-in is
  /// [session] and [client], and any added ones.
  final servers = ServerSet();

  /// The main server's sign-in (`session.json`).
  ServerSession? get session => servers.main.session;
  set session(ServerSession? s) => servers.main.session = s;

  /// The main server's client.
  MediaServer? get client => servers.main.client;
  set client(MediaServer? c) => servers.main.client = c;

  /// Where a restored profile signed in, for pre-filling sign-in: server URL,
  /// name and id, user id and name. Null otherwise.
  Map<String, Object?>? signInHint;
  LibraryIndex library = LibraryIndex.empty;
  List<Channel> _channels = [];
  List<ProgramBlock> _blocks = [];
  final Map<String, ProgramSchedule?> _schedules = {};

  String get deviceName => PlatformInfo.deviceName;

  /// All channels sorted by number, including hidden ones.
  List<Channel> get allChannels => _channels;

  /// What the guide and channel up/down use.
  List<Channel> get channels => _channels.where((c) => !c.hidden).toList();

  /// Programming blocks, in the order they were created.
  List<ProgramBlock> get blocks => _blocks;

  ProgramSchedule? scheduleFor(Channel c) {
    if (c.isLive) return live.scheduleFor(c);
    final premieres = premierePlan;
    return _schedules.putIfAbsent(c.id, () {
      // Built before: what follows may differ from what aired (timeshift D6).
      if (!_scheduleBuilt.add(c.id)) _scheduleChanged[c.id] = DateTime.now();
      return ChannelSchedule.build(c, library, _blocks, _breakContext(planFor(c), c.effectiveSlotRule), premieres);
    });
  }

  final _scheduleBuilt = <String>{};
  final _scheduleChanged = <String, DateTime>{};

  /// When [channelId]'s schedule was last rebuilt this session: rewinding
  /// stays within the slot on air then.
  DateTime? scheduleChangedAt(String channelId) => _scheduleChanged[channelId];

  /// Records a rebuild at [at] (tests, whose clocks aren't the real time).
  @visibleForTesting
  void debugScheduleChanged(String channelId, DateTime? at) {
    if (at == null) {
      _scheduleChanged.remove(channelId);
    } else {
      _scheduleChanged[channelId] = at;
    }
  }

  // ---- New episode premieres (episode-premieres) ------------------------------

  PremierePlan? _premierePlan;
  bool _premiereStale = true;

  /// Which episodes premiere where; rebuilt (with every schedule) when the
  /// lineup, the library or the premiere settings change.
  PremierePlan? get premierePlan {
    if (_premiereStale) {
      _premiereStale = false;
      _premierePlan = PremierePlan.build(library, channels, settings.premieres);
      _schedules.clear();
    }
    return _premierePlan;
  }

  void _premieresChanged() {
    _premiereStale = true;
    _autoGroups = null;
    _schedules.clear();
  }

  // ---- Channel groups (channel-groups) -------------------------------------------

  AutoGroups? _autoGroups;

  /// Which channels the automatic tabs hold; worked out again when the
  /// lineup, the library or the blocks change.
  AutoGroups get autoGroups => _autoGroups ??= AutoGroups(library, _blocks, kidProfile: maxRatingRank != null);

  /// The guide's tabs, in order, each with its visible channels.
  List<GuideTab> guideTabs() => resolveGuideTabs(
        visible: channels,
        groups: settings.groups,
        order: settings.guideTabs,
        hidden: settings.hiddenTabs,
        auto: autoGroups,
      );

  /// Every tab, hidden and empty ones included (for the Channel groups
  /// screen), in order.
  List<String> get allTabIds => GuideTabs.normalize(settings.guideTabs, settings.groups);

  /// What [tabId] is called.
  String tabName(String tabId) =>
      settings.groups.where((g) => g.id == tabId).firstOrNull?.name ?? GuideTabs.builtinName(tabId) ?? tabId;

  /// The M3U `group-title` for [c] (lineup-export).
  String m3uGroupFor(Channel c, {required String fallback}) =>
      channel_groups.m3uGroupFor(c, groups: settings.groups, order: settings.guideTabs, auto: autoGroups, fallback: fallback);

  /// Remembers the guide's tab.
  Future<void> setGuideTab(String tabId) async {
    if (settings.guideTab == tabId) return;
    settings.guideTab = tabId;
    await _saveSettings();
  }

  /// A new, empty group named [name], placed after Favorites.
  Future<ChannelGroup> createGroup(String name) async {
    final group = ChannelGroup(
      id: 'group:${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: name.trim().isEmpty ? 'New group' : name.trim(),
    );
    settings.groups = [...settings.groups, group];
    settings.guideTabs = GuideTabs.normalize(settings.guideTabs, settings.groups);
    await _groupsChanged();
    return group;
  }

  Future<void> renameGroup(ChannelGroup group, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == group.name) return;
    group.name = trimmed;
    await _groupsChanged();
  }

  Future<void> deleteGroup(ChannelGroup group) async {
    settings.groups = [for (final g in settings.groups) if (g.id != group.id) g];
    settings.guideTabs = GuideTabs.normalize(settings.guideTabs, settings.groups);
    settings.hiddenTabs = {...settings.hiddenTabs}..remove(group.id);
    await _groupsChanged();
  }

  /// Puts [ch] in [group] or takes it out.
  Future<void> setInGroup(ChannelGroup group, Channel ch, bool member) async {
    final ids = [...group.channelIds]..remove(ch.id);
    if (member) ids.add(ch.id);
    group.channelIds = ids;
    await _groupsChanged();
  }

  /// Moves a tab [delta] places; All stays first.
  Future<void> moveTab(String tabId, int delta) async {
    final order = allTabIds;
    final i = order.indexOf(tabId);
    final j = i + delta;
    if (tabId == GuideTabs.all || i < 0 || j < 1 || j >= order.length) return;
    order
      ..removeAt(i)
      ..insert(j, tabId);
    settings.guideTabs = order;
    await _groupsChanged();
  }

  /// Hides a tab from the guide or shows it again; All is always shown.
  Future<void> setTabHidden(String tabId, bool hidden) async {
    if (tabId == GuideTabs.all) return;
    settings.hiddenTabs = {...settings.hiddenTabs};
    hidden ? settings.hiddenTabs.add(tabId) : settings.hiddenTabs.remove(tabId);
    await _groupsChanged();
  }

  Future<void> _groupsChanged() async {
    notifyListeners();
    await _saveSettings();
  }

  /// Changes the premiere slot. Like a block edit, it takes effect at once.
  Future<void> setPremiereSettings(PremiereSettings premieres) async {
    if (premieres == settings.premieres) return;
    settings.premieres = premieres;
    _premieresChanged();
    notifyListeners();
    await _saveSettings();
  }

  /// Whether [ch] can be a show's home channel for premieres.
  Future<void> setChannelPremieres(Channel ch, bool on) async {
    if (on == ch.premieres) return;
    ch.premieres = on;
    _setChannels(_channels);
    await _saveChannels();
  }

  // ---- Live TV sources (live-tv-sources) ---------------------------------------

  /// The profile's Live TV sources and their channels.
  late final live = LiveTvManager(storage, signedIn: (source) {
    final server = _liveServer(source.serverId);
    final c = server?.client, s = server?.session;
    return c == null || s == null || server!.state == ServerState.needsSignIn ? null : (client: c, session: s);
  });

  /// The server a server Live TV source with [serverId] belongs to: the one
  /// with that id, or the main server for a source (or sign-in) that never
  /// recorded one.
  ProfileServer? _liveServer(String? serverId) {
    if (serverId == null) return servers.main;
    return servers.byServerId(serverId) ?? (servers.main.serverId == null ? servers.main : null);
  }

  /// Kid profiles keep their sources saved but get no live channels.
  bool get liveEnabled => maxRatingRank == null;

  /// The lineup has generated channels (live ones don't count: a profile
  /// with an M3U source and no library scan yet still needs its lineup).
  bool get _hasGenerated => _channels.any((c) => !c.isLive);

  /// A fresh generated lineup, numbered around the live channels' numbers.
  List<Channel> _generated() {
    final fresh = ChannelGenerator(library).generate();
    final held = {
      if (liveEnabled)
        for (final s in live.sources)
          for (final c in s.chosen.values) c.number,
    };
    if (fresh.isNotEmpty && held.isNotEmpty) ChannelNumbers.numberSkipping(fresh, held, start: fresh.first.number);
    return fresh;
  }

  /// Every number in the lineup.
  Set<int> get _takenNumbers => {for (final c in _channels) c.number};

  late final _liveRefresher = LiveRefresher(
    sources: () => liveEnabled ? live.sources : const [],
    stateOf: (s) => live.entryFor(s).state,
    refresh: (s, {required channels, required guide}) => refreshLiveSource(s, channels: channels, guide: guide),
  );

  /// Refreshes run for the profile on screen, once the launch's tune has
  /// its picture.
  void _startLiveRefresh() {
    // Nothing to keep fresh without sources; adding one starts it.
    if (!liveEnabled || _background || _closed || phase != AppPhase.ready || live.sources.isEmpty) return;
    _afterLaunchTune(() {
      if (!_background && !_closed) _liveRefresher.start();
    });
  }

  /// Refreshes [source] (see [LiveTvManager.refresh]).
  Future<void> refreshLiveSource(LiveSource source, {bool channels = true, bool guide = true}) async {
    final groupsChanged = await live.refresh(source,
        channels: channels, guide: guide, taken: () => _takenNumbers, groups: settings.groups);
    if (groupsChanged) await _saveSettings();
  }

  /// "Refresh now" on a source.
  Future<void> refreshLiveNow(LiveSource source) => _liveRefresher.refreshNow(source);

  /// The guide reached [until] on [ch]: a server source fetches on to it.
  void needLiveGuideUntil(Channel ch, DateTime until) {
    final source = ch.live == null ? null : live.sourceById(ch.live!.sourceId);
    if (source != null) unawaited(live.extendGuide(source, until));
  }

  /// The lineup's live channels as the sources have them now.
  void _onLiveChanged() {
    if (_closed) return;
    final before = [for (final c in _channels) if (c.isLive) '${c.id}#${c.number}#${c.hidden}'];
    final after = liveEnabled ? [for (final c in live.lineupChannels()) '${c.id}#${c.number}#${c.hidden}'] : const <String>[];
    if (before.length != after.length || !before.toSet().containsAll(after)) {
      _setChannels(_channels);
    } else {
      notifyListeners();
    }
  }

  /// Adds [source] with the [channels] it was read with, choosing the
  /// default ones (all of a small lineup, none of a big one).
  Future<void> addLiveSource(LiveSource source, List<LiveChannelInfo> channels) async {
    await live.addSource(source, channels);
    final chosen = LiveTvManager.defaultChoice(channels);
    await chooseLiveChannels(source, chosen);
    // Its guide is read even with nothing chosen yet: the picker shows
    // which channels have guide data.
    if (chosen.isEmpty) unawaited(refreshLiveSource(source, channels: false));
    _startLiveRefresh();
  }

  /// Makes [keys] [source]'s chosen channels, then loads their guide.
  Future<void> chooseLiveChannels(LiveSource source, Set<String> keys) async {
    final groupsChanged = await live.choose(source, keys, taken: _takenNumbers, groups: settings.groups);
    if (groupsChanged) await _saveSettings();
    _setChannels(_channels);
    if (keys.isNotEmpty) unawaited(refreshLiveSource(source, channels: false));
  }

  /// Whether the profile's server ([key]: which one, multi-server) has Live
  /// TV this user may watch, and if not why; null when there's no server (or
  /// it can't be asked).
  Future<LiveTvAvailability?> liveTvAvailability({String key = ServerSet.mainKey}) async {
    final tv = servers.byKey(key)?.client?.liveTv;
    if (tv == null) return null;
    try {
      return await tv.availability();
    } on ServerException catch (e) {
      debugPrint('Live TV availability: ${e.message}');
      return null;
    }
  }

  /// Adds the profile's server's ([key]: which one, multi-server) Live TV as
  /// a source, with every channel chosen if it has 150 or fewer. Throws
  /// [LiveSourceException].
  Future<LiveSource> addServerLiveSource({String key = ServerSet.mainKey}) async {
    final s = servers.byKey(key)?.session;
    if (s == null) throw const LiveSourceException('Not signed in');
    if (servers.multiple && live.serverSourceFor(s.serverId) != null) {
      throw LiveSourceException('${s.serverName} Live TV is already a source');
    }
    final source = LiveSource(
      id: LiveSource.newId(),
      kind: LiveSourceKind.server,
      name: '${s.serverName} Live TV',
      serverKind: s.kind,
      serverId: s.serverId,
    );
    final reader = live.clientFor(source);
    if (reader == null) throw LiveSourceException("Couldn't reach ${s.serverName}");
    final channels = await reader.fetchChannels();
    if (channels.isEmpty) throw LiveSourceException('${s.serverName} has no Live TV channels');
    await addLiveSource(source, channels);
    return source;
  }

  /// Reads the playlist [source] describes (URL or file) and its header's
  /// guide; throws [LiveSourceException] saying why it can't be used.
  Future<List<LiveChannelInfo>> readM3u(LiveSource source) async {
    final playlist = await M3uSource.readPlaylist(source, store: live.store, downloader: live.downloader);
    if ((source.guideUrl == null && source.guideFile == null) || source.guideFromPlaylist) {
      source.guideUrl = playlist.guideUrls.firstOrNull;
      source.guideFromPlaylist = source.guideUrl != null;
    }
    return playlist.channels;
  }

  /// Adds an M3U playlist source once its playlist reads with at least one
  /// channel ([playlist] or [playlistUrl]; the guide is optional, the
  /// playlist header's when none is given). Picked files are copied into
  /// the profile folder. Throws [LiveSourceException], saving nothing.
  Future<LiveSource> addM3uSource({
    required String name,
    String? playlistUrl,
    PickedLiveFile? playlist,
    String? guideUrl,
    PickedLiveFile? guide,
  }) async {
    final id = LiveSource.newId();
    final source = LiveSource(
      id: id,
      kind: LiveSourceKind.m3u,
      name: name.trim().isEmpty ? 'M3U playlist' : name.trim(),
      playlistUrl: playlist == null ? _blankToNull(playlistUrl) : null,
      guideUrl: guide == null ? _blankToNull(guideUrl) : null,
    );
    if (playlist != null) source.playlistFile = await live.store.savePicked(playlist, id, 'playlist');
    try {
      if (guide != null) source.guideFile = await live.store.savePicked(guide, id, 'guide');
      final channels = await readM3u(source);
      await addLiveSource(source, channels);
      return source;
    } on Object {
      await live.store.deleteFiles(source);
      rethrow;
    }
  }

  /// Changes an M3U source's name, playlist or guide (each kept when
  /// null), then refreshes it. The playlist must still read. Throws
  /// [LiveSourceException], changing nothing.
  Future<void> editM3uSource(LiveSource source,
      {String? name, String? playlistUrl, PickedLiveFile? playlist, String? guideUrl, PickedLiveFile? guide, bool clearGuide = false}) async {
    final draft = LiveSource(
      id: source.id,
      kind: source.kind,
      name: source.name,
      playlistUrl: playlist != null ? null : (playlistUrl == null ? source.playlistUrl : _blankToNull(playlistUrl)),
      playlistFile: playlist != null || playlistUrl != null ? null : source.playlistFile,
      guideUrl: clearGuide || guide != null ? null : (guideUrl == null ? source.guideUrl : _blankToNull(guideUrl)),
      guideFile: clearGuide || guide != null || guideUrl != null ? null : source.guideFile,
      guideFromPlaylist: !clearGuide && guide == null && guideUrl == null && source.guideFromPlaylist,
    );
    if (playlist != null) {
      draft.playlistFile = await live.store.savePicked(playlist, '${source.id}-new', 'playlist');
    }
    await readM3u(draft);
    if (playlist != null) {
      source.playlistFile = await live.store.savePicked(playlist, source.id, 'playlist');
      await live.store.fileFor(draft.playlistFile!).delete();
    } else {
      source.playlistFile = draft.playlistFile;
    }
    source
      ..name = name?.trim().isNotEmpty == true ? name!.trim() : source.name
      ..playlistUrl = draft.playlistUrl
      ..guideUrl = draft.guideUrl
      ..guideFile = guide != null ? await live.store.savePicked(guide, source.id, 'guide') : draft.guideFile
      ..guideFromPlaylist = draft.guideFromPlaylist;
    await live.save();
    unawaited(refreshLiveNow(source));
  }

  static String? _blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  /// Removes [source] and its channels from the lineup, groups and
  /// favorites.
  Future<void> removeLiveSource(LiveSource source) async {
    if (await live.removeSource(source, settings.groups)) await _saveSettings();
    if (live.sources.isEmpty) _liveRefresher.stop();
    _setChannels(_channels);
  }

  // ---- Commercial breaks ---------------------------------------------------

  /// The clips the pools hold right now (and recently).
  final catalog = CommercialCatalog();

  AnalysisCache? _analysis;
  MediaAnalyzer? _analyzer;

  /// Analysis results for this server, once its id is known.
  AnalysisCache? get analysisCache => _analysis;

  /// With several servers (multi-server D6): each one's results, in its own
  /// cache, by server key (the main one's is [_analysis]).
  final _addedCaches = <String, AnalysisCache>{};
  ServerAnalysis? _serverAnalysis;

  /// Where analysis reads and records: the main server's cache, or every
  /// server's with several.
  AnalysisStore? get _store => servers.multiple ? _serverAnalysis : _analysis;

  /// Opens the added servers' caches and routes analysis through them all,
  /// after a server joined or left (or at start). Analysis restarts on the
  /// new set.
  Future<void> _openServerAnalysis() async {
    final keep = {
      for (final s in servers.added)
        if (s.serverId != null) s.key,
    };
    for (final key in [..._addedCaches.keys]) {
      if (!keep.contains(key)) await AnalysisCache.release(_addedCaches.remove(key)!);
    }
    for (final server in servers.added) {
      final id = server.serverId;
      if (id == null || _addedCaches.containsKey(server.key)) continue;
      final cache = await AnalysisCache.acquire(storage.analysisDir, id);
      if (_closed) {
        await AnalysisCache.release(cache);
        return;
      }
      _addedCaches[server.key] = cache;
    }
    final before = _serverAnalysis;
    before?.detach();
    before?.removeListener(_onAnalysis);
    _serverAnalysis = servers.multiple
        ? (ServerAnalysis({ServerSet.mainKey: ?_analysis, ..._addedCaches})..addListener(_onAnalysis))
        : null;
    if (_closed) return;
    await _stopAnalysis();
    _updateCatalog();
    _startAnalysis();
  }

  /// True while the TV is opening a stream; analysis holds off meanwhile.
  final playbackBusy = ValueNotifier(false);

  /// What analysis holds off for: the TV tuning, or Live TV export streaming.
  late final _analysisBusy = ValueNotifier(_busyNow);

  bool get _busyNow => playbackBusy.value || (exportBusy?.value ?? false);

  void _updateAnalysisBusy() => _analysisBusy.value = _busyNow;

  @visibleForTesting
  ValueListenable<bool> get analysisBusy => _analysisBusy;

  /// Moves this profile off screen ([on]) or onto it. Off screen, analysis
  /// stops and the library is kept fresh on a timer.
  Future<void> setBackground(bool on) async {
    if (_closed || on == _background) return;
    _background = on;
    _syncStaleCheck();
    if (on) {
      _liveRefresher.stop();
      if (!_analysisAllowedNow) await _stopAnalysis();
    } else {
      _startAnalysis();
      _startLiveRefresh();
    }
    notifyListeners();
  }

  /// How often a background profile checks whether its library is stale.
  @visibleForTesting
  static Duration staleCheckInterval = const Duration(minutes: 30);

  void _syncStaleCheck() {
    _staleCheck?.cancel();
    _staleCheck = null;
    if (!_background || _closed) return;
    _staleCheck = Timer.periodic(staleCheckInterval, (_) {
      if (phase == AppPhase.ready && DateTime.now().difference(library.fetchedAt) > libraryMaxAge) {
        unawaited(refreshLibrary(background: true));
      }
    });
  }

  /// What the TV is doing (set by the tuner); with a cap, it sets how fast
  /// the analyzer may download (see [analyzerBudget]).
  final playbackActivity = ValueNotifier(PlaybackActivity.none);

  LoopbackStreamProxy? _proxy;

  /// Volume leveling as set (volume-leveling spec), for the tuner, which
  /// follows it.
  final volumeLeveling = ValueNotifier(false);

  /// The playing file's average bitrate in bits per second, once the tuner
  /// knows it (null while it doesn't): with no cap, it sets the analyzer's
  /// budget.
  final playingBitrate = ValueNotifier<int?>(null);

  /// The analyzer's download budget right now.
  Budget get analyzerBudgetNow => _asleep
      ? const Budget.paused()
      : analyzerBudget(playbackActivity.value, settings.playback, fileBitsPerSecond: playingBitrate.value);

  bool _asleep = false;

  /// The sleep timer has the app asleep (sleep-timer spec): background reads
  /// from the server (analysis, index fills) wait too, so nothing keeps the
  /// server busy all night.
  bool get asleep => _asleep;
  set asleep(bool value) {
    if (value == _asleep) return;
    _asleep = value;
    _pushBudget();
  }

  // ---- Playback decisions ----------------------------------------------------

  /// Decisions saved by an older version; deleted at start-up.
  static const legacyDecisionsFile = 'playback_decisions.json';

  /// This session's decisions by source and cap (`template` null for direct
  /// play); cleared when the setting changes.
  final _decisions = <(String, int?), Decision>{};

  /// The cap opens and decisions use, in kbps (null for none): the chosen
  /// cap.
  int? get capInEffect => settings.playback.capKbps();

  /// On Android every segment's method is Jellyfin's decision for the
  /// device (android-playback), whatever the setting.
  bool get decidesEverySegment => PlatformInfo.isAndroid;

  /// `PlaybackInfo` requests in flight, by source and cap: a tune, a
  /// prefetch and the launch's early request share one. Shared as an
  /// outcome, never as an error: a future's error only reaches listeners in
  /// its own error zone (tests start the app in another one), so each
  /// caller gets it back as an error in its own.
  final _deciding = <(String, int?), Future<_Asked>>{};

  /// Whether a decision for [source] under [capKbps] is being asked.
  bool deciding(String source, int? capKbps) => _deciding.containsKey((source, capKbps));

  /// The decision for [source] under [capKbps] (null: no cap; `template`
  /// null for direct play): this session's, the request already in flight,
  /// or a new request, kept once Jellyfin answers. Jellyfin decides.
  Future<Decision> decide(String source, int? capKbps, {Duration startAt = Duration.zero}) {
    final saved = savedDecision(source, capKbps);
    if (saved != null) return Future.value(saved);
    final key = (source, capKbps);
    if (_deciding[key] case final inFlight?) return _answer(inFlight);
    // The server the source is on (multi-server); the main one's client
    // as it is.
    final c = servers.clientFor(source);
    if (c == null) return Future.error(StateError('Not signed in.'));
    final playback = settings.playback;
    final request = () async {
      try {
        final maxBitrate = capKbps == null ? null : capKbps * 1000;
        // Only Android waits for its profile: elsewhere the request goes at
        // once, as it always has.
        final profile = PlatformInfo.isAndroid ? await deviceProfile(capKbps) : null;
        final decision = await c.playbackDecision(source, maxBitrate: maxBitrate, startAt: startAt, profile: profile);
        var template = decision.transcodeTemplate;
        // On Android a re-encode with no cap asks for what keeps the original
        // picture, not Jellyfin's ceiling.
        if (PlatformInfo.isAndroid && capKbps == null && template != null && !decision.directStream) {
          template = limitConversion(template, sourceBitrate: decision.sourceBitrate, sourceCodec: decision.sourceCodec);
        }
        final kept = (template: template, directStream: decision.directStream);
        // A setting changed meanwhile cleared the decisions; this one
        // was asked under the old one.
        if (settings.playback.decidesLike(playback)) _decisions[key] = kept;
        return kept;
      } finally {
        _deciding.remove(key);
      }
    }();
    final asked = request.then<_Asked>((d) => (decision: d, error: null, stack: null),
        onError: (Object e, StackTrace s) => (decision: null, error: e, stack: s));
    _deciding[key] = asked;
    return _answer(asked);
  }

  static Future<Decision> _answer(Future<_Asked> asked) async {
    final a = await asked;
    if (a.error case final e?) Error.throwWithStackTrace(e, a.stack!);
    return a.decision!;
  }

  /// At launch, asks the decision for what's on the channel the TV will
  /// tune: the tune then awaits this request instead of starting its own
  /// after the TV screen shows. With a cap in effect for a program part, or
  /// on Android for any segment.
  void _askLaunchDecision() {
    final cap = capInEffect;
    final android = decidesEverySegment;
    final visible = channels;
    final limits = servers.all.any((s) => s.qualityLimit != null);
    if ((cap == null && !android && !limits) || visible.isEmpty) return;
    // As the TV screen picks it.
    final ch = visible.where((c) => c.id == settings.lastChannelId).firstOrNull ?? visible.first;
    // A live channel opens its stream from its source, with no decision.
    if (ch.isLive) return;
    final now = DateTime.now();
    final on = scheduleFor(ch)?.playbackAt(now);
    // The copy that will play (multi-server).
    final item = on?.item == null ? null : copyToPlay(on!.item!)?.item;
    if (on == null || item == null) return;
    final program = !on.isBreak && !on.isCommercial;
    if (!program && !android) return;
    // The cap is only ever for program parts, lowered by the server's limit.
    final segmentCap = program ? capFor(ServerSet.keyOf(item.sourceId), cap) : null;
    if (savedDecision(item.sourceId, segmentCap) != null) return;
    PlaybackDiagnostics.mark('launch decision asked');
    unawaited(decide(item.sourceId, segmentCap, startAt: on.positionAt(now))
        .then((_) {}, onError: (Object e) => debugPrint('Launch playback decision failed: $e')));
  }

  /// This session's decision for [source] under [capKbps] (`template` null
  /// for direct play), or null if there's none.
  Decision? savedDecision(String source, int? capKbps) => _decisions[(source, capKbps)];

  void saveDecision(String source, int? capKbps, Uri? template, {bool directStream = false}) =>
      _decisions[(source, capKbps)] = (template: template, directStream: directStream);

  // ---- The device profile (android-playback) ---------------------------------

  Future<DeviceCapabilities?>? _capabilities;

  /// The device profile decisions under [capKbps] send: on Android, built
  /// from what the device decodes (asked once), without passthrough while
  /// volume leveling is on; elsewhere null, for the Linux profile.
  Future<Map<String, Object?>?> deviceProfile(int? capKbps) async {
    if (!PlatformInfo.isAndroid) return null;
    final caps = await (_capabilities ??= _queryCapabilities()) ?? DeviceCapabilities.fallback;
    return androidDeviceProfile(caps,
        maxBitrate: capKbps == null ? null : capKbps * 1000, leveling: settings.playback.volumeLeveling);
  }

  static Future<DeviceCapabilities?> _queryCapabilities() async {
    final caps = await DeviceCapabilities.query();
    if (PlaybackDiagnostics.enabled) {
      for (final d in caps?.decoders ?? const <String>[]) {
        PlaybackDiagnostics.note('DECODER', d);
      }
      PlaybackDiagnostics.note('DEVICE', '${caps ?? 'unknown: ${DeviceCapabilities.fallback}'}');
      PlaybackDiagnostics.note('DEVICE', 'profile ${jsonEncode(androidDeviceProfile(caps ?? DeviceCapabilities.fallback))}');
    }
    return caps;
  }

  void _pushBudget() => unawaited(_proxy?.setBudget(analyzerBudgetNow));

  /// One ffmpeg for the whole app (so it's looked for once per launch).
  static final ffmpeg = FfmpegRunner();

  static final _noProgress = ValueNotifier(const AnalysisProgress());

  /// Whether media analysis is running (it waits when there's nothing to do).
  bool get analyzing => _analyzer?.running ?? false;

  /// How far media analysis has got.
  ValueListenable<AnalysisProgress> get analysisProgress => _analyzer?.progress ?? _noProgress;

  /// The plan [c] is set to: its own, or the main one.
  BreakPlan configuredPlanFor(Channel c) => c.commercialPlan ?? settings.commercialPlan;

  /// The logo setting [c] follows: its own, or the main one.
  LogoMode logoModeFor(Channel c) => c.logoMode ?? settings.logoMode;

  /// The look [c] has: its own settings over the main ones.
  ResolvedRetro retroFor(Channel c) => ResolvedRetro.of(c.retro, settings.retro);

  /// The plan [c] airs with: [configuredPlanFor], or Off while none of the
  /// pools it uses has clips.
  BreakPlan planFor(Channel c) {
    // Live channels never get breaks (live-playback).
    if (c.isLive) return BreakPlan.off;
    final plan = configuredPlanFor(c);
    return plan.isOff || !hasClipsFor(plan) ? BreakPlan.off : plan;
  }

  /// Whether any pool [plan] draws from has clips.
  bool hasClipsFor(BreakPlan plan) => plan.poolsUsed.any(catalog.hasClips);

  /// Whether [c] gets commercial breaks.
  bool breaksFor(Channel c) => !planFor(c).isOff;

  BreakContext _breakContext(BreakPlan plan, [SlotRule? slotRule]) =>
      BreakContext(plan: plan, clips: catalog, points: _store ?? const ChapterPoints(), slotRule: slotRule);

  /// Every channel's [planFor], to see what a change changes.
  Map<String, BreakPlan> _plans() => {for (final ch in _channels) ch.id: planFor(ch)};

  Channel? channelById(String id) => _channels.where((c) => c.id == id).firstOrNull;

  Future<void> start() async {
    // What the device decodes, for every decision's device profile; asked
    // now so the launch's decision doesn't wait for it.
    if (PlatformInfo.isAndroid) _capabilities ??= _queryCapabilities();
    final settingsJson = await storage.readJson(_settingsFile);
    settings = settingsJson is Map<String, Object?>
        ? AppSettings.fromJson(settingsJson)
        : AppSettings.fresh();
    volumeLeveling.value = settings.playback.volumeLeveling;
    final renamed = settingsJson is Map<String, Object?> && settingsJson['installId'] != settings.installId;
    if (settings.migrated) {
      // The old format is kept in a backup first; the upgrade goes ahead
      // even if that fails, since the app can't refuse to start.
      try {
        await safetyBackup?.call('before-upgrade');
      } on Object catch (e) {
        debugPrint('No backup before upgrading settings: $e');
      }
    }
    if (settingsJson == null || renamed || settings.migrated) await _saveSettings();
    PlaybackDiagnostics.mark('settings read');
    // Decisions and a connection measurement saved by an older version.
    unawaited(storage.delete(legacyDecisionsFile).catchError((Object e) {
      debugPrint('Could not delete $legacyDecisionsFile: $e');
    }));

    final sessionJson = await storage.readJson(_sessionFile);
    if (sessionJson is! Map<String, Object?>) {
      final hint = await storage.readJson(signInHintFile);
      signInHint = hint is Map<String, Object?> ? hint : null;
      _setPhase(AppPhase.signedOut);
      return;
    }
    session = ServerSession.fromJson(sessionJson);
    client = _sessionClient?.call(session!) ?? clientForSession(session!);
    // Added servers (multi-server); none for most profiles.
    servers.load(await storage.readJson(ServerSet.file),
        (s, key) => _sessionClient?.call(s) ?? clientForSession(s, key: key));
    // A Plex server may have another address now (a phone away from home).
    if (session!.kind == ServerKind.plex) unawaited(reachServerAgain(checkFirst: true));
    // One-time sign-in upgrades; they wait for the launch's picture.
    _afterLaunchTune(() {
      unawaited(_renameDevice());
      unawaited(_recordServerId());
    });

    final libraryJson = await storage.readJson(_libraryFile);
    final channelsJson = await storage.readJson(_channelsFile);
    PlaybackDiagnostics.mark('library and channels read');
    // Blocks whenever they're saved: a restored lineup has them without a
    // library index.
    await _loadBlocks();
    await live.load();
    PlaybackDiagnostics.mark('live sources read');
    if (libraryJson is Map<String, Object?> && channelsJson is List) {
      library = LibraryIndex.fromJson(libraryJson);
      PlaybackDiagnostics.mark('library parsed');
      // A kid's limit may have been tightened since this was saved.
      final limit = maxRatingRank;
      if (limit != null) library = library.restrictedTo(limit);
      // Clips (and so which channels have breaks) must be known before the
      // lineup is, or every launch would shift the guide.
      if (session!.serverId case final id?) await _openAnalysis(id);
      if (servers.multiple) await _openServerAnalysis();
      PlaybackDiagnostics.mark('analysis cache open');
      _updateCatalog(rebase: false);
      _setChannels([for (final c in channelsJson.cast<Map<String, Object?>>()) Channel.fromJson(c)]);
      await _cleanUpLineup();
      _askLaunchDecision();
      _setPhase(AppPhase.ready);
      PlaybackDiagnostics.mark('ready (channels set)');
      _startAnalysis();
      _startLiveRefresh();
      // Sources with roots this library hasn't resolved (saved before
      // roots, or before a root was added): fetched on their own.
      if (_unresolvedRoots().isNotEmpty) _afterLaunchTune(() => unawaited(resolveRoots()));
      final age = DateTime.now().difference(library.fetchedAt);
      if (age > libraryMaxAge) {
        // It downloads the whole library: after the launch's picture.
        _afterLaunchTune(() {
          PlaybackDiagnostics.mark('library refresh started (cache ${age.inHours} h old)');
          unawaited(refreshLibrary(background: true));
        });
      }
    } else if (channelsJson is List) {
      // A restored lineup, without its library index: the first scan merges
      // into it, keeping every anchor, so the same shows are on the air
      // (backup-restore D8).
      if (session!.serverId case final id?) await _openAnalysis(id);
      _setChannels([for (final c in channelsJson.cast<Map<String, Object?>>()) Channel.fromJson(c)]);
      _restoredLineup = true;
      await refreshLibrary();
    } else {
      await refreshLibrary();
    }
    _armLaunchGate();
  }

  /// Once per profile, a lineup made before show identity is cleaned up
  /// (lineup-dedup D7), without a scan: the saved library re-keyed, saved
  /// show keys rewritten, duplicate and thin generated channels retired and
  /// merged as a refresh does, then generated channels numbered from 1 in
  /// their order, around the numbers live and user-built channels hold. A
  /// safety backup comes first; without one, it waits for the next launch.
  Future<void> _cleanUpLineup() async {
    if (settings.lineupVersion >= AppSettings.currentLineupVersion) return;
    if (_channels.any((c) => c.auto && !c.isLive)) {
      try {
        await safetyBackup?.call(BackupReason.beforeLineupCleanup);
      } on Object catch (e) {
        debugPrint('No backup before cleaning up the lineup; trying again next launch: $e');
        return;
      }
      final previous = library;
      final plansBefore = _plans();
      library = previous.rekeyed();
      _mergeLibraryIntoChannels(previous, plansBefore);
      final held = {for (final c in _channels) if (!c.auto || c.isLive) c.number};
      ChannelNumbers.numberSkipping([for (final c in _channels) if (c.auto && !c.isLive) c], held);
      _setChannels(_channels);
      PlaybackDiagnostics.note('LINEUP', 'cleaned up: ${[for (final c in _channels) '${c.number} ${c.name}'].join(', ')}');
      await storage.writeJson(_libraryFile, library.toJson());
      await _saveChannels();
      await _saveBlocks();
    }
    settings.lineupVersion = AppSettings.currentLineupVersion;
    await _saveSettings();
  }

  Future<void> _loadBlocks() async {
    final blocksJson = await storage.readJson(_blocksFile);
    if (blocksJson is List) {
      _blocks = [for (final b in blocksJson.cast<Map<String, Object?>>()) ProgramBlock.fromJson(b)];
    }
  }

  /// Sign-ins from before the rename identify this PC to Jellyfin as
  /// "retrotv-…". Switch to the new ID once the server confirms it still
  /// accepts the sign-in that way; if it doesn't (or is unreachable), keep
  /// the old ID and try again next launch, so nobody gets signed out.
  Future<void> _renameDevice() async {
    final old = session;
    if (old == null) return;
    final id = AppSettings.migrateDeviceId(old.deviceId);
    if (id == old.deviceId) return;
    final renamed = old.withDeviceId(id);
    final candidate = clientForSession(renamed);
    try {
      await candidate.checkSession();
    } on ServerException catch (e) {
      debugPrint('Kept the old Jellyfin device ID: ${e.message}');
      candidate.close();
      return;
    }
    final current = session;
    if (current == null || current.accessToken != old.accessToken || current.deviceId != old.deviceId) {
      // Signed out or in again meanwhile.
      candidate.close();
      return;
    }
    final previous = client;
    // Keeps anything recorded meanwhile, such as the server id.
    session = current.withDeviceId(id);
    client = candidate;
    await storage.writeJson(_sessionFile, session!.toJson(), private: true);
    previous?.close();
  }

  /// Saves the server's id with a sign-in that doesn't have it yet (signed
  /// in before it was recorded). Analysis results are kept per server id, so
  /// they survive a change of server address.
  Future<void> _recordServerId() async {
    final old = session;
    final c = client;
    if (old == null || c == null || old.serverId != null) return;
    final String? id;
    try {
      // The public endpoint needs no sign-in, so a client being replaced
      // (device rename) can't fail this.
      final probe = clientFor(c.kind, c.serverUrl);
      try {
        id = (await probe.publicInfo()).id;
      } finally {
        probe.close();
      }
    } on ServerException catch (e) {
      debugPrint('Could not read the server id: ${e.message}');
      return;
    }
    // Signed out, in again, or renamed meanwhile: that path saves its own.
    if (id == null || session?.accessToken != old.accessToken || session?.serverId != null) return;
    session = session!.withServerId(id);
    await storage.writeJson(_sessionFile, session!.toJson(), private: true);
    _onServerId(id);
  }

  /// Called once the server's id is known.
  void _onServerId(String id) => unawaited(() async {
        await _openAnalysis(id);
        if (_closed) return;
        if (servers.multiple) return _openServerAnalysis();
        _updateCatalog();
        _startAnalysis();
      }());

  // ---- Sign in / out ------------------------------------------------------

  /// A client for the [kind] of server at [serverUrl], not signed in yet.
  MediaServer clientFor(ServerKind kind, String serverUrl) =>
      serverClient(kind, serverUrl, deviceId: settings.installId, deviceName: deviceName);

  /// A client for a saved sign-in, of the server [key] (multi-server).
  MediaServer clientForSession(ServerSession session, {String key = ServerSet.mainKey}) {
    final client = sessionClient(session, deviceName: deviceName);
    // Plex's part paths come from the loaded library.
    _attach(client, key);
    return client;
  }

  /// Connected through Plex's relay, which limits quality.
  bool get plexRelay => session?.relay == true;

  final _reaching = <String, Future<bool>>{};
  final _reachedAt = <String, DateTime>{};

  /// When the server doesn't answer: a Plex profile looks its server up
  /// again with its Plex account, picks an address by the connection rules
  /// and saves it, without signing out (server-sign-in spec). True when the
  /// address changed. At most once every 30 seconds; other servers have
  /// only the one address. With [checkFirst], the saved address is tried
  /// first, and kept if it answers.
  ///
  /// [key] names the server (multi-server); the main one by default.
  Future<bool> reachServerAgain({bool checkFirst = false, String key = ServerSet.mainKey}) {
    final server = servers.byKey(key);
    final s = server?.session;
    if (server == null || s == null || s.kind != ServerKind.plex || s.accountToken == null || s.serverId == null) {
      return Future.value(false);
    }
    if (_reaching[key] case final inFlight?) return inFlight;
    final last = _reachedAt[key];
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 30)) return Future.value(false);
    _reachedAt[key] = DateTime.now();
    return _reaching[key] = _rediscoverPlex(server, s, checkFirst: checkFirst).whenComplete(() => _reaching.remove(key));
  }

  Future<bool> _rediscoverPlex(ProfileServer server, ServerSession s, {required bool checkFirst}) async {
    if (checkFirst) {
      final http = Client();
      try {
        if (await answersAt(http, PlexConnection(uri: s.serverUrl, relay: s.relay), s.serverId!)) return false;
      } finally {
        http.close();
      }
    }
    final account = PlexAccount(clientId: s.deviceId, deviceName: deviceName);
    try {
      final found = await rediscover(account, accountToken: s.accountToken!, machineId: s.serverId!);
      if (found.resource == null) {
        // The share was removed: as an expired sign-in.
        await _expireServer(server);
        return false;
      }
      final c = found.connection;
      if (c == null || server.session != s) return false;
      if (c.uri == s.serverUrl && c.relay == s.relay && found.resource!.accessToken == s.accessToken) return false;
      PlaybackDiagnostics.note('PLEX', '${server.isMain ? '' : '${server.key} '}address ${s.serverUrl} → ${c.uri}${c.relay ? ' (relay)' : ''}');
      final moved = s.withServerUrl(c.uri, relay: c.relay, accessToken: found.resource!.accessToken);
      final previous = server.client;
      server
        ..session = moved
        ..client = clientForSession(moved, key: server.key);
      _decisions.clear();
      if (server.isMain) {
        await storage.writeJson(_sessionFile, moved.toJson(), private: true);
      } else {
        await _saveServers();
      }
      previous?.close();
      notifyListeners();
      return true;
    } on ServerException catch (e) {
      if (e.statusCode == 401) await _expireServer(server);
      debugPrint('Could not look the Plex server up again: ${e.message}');
      return false;
    } finally {
      account.close();
    }
  }

  Future<void> _expireSession() async {
    await signOut();
    syncError = 'Your session expired. Please sign in again.';
    notifyListeners();
  }

  /// [server]'s sign-in expired: with one server the profile signs out as
  /// before; with several, that server needs signing in again and the
  /// others carry on (multi-server D3).
  Future<void> _expireServer(ProfileServer server) async {
    if (server.isMain && !servers.multiple) return _expireSession();
    if (server.state == ServerState.needsSignIn) return;
    server.state = ServerState.needsSignIn;
    PlaybackDiagnostics.note('SERVER', '${server.key} needs sign-in');
    notifyListeners();
  }

  /// How often servers marked Can't be reached are tried again.
  @visibleForTesting
  static Duration serverPingInterval = const Duration(minutes: 1);

  /// Runs only while a server is marked Can't be reached.
  Timer? _serverPings;

  void _syncServerPings() {
    final any = !_closed && servers.all.any((s) => s.state == ServerState.unreachable);
    if (!any) {
      _serverPings?.cancel();
      _serverPings = null;
    } else {
      _serverPings ??= Timer.periodic(serverPingInterval, (_) => unawaited(pingUnreachable()));
    }
  }

  /// The tuner (or a scan) couldn't reach [server]: its copies are skipped
  /// until it answers a ping again (multi-server D5).
  void _markUnreachable(ProfileServer server) {
    if (server.state != ServerState.ok) return;
    server.state = ServerState.unreachable;
    PlaybackDiagnostics.note('SERVER', '${server.key} unreachable');
    _syncServerPings();
    notifyListeners();
  }

  /// Marks the server with [key] Can't be reached.
  void markUnreachable(String key) {
    if (servers.byKey(key) case final server?) _markUnreachable(server);
  }

  /// Asks every server marked Can't be reached whether it answers again.
  @visibleForTesting
  Future<void> pingUnreachable() async {
    for (final server in servers.all) {
      final c = server.client;
      if (server.state != ServerState.unreachable || c == null) continue;
      var answers = true;
      try {
        // Needs no sign-in, and goes through the client's own connections.
        await c.publicInfo().timeout(const Duration(seconds: 10));
      } on ServerException catch (e) {
        answers = !e.unreachable;
      } on TimeoutException {
        answers = false;
      }
      if (!answers) {
        // Still down; a Plex server may have moved.
        if (server.kind == ServerKind.plex) unawaited(reachServerAgain(key: server.key));
      } else if (server.state == ServerState.unreachable && !_closed) {
        server.state = ServerState.ok;
        PlaybackDiagnostics.note('SERVER', '${server.key} ok');
        notifyListeners();
      }
    }
    _syncServerPings();
  }

  // ---- The profile's servers (multi-server) ---------------------------------

  /// The server already in the profile that [session] signs in to, if any.
  ProfileServer? serverLike(ServerSession session) =>
      servers.byServerId(session.serverId) ??
      servers.all.where((s) => s.serverUrl == session.serverUrl && s.kind == session.kind).firstOrNull;

  /// Adds a signed-in server at the end of Play from, and refreshes the
  /// library in the background (D7). Throws [ServerException] when the
  /// profile already has it.
  Future<ProfileServer> addServer(ServerSession newSession, MediaServer newClient, {bool refresh = true}) async {
    if (serverLike(newSession) case final existing?) {
      newClient.close();
      throw ServerException('${existing.name} is already in this profile');
    }
    // The library so far is the main server's: its part until it's scanned
    // again, so a failing first scan keeps it.
    if (!servers.multiple && !library.isEmpty) await storage.writeJson(_partFile(ServerSet.mainKey), library.toJson());
    final server = servers.add(newSession, newClient);
    _attach(newClient, server.key);
    await _saveServers();
    PlaybackDiagnostics.note('SERVER', 'added ${server.key} (${newSession.kind.label})');
    await _openServerAnalysis();
    notifyListeners();
    if (refresh) unawaited(refreshLibrary(background: true));
    return server;
  }

  /// Sign in again to [key] (D7): keeps its key, so its items come back
  /// to the same channels. The main server's sign-in is saved as today's.
  Future<void> signInAgainTo(String key, ServerSession newSession, MediaServer newClient, {bool refresh = true}) async {
    final server = servers.byKey(key);
    if (server == null) throw ServerException('That server is no longer in this profile');
    final other = serverLike(newSession);
    if (other != null && other.key != key) {
      newClient.close();
      throw ServerException('${other.name} is already in this profile');
    }
    final previous = server.client;
    server
      ..session = newSession
      ..client = newClient
      ..hint = null
      ..state = ServerState.ok;
    _attach(newClient, key);
    _decisions.clear();
    if (server.isMain) {
      await storage.writeJson(_sessionFile, newSession.toJson(), private: true);
    } else {
      await _saveServers();
    }
    if (!identical(previous, newClient)) previous?.close();
    _syncServerPings();
    if (!server.isMain) await _openServerAnalysis();
    notifyListeners();
    if (refresh) unawaited(refreshLibrary(background: true));
  }

  /// Takes the added server [key] out of the profile (D7): signs out of it,
  /// forgets its part and its Live TV source, and refreshes, so its items
  /// leave the channels as items gone from a server do.
  Future<void> removeServer(String key) async {
    final server = servers.byKey(key);
    if (server == null || server.isMain) return;
    final serverId = server.serverId;
    await _signOutOf(server);
    servers.remove(key);
    await storage.delete(_partFile(key));
    if (!servers.multiple) await storage.delete(_partFile(ServerSet.mainKey));
    await _saveServers();
    if (serverId != null) {
      if (live.serverSourceFor(serverId) case final source?) await removeLiveSource(source);
    }
    _syncServerPings();
    await _openServerAnalysis();
    PlaybackDiagnostics.note('SERVER', 'removed $key');
    notifyListeners();
    await refreshLibrary(background: true);
  }

  /// Moves [key] [delta] places in Play from.
  Future<void> moveServer(String key, int delta) async {
    servers.move(key, delta);
    _decisions.clear();
    await _saveServers();
    notifyListeners();
  }

  /// [key]'s quality limit in kbps (null: same as the profile).
  Future<void> setServerQualityLimit(String key, int? kbps) async {
    final server = servers.byKey(key);
    if (server == null) return;
    server.qualityLimit = kbps == null ? null : kbps * 1000;
    _decisions.clear();
    await _saveServers();
    notifyListeners();
  }

  /// The cap a program part from server [key] plays under, in kbps: the
  /// lower of [cap] (the profile's) and the server's quality limit.
  int? capFor(String key, int? cap) {
    final limit = servers.byKey(key)?.qualityLimitKbps;
    if (limit == null) return cap;
    return cap == null || limit < cap ? limit : cap;
  }

  /// Item counts per server, from the merged library: each copy counts for
  /// its own server.
  Map<String, ({int episodes, int movies, int songs})> serverCounts() {
    final counts = <String, ({int episodes, int movies, int songs})>{};
    void add(String id, MediaKind kind) {
      final key = ServerSet.keyOf(id);
      final c = counts[key] ?? (episodes: 0, movies: 0, songs: 0);
      counts[key] = switch (kind) {
        MediaKind.episode => (episodes: c.episodes + 1, movies: c.movies, songs: c.songs),
        MediaKind.movie => (episodes: c.episodes, movies: c.movies + 1, songs: c.songs),
        _ => (episodes: c.episodes, movies: c.movies, songs: c.songs + 1),
      };
    }

    for (final e in [...library.episodes, ...library.movies, ...library.songs, ...library.musicVideos]) {
      for (final c in e.copies) {
        add(c.id, e.kind);
      }
    }
    return counts;
  }

  /// The client to ask about [id], any id the library holds (see
  /// [ServerSet.clientFor]); null when its server isn't signed in.
  MediaServer? clientOf(String id) => servers.clientFor(id);

  /// Which copy of [entry] plays now (D5): the first in Play from whose
  /// server can be used, else the first copy (which then fails to open as an
  /// unreachable server does). [entry] as that copy, and its client.
  ({MediaEntry item, MediaServer client, String key})? copyToPlay(MediaEntry entry) {
    final copies = servers.copiesOf(entry);
    final copy = copies.firstOrNull ?? entry.copy;
    final client = servers.clientFor(copy.id);
    if (client == null) return null;
    return (item: entry.asCopy(copy), client: client, key: ServerSet.keyOf(copy.id));
  }

  /// Where to read the file of [sourceId] (an entry's source) from: the copy
  /// that plays (multi-server), with its server's headers.
  ({Uri url, Map<String, String> headers}) streamOf(String sourceId) {
    final entry = library[sourceId];
    final pick = entry == null || entry.sourceId != sourceId ? null : copyToPlay(entry);
    final server = pick?.client ?? clientOf(sourceId) ?? client!;
    return (url: server.streamUri(pick?.item.sourceId ?? sourceId), headers: server.authHeaders);
  }

  /// Every server's libraries (multi-server), in Play from order, with
  /// library ids; named "{server} › {library}" when the profile has more
  /// than one server (D8). A server that can't list them is left out;
  /// throws only when none can.
  Future<List<ServerLibrary>> allLibraries() async {
    if (!servers.multiple) {
      final c = client;
      if (c == null) throw ServerException('Not signed in.');
      return c.libraries();
    }
    final out = <ServerLibrary>[];
    ServerException? failure;
    for (final server in servers.ordered) {
      if (server.client == null || server.state == ServerState.needsSignIn) continue;
      final c = servers.clientFor(ServerSet.globalId(server.key, ''))!;
      try {
        for (final l in await c.libraries()) {
          out.add(ServerLibrary(id: l.id, name: '${server.name} › ${l.name}', collectionType: l.collectionType));
        }
      } on ServerException catch (e) {
        failure ??= e;
        debugPrint('Libraries of ${server.name}: ${e.message}');
      }
    }
    if (out.isEmpty && failure != null) throw failure;
    return out;
  }

  /// [root]'s label as the source editors show it: with one server as
  /// saved; with several, starting with its server's name unless it already
  /// does (D8).
  String rootLabel(PoolRoot root) {
    if (!servers.multiple) return root.label;
    final name = servers.byKey(ServerSet.keyOf(root.itemId))?.name;
    if (name == null || root.label.startsWith('$name › ')) return root.label;
    return '$name › ${root.label}';
  }

  /// Whether [entry] has a usable copy on a server other than [key].
  bool hasOtherCopy(MediaEntry entry, String key) =>
      servers.copiesOf(entry).any((c) => ServerSet.keyOf(c.id) != key);

  /// Whether the server [key] answers now (a request that needs no sign-in).
  Future<bool> serverAnswers(String key) async {
    final c = servers.byKey(key)?.client;
    if (c == null) return false;
    try {
      await c.publicInfo().timeout(const Duration(seconds: 5));
      return true;
    } on ServerException catch (e) {
      return !e.unreachable;
    } on TimeoutException {
      return false;
    }
  }

  /// Plex clients look their part paths up in the library under [key].
  void _attach(MediaServer c, String key) {
    if (c is PlexClient) {
      c.index = () => library;
      c.partPath = (id) => library.copyById(ServerSet.globalId(key, id))?.streamPath;
    }
  }

  /// Ends the sign-in on an added [server], as signing out does; a failed
  /// request still forgets it here.
  Future<void> _signOutOf(ProfileServer server) async {
    try {
      await server.client?.logout();
    } on ServerException catch (e) {
      debugPrint('Sign-out of ${server.name}: ${e.message}');
    }
    server.client?.close();
    server.client = null;
    server.session = null;
  }

  Future<void> _saveServers() async {
    final json = servers.toJson();
    if (json == null) {
      await storage.delete(ServerSet.file);
    } else {
      await storage.writeJson(ServerSet.file, json, private: true);
    }
  }

  Future<void> completeSignIn(ServerSession newSession, MediaServer newClient) async {
    session = newSession;
    client = newClient;
    servers.main.state = ServerState.ok;
    _attach(newClient, ServerSet.mainKey);
    _decisions.clear();
    await storage.writeJson(_sessionFile, newSession.toJson(), private: true);
    // A Plex sign-in knows its server's id from the start; Jellyfin and Emby
    // ones look it up.
    if (newSession.serverId case final id?) {
      _onServerId(id);
    } else {
      await _recordServerId();
    }
    await _adoptRestoredLineup();
    await refreshLibrary();
  }

  /// A restored profile's lineup waits on disk for its sign-in (D8). On the
  /// server the backup came from it's loaded, so the first scan merges into
  /// it; on another server it's deleted, and a fresh lineup is generated.
  /// Settings are kept either way.
  Future<void> _adoptRestoredLineup() async {
    final hint = signInHint ?? await storage.readJson(signInHintFile);
    signInHint = null;
    if (_hasGenerated) return;
    final channelsJson = await storage.readJson(_channelsFile);
    final serverId = hint is Map<String, Object?> ? hint['serverId'] : null;
    if (channelsJson is List && serverId != null && serverId == session?.serverId) {
      await _loadBlocks();
      _setChannels([for (final c in channelsJson.cast<Map<String, Object?>>()) Channel.fromJson(c)]);
      _restoredLineup = true;
      // The backup's added servers come back needing sign-in (multi-server
      // D10), keeping their keys so their programs return to the channels.
      servers.load(await storage.readJson(ServerSet.file), (s, key) => clientForSession(s, key: key));
      if (servers.multiple) await _openServerAnalysis();
    } else {
      _blocks = [];
      await storage.delete(_channelsFile);
      await storage.delete(_blocksFile);
      // Their ids belong to the lineup that's gone.
      await storage.delete(ServerSet.file);
    }
    await storage.delete(signInHintFile);
  }

  Future<void> signOut() async {
    await _stopAnalysis();
    // The next sign-in may be to another server, with its own results.
    final cache = _analysis;
    _analysis = null;
    cache?.removeListener(_onAnalysis);
    if (cache != null) await AnalysisCache.release(cache);
    _serverAnalysis
      ?..detach()
      ..removeListener(_onAnalysis);
    _serverAnalysis = null;
    for (final c in _addedCaches.values) {
      await AnalysisCache.release(c);
    }
    _addedCaches.clear();
    // Every server's sign-in ends (multi-server).
    for (final server in servers.added) {
      await _signOutOf(server);
      await storage.delete(_partFile(server.key));
    }
    if (servers.multiple) await storage.delete(_partFile(ServerSet.mainKey));
    servers.load(null, (s, key) => clientForSession(s, key: key));
    await storage.delete(ServerSet.file);
    _syncServerPings();
    try {
      await client?.logout();
    } on ServerException {
      // Signing out locally still works if the server is unreachable.
    }
    client?.close();
    client = null;
    session = null;
    servers.main.state = ServerState.ok;
    _decisions.clear();
    library = LibraryIndex.empty;
    _updateCatalog(rebase: false);
    _blocks = [];
    _schedules.clear();
    _setChannels([]);
    for (final f in [_sessionFile, _libraryFile, _channelsFile, _blocksFile]) {
      await storage.delete(f);
    }
    _setPhase(AppPhase.signedOut);
  }

  // ---- Library ------------------------------------------------------------

  bool _refreshing = false;

  /// A library scan is running.
  bool get isRefreshingLibrary => _refreshing;

  /// The lineup was restored from a backup and has no library index yet:
  /// its first scan is like a first sign-in's, and keeps every anchor.
  bool _restoredLineup = false;

  /// A library scan is in progress ([syncStatus] says what it's doing).
  bool get refreshing => _refreshing;

  /// What the last library scan found that the lineup didn't have.
  ({int shows, int episodes, int movies, int songs, int channels})? lastRefresh;

  /// The scan under way; a refresh asked for meanwhile waits for it.
  Future<void>? _refreshRun;

  /// Re-scans Jellyfin. New episodes and movies join existing channels
  /// right after what's on air now, without changing it; new genre/show
  /// channels are added. While a scan is running, waits for that one.
  Future<void> refreshLibrary({bool background = false}) {
    if (client == null) return Future.value();
    return _refreshRun ??= _refreshLibrary(background: background).whenComplete(() => _refreshRun = null);
  }

  Future<void> _refreshLibrary({bool background = false}) async {
    final c = client;
    if (c == null || _refreshing) return;
    _refreshing = true;
    syncError = null;
    notifyListeners();
    if (!background || phase != AppPhase.ready) _setPhase(AppPhase.syncing);
    try {
      LibraryIndex fresh;
      if (servers.multiple) {
        fresh = await _scanServers();
      } else {
        syncStatus = 'Connecting to ${session?.serverName ?? 'your server'}…';
        notifyListeners();
        fresh = await fetchLibraryIndex(c, pools: settings.commercialPools, channelRoots: _channelRoots(),
            onStatus: (s) {
          syncStatus = s;
          notifyListeners();
        }, onLibraries: _labelLibraryRoots);
      }
      final limit = maxRatingRank;
      if (limit != null) fresh = fresh.restrictedTo(limit);
      // When this profile could first know each episode (episode-premieres):
      // a profile with no lineup yet is on its first scan.
      final restored = _restoredLineup;
      fresh = fresh.withAvailability(!_hasGenerated || restored ? null : library, DateTime.now());
      syncStatus = 'Building channels…';
      notifyListeners();
      final previous = library;
      final plansBefore = _plans();
      final channelsBefore = {for (final ch in _channels) ch.id};
      final showsBefore = {for (final s in previous.series) s.key};
      library = fresh;
      if (restored) {
        // The clips are known before the merge, as at a launch, so no
        // channel is rebased for gaining its breaks: with no previous index
        // every anchor stays as the backup had it.
        _restoredLineup = false;
        _updateCatalog(rebase: false);
      }
      if (_hasGenerated) {
        _mergeLibraryIntoChannels(previous, plansBefore);
      } else {
        _schedules.clear();
        _setChannels(_generated());
        settings.lineupVersion = AppSettings.currentLineupVersion;
      }
      // New pool contents may bring clips (or take them away).
      _updateCatalog();
      lastRefresh = (
        shows: fresh.series.where((s) => !showsBefore.contains(s.key)).length,
        episodes: fresh.episodes.where((e) => previous[e.id] == null).length,
        movies: fresh.movies.where((m) => previous[m.id] == null).length,
        songs: [...fresh.songs, ...fresh.musicVideos].where((m) => previous[m.id] == null).length,
        channels: _channels.where((ch) => !channelsBefore.contains(ch.id)).length,
      );
      await storage.writeJson(_libraryFile, library.toJson());
      await _saveChannels();
      await _saveBlocks();
      // Groups and the last channel follow merged channels.
      await _saveSettings();
      _setPhase(AppPhase.ready);
      _startAnalysis();
      _startLiveRefresh();
      _analyzer?.poke();
    } on ServerException catch (e) {
      syncError = e.message;
      if (e.statusCode == 401 && !servers.multiple) {
        // The token was revoked (e.g. device removed in the dashboard).
        await _expireSession();
      } else if (e.unreachable && await reachServerAgain()) {
        // A Plex server at another address: scan there.
        _refreshAgain = true;
        syncError = null;
      } else {
        // First sync: the sync screen shows the error with a retry button.
        // Background refresh: keep showing the cached lineup.
        notifyListeners();
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
    if (_refreshAgain && client != null) {
      _refreshAgain = false;
      await _refreshLibrary(background: true);
    }
  }

  /// A server's last scanned index (multi-server), as merged.
  static String _partFile(String key) => 'library_parts/$key.json';

  /// Scans every server in Play from order and merges them (multi-server
  /// D3). A server that fails keeps its last part; throws only when no
  /// server has anything.
  Future<LibraryIndex> _scanServers() async {
    final list = servers.ordered;
    final parts = <LibraryIndex>[];
    ServerException? failure;
    for (final (i, server) in list.indexed) {
      final where = '${server.name} (${i + 1} of ${list.length})';
      syncStatus = 'Scanning $where…';
      notifyListeners();
      void status(String s) {
        syncStatus = '$where: $s';
        notifyListeners();
      }

      LibraryIndex? part;
      if (server.client != null && server.state != ServerState.needsSignIn) {
        for (var attempt = 0; part == null && attempt < 2; attempt++) {
          try {
            part = await _scanServer(server, status);
          } on ServerException catch (e) {
            failure ??= e;
            debugPrint('Could not scan ${server.name}: ${e.message}');
            if (e.statusCode == 401) {
              await _expireServer(server);
              break;
            }
            // A Plex server at another address: scan there.
            if (e.unreachable && attempt == 0 && await reachServerAgain(key: server.key)) continue;
            if (e.unreachable) _markUnreachable(server);
            break;
          }
        }
      }
      part ??= await _savedPart(server.key);
      if (part != null) parts.add(part);
      if (_closed) break;
    }
    if (parts.isEmpty) throw failure ?? ServerException('None of your servers could be reached.');
    return mergeLibraries(parts, previous: _hasGenerated ? library : null);
  }

  /// [server]'s index under its global ids, saved as its part.
  Future<LibraryIndex> _scanServer(ProfileServer server, void Function(String) onStatus) async {
    final key = server.key;
    bool mine(String id) => ServerSet.keyOf(id) == key;
    final pools = [
      for (final p in settings.commercialPools)
        CommercialPool(id: p.id, name: p.name, kind: p.kind, roots: [
          for (final r in p.roots)
            if (mine(r.itemId))
              PoolRoot(itemId: ServerSet.rawId(r.itemId), libraryId: ServerSet.rawId(r.libraryId), label: r.label)
        ])
    ];
    var part = await fetchLibraryIndex(server.client!,
        pools: pools,
        channelRoots: {for (final r in _channelRoots()) if (mine(r)) ServerSet.rawId(r)},
        providerIds: true,
        onStatus: onStatus,
        onLibraries: (libraries) => _labelLibraryRoots(libraries, key: key));
    if (!server.isMain) part = part.withServerKey((id) => ServerSet.globalId(key, id));
    if (server.state != ServerState.ok) {
      server.state = ServerState.ok;
      PlaybackDiagnostics.note('SERVER', '${server.key} ok');
      _syncServerPings();
    }
    await storage.writeJson(_partFile(key), part.toJson());
    return part;
  }

  Future<LibraryIndex?> _savedPart(String key) async {
    final json = await storage.readJson(_partFile(key));
    try {
      // Saved before show identity (lineup-dedup): its shows merged again.
      return json is Map<String, Object?> ? LibraryIndex.fromJson(json).rekeyed() : null;
    } on Object catch (e) {
      debugPrint('Unreadable library part $key: $e');
      return null;
    }
  }

  /// Names whole-library pool folders after their library (upgrades from
  /// before pools don't know the names, and libraries can be renamed).
  /// [key]: the server the libraries are on (multi-server).
  void _labelLibraryRoots(List<ServerLibrary> libraries, {String key = ServerSet.mainKey}) {
    final names = {for (final l in libraries) ServerSet.globalId(key, l.id): l.name};
    var changed = false;
    for (final pool in settings.commercialPools) {
      final roots = [...pool.roots];
      for (final (i, r) in roots.indexed) {
        final name = names[r.itemId];
        if (r.isWholeLibrary && name != null && name != r.label) {
          roots[i] = r.withLabel(name);
          changed = true;
        }
      }
      pool.roots = roots;
    }
    if (changed) unawaited(_saveSettings());
  }

  /// The roots of every channel's and block's source.
  Set<String> _channelRoots() => {
        for (final c in _channels)
          if (!c.isLive) for (final r in c.source.roots) r.itemId,
        for (final b in _blocks)
          for (final r in b.source.roots) r.itemId,
      };

  Set<String> _unresolvedRoots([Iterable<PoolRoot>? roots]) => {
        for (final r in roots?.map((r) => r.itemId) ?? _channelRoots())
          // A root that was missing may be back, or filled since.
          if (!library.roots.contains(r) || library.missingRoots.contains(r)) r,
      };

  /// Whether [root] was looked for on the server and isn't there (or holds
  /// nothing to play): the source editors mark it "Not found on the server".
  bool rootMissing(PoolRoot root) => library.missingRoots.contains(root.itemId);

  /// Fetches [roots] (every source root the library hasn't resolved, when
  /// null) on their own, without a full scan, and merges what's under them
  /// into the library and the channels using them (custom-channels D3).
  Future<void> resolveRoots([Iterable<PoolRoot>? roots]) async {
    final wanted = _unresolvedRoots(roots);
    if (client == null || wanted.isEmpty) return;
    // Each server's roots through its own client (multi-server D3).
    final byKey = <String, Set<String>>{};
    for (final r in wanted) {
      byKey.putIfAbsent(ServerSet.keyOf(r), () => {}).add(ServerSet.rawId(r));
    }
    final found = <String, Set<String>>{};
    final missing = <String>{};
    for (final MapEntry(:key, value: raw) in byKey.entries) {
      final server = servers.byKey(key);
      final c = server?.client;
      String global(String id) => ServerSet.globalId(key, id);
      if (server == null) {
        // The server was removed: its roots hold nothing now.
        for (final r in raw) {
          found[global(r)] = {};
          missing.add(global(r));
        }
        continue;
      }
      if (c == null || !server.usable) continue;
      try {
        final result = await fetchRoots(c, raw);
        result.found.forEach((root, ids) => found[global(root)] = {for (final id in ids) global(id)});
        missing.addAll(result.missing.map(global));
      } on ServerException catch (e) {
        debugPrint('Could not fetch channel sources from ${server.name}: ${e.message}');
      }
    }
    if (_closed || found.isEmpty) return;
    final result = (found: found, missing: missing);
    final previous = library;
    final plansBefore = _plans();
    library = library.withRoots(result.found, missing: result.missing);
    _mergeLibraryIntoChannels(previous, plansBefore);
    await storage.writeJson(_libraryFile, library.toJson());
    await _saveChannels();
    await _saveBlocks();
    await _saveSettings();
  }

  void _mergeLibraryIntoChannels(LibraryIndex previous, Map<String, BreakPlan> plansBefore) {
    final now = DateTime.now();
    // Saved show keys follow the shows the scan merged; a show's second
    // channel merges into its first (lineup-dedup D3, D6).
    final renamed = _remapShowKeys(previous);
    // Channels the bigger library now qualifies for, after the generated
    // ones (skipping numbers live channels hold).
    final existingIds = {for (final c in _channels) c.id};
    // Show channels up to the generator's limit: a kept channel a growing
    // show would outrank isn't joined by one more (D5).
    const options = GeneratorOptions();
    var showRoom = options.maxShowChannels -
        _channels.where((c) => c.id.startsWith(_showPrefix) && !_showTooSmall(c)).length;
    final added = [
      for (final c in ChannelGenerator(library, options: options).generate())
        if (!existingIds.contains(c.id) && (!c.id.startsWith(_showPrefix) || showRoom-- > 0)) c..number = 1 << 30,
    ];
    // Each show and movie airs on one genre channel; a genre channel left
    // under its minimums is thin: retired, or not added.
    final thin = ChannelGenerator.spreadTitles(library, [..._channels, ...added]);
    final retired = <Channel>[];
    for (final ch in _channels) {
      if (ch.isLive) continue;
      if (ch.blockOnly) {
        _schedules.remove(ch.id);
        continue;
      }
      final fresh = buildPlaylist(library, ch.source, ch.order, seed: ch.seed);
      if (_retires(ch, fresh, thin)) {
        retired.add(ch);
        continue;
      }
      // What's new airs from the next program on.
      final onAir = ChannelSchedule.build(
              ch, previous, const [], _breakContext(plansBefore[ch.id] ?? planFor(ch), ch.effectiveSlotRule))
          ?.programAt(now)
          .item
          ?.id;
      // A channel follows its source: what left it (a collection's removed
      // episode, a show moved to another genre channel) goes too.
      var merged = _mergedPlaylist(ch.playlist, fresh,
          onlyFresh: !ch.isMusic, previous: previous, after: onAir == null ? null : _currentId(onAir, previous));
      if (ch.isMusic && merged.length > maxMusicPlaylist) {
        // Keep the channel's fixed sample, in the order it airs.
        final sample = fresh.toSet();
        merged = [for (final id in merged) if (sample.contains(id)) id];
      }
      _rebase(ch, merged, now, previous: previous, planBefore: plansBefore[ch.id]);
    }
    // What the generator no longer makes goes, its schedule and premiere
    // home with it (D5).
    for (final ch in retired) {
      _channels.remove(ch);
      PlaybackDiagnostics.note('LINEUP', 'retired ${ch.number} ${ch.name} (${ch.id})');
    }
    for (final b in _blocks) {
      b.playlist = _mergedPlaylist(b.playlist, blockPlaylist(b),
          onlyFresh: !b.hasLineup && (b.source.roots.isNotEmpty || b.source.ratingFloor != null), previous: previous);
    }
    _schedules.clear();
    for (final c in added) {
      if (thin.contains(c.id)) continue;
      c.playlist = buildPlaylist(library, c.source, c.order, seed: c.seed);
      if (c.playlist.isEmpty) continue;
      c.number = ChannelNumbers.nextGenerated(_channels);
      _channels.add(c);
    }
    ChannelGenerator.nameApart(library, [for (final c in _channels) if (c.auto && !c.isLive) c],
        keep: existingIds.difference(renamed));
    _setChannels(_channels);
  }

  /// Whether a refresh retires generated [ch] (lineup-dedup D5): it plays
  /// nothing ([fresh] is empty), it is a [thin] genre channel, or its show
  /// is gone or has too few episodes for a channel of its own. Hidden
  /// channels too; a channel carrying the user's blocks stays, and nothing
  /// goes when the scan found nothing at all.
  bool _retires(Channel ch, List<String> fresh, Set<String> thin) {
    if (!ch.auto || ch.isLive || ch.blockOnly || library.isEmpty) return false;
    if (_blocks.any((b) => b.channelId == ch.id)) return false;
    return fresh.isEmpty || thin.contains(ch.id) || (ch.id.startsWith(_showPrefix) && _showTooSmall(ch));
  }

  /// Whether show channel [ch]'s show is gone, unnamed, or has too few
  /// episodes for a channel of its own.
  bool _showTooSmall(Channel ch) {
    final key = ch.source.seriesKeys.firstOrNull;
    final show = library.seriesByKey[key];
    return show == null ||
        show.isUnknown ||
        (library.episodesBySeries[key]?.length ?? 0) < const GeneratorOptions().minEpisodesForShowChannel;
  }

  static const _showPrefix = 'auto:show:';

  /// Channels retired into another, by id: where the remote's last channel
  /// goes now (lineup-dedup D6).
  final _movedChannels = <String, String>{};

  /// The id channel [id] has now: its own, or the channel it was merged
  /// into.
  String currentChannelId(String id) {
    var current = id;
    for (var i = 0; i < 8 && _movedChannels.containsKey(current); i++) {
      current = _movedChannels[current]!;
    }
    return current;
  }

  /// Rewrites saved show keys for [library] (lineup-dedup D3): sources,
  /// block lineups and show channels' ids. A show channel whose id another
  /// channel already has retires into it (D6). Show channels with the name
  /// the generator gave them take their show's name now; returns their ids.
  Set<String> _remapShowKeys(LibraryIndex previous) {
    bool isShow(Channel c) => c.auto && !c.isLive && c.id.startsWith(_showPrefix);
    // Each show channel's show name before the scan; a channel named that,
    // or the generator's "Name (kind)" for it, has the generator's name.
    final showName = {
      for (final c in _channels)
        if (isShow(c)) c.id: previous.seriesByKey[c.source.seriesKeys.firstOrNull]?.name,
    };
    bool generated(Channel c) => switch (showName[c.id]) {
          final name? => c.name == name || c.name.startsWith('$name ('),
          null => false,
        };
    final generatedName = {for (final c in _channels) if (isShow(c)) c.id: generated(c)};
    final renames = ShowKeyRemap(library, previous: previous).apply(_channels, _blocks);
    for (final MapEntry(key: from, value: to) in renames.entries) {
      final a = channelById(from);
      if (a == null) continue;
      final b = channelById(to);
      final aGenerated = generatedName.remove(from) ?? true;
      if (b == null) {
        _channels[_channels.indexOf(a)] = a.withId(to);
        _channelMoved(from, to);
        generatedName[to] = aGenerated;
        showName[to] = showName.remove(from);
        continue;
      }
      final bGenerated = generatedName[to] ?? true;
      _retireInto(a, b, nameEdited: !aGenerated && bGenerated);
      generatedName[to] = aGenerated && bGenerated;
    }
    final renamed = <String>{};
    for (final c in _channels.where(isShow)) {
      final show = library.seriesByKey[c.source.seriesKeys.firstOrNull];
      // "Name (kind)" stays: the generator named it apart from another.
      if (show == null || !(generatedName[c.id] ?? false) || c.name != showName[c.id] || c.name == show.name) continue;
      c.name = show.name;
      renamed.add(c.id);
    }
    return renamed;
  }

  /// Retires show channel [a] into [b], the other channel of its show
  /// (lineup-dedup D6): [b] takes [a]'s favorite and groups, stays hidden
  /// only if both were, takes [a]'s name ([nameEdited]), icon, logo, retro
  /// look and break plan where the user changed [a]'s and not [b]'s, and
  /// the lower number. Its playlist and schedule are [b]'s, rebased by the
  /// refresh.
  void _retireInto(Channel a, Channel b, {required bool nameEdited}) {
    bool iconEdited(Channel c) =>
        c.icon.kind != ChannelIconKind.jellyfin &&
        !(c.icon.kind == ChannelIconKind.builtin && c.icon.value == 'live_tv');
    b.favorite = a.favorite || b.favorite;
    b.hidden = a.hidden && b.hidden;
    if (nameEdited) b.name = a.name;
    if (iconEdited(a) && !iconEdited(b)) b.icon = a.icon;
    b.logoMode ??= a.logoMode;
    if (b.retro.followsMain) b.retro = a.retro;
    b.commercialPlan ??= a.commercialPlan;
    b.number = min(a.number, b.number);
    _channels.remove(a);
    _schedules.remove(a.id);
    _channelMoved(a.id, b.id);
    PlaybackDiagnostics.note('LINEUP', 'merged ${a.name} (${a.id}) into ${b.number} ${b.name} (${b.id})');
  }

  /// Points what refers to channel [from] at [to]: groups, the last
  /// channel, blocks and the remote's last channel.
  void _channelMoved(String from, String to) {
    for (final g in settings.groups) {
      final ids = g.channelIds;
      if (!ids.contains(from)) continue;
      g.channelIds = ids.contains(to) ? [for (final id in ids) if (id != from) id] : [for (final id in ids) id == from ? to : id];
    }
    if (settings.lastChannelId == from) settings.lastChannelId = to;
    for (final b in _blocks) {
      if (b.channelId == from) b.channelId = to;
    }
    _movedChannels[from] = to;
  }

  /// Keeps [playlist]'s order, dropping items gone from the library (with
  /// [onlyFresh], also those no longer in [fresh]) and adding the new ones
  /// from [fresh]: spread out from just [after] (the program on air), so
  /// they start airing now, or at the end without it.
  List<String> _mergedPlaylist(List<String> playlist, List<String> fresh,
      {bool onlyFresh = false, LibraryIndex? previous, String? after}) {
    // An item whose copy is now another's alternate (multi-server: a mirror
    // removed, or a server added) keeps its place under the entry's id.
    final listed = playlist.toSet(), moved = <String>{};
    final current = [
      for (final id in playlist)
        if (_currentId(id, previous) case final p when p == id || (!listed.contains(p) && moved.add(p))) p,
    ];
    final known = current.toSet();
    final wanted = onlyFresh ? fresh.toSet() : null;
    final kept = [
      for (final id in current)
        if (library[id] != null && (wanted?.contains(id) ?? true)) id,
    ];
    final added = [
      for (final id in fresh)
        if (!known.contains(id)) id,
    ];
    final at = after == null ? -1 : kept.indexOf(after);
    if (added.isEmpty || at < 0) return [...kept, ...added];
    return spliceNew(kept, added, at + 1);
  }

  /// The id the library holds [id]'s title under now (multi-server): its own,
  /// or the entry holding one of its copies (from [previous], the index it
  /// was in) when a server joined or left.
  String _currentId(String id, LibraryIndex? previous) {
    if (library[id] != null) return id;
    final primary = library.primaryIdOf(id);
    if (library[primary] != null) return primary;
    for (final c in previous?[id]?.copies ?? const <MediaCopy>[]) {
      final other = library.primaryIdOf(c.id);
      if (library[other] != null) return other;
    }
    return id;
  }

  /// Replaces [ch]'s playlist while keeping the current program on air at
  /// the same position, so editing a channel never makes it "jump".
  ///
  /// [previous] is the library [ch]'s current schedule was built against,
  /// when the library itself is being replaced; [planBefore] and
  /// [ruleBefore] are the plan and slot rule it aired with, when that is
  /// what's changing.
  ///
  /// The program on air keeps its position in the show (or, during a
  /// break, its slot keeps its start). Then the anchor moves to the slot
  /// length's or the plan's clock boundary, if there is one, so later slots
  /// line up on the clock; that moves the slot by at most half a boundary.
  ///
  /// Returns whether the program on air is still on the air.
  bool _rebase(Channel ch, List<String> playlist, DateTime now,
      {LibraryIndex? previous, BreakPlan? planBefore, ({SlotRule? rule})? ruleBefore}) {
    final oldSchedule = ChannelSchedule.build(ch, previous ?? library, const [],
        _breakContext(planBefore ?? planFor(ch), ruleBefore == null ? ch.effectiveSlotRule : ruleBefore.rule));
    ch.playlist = playlist;
    _schedules.remove(ch.id);
    if (oldSchedule == null) return false;
    final slot = oldSchedule.programAt(now);
    final item = slot.item;
    if (item == null) return false;
    final playing = oldSchedule.playbackAt(now);
    // In a show part: keep the position in the show. In a break: keep the
    // slot's start.
    final position = playing.isBreak ? null : playing.positionAt(now);

    final plan = planFor(ch);
    final rule = ch.effectiveSlotRule;
    final fresh = ChannelSchedule.build(ch, library, const [], _breakContext(plan, rule));
    final loop = fresh?.loop;
    final index = loop?.indexOf(item.id) ?? loop?.indexOf(_currentId(item.id, previous));
    if (fresh == null || loop == null || index == null) return false;
    var layoutStart = slot.layoutStart;
    if (position != null) {
      // The layout's break points depend on its start, which is what's
      // being worked out: settle it in a few rounds.
      layoutStart = now.subtract(position);
      for (var round = 0; round < 3; round++) {
        final next = now.subtract(fresh.slotOffsetOf(item, position, layoutStart));
        if (next == layoutStart) break;
        layoutStart = next;
      }
    }
    final offset = loop.offsetOf(index);
    var anchor = layoutStart.subtract(offset);
    ch.slotCarry = null;
    final carried = rule == null ? null : _carryOver(fresh, ch, item, index, layoutStart, now, rule);
    if (carried != null) {
      ch.slotCarry = carried;
      // The loop goes on from the next program, on the clock.
      final after = (index + 1) % ch.playlist.where((id) => library[id] != null).length;
      ch.anchor = carried.end.subtract(loop.offsetOf(after));
      if (after == 0) ch.anchor = carried.end;
      _schedules.remove(ch.id);
      return true;
    }
    final grid = rule?.length ?? plan.alignment;
    if (grid != null) {
      // The nearest boundary, unless that would take the program off the
      // air; then the other one.
      final slot = fresh.slotPlanFor(item, ruled: true).slotLength;
      bool keepsOnAir(DateTime a) {
        final into = now.difference(a.add(offset));
        return !into.isNegative && into < slot;
      }

      final (nearest, other) = _boundaries(anchor, grid);
      anchor = keepsOnAir(nearest) || !keepsOnAir(other) ? nearest : other;
    }
    ch.anchor = anchor;
    return true;
  }

  /// When [item]'s slot from [layoutStart] isn't on [rule]'s clock: its own
  /// slot, so it keeps its position, up to a boundary. That's the first one
  /// its program and breaks fit before; Truncate cuts at the first after
  /// [now].
  static SlotCarry? _carryOver(ChannelSchedule schedule, Channel ch, MediaEntry item, int index, DateTime layoutStart,
      DateTime now, SlotRule rule) {
    final (a, b) = _boundaries(layoutStart, rule.length);
    if (layoutStart == a || layoutStart == b) return null;
    DateTime nextAfter(DateTime t) {
      final (x, y) = _boundaries(t, rule.length);
      final later = x.isAfter(y) ? x : y;
      return x.isAfter(t) && x.isBefore(later) ? x : later;
    }

    final plain = schedule.slotPlanFor(item);
    final filled = layoutStart.add(plain.slotLength - plain.tail);
    var end = filled;
    final (x, y) = _boundaries(filled, rule.length);
    if (filled != x && filled != y) end = nextAfter(filled);
    if (rule.tail == TailMode.truncate) {
      final cut = nextAfter(now);
      if (cut.isBefore(end)) end = cut;
    }
    return SlotCarry(itemId: item.id, start: layoutStart, end: end);
  }

  /// The multiples of [grid] (15, 30, 60, 90 or 120 minutes from local
  /// midnight) on either side of [t], nearest first.
  static (DateTime, DateTime) _boundaries(DateTime t, Duration grid) {
    final minutes = grid.inMinutes;
    final minute = (t.hour * 60 + t.minute) ~/ minutes * minutes;
    final floor = DateTime(t.year, t.month, t.day, minute ~/ 60, minute % 60);
    final ceil = floor.add(grid);
    return t.difference(floor) <= ceil.difference(t) ? (floor, ceil) : (ceil, floor);
  }

  // ---- Channel editing ----------------------------------------------------

  Future<void> updateChannel(Channel ch,
      {String? name,
      ChannelIcon? icon,
      bool? hidden,
      bool? favorite,
      int? number,
      PlaybackOrder? order}) async {
    if (name != null && name.trim().isNotEmpty) ch.name = name.trim();
    if (icon != null) ch.icon = icon;
    if (hidden != null) ch.hidden = hidden;
    if (favorite != null) ch.favorite = favorite;
    if (number != null) _renumber(ch, number);
    if (order != null && order != ch.order && !ch.blockOnly) {
      ch.order = order;
      _rebase(ch, buildPlaylist(library, ch.source, order, seed: ch.seed), DateTime.now());
    }
    _setChannels(_channels);
    await _saveChannels();
  }

  // ---- Custom channels (custom-channels) -------------------------------------

  /// The name a new custom channel gets when none is given.
  static const customChannelName = 'My Channel';

  /// A channel of [source] (collections, folders, shows, seasons, genres
  /// and movies) in [order], with the next free number, on the air at once.
  /// Throws [StateError] when nothing is picked or nothing matches.
  Future<Channel> createCustomChannel(String name, ChannelSource source,
      {PlaybackOrder order = PlaybackOrder.random}) async {
    if (source.isMusic || !source.hasPicks) throw StateError('Choose something for the channel to play.');
    await resolveRoots(source.roots);
    final now = DateTime.now();
    final id = 'user:${now.microsecondsSinceEpoch.toRadixString(36)}';
    final playlist = buildPlaylist(library, source, order, seed: stableHash(id));
    if (playlist.isEmpty) throw StateError('Nothing in the library matches that.');
    final ch = Channel(
      id: id,
      number: ChannelNumbers.nextGenerated(_channels),
      name: name.trim().isEmpty ? customChannelName : name.trim(),
      icon: const ChannelIcon.builtin('live_tv'),
      source: source,
      order: order,
      playlist: playlist,
      // Like a generated lineup, it "started" at midnight: tuning in joins
      // a program under way.
      anchor: DateTime(now.year, now.month, now.day),
      auto: false,
    );
    _setChannels([..._channels, ch]);
    await _saveChannels();
    return ch;
  }

  /// Changes what custom channel [ch] plays. The program on the air stays
  /// on at the same point when it's still in [source]; otherwise the new
  /// playlist starts now.
  Future<void> setChannelSource(Channel ch, ChannelSource source, {DateTime? now}) async {
    if (!ch.isCustom) throw StateError('Only channels you added can change what they play.');
    if (source.isMusic || !source.hasPicks) throw StateError('Choose something for the channel to play.');
    await resolveRoots(source.roots);
    final playlist = buildPlaylist(library, source, ch.order, seed: ch.seed);
    if (playlist.isEmpty) throw StateError('Nothing in the library matches that.');
    final at = now ?? DateTime.now();
    ch.source = source;
    if (!_rebase(ch, playlist, at)) ch.anchor = at;
    _setChannels(_channels);
    await _saveChannels();
  }

  /// Whether [ch] can be reshuffled: a shuffled or least watched first
  /// channel that plays programs.
  bool canReshuffle(Channel ch) =>
      ch.playsPrograms && (ch.order == PlaybackOrder.random || ch.order == PlaybackOrder.weighted);

  /// Rebuilds [ch]'s order with a new seed (and, for Least watched first,
  /// today's play counts), keeping the program on the air.
  Future<void> reshuffleChannel(Channel ch, {DateTime? now}) async {
    if (!canReshuffle(ch)) throw StateError('Only shuffled channels can be reshuffled.');
    ch.generation++;
    _rebase(ch, buildPlaylist(library, ch.source, ch.order, seed: ch.seed), now ?? DateTime.now());
    _setChannels(_channels);
    await _saveChannels();
  }

  /// Sets [ch]'s slot length and tail mode (null: off), keeping the program
  /// on the air in place as a break plan change does.
  Future<void> setSlotRule(Channel ch, SlotRule? rule, {DateTime? now}) async {
    if (!ch.playsPrograms) throw StateError("This channel doesn't have slots.");
    if (rule == ch.slotRule) return;
    final before = ch.slotRule;
    ch.slotRule = rule;
    _rebase(ch, ch.playlist, now ?? DateTime.now(), ruleBefore: (rule: before));
    _setChannels(_channels);
    await _saveChannels();
    // An offline image no channel uses any more goes.
    final old = before?.offlineImage;
    if (old != null && !_channels.any((c) => c.slotRule?.offlineImage == old)) await icons.delete(old);
  }

  /// Moves [ch] to [number]; a channel already there swaps into [ch]'s slot.
  void _renumber(Channel ch, int number) {
    if (number < 1 || number == ch.number) return;
    for (final other in _channels) {
      if (other != ch && other.number == number) other.number = ch.number;
    }
    ch.number = number;
  }

  /// Discards all channel edits and regenerates the default lineup.
  /// Channels the user added (custom, block and music channels) are kept
  /// with their settings, moved after the generated ones.
  ///
  /// A safety backup is saved first; if it can't be, nothing is reset and
  /// the error is thrown.
  Future<void> resetChannels() async {
    await safetyBackup?.call('before-reset');
    _schedules.clear();
    final fresh = _generated();
    for (final c in _channels.where((c) => !c.auto && !c.isLive)) {
      c.number = ChannelNumbers.nextGenerated([...fresh, ..._channels.where((c) => c.isLive)]);
      fresh.add(c);
    }
    _setChannels(fresh);
    await _saveChannels();
    if (settings.lineupVersion != AppSettings.currentLineupVersion) {
      settings.lineupVersion = AppSettings.currentLineupVersion;
      await _saveSettings();
    }
  }

  // ---- Channel logo (channel-logo) -------------------------------------------

  /// Sets the main logo setting, for every channel that follows it. The TV
  /// and Live TV export use it at once.
  Future<void> setMainLogoMode(LogoMode mode) async {
    if (mode == settings.logoMode) return;
    settings.logoMode = mode;
    notifyListeners();
    await _saveSettings();
  }

  /// Gives [ch] its own logo setting; null follows the main one again.
  Future<void> setChannelLogoMode(Channel ch, LogoMode? mode) async {
    if (mode == ch.logoMode) return;
    ch.logoMode = mode;
    notifyListeners();
    await _saveChannels();
  }

  // ---- Retro look (retro-presentation) -----------------------------------------

  /// Sets the main retro look and Custom style. Every channel on them shows
  /// it at once.
  Future<void> setMainRetro(RetroSettings retro) async {
    settings.retro = retro;
    notifyListeners();
    await _saveSettings();
  }

  /// Gives [ch] its own retro look; what's null follows the main setting.
  Future<void> setChannelRetro(Channel ch, ChannelRetro retro) async {
    if (retro == ch.retro) return;
    ch.retro = retro;
    notifyListeners();
    await _saveChannels();
  }

  Future<void> setLastChannel(Channel ch) async {
    if (settings.lastChannelId == ch.id) return;
    settings.lastChannelId = ch.id;
    await _saveSettings();
  }

  // ---- Playback ----------------------------------------------------------

  /// Changes the Playback settings. What's playing plays on; the tuner
  /// uses the new setting from the next segment it opens. The analyzer's
  /// budget follows right away. This session's decisions are cleared.
  /// Volume leveling goes to the tuner at once: mpv levels what's playing;
  /// on Android, where the device profile changes with it, the tuner
  /// re-tunes.
  Future<void> setPlayback(PlaybackSettings playback) async {
    if (playback == settings.playback) return;
    if (!playback.decidesLike(settings.playback)) _decisions.clear();
    settings.playback = playback;
    volumeLeveling.value = playback.volumeLeveling;
    _pushBudget();
    notifyListeners();
    await _saveSettings();
  }

  // ---- Commercials -------------------------------------------------------

  /// Sets the main break plan, for every channel that follows it, keeping
  /// what's on air in place.
  ///
  /// [now] is the moment to keep in place (tests pass other times).
  Future<void> setGlobalPlan(BreakPlan plan, {DateTime? now}) async {
    if (plan == settings.commercialPlan) return;
    final before = _plans();
    settings.commercialPlan = plan;
    _rebaseForPlans(before, now ?? DateTime.now());
    _analyzer?.poke();
    await _saveSettings();
    await _saveChannels();
  }

  /// Gives [ch] its own plan; null follows the main one again.
  Future<void> setChannelPlan(Channel ch, BreakPlan? plan, {DateTime? now}) async {
    final before = {ch.id: planFor(ch)};
    ch.commercialPlan = plan;
    _rebaseForPlans(before, now ?? DateTime.now());
    _analyzer?.poke();
    await _saveChannels();
  }

  /// Rebases each channel whose plan (as aired) differs from [before].
  void _rebaseForPlans(Map<String, BreakPlan> before, DateTime now) {
    for (final ch in _channels) {
      final was = before[ch.id];
      if (was == null) continue;
      if (was != planFor(ch) && !ch.blockOnly) _rebase(ch, ch.playlist, now, planBefore: was);
      _schedules.remove(ch.id);
    }
    notifyListeners();
  }

  /// Rebuilds the clips from the library and analysis. When that changes
  /// whether a channel's pools have clips, the channel is rebased; and
  /// schedules are rebuilt, so later breaks use the new clips (breaks
  /// already under way keep theirs).
  void _updateCatalog({bool rebase = true}) {
    final before = _plans();
    final version = catalog.version;
    _rebuildCatalog();
    if (catalog.version == version) return;
    if (rebase) {
      _rebaseForPlans(before, DateTime.now());
      // The rebased anchors and the results behind them are saved together,
      // so a restart right now sees the same lineup.
      unawaited(_saveChannels());
      unawaited(_analysis?.flush());
    }
    _schedules.clear();
    notifyListeners();
  }

  Future<void> _openAnalysis(String serverId) async {
    if (_analysis != null) return;
    final cache = await AnalysisCache.acquire(storage.analysisDir, serverId);
    if (_closed || _analysis != null) {
      await AnalysisCache.release(cache);
      return;
    }
    _analysis = cache..addListener(_onAnalysis);
  }

  /// New analysis results: new clips, and break points for later slots.
  void _onAnalysis() {
    final version = catalog.version;
    _updateCatalog();
    if (catalog.version == version) {
      // Only break points changed; slots under way keep theirs.
      _schedules.clear();
      notifyListeners();
    }
  }

  void _startAnalysis() {
    final cache = _store;
    final c = client;
    if (!runAnalysis || !_analysisAllowedNow || _closed || _analyzer != null || cache == null || c == null || phase != AppPhase.ready) {
      return;
    }
    // The analyzer only ever reads the static stream (direct-play spec),
    // each item from its own server (multi-server).
    final proxy = _proxy = LoopbackStreamProxy(
        upstream: (id) => (clientOf(id) ?? client!).streamUri(id),
        headers: () => client!.authHeaders,
        headersFor: (id) => (clientOf(id) ?? client!).authHeaders)
      ..budget = analyzerBudgetNow;
    _analyzer = MediaAnalyzer(
      cache: cache,
      scanner: ffmpeg,
      proxy: proxy,
      segments: (id) async =>
          [for (final s in await (clientOf(id) ?? client!).commercialSegments(id)) Span(s.start, s.end)],
      work: _analysisWork,
      busy: _analysisBusy,
    )..start();
    _analyzer!.state.addListener(_syncAnalysisIdle);
    notifyListeners();
  }

  /// The proxy the analyzer reads through (tests check its upstream).
  @visibleForTesting
  LoopbackStreamProxy? get analyzerProxy => _proxy;

  /// What the analyzer is doing, for playback diagnostics.
  Future<({String job, String budget, int proxyBytes})> analyzerDebugState() async {
    final proxy = _proxy;
    return (
      job: _analyzer == null ? 'not running' : (_analyzer!.progress.value.current ?? 'idle'),
      budget: '${proxy?.budget ?? 'no proxy'}',
      proxyBytes: proxy == null ? 0 : await proxy.bytesServed(),
    );
  }

  Future<void> _stopAnalysis() async {
    final analyzer = _analyzer;
    _analyzer = null;
    _proxy = null;
    analyzer?.state.removeListener(_syncAnalysisIdle);
    await analyzer?.stop();
  }

  ({DateTime at, Set<String> ids})? _soon;

  /// Reels to split, and programs that need break points: every program on
  /// a channel whose plan has mid-rolls, airing in the next 24 hours first.
  AnalysisWork _analysisWork() {
    final pools = {for (final p in settings.commercialPools) p.id};
    final reels = [
      for (final c in library.commercials)
        if (c.runtime > LibraryIndex.maxClip && c.poolIds.any(pools.contains)) c,
    ];
    final counts = <String, Set<int>>{};
    for (final ch in _channels) {
      final plan = configuredPlanFor(ch);
      if (plan.isOff) continue;
      final ids = [
        ...ch.playlist,
        for (final b in _blocks)
          if (b.channelId == ch.id) ...b.playlist,
      ];
      for (final id in ids) {
        final item = library[id];
        // Music never breaks inside an item: nothing to analyze.
        if (item == null || item.kind == MediaKind.commercial || item.isMusic) continue;
        final mids = resolve(plan, item.runtime).midCount;
        if (mids > 0) counts.putIfAbsent(id, () => {}).add(mids);
      }
    }
    final now = DateTime.now();
    var soon = _soon;
    if (soon == null || now.difference(soon.at) > const Duration(minutes: 10)) {
      final ids = <String>{};
      for (final ch in channels) {
        for (final p in scheduleFor(ch)?.programsBetween(now, now.add(const Duration(hours: 24))) ?? const []) {
          if (p.item case final item?) ids.add(item.id);
        }
      }
      _soon = soon = (at: now, ids: ids);
    }
    return AnalysisWork(
      reels: reels,
      programs: [
        for (final e in counts.entries) ProgramNeed(library[e.key]!, e.value, soon: soon.ids.contains(e.key)),
      ],
    );
  }

  bool _closed = false;

  /// Stops background work (analysis) and saves what's pending. The app
  /// can't be used afterwards; a profile switch makes a new one.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    analysisAllowed?.removeListener(_onAnalysisAllowed);
    _staleCheck?.cancel();
    _launchTimer?.cancel();
    _serverPings?.cancel();
    playbackActivity.removeListener(_onLaunchActivity);
    playbackBusy.removeListener(_updateAnalysisBusy);
    exportBusy?.removeListener(_updateAnalysisBusy);
    await _stopAnalysis();
    _syncAnalysisIdle();
    _analysis?.removeListener(_onAnalysis);
    if (_analysis case final cache?) await AnalysisCache.release(cache);
    _serverAnalysis?.detach();
    for (final cache in _addedCaches.values) {
      await AnalysisCache.release(cache);
    }
    _addedCaches.clear();
    _liveRefresher.stop();
    live.removeListener(_onLiveChanged);
    live.dispose();
    for (final server in servers.all) {
      server.client?.close();
    }
  }

  // ---- Commercial pools ----------------------------------------------------

  CommercialPool? poolById(String id) => settings.commercialPools.where((p) => p.id == id).firstOrNull;

  /// Adds an empty pool named "Commercials" (numbered if that's taken).
  Future<CommercialPool> createPool() async {
    final pool = CommercialPool(
      id: 'pool-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: CommercialPool.nextName(settings.commercialPools.map((p) => p.name)),
    );
    settings.commercialPools = [...settings.commercialPools, pool];
    notifyListeners();
    await _saveSettings();
    return pool;
  }

  Future<void> renamePool(CommercialPool pool, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == pool.name) return;
    pool.name = trimmed;
    notifyListeners();
    await _saveSettings();
  }

  /// Removes [pool]. Plans that drew a role from it use all pools instead,
  /// and its videos rejoin the regular channels on the re-scan.
  Future<void> deletePool(CommercialPool pool) async {
    final before = _plans();
    settings.commercialPools = [for (final p in settings.commercialPools) if (p.id != pool.id) p];
    _dropPoolFromPlans(pool);
    // Its clips are gone right away; the re-scan returns its videos to
    // the channels.
    final version = catalog.version;
    _rebuildCatalog();
    if (catalog.version != version) _schedules.clear();
    _rebaseForPlans(before, DateTime.now());
    await _saveSettings();
    await _saveChannels();
    _refreshForPools();
  }

  /// Marks [pool] as commercials or bumpers. Plans that picked it for what
  /// it no longer holds use all pools (or all bumper pools) instead, as do
  /// channels' filler. Its folders are the same, so there's no re-scan.
  Future<void> setPoolKind(CommercialPool pool, PoolKind kind) async {
    if (pool.kind == kind) return;
    final before = _plans();
    pool.kind = kind;
    _dropPoolFromPlans(pool);
    for (final ch in _channels) {
      if (ch.slotRule case final rule? when rule.poolId == pool.id) {
        ch.slotRule = rule.copyWith(poolId: () => null);
      }
    }
    _rebuildCatalog();
    _schedules.clear();
    _rebaseForPlans(before, DateTime.now());
    _analyzer?.poke();
    await _saveSettings();
    await _saveChannels();
  }

  void _dropPoolFromPlans(CommercialPool pool) {
    BreakPlan without(BreakPlan plan) => plan.withRoles(plan.roles.withoutPool(pool.id));
    settings.commercialPlan = without(settings.commercialPlan);
    for (final ch in _channels) {
      if (ch.commercialPlan case final plan?) ch.commercialPlan = without(plan);
    }
  }

  void _rebuildCatalog() => catalog.update(library.commercials, _store, settings.commercialPools.map((p) => p.id),
      bumperPools: [for (final p in settings.commercialPools) if (p.kind == PoolKind.bumpers) p.id]);

  /// Sets the folders [pool] draws from, then re-scans so their videos
  /// leave the regular channels and fill breaks instead.
  Future<void> setPoolRoots(CommercialPool pool, List<PoolRoot> roots) async {
    pool.roots = [...roots];
    notifyListeners();
    await _saveSettings();
    _refreshForPools();
  }

  /// Pool contents changed: re-scan in the background, or right after the
  /// scan already running.
  void _refreshForPools() {
    if (_refreshing) {
      _refreshAgain = true;
    } else {
      unawaited(refreshLibrary(background: true));
    }
  }

  bool _refreshAgain = false;

  /// Removes a custom logo file, switching channels that used it back to a
  /// default icon.
  Future<void> deleteCustomIcon(String name) async {
    var changed = false;
    for (final ch in _channels) {
      if (ch.icon.kind == ChannelIconKind.custom && ch.icon.value == name) {
        ch.icon = const ChannelIcon.builtin('live_tv');
        changed = true;
      }
    }
    // An offline image in use stays.
    if (_channels.any((c) => c.slotRule?.offlineImage == name)) {
      if (changed) await _saveChannels();
      notifyListeners();
      return;
    }
    await icons.delete(name);
    if (changed) await _saveChannels();
    notifyListeners();
  }

  // ---- Programming blocks -------------------------------------------------

  /// A new, unsaved block with sensible defaults: Saturday 7 AM to noon.
  ProgramBlock newBlock() {
    final today = DateTime.now();
    return ProgramBlock(
      id: 'block:${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      title: '',
      channelId: channels.firstOrNull?.id ?? '',
      days: {DateTime.saturday},
      startMinute: 7 * 60,
      endMinute: 12 * 60,
      source: const ChannelSource(includeEpisodes: false),
      order: PlaybackOrder.cyclic,
      playlist: const [],
      anchor: DateTime(today.year, today.month, today.day),
    );
  }

  /// The block [block] would collide with on its channel, if any.
  ProgramBlock? blockConflict(ProgramBlock block) => _blocks
      .where((b) => b.id != block.id && b.enabled && block.enabled)
      .where((b) => blocksOverlap(b, block))
      .firstOrNull;

  /// Why [draft] can't be saved, if it can't: the blocks editor's rules,
  /// for the TV and the web admin. [newChannel]: it gets a new channel on
  /// save; [lineupMode]: it plays a lineup of shows rather than a mix.
  String? blockProblem(ProgramBlock draft, {bool newChannel = false, bool lineupMode = false}) {
    if (draft.title.trim().isEmpty) return 'Give the block a title.';
    if (draft.days.isEmpty) return 'Pick at least one day.';
    if (draft.startMinute == draft.endMinute) return 'The block has to end at a different time than it starts.';
    if (!newChannel && channelById(draft.channelId) == null) return 'Choose a channel.';
    if (lineupMode && !draft.hasLineup) return 'Add a show to the lineup.';
    if (blockPlaylist(draft).isEmpty) {
      if (lineupMode) return "The lineup's shows have no episodes. Pick other shows.";
      final floor = draft.source.ratingFloor;
      // Something matches, just nothing rated high enough (late-night-drift D7).
      if (floor != null &&
          buildPlaylist(library, draft.source.copyWith(ratingFloor: () => null), draft.order, seed: 0).isNotEmpty) {
        return 'Nothing in this mix is rated ${floor.shortLabel} or higher. Choose a lower rating or other shows.';
      }
      return 'Choose some shows or movies for the block to play.';
    }
    if (!newChannel) {
      final clash = blockConflict(draft);
      if (clash != null) return 'This overlaps "${clash.title}" (${describeBlock(clash)}) on the same channel.';
    }
    return null;
  }

  /// Resolves what [block] plays, so editors can show it: its mix, or its
  /// lineup's shows, each show's episodes in airing order.
  List<String> blockPlaylist(ProgramBlock block) => block.hasLineup
      ? [
          for (final key in {for (final s in block.lineup) s.seriesKey})
            for (final e in library.episodesBySeries[key] ?? const <MediaEntry>[]) e.id,
        ]
      : buildPlaylist(library, block.source, block.order, seed: stableHash(block.id));

  /// Whether saving [block] restarts its lineup: new blocks, and blocks
  /// whose content changed.
  bool blockRestarts(ProgramBlock block) {
    final old = _blocks.where((b) => b.id == block.id).firstOrNull;
    return old == null ||
        old.order != block.order ||
        !_sameJson(old.source.toJson(), block.source.toJson()) ||
        !_sameJson([for (final s in old.lineup) s.toJson()], [for (final s in block.lineup) s.toJson()]);
  }

  /// What [block]'s next airing (or the one on now) would play once saved,
  /// on [channelId]'s schedule, or on a new block-only channel when null.
  ({Airing airing, List<ScheduledProgram> programs})? previewBlock(ProgramBlock block, String? channelId) {
    final draft = block.copy()..enabled = true;
    if (blockRestarts(block)) {
      final today = DateTime.now();
      draft.playlist = blockPlaylist(draft);
      draft.anchor = DateTime(today.year, today.month, today.day);
    }
    final channel = (channelId == null ? null : channelById(channelId)) ??
        Channel(
          id: '',
          number: 0,
          name: '',
          icon: const ChannelIcon.builtin('live_tv'),
          source: const ChannelSource(),
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: draft.anchor,
          blockOnly: true,
        );
    draft.channelId = channel.id;
    final schedule = ChannelSchedule.build(channel, library, [draft], _breakContext(planFor(channel)));
    final blocks = schedule?.blocks.where((b) => b.block.id == draft.id);
    if (blocks == null || blocks.isEmpty) return null;
    final now = DateTime.now();
    final airing = blocks.first.airingsBetween(now, now.add(const Duration(days: 400))).firstOrNull;
    if (airing == null) return null;
    return (airing: airing, programs: blocks.first.programsIn(airing));
  }

  /// Adds or replaces [block]. When its content changed, the lineup starts
  /// over from its first program today.
  Future<void> saveBlock(ProgramBlock block) async {
    // New roots are fetched first, so the block fills now.
    await resolveRoots(block.source.roots);
    final existing = _blocks.indexWhere((b) => b.id == block.id);
    if (blockRestarts(block)) {
      final today = DateTime.now();
      block.playlist = blockPlaylist(block);
      block.anchor = DateTime(today.year, today.month, today.day);
    }
    if (existing < 0) {
      _blocks = [..._blocks, block];
    } else {
      _blocks = [..._blocks]..[existing] = block;
    }
    _autoGroups = null;
    _schedules.clear();
    notifyListeners();
    await _saveBlocks();
  }

  Future<void> deleteBlock(ProgramBlock block) async {
    _blocks = _blocks.where((b) => b.id != block.id).toList();
    _autoGroups = null;
    _schedules.clear();
    notifyListeners();
    await _saveBlocks();
  }

  /// A new channel that only airs programming blocks, with the next free
  /// number.
  Future<Channel> createBlockChannel(String name) async {
    final now = DateTime.now();
    final ch = Channel(
      id: 'user:${now.microsecondsSinceEpoch.toRadixString(36)}',
      number: ChannelNumbers.nextGenerated(_channels),
      name: name.trim().isEmpty ? 'Block Channel' : name.trim(),
      icon: const ChannelIcon.builtin('live_tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: const [],
      anchor: DateTime(now.year, now.month, now.day),
      auto: false,
      blockOnly: true,
    );
    _setChannels([..._channels, ch]);
    await _saveChannels();
    return ch;
  }

  /// A music channel of [source]'s songs or music videos, shuffled, with
  /// the next free number. Throws [StateError] when nothing matches.
  Future<Channel> createMusicChannel(String name, ChannelSource source) async {
    if (!source.isMusic) throw StateError('Choose songs or music videos.');
    final now = DateTime.now();
    final id = 'user:${now.microsecondsSinceEpoch.toRadixString(36)}';
    final playlist = buildPlaylist(library, source, PlaybackOrder.random, seed: stableHash(id));
    if (playlist.isEmpty) throw StateError('Nothing in the library matches that.');
    final ch = Channel(
      id: id,
      number: ChannelNumbers.nextGenerated(_channels),
      name: name.trim().isEmpty ? 'Music' : name.trim(),
      icon: ChannelIcon.builtin(source.includeMusicVideos ? 'music_video' : 'music_note'),
      source: source,
      order: PlaybackOrder.random,
      playlist: playlist,
      anchor: now,
      auto: false,
    );
    _setChannels([..._channels, ch]);
    await _saveChannels();
    return ch;
  }

  /// Removes a channel the user added (a custom, block or music channel), with its
  /// blocks and group places. Generated and live channels can only be
  /// hidden.
  Future<void> deleteUserChannel(Channel ch) async {
    if (ch.auto || ch.isLive) throw StateError('Only channels you added can be removed. Hide this one instead.');
    _blocks = _blocks.where((b) => b.channelId != ch.id).toList();
    for (final g in settings.groups) {
      g.channelIds = [for (final id in g.channelIds) if (id != ch.id) id];
    }
    _autoGroups = null;
    _schedules.clear();
    _setChannels([for (final c in _channels) if (c.id != ch.id) c]);
    await _saveChannels();
    await _saveBlocks();
    await _saveSettings();
  }

  static bool _sameJson(Object? a, Object? b) => a.toString() == b.toString();

  // ---- Persistence --------------------------------------------------------

  void _setChannels(List<Channel> list) {
    // Edits to live channels are theirs before they're rebuilt; they're
    // saved with the lineup.
    if (liveEnabled) live.takeEdits(list.where((c) => c.isLive));
    _channels = [
      for (final c in list)
        if (!c.isLive) c,
      if (liveEnabled) ...live.lineupChannels(),
    ]..sort((a, b) => a.number.compareTo(b.number));
    // Which channel is each show's premiere home may have changed.
    _premieresChanged();
    notifyListeners();
  }

  void _setPhase(AppPhase p) {
    phase = p;
    notifyListeners();
  }

  /// Generated channels go to `channels.json` as always; live channels'
  /// settings to their sources (live-tv-sources D1).
  Future<void> _saveChannels() async {
    await storage.writeJson(_channelsFile, [for (final c in _channels) if (!c.isLive) c.toJson()]);
    if (_channels.any((c) => c.isLive)) await live.saveFrom(_channels.where((c) => c.isLive));
  }

  Future<void> _saveBlocks() =>
      storage.writeJson(_blocksFile, [for (final b in _blocks) b.toJson()]);

  Future<void> _saveSettings() => storage.writeJson(_settingsFile, settings.toJson());
}
