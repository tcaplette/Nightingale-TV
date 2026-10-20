import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'channels/channel.dart';
import 'channels/channel_generator.dart';
import 'channels/program_block.dart';
import 'channels/schedule.dart';
import 'commercials/analysis/analysis_cache.dart';
import 'commercials/analysis/detections.dart';
import 'commercials/analysis/ffmpeg_runner.dart';
import 'commercials/analysis/media_analyzer.dart';
import 'commercials/analysis/stream_proxy.dart';
import 'commercials/break_plan.dart';
import 'commercials/break_sources.dart';
import 'commercials/commercial_catalog.dart';
import 'commercials/commercial_pool.dart';
import 'data/app_storage.dart';
import 'icons/custom_icons.dart';
import 'jellyfin/jellyfin_client.dart';
import 'library/library_index.dart';
import 'platform/platform_info.dart';
import 'playback/android_device_profile.dart';
import 'playback/playback_diagnostics.dart';

/// A choice for the maximum streaming bitrate: Original (no [kbps]) or a
/// fixed cap.
typedef BitratePreset = ({String label, int? kbps});

/// A playback decision kept for the session: the conversion's URL template
/// (null: direct play), and whether that conversion keeps the video (a
/// direct stream).
typedef Decision = ({Uri? template, bool directStream});

/// "Transcode only if needed": off unless the user turns it on. Per PC, not
/// per profile, since it's about this machine and its network.
class PlaybackSettings {
  /// A fixed [maxKbps] cap, or Original when it's null.
  const PlaybackSettings({this.transcodeIfNeeded = false, this.maxKbps});

  /// A setting never saved: off, with Original chosen.
  static const off = PlaybackSettings();

  /// Convert a program when it's over the cap or won't direct-play.
  final bool transcodeIfNeeded;

  /// The fixed cap in kbps, kept while the toggle is off; null is Original
  /// (no limit).
  final int? maxKbps;

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

  PlaybackSettings copyWith({bool? transcodeIfNeeded, BitratePreset? bitrate}) => PlaybackSettings(
        transcodeIfNeeded: transcodeIfNeeded ?? this.transcodeIfNeeded,
        maxKbps: bitrate == null ? maxKbps : bitrate.kbps,
      );

  Map<String, Object?> toJson() => {
        'transcodeIfNeeded': transcodeIfNeeded,
        'bitrate': maxKbps ?? 'original',
      };

  /// A missing or unreadable setting is off with Original chosen. A saved
  /// "auto" (removed) is Original, with the toggle as it was; a saved cap
  /// snaps to the preset at or below it (4 Mbps for anything lower). Saved
  /// before Auto (as `maxBitrateMbps`), the same rules apply.
  factory PlaybackSettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return off;
    final on = json['transcodeIfNeeded'] == true;
    final bitrate = json['bitrate'];
    if (bitrate is num) return PlaybackSettings(transcodeIfNeeded: on, maxKbps: capAtOrBelow(bitrate));
    if (!json.containsKey('bitrate')) {
      if (json['maxBitrateMbps'] case final num mbps) {
        return PlaybackSettings(transcodeIfNeeded: on, maxKbps: capAtOrBelow(mbps * 1000));
      }
    }
    return PlaybackSettings(transcodeIfNeeded: on);
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSettings && other.transcodeIfNeeded == transcodeIfNeeded && other.maxKbps == maxKbps;

  @override
  int get hashCode => Object.hash(transcodeIfNeeded, maxKbps);

  @override
  String toString() => 'PlaybackSettings(${transcodeIfNeeded ? 'on' : 'off'}, ${preset.label})';
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
  }) : commercialPools = commercialPools ?? [];

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
    if (j['commercialPlan'] case final Map<String, Object?> plan) {
      return AppSettings(
        installId: installId,
        commercialPlan: BreakPlan.fromJson(plan),
        commercialPools: [
          for (final p in (j['commercialPools'] as List? ?? const []).cast<Map<String, Object?>>())
            CommercialPool.fromJson(p)
        ],
        lastChannelId: lastChannelId,
        playback: playback,
      );
    }
    // Saved before break plans: an on/off switch and whole libraries.
    final libraries = (j['commercialLibraryIds'] as List?)?.cast<String>() ?? const [];
    return AppSettings(
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
    );
  }

  static AppSettings fresh() {
    final rng = Random.secure();
    final id = List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return AppSettings(installId: '$deviceIdPrefix$id');
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
      @visibleForTesting this._sessionClient})
      : icons = CustomIconStore(storage.logosDir) {
    playbackActivity.addListener(_pushBudget);
    playingBitrate.addListener(_pushBudget);
    playbackBusy.addListener(_updateAnalysisBusy);
    exportBusy?.addListener(_updateAnalysisBusy);
    _syncStaleCheck();
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

  /// Builds the client for a saved sign-in at [start] (tests give a fake).
  final JellyfinClient Function(JellyfinSession session)? _sessionClient;

  /// True while Live TV export is streaming anything; analysis holds off
  /// meanwhile, as it does while the TV tunes.
  final ValueListenable<bool>? exportBusy;

  /// Kept loaded for Live TV export while another profile is on screen: no
  /// analysis, and the library is refreshed on a timer, since nobody opens
  /// this profile to trigger it.
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

  /// Re-scan the library in the background when the cache is older than this.
  static const libraryMaxAge = Duration(hours: 6);

  final AppStorage storage;
  final CustomIconStore icons;

  AppPhase phase = AppPhase.starting;
  String syncStatus = '';
  String? syncError;
  late AppSettings settings;
  JellyfinSession? session;
  JellyfinClient? client;
  LibraryIndex library = LibraryIndex.empty;
  List<Channel> _channels = [];
  List<ProgramBlock> _blocks = [];
  final Map<String, ChannelSchedule?> _schedules = {};

  String get deviceName => PlatformInfo.deviceName;

  /// All channels sorted by number, including hidden ones.
  List<Channel> get allChannels => _channels;

  /// What the guide and channel up/down use.
  List<Channel> get channels => _channels.where((c) => !c.hidden).toList();

  /// Programming blocks, in the order they were created.
  List<ProgramBlock> get blocks => _blocks;

  ChannelSchedule? scheduleFor(Channel c) =>
      _schedules.putIfAbsent(c.id, () => ChannelSchedule.build(c, library, _blocks, _breakContext(planFor(c))));

  // ---- Commercial breaks ---------------------------------------------------

  /// The clips the pools hold right now (and recently).
  final catalog = CommercialCatalog();

  AnalysisCache? _analysis;
  MediaAnalyzer? _analyzer;

  /// Analysis results for this server, once its id is known.
  AnalysisCache? get analysisCache => _analysis;

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
      await _stopAnalysis();
    } else {
      _startAnalysis();
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

  /// The playing file's average bitrate in bits per second, once the tuner
  /// knows it (null while it doesn't): with no cap, it sets the analyzer's
  /// budget.
  final playingBitrate = ValueNotifier<int?>(null);

  /// The analyzer's download budget right now.
  Budget get analyzerBudgetNow =>
      analyzerBudget(playbackActivity.value, settings.playback, fileBitsPerSecond: playingBitrate.value);

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
  /// prefetch and the launch's early request share one.
  final _deciding = <(String, int?), Future<Decision>>{};

  /// Whether a decision for [source] under [capKbps] is being asked.
  bool deciding(String source, int? capKbps) => _deciding.containsKey((source, capKbps));

  /// The decision for [source] under [capKbps] (null: no cap; `template`
  /// null for direct play): this session's, the request already in flight,
  /// or a new request, kept once Jellyfin answers. Jellyfin decides.
  Future<Decision> decide(String source, int? capKbps, {Duration startAt = Duration.zero}) {
    final saved = savedDecision(source, capKbps);
    if (saved != null) return Future.value(saved);
    final key = (source, capKbps);
    if (_deciding[key] case final inFlight?) return inFlight;
    final c = client;
    if (c == null) return Future.error(StateError('Not signed in.'));
    final playback = settings.playback;
    final request = () async {
      try {
        final maxBitrate = capKbps == null ? null : capKbps * 1000;
        // Only Android waits for its profile: elsewhere the request goes at
        // once, as it always has.
        final profile = PlatformInfo.isAndroid ? await deviceProfile(capKbps) : null;
        final decision = await c.playbackInfo(source, maxBitrate: maxBitrate, startAt: startAt, profile: profile);
        var template = decision.transcodeTemplate;
        // On Android a re-encode with no cap asks for what keeps the original
        // picture, not Jellyfin's ceiling.
        if (PlatformInfo.isAndroid && capKbps == null && template != null && !decision.directStream) {
          template = limitConversion(template, sourceBitrate: decision.sourceBitrate, sourceCodec: decision.sourceCodec);
        }
        final kept = (template: template, directStream: decision.directStream);
        // A setting changed meanwhile cleared the decisions; this one
        // was asked under the old one.
        if (settings.playback == playback) _decisions[key] = kept;
        return kept;
      } finally {
        _deciding.remove(key);
      }
    }();
    _deciding[key] = request;
    return request;
  }

  /// At launch, asks the decision for what's on the channel the TV will
  /// tune: the tune then awaits this request instead of starting its own
  /// after the TV screen shows. With a cap in effect for a program part, or
  /// on Android for any segment.
  void _askLaunchDecision() {
    final cap = capInEffect;
    final android = decidesEverySegment;
    final visible = channels;
    if ((cap == null && !android) || visible.isEmpty) return;
    // As the TV screen picks it.
    final ch = visible.where((c) => c.id == settings.lastChannelId).firstOrNull ?? visible.first;
    final now = DateTime.now();
    final on = scheduleFor(ch)?.playbackAt(now);
    final item = on?.item;
    if (on == null || item == null) return;
    final program = !on.isBreak && !on.isCommercial;
    if (!program && !android) return;
    // The cap is only ever for program parts.
    final segmentCap = program ? cap : null;
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
  /// from what the device decodes (asked once); elsewhere null, for the
  /// Linux profile.
  Future<Map<String, Object?>?> deviceProfile(int? capKbps) async {
    if (!PlatformInfo.isAndroid) return null;
    final caps = await (_capabilities ??= _queryCapabilities()) ?? DeviceCapabilities.fallback;
    return androidDeviceProfile(caps, maxBitrate: capKbps == null ? null : capKbps * 1000);
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

  /// The plan [c] airs with: [configuredPlanFor], or Off while none of the
  /// pools it uses has clips.
  BreakPlan planFor(Channel c) {
    final plan = configuredPlanFor(c);
    return plan.isOff || !hasClipsFor(plan) ? BreakPlan.off : plan;
  }

  /// Whether any pool [plan] draws from has clips.
  bool hasClipsFor(BreakPlan plan) => plan.poolsUsed.any(catalog.hasClips);

  /// Whether [c] gets commercial breaks.
  bool breaksFor(Channel c) => !planFor(c).isOff;

  BreakContext _breakContext(BreakPlan plan) =>
      BreakContext(plan: plan, clips: catalog, points: _analysis ?? const ChapterPoints());

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
    final renamed = settingsJson is Map<String, Object?> && settingsJson['installId'] != settings.installId;
    if (settingsJson == null || renamed || settings.migrated) await _saveSettings();
    PlaybackDiagnostics.mark('settings read');
    // Decisions and a connection measurement saved by an older version.
    unawaited(storage.delete(legacyDecisionsFile).catchError((Object e) {
      debugPrint('Could not delete $legacyDecisionsFile: $e');
    }));

    final sessionJson = await storage.readJson(_sessionFile);
    if (sessionJson is! Map<String, Object?>) {
      _setPhase(AppPhase.signedOut);
      return;
    }
    session = JellyfinSession.fromJson(sessionJson);
    client = _sessionClient?.call(session!) ?? JellyfinClient.fromSession(session!, deviceName: deviceName);
    // One-time sign-in upgrades; they wait for the launch's picture.
    _afterLaunchTune(() {
      unawaited(_renameDevice());
      unawaited(_recordServerId());
    });

    final libraryJson = await storage.readJson(_libraryFile);
    final channelsJson = await storage.readJson(_channelsFile);
    PlaybackDiagnostics.mark('library and channels read');
    if (libraryJson is Map<String, Object?> && channelsJson is List) {
      library = LibraryIndex.fromJson(libraryJson);
      PlaybackDiagnostics.mark('library parsed');
      // A kid's limit may have been tightened since this was saved.
      final limit = maxRatingRank;
      if (limit != null) library = library.restrictedTo(limit);
      final blocksJson = await storage.readJson(_blocksFile);
      if (blocksJson is List) {
        _blocks = [for (final b in blocksJson.cast<Map<String, Object?>>()) ProgramBlock.fromJson(b)];
      }
      // Clips (and so which channels have breaks) must be known before the
      // lineup is, or every launch would shift the guide.
      if (session!.serverId case final id?) await _openAnalysis(id);
      PlaybackDiagnostics.mark('analysis cache open');
      _updateCatalog(rebase: false);
      _setChannels([for (final c in channelsJson.cast<Map<String, Object?>>()) Channel.fromJson(c)]);
      _askLaunchDecision();
      _setPhase(AppPhase.ready);
      PlaybackDiagnostics.mark('ready (channels set)');
      _startAnalysis();
      final age = DateTime.now().difference(library.fetchedAt);
      if (age > libraryMaxAge) {
        // It downloads the whole library: after the launch's picture.
        _afterLaunchTune(() {
          PlaybackDiagnostics.mark('library refresh started (cache ${age.inHours} h old)');
          unawaited(refreshLibrary(background: true));
        });
      }
    } else {
      await refreshLibrary();
    }
    _armLaunchGate();
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
    final candidate = JellyfinClient.fromSession(renamed, deviceName: deviceName);
    try {
      await candidate.checkSession();
    } on JellyfinException catch (e) {
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
      id = await JellyfinClient(serverUrl: c.serverUrl, deviceId: c.deviceId, deviceName: deviceName)
          .serverIdOnce();
    } on JellyfinException catch (e) {
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
        _updateCatalog();
        _startAnalysis();
      }());

  // ---- Sign in / out ------------------------------------------------------

  JellyfinClient clientFor(String serverUrl) => JellyfinClient(
        serverUrl: serverUrl,
        deviceId: settings.installId,
        deviceName: deviceName,
      );

  Future<void> completeSignIn(JellyfinSession newSession, JellyfinClient newClient) async {
    session = newSession;
    client = newClient;
    _decisions.clear();
    await storage.writeJson(_sessionFile, newSession.toJson(), private: true);
    await _recordServerId();
    await refreshLibrary();
  }

  Future<void> signOut() async {
    await _stopAnalysis();
    // The next sign-in may be to another server, with its own results.
    final cache = _analysis;
    _analysis = null;
    cache?.removeListener(_onAnalysis);
    if (cache != null) await AnalysisCache.release(cache);
    try {
      await client?.logout();
    } on JellyfinException {
      // Signing out locally still works if the server is unreachable.
    }
    client?.close();
    client = null;
    session = null;
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

  /// A library scan is in progress ([syncStatus] says what it's doing).
  bool get refreshing => _refreshing;

  /// Re-scans Jellyfin. New episodes join existing channels without
  /// changing what's on air right now; new genre/show channels are added.
  Future<void> refreshLibrary({bool background = false}) async {
    final c = client;
    if (c == null || _refreshing) return;
    _refreshing = true;
    syncError = null;
    notifyListeners();
    if (!background || phase != AppPhase.ready) _setPhase(AppPhase.syncing);
    try {
      syncStatus = 'Connecting to ${session?.serverName ?? 'Jellyfin'}…';
      notifyListeners();
      var fresh = await fetchLibraryIndex(c, pools: settings.commercialPools, onStatus: (s) {
        syncStatus = s;
        notifyListeners();
      }, onLibraries: _labelLibraryRoots);
      final limit = maxRatingRank;
      if (limit != null) fresh = fresh.restrictedTo(limit);
      syncStatus = 'Building channels…';
      notifyListeners();
      final previous = library;
      final plansBefore = _plans();
      library = fresh;
      if (_channels.isNotEmpty) {
        _mergeLibraryIntoChannels(previous, plansBefore);
      } else {
        _schedules.clear();
        _setChannels(ChannelGenerator(library).generate());
      }
      // New pool contents may bring clips (or take them away).
      _updateCatalog();
      await storage.writeJson(_libraryFile, library.toJson());
      await _saveChannels();
      await _saveBlocks();
      _setPhase(AppPhase.ready);
      _startAnalysis();
      _analyzer?.poke();
    } on JellyfinException catch (e) {
      syncError = e.message;
      if (e.statusCode == 401) {
        // The token was revoked (e.g. device removed in the dashboard).
        await signOut();
        syncError = 'Your session expired. Please sign in again.';
        notifyListeners();
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
      await refreshLibrary(background: true);
    }
  }

  /// Names whole-library pool folders after their library (upgrades from
  /// before pools don't know the names, and libraries can be renamed).
  void _labelLibraryRoots(List<JellyfinLibrary> libraries) {
    final names = {for (final l in libraries) l.id: l.name};
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

  void _mergeLibraryIntoChannels(LibraryIndex previous, Map<String, BreakPlan> plansBefore) {
    final now = DateTime.now();
    for (final ch in _channels) {
      if (ch.blockOnly) {
        _schedules.remove(ch.id);
        continue;
      }
      _rebase(ch, _mergedPlaylist(ch.playlist, buildPlaylist(library, ch.source, ch.order, seed: stableHash(ch.id))), now,
          previous: previous, planBefore: plansBefore[ch.id]);
    }
    for (final b in _blocks) {
      b.playlist = _mergedPlaylist(b.playlist, blockPlaylist(b));
    }
    _schedules.clear();
    // Add channels the bigger library now qualifies for.
    final existingIds = {for (final c in _channels) c.id};
    var next = _channels.fold(1, (n, c) => max(n, c.number)) + 1;
    for (final c in ChannelGenerator(library).generate()) {
      if (existingIds.contains(c.id)) continue;
      c.number = next++;
      _channels.add(c);
    }
    _setChannels(_channels);
  }

  /// Keeps [playlist]'s order, dropping items gone from the library and
  /// appending the new ones from [fresh].
  List<String> _mergedPlaylist(List<String> playlist, List<String> fresh) {
    final known = playlist.toSet();
    return [
      for (final id in playlist)
        if (library[id] != null) id,
      for (final id in fresh)
        if (!known.contains(id)) id,
    ];
  }

  /// Replaces [ch]'s playlist while keeping the current program on air at
  /// the same position, so editing a channel never makes it "jump".
  ///
  /// [previous] is the library [ch]'s current schedule was built against,
  /// when the library itself is being replaced; [planBefore] is the plan it
  /// aired with, when that is what's changing.
  ///
  /// The program on air keeps its position in the show (or, during a
  /// break, its slot keeps its start). Then the anchor moves to the plan's
  /// clock boundary, if it has one, so later slots line up on the clock;
  /// that moves the slot by at most half a boundary.
  void _rebase(Channel ch, List<String> playlist, DateTime now, {LibraryIndex? previous, BreakPlan? planBefore}) {
    final oldSchedule = ChannelSchedule.build(ch, previous ?? library, const [], _breakContext(planBefore ?? planFor(ch)));
    ch.playlist = playlist;
    _schedules.remove(ch.id);
    if (oldSchedule == null) return;
    final slot = oldSchedule.programAt(now);
    final item = slot.item;
    if (item == null) return;
    final playing = oldSchedule.playbackAt(now);
    // In a show part: keep the position in the show. In a break: keep the
    // slot's start.
    final position = playing.isBreak ? null : playing.positionAt(now);

    final plan = planFor(ch);
    final fresh = ChannelSchedule.build(ch, library, const [], _breakContext(plan));
    final loop = fresh?.loop;
    final index = loop?.indexOf(item.id);
    if (fresh == null || loop == null || index == null) return;
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
    final grid = plan.alignment;
    if (grid != null) {
      // The nearest boundary, unless that would take the program off the
      // air; then the other one.
      final slot = fresh.slotPlanFor(item).slotLength;
      bool keepsOnAir(DateTime a) {
        final into = now.difference(a.add(offset));
        return !into.isNegative && into < slot;
      }

      final (nearest, other) = _boundaries(anchor, grid);
      anchor = keepsOnAir(nearest) || !keepsOnAir(other) ? nearest : other;
    }
    ch.anchor = anchor;
  }

  /// The multiples of [grid] (15, 30 or 60 minutes past the hour, local
  /// time) on either side of [t], nearest first.
  static (DateTime, DateTime) _boundaries(DateTime t, Duration grid) {
    final minutes = grid.inMinutes;
    final floor = DateTime(t.year, t.month, t.day, t.hour, t.minute ~/ minutes * minutes);
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
      _rebase(ch, buildPlaylist(library, ch.source, order, seed: stableHash(ch.id)),
          DateTime.now());
    }
    _setChannels(_channels);
    await _saveChannels();
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
  /// Channels made for programming blocks are kept, moved after the
  /// generated ones.
  Future<void> resetChannels() async {
    _schedules.clear();
    final fresh = ChannelGenerator(library).generate();
    var next = fresh.fold(1, (n, c) => max(n, c.number)) + 1;
    for (final c in _channels.where((c) => c.blockOnly)) {
      c.number = next++;
      fresh.add(c);
    }
    _setChannels(fresh);
    await _saveChannels();
  }

  Future<void> setLastChannel(Channel ch) async {
    if (settings.lastChannelId == ch.id) return;
    settings.lastChannelId = ch.id;
    await _saveSettings();
  }

  // ---- Playback ----------------------------------------------------------

  /// Changes "Transcode only if needed". What's playing plays on; the tuner
  /// uses the new setting from the next segment it opens. The analyzer's
  /// budget follows right away. This session's decisions are cleared.
  Future<void> setPlayback(PlaybackSettings playback) async {
    if (playback == settings.playback) return;
    settings.playback = playback;
    _decisions.clear();
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
    catalog.update(library.commercials, _analysis, settings.commercialPools.map((p) => p.id));
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
    final cache = _analysis;
    final c = client;
    if (!runAnalysis || _background || _closed || _analyzer != null || cache == null || c == null || phase != AppPhase.ready) {
      return;
    }
    // The analyzer only ever reads the static stream (direct-play spec).
    final proxy = _proxy = LoopbackStreamProxy(upstream: (id) => client!.streamUri(id), headers: () => client!.authHeaders)
      ..budget = analyzerBudgetNow;
    _analyzer = MediaAnalyzer(
      cache: cache,
      scanner: ffmpeg,
      proxy: proxy,
      segments: (id) async =>
          [for (final s in await client!.commercialSegments(id)) Span(s.start, s.end)],
      work: _analysisWork,
      busy: _analysisBusy,
    )..start();
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
        if (item == null || item.kind == MediaKind.commercial) continue;
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
    _staleCheck?.cancel();
    _launchTimer?.cancel();
    playbackActivity.removeListener(_onLaunchActivity);
    playbackBusy.removeListener(_updateAnalysisBusy);
    exportBusy?.removeListener(_updateAnalysisBusy);
    await _stopAnalysis();
    _analysis?.removeListener(_onAnalysis);
    if (_analysis case final cache?) await AnalysisCache.release(cache);
    client?.close();
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
    BreakPlan without(BreakPlan plan) => plan.withRoles(plan.roles.withoutPool(pool.id));
    settings.commercialPlan = without(settings.commercialPlan);
    for (final ch in _channels) {
      if (ch.commercialPlan case final plan?) ch.commercialPlan = without(plan);
    }
    // Its clips are gone right away; the re-scan returns its videos to
    // the channels.
    final version = catalog.version;
    catalog.update(library.commercials, _analysis, settings.commercialPools.map((p) => p.id));
    if (catalog.version != version) _schedules.clear();
    _rebaseForPlans(before, DateTime.now());
    await _saveSettings();
    await _saveChannels();
    _refreshForPools();
  }

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
    _schedules.clear();
    notifyListeners();
    await _saveBlocks();
  }

  Future<void> deleteBlock(ProgramBlock block) async {
    _blocks = _blocks.where((b) => b.id != block.id).toList();
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
      number: _channels.fold(1, (n, c) => max(n, c.number)) + 1,
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

  static bool _sameJson(Object? a, Object? b) => a.toString() == b.toString();

  // ---- Persistence --------------------------------------------------------

  void _setChannels(List<Channel> list) {
    _channels = [...list]..sort((a, b) => a.number.compareTo(b.number));
    notifyListeners();
  }

  void _setPhase(AppPhase p) {
    phase = p;
    notifyListeners();
  }

  Future<void> _saveChannels() =>
      storage.writeJson(_channelsFile, [for (final c in _channels) c.toJson()]);

  Future<void> _saveBlocks() =>
      storage.writeJson(_blocksFile, [for (final b in _blocks) b.toJson()]);

  Future<void> _saveSettings() => storage.writeJson(_settingsFile, settings.toJson());
}
