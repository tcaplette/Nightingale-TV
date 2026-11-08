import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/break_notices.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../commercials/break_plan.dart';
import '../library/library_index.dart';
import '../live/live_source.dart';
import '../live/live_source_client.dart';
import '../live/url_privacy.dart';
import '../platform/platform_info.dart';
import '../server/languages.dart';
import '../server/live_tv.dart';
import '../server/server_set.dart';
import 'android_device_profile.dart';
import 'index_cache.dart';
import 'playback_diagnostics.dart';
import 'playback_proxy.dart';
import 'report_plan.dart';
import 'subtitles.dart';
import 'tuner_player.dart';
import '../server/media_server.dart';

enum TunerStatus {
  idle,

  /// Opening a stream (channel change or next program).
  tuning,
  playing,

  /// The file ended before its slot did; waiting for the next program.
  standby,

  /// The stream failed. The channel retries at the next program.
  error,

  /// A block-only channel between its programming blocks.
  offAir,
}

/// Plays whatever a channel's schedule says is on air right now, joining
/// mid-program, and moves to the next program when the slot ends.
class Tuner extends ChangeNotifier {
  /// [player], [clock] and [proxy] are for tests; the app uses the
  /// platform's player (mpv, or ExoPlayer on Android), the real time, and a playback proxy (unless NIGHTINGALE_TV_NO_PROXY=1).
  Tuner(this.app, {TunerPlayer? player, DateTime Function()? clock, PlaybackProxy? proxy})
      : media = player ?? TunerPlayer.create(leveling: app.volumeLeveling.value),
        _clock = clock ?? DateTime.now,
        _proxy = proxy ?? (player == null && !PlaybackProxy.disabled ? PlaybackProxy() : null) {
    _diagnostics = PlaybackDiagnostics.start(
        app.storage.root, media, app.analyzerDebugState, () => status == TunerStatus.playing && !paused,
        active: () => channel != null);
    if (_diagnostics != null) debugPrint('Playback diagnostics: ${_diagnostics!.path}');
    _subscriptions.addAll([
      // Tuned in once the picture moves: mpv reports "playing" (and not
      // "buffering") right after an open, seconds before the first frame.
      media.positionStream.listen(_onPosition),
      media.completedStream.listen((completed) {
        if (!completed || status != TunerStatus.playing) return;
        // A stream given up while paused opens again at the resume.
        if (paused) {
          _reopenOnResume = true;
          return;
        }
        // A live stream never ends by itself: it dropped.
        if (_live != null) {
          _liveLost('the stream ended');
          return;
        }
        // A commercial shorter than its listed length holds its last
        // picture until the hand-over; a program part shows stand-by.
        if (inBreak) {
          _diagnostics?.event('${_label(segment)} ended early; holding its last picture');
          return;
        }
        _setStatus(TunerStatus.standby);
      }),
      // mpv's log quotes stream URLs, which can hold an IPTV login.
      media.logStream.listen((line) => _diagnostics?.mpvLog(scrubUrlsIn(line))),
      // The player moved on to the preloaded segment by itself.
      media.advanced.listen((_) => _onAdvanced()),
      media.errorStream.listen((message) {
        debugPrint('Playback error: $message');
        _diagnostics?.event('player error: "$message" while ${status.name} (mayFallBack=$_mayFallBack, transcoding=${_active?.playSessionId})');
        _onPlaybackError(message);
      }),
    ]);
    _leveling = app.volumeLeveling.value;
    unawaited(media.setVolumeLeveling(_leveling));
    app.volumeLeveling.addListener(_onLevelingChanged);
    unawaited(media.setCaptionSize(app.captionSize.value));
    app.captionSize.addListener(_onCaptionSizeChanged);
    app.addListener(_onSettingsChanged);
    _startProxy();
  }

  /// Volume leveling as the player has it.
  bool _leveling = false;

  /// Volume leveling changed (volume-leveling spec). mpv levels what's
  /// playing at once. On Android the device profile and the audio output
  /// change with it: the player is rebuilt, and the channel re-tuned (the
  /// app has cleared this session's decisions).
  Future<void> _onLevelingChanged() async {
    final on = app.volumeLeveling.value;
    if (on == _leveling) return;
    _leveling = on;
    _diagnostics?.event('volume leveling ${on ? 'on' : 'off'}');
    await media.setVolumeLeveling(on);
    if (PlatformInfo.isAndroid) await _retuneInPlace();
  }

  /// The player draws captions at the size in force, on what's showing too.
  void _onCaptionSizeChanged() => unawaited(media.setCaptionSize(app.captionSize.value));

  /// Pause and rewind turned off: a viewer behind goes live at once.
  void _onSettingsChanged() {
    if (shifted && !app.settings.playback.pauseAndRewind) unawaited(goLive());
    _followPlan();
  }

  /// The channel on and the break plan it aired with when last looked at.
  ({String channelId, BreakPlan plan})? _planSeen;

  /// The channel's plan as aired changed (clips came or went in a scan, or
  /// it was edited from the web admin): a block's lineup may have moved, so
  /// the tuner follows the new schedule (see [reschedule]).
  void _followPlan() {
    final ch = channel;
    if (ch == null || ch.isLive) {
      _planSeen = null;
      return;
    }
    final plan = app.planFor(ch);
    final seen = _planSeen;
    _planSeen = (channelId: ch.id, plan: plan);
    if (seen != null && seen.channelId == ch.id && seen.plan != plan) unawaited(reschedule());
  }

  static const _progressInterval = Duration(seconds: 10);

  /// Progress reports (or, with reports off, a conversion's pings) go this
  /// often.
  @visibleForTesting
  Duration progressEvery = _progressInterval;

  /// How long a transcoded part may take to start playing.
  @visibleForTesting
  Duration transcodeStartup = const Duration(seconds: 10);

  /// How long stopping a transcode job may hold up quitting.
  static const exitTimeout = Duration(seconds: 2);

  final AppState app;
  final TunerPlayer media;
  final DateTime Function() _clock;

  /// The schedule's time for the picture on screen: the clock, but behind
  /// it by as much as the segment on now runs past its scheduled end (a
  /// part joined early on a keyframe plays that much longer), so overlays
  /// worked out from the schedule (break notices) match the real cut.
  DateTime pictureNow() {
    final now = viewNow(), seg = segment, end = _segmentEnd;
    if (seg == null || end == null || !end.isAfter(seg.end)) return now;
    return now.subtract(end.difference(seg.end));
  }

  /// A break notice that came up, the scheduled cut it counts down to
  /// ([at]) and when that cut shows on screen ([cut]): logged with how
  /// early or late the segment changed (diagnostics only).
  ({BreakNoticeKind kind, DateTime at, DateTime cut, int channel})? _notice;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// With NIGHTINGALE_TV_DEBUG_PLAYBACK=1, a log of how playback is going.
  PlaybackDiagnostics? _diagnostics;

  Channel? channel;
  Channel? previousChannel;

  /// Captions (subtitles) on: the profile's saved choice (subtitles spec).
  bool get captions => app.settings.playback.captions;
  /// The guide slot on air (the program and its breaks).
  ScheduledProgram? program;

  /// What's actually playing within [program]: a part of the show or a
  /// commercial.
  ScheduledProgram? segment;

  /// A commercial break is on.
  bool get inBreak => segment?.isBreak ?? false;

  /// Tuning a channel (a tune, or the first one at startup), not just opening
  /// the next segment on it: the TV screen shows the channel number meanwhile.
  bool get changingChannel => status == TunerStatus.tuning && _changingChannel;
  TunerStatus status = TunerStatus.idle;
  String? error;

  Timer? _programEnd;
  Timer? _progress;
  _Report? _report;

  /// "Stopped" reports for viewings left behind. They're sent at the next
  /// picture, or [stoppedReportDelay] after the tune, so they never hold up
  /// or compete with an open (fast-tune spec); quitting sends them at once.
  final _stoppedQueue = <(MediaServer, PlaybackReport)>[];
  Timer? _stoppedTimer;

  /// How long a queued "stopped" report may wait for the next picture.
  @visibleForTesting
  Duration stoppedReportDelay = const Duration(seconds: 10);

  /// Bumped on every tune so stale async work can tell it was superseded.
  int _generation = 0;

  // ---- Transcoding (with "Transcode only if needed" on, and on Android) ----
  // Per program video and cap, its decision (a transcode URL template, or
  // direct play) is kept in [AppState.savedDecision]: reused for the
  // program's later parts, re-tunes and later airings this session, until
  // the setting changes.

  /// The one transcode job this app may have running.
  _Transcode? _active;

  /// The part opening now is a direct-played program part that may still
  /// fall back to a transcode.
  bool _mayFallBack = false;
  Timer? _startup;

  /// Ask Jellyfin for decisions ahead of time (tests that count requests
  /// turn it off).
  @visibleForTesting
  bool prefetch = true;

  /// Decisions are asked ahead this long after a picture, or once mpv has
  /// [prefetchBuffered] seconds buffered if that's sooner; never while a
  /// stream opens.
  @visibleForTesting
  Duration prefetchAfter = const Duration(seconds: 10);
  static const prefetchBuffered = 10.0;
  Timer? _prefetchTimer;
  bool _prefetchArmed = false;

  // ---- Sampling (prefetch and fill timing, the analyzer's budget) ------------

  /// How often mpv's buffer is read (tests drive [debugSample]).
  @visibleForTesting
  Duration sampleEvery = const Duration(seconds: 1);
  Timer? _sampler;
  bool _sampling = false;

  // ---- Opening -------------------------------------------------------------

  /// The open now hasn't shown its first frame yet (see [_onPosition]).
  bool _awaitingFirstFrame = false;

  /// Where the open now should land: the join position, or 0 for a transcode
  /// (Jellyfin seeks).
  Duration _landing = Duration.zero;
  Duration? _lastTick;

  /// The open now joins its program at the keyframe before [startAt].
  ({Duration startAt, DateTime end, int generation})? _keyframeJoin;

  /// A join must be this far into its part to start at a keyframe, so that
  /// keyframe can't be in the part before (they're rarely further apart).
  static const _keyframeJoinMargin = Duration(seconds: 15);

  /// When the segment on now hands over to the next.
  DateTime? _segmentEnd;

  /// The channel itself is changing, not just the segment on it.
  bool _changingChannel = false;

  /// Something was tuned since this tuner was made (diagnostics: the first
  /// tune is the launch's).
  bool _tunedOnce = false;

  /// The segment change on now, until its picture (HANDOVER).
  _Handover? _handover;

  // ---- The next segment, preloaded (segment-handover spec) -------------------

  /// Preload the next segment (tests that count opens turn it off).
  @visibleForTesting
  bool preload = true;

  /// The next segment goes into the player's playlist this long before its
  /// hand-over (at once if less is left); a decision it needs is asked
  /// [_decideLead] before.
  static const preloadLead = Duration(seconds: 30);
  static const _decideLead = Duration(seconds: 60);
  Timer? _preloadTimer;
  Timer? _decideTimer;

  /// In the player's playlist after the segment on now.
  _Preload? _preloaded;

  /// The player is adding it now.
  Future<void>? _enqueueing;

  /// Bumped whenever what's preloaded is dropped, so a preload on its way
  /// can tell.
  int _preloadSerial = 0;

  /// The tuner is moving the player on itself ([_atHandover]).
  bool _advancing = false;

  /// The proxy URL the player reads the segment on now from (null: none),
  /// which a preload is served alongside.
  Uri? _routedNow;

  // ---- The playback proxy (fast-tune spec) -----------------------------------

  /// mpv reaches the server through it: warm connections, and each file's
  /// head and index from the index cache. Null: real URLs.
  final PlaybackProxy? _proxy;

  /// Completes with whether the proxy started.
  Future<bool>? _proxyReady;
  StreamSubscription<ProxyEvent>? _proxyEvents;

  /// An open waits this long for the proxy before opening the real URL.
  static const _proxyTimeout = Duration(seconds: 1);

  void _startProxy() {
    final proxy = _proxy;
    if (proxy == null) return;
    _proxyReady = () async {
      try {
        await proxy.start();
        _proxyEvents = proxy.events.listen(_onProxyEvent);
        _warmConnections();
        return true;
      } on Object catch (e) {
        debugPrint('Playback proxy failed to start: $e');
        _diagnostics?.event('playback proxy failed to start: $e');
        return false;
      }
    }();
  }

  /// Keeps connections to the servers warm (each one that can be used,
  /// multi-server): at start and after each open.
  void _warmConnections() {
    final proxy = _proxy;
    if (proxy == null || !proxy.running) return;
    for (final server in app.servers.all) {
      final client = server.client;
      if (client == null || !server.usable) continue;
      unawaited(proxy.warm(client.pingUri, client.authHeaders).catchError((Object e) {
        debugPrint('Playback proxy: warm-up failed: $e');
      }));
    }
  }

  /// Which copy of [entry] plays (multi-server D5): [entry] as that copy,
  /// with the client to play it through. With one server, [entry] and the
  /// server's client.
  ({MediaEntry item, MediaServer client, String key})? _pick(MediaEntry entry) => app.copyToPlay(entry);

  /// The cap a program part of [item] plays under, in kbps: the profile's,
  /// lowered by its server's quality limit.
  int? _capFor(MediaEntry item) => app.capFor(ServerSet.keyOf(item.sourceId), app.capInEffect);

  /// The copy the segment on now plays from.
  ({MediaEntry item, MediaServer client, String key})? _playing;

  /// The server the segment on now plays from.
  @visibleForTesting
  String? get debugPlayingKey => _playing?.key;

  void _onProxyEvent(ProxyEvent e) {
    final d = _diagnostics;
    if (d == null) return;
    switch (e.kind) {
      case 'upstream':
        d.proxyUpstream(warm: e.data['warm'] == true, from: e.data['from'], ms: e.data['ms']);
      case 'cache':
        d.proxyCache('${e.data['what']}', e.data['source'] ?? e.data['from']);
      case 'fill':
        d.cacheFill('${e.data['summary']}');
    }
  }

  /// What mpv opens for [url]: the proxy's loopback URL (no auth headers:
  /// the proxy adds them), or [url] itself when there's no proxy or it
  /// doesn't answer within [_proxyTimeout].
  /// [preload]: the next segment, served alongside the one on now.
  Future<(Uri, Map<String, String>)> _route(Uri url, MediaServer client,
      {IndexCacheKey? cache, Duration start = Duration.zero, bool preload = false}) async {
    final proxy = _proxy;
    final ready = _proxyReady;
    // An HLS playlist (Plex's transcodes) names its parts by relative paths,
    // which only resolve against the server: the player opens it there.
    final hls = url.path.endsWith('.m3u8');
    if (proxy != null && ready != null && !hls) {
      try {
        if (await ready.timeout(_proxyTimeout)) {
          final routed = await proxy
              .open(url, client.authHeaders,
                  cache: cache, joins: start > const Duration(seconds: 1), alongside: preload ? _routedNow : null)
              .timeout(_proxyTimeout);
          if (!preload) _diagnostics?.tuneProxy(true);
          return (routed, const <String, String>{});
        }
      } on Object catch (e) {
        debugPrint('Playback proxy: open failed ($e); opening directly');
        _diagnostics?.event('proxy: ${preload ? 'preload' : 'open'} failed ($e); opening directly');
      }
    }
    if (!preload) _diagnostics?.tuneProxy(false);
    return (url, client.authHeaders);
  }

  /// [routed] as the player reads it now (a proxy URL, or none).
  void _readingFrom(Uri routed) => _routedNow = routed.host == '127.0.0.1' ? routed : null;

  // ---- Index fills (fast-tune spec, "Direct-play index cache") ----------------

  /// Channels watched most recently, newest first.
  final _recent = <String>[];

  /// A fill pass is due once the picture is up and mpv has buffered enough.
  bool _fillDue = false;
  bool _filling = false;

  /// Seconds mpv had buffered at the last sample.
  double _buffered = 0;

  /// At most this many files per pass.
  static const _fillsPerPass = 20;

  /// Fills run when nothing is opening, and either nothing plays or mpv has
  /// [prefetchBuffered] seconds buffered.
  bool get _mayFill =>
      status != TunerStatus.tuning && (status != TunerStatus.playing || _buffered >= prefetchBuffered);

  /// The programs the next tunes are likely to open: the next one on this
  /// channel and what's on one up and one down (decisions and index fills).
  List<ScheduledProgram> _likelyNext() {
    final ch = channel;
    if (ch == null) return const [];
    final now = _clock();
    final programs = <ScheduledProgram?>[];
    final schedule = this.schedule;
    final current = program;
    if (schedule != null && current != null) programs.add(schedule.next(current));
    if (ch.isLive) return const [];
    final list = app.channels;
    final index = list.indexWhere((c) => c.id == ch.id);
    if (index >= 0 && list.length > 1) {
      for (final delta in const [1, -1]) {
        final neighbor = list[(index + delta) % list.length];
        // Live channels have nothing to decide or read ahead.
        if (!neighbor.isLive) programs.add(app.scheduleFor(neighbor)?.programAt(now));
      }
    }
    return [
      for (final p in programs)
        if (p?.item case final item? when item.kind != MediaKind.commercial) p!,
    ];
  }

  /// What a fill pass reads: [_likelyNext], then the next 2 hours on the 5
  /// channels watched most recently.
  List<MediaEntry> _fillCandidates() {
    final now = _clock();
    final out = <String, MediaEntry>{};
    void add(MediaEntry? item) {
      if (item != null && item.kind != MediaKind.commercial && out.length < _fillsPerPass) {
        out.putIfAbsent(item.sourceId, () => item);
      }
    }

    for (final p in _likelyNext()) {
      add(p.item);
    }
    final recent = [..._recent];
    final last = app.settings.lastChannelId;
    if (recent.isEmpty && last != null) recent.add(last);
    for (final id in recent) {
      final ch = app.channelById(id);
      final schedule = ch == null || ch.isLive ? null : app.scheduleFor(ch);
      for (final p in schedule?.programsBetween(now, now.add(const Duration(hours: 2))) ?? const <ScheduledProgram>[]) {
        add(p.item);
      }
    }
    return out.values.toList();
  }

  /// Reads the head and index of each [_fillCandidates] not cached yet,
  /// one at a time, at the analyzer's budget, while [_mayFill].
  Future<void> _fillPass() async {
    final proxy = _proxy;
    if (proxy == null || app.client == null || !proxy.running || _filling) return;
    _fillDue = false;
    _filling = true;
    final generation = _generation;
    try {
      for (final entry in _fillCandidates()) {
        if (generation != _generation || !_mayFill) break;
        // The copy that would play (multi-server).
        final pick = _pick(entry);
        if (pick == null) continue;
        final (:item, :client, key: _) = pick;
        if (await proxy.cached(item.sourceId)) continue;
        final budget = app.analyzerBudgetNow;
        if (budget.paused) break;
        await proxy.fill((source: item.sourceId, etag: item.etag, size: item.size), client.streamUri(item.sourceId),
            client.authHeaders,
            bytesPerSecond: budget.bytesPerSecond);
      }
    } on Object catch (e) {
      debugPrint('Index fill failed: $e');
    } finally {
      _filling = false;
    }
  }

  /// Tunes [ch], at the live point, or at [at]: where the viewer was before
  /// the app went out of sight (timeshift D12).
  /// Tunes so far (the still-watching count starts again on each).
  int tunes = 0;

  Future<void> tune(Channel ch, {ViewingPlace? at}) async {
    tunes++;
    // A sleep timer's fade that was cancelled never leaves a channel quiet.
    unawaited(media.setVolume(1));
    // Diagnostics: the first tune is the launch's; one after [stop] (Android
    // coming back to the front) is a resume.
    final trigger = !_tunedOnce ? 'launch' : (channel == null ? 'resume' : 'channel');
    _tunedOnce = true;
    // How far the program on the channel being left got.
    _noteReached(atSegmentEnd: false);
    _endShift();
    if (channel != null && channel!.id != ch.id) previousChannel = channel;
    channel = ch;
    _recent
      ..remove(ch.id)
      ..insert(0, ch.id);
    if (_recent.length > 5) _recent.removeLast();
    // In front again (Android) if it was hidden.
    if (_proxyReady != null) unawaited(_proxy!.setBackground(false).catchError((Object _) {}));
    unawaited(app.setLastChannel(ch));
    var exact = false;
    if (at != null && !ch.isLive) {
      if (_clock().difference(at.view) > maxBehind) {
        _notices.add(backToLiveNotice);
      } else {
        exact = true;
        _pinned = at.schedule;
        if (at.paused) {
          _frozen = at.view;
          _pausedWall = _clock();
          _pausedPosition = null;
        } else {
          _shift = _clock().difference(at.view);
        }
      }
    }
    await _playCurrent(++_generation, trigger: trigger, exact: exact);
  }

  /// Re-tunes the current channel, e.g. after its playlist changed. A viewer
  /// behind the schedule goes live.
  Future<void> retune() async {
    _endShift();
    if (channel != null) await _playCurrent(++_generation, trigger: 'retune');
  }

  /// Re-tunes for the player's or server's sake: a viewer behind the schedule
  /// keeps their place.
  Future<void> _retuneInPlace() async {
    if (channel != null) await _playCurrent(++_generation, trigger: 'retune', exact: shifted);
  }

  /// After a schedule change that keeps the program on air (e.g. a new break
  /// plan): the segment playing now plays on, and the new schedule takes
  /// over when it ends (a stream that failed is retried then, as usual).
  /// Falls back to [retune] when nothing is on.
  Future<void> reschedule() async {
    final ch = channel;
    final current = segment;
    if (ch == null) return;
    // Behind the schedule, playback goes on from the pinned one.
    if (shifted) return;
    if (ch.isLive) {
      // The guide changed; the stream plays on.
      _setLiveProgramme(ch, _generation);
      notifyListeners();
      return;
    }
    final schedule = this.schedule;
    final now = viewNow();
    if (schedule == null || current == null || !current.end.isAfter(now)) {
      await retune();
      return;
    }
    final slot = schedule.programAt(now);
    // Another program is on air now (the plan moved the lineup): it's tuned
    // in, rather than playing the old one on under the new guide.
    if (slot.item?.id != program?.item?.id) {
      await retune();
      return;
    }
    program = slot;
    // The rebased slot is still the same viewing of the same program.
    final report = _report;
    if (report != null && report.viewing.itemId == slot.item?.id && report.viewing.channelId == ch.id) {
      report.viewing = (channelId: ch.id, itemId: report.viewing.itemId, layoutStart: slot.layoutStart);
    }
    _endSegmentAt(current.end, _generation);
    // The segment after it may have changed: it's preloaded again.
    await _dropPreload();
    if (_mayPreload && !_awaitingFirstFrame) _armPreload();
    notifyListeners();
  }

  // ---- Captions (subtitles spec) ------------------------------------------------

  /// Each item's subtitle tracks, asked once per session (captions on, or
  /// the picker open), by source id; and those that have arrived.
  final _subtitleLists = <String, Future<List<SubtitleTrack>>>{};
  final _subtitlesKnown = <String, List<SubtitleTrack>>{};

  /// The track the viewer picked in the picker for the item it belongs to:
  /// it shows while that item plays, whatever the language rule says.
  ({String source, SubtitleTrack track})? _picked;

  /// A conversion plays now (tests and diagnostics).
  @visibleForTesting
  bool get converting => _active != null;

  /// The server is drawing the captions into the picture of what's playing,
  /// so their size can't change here.
  bool get captionsBurnedIn {
    final job = _active;
    return job?.burn != null && job!.item.sourceId == _playing?.item.sourceId;
  }

  /// The track showing now (captions on, a program with tracks); null
  /// otherwise, and on a live channel.
  SubtitleTrack? shownSubtitle;

  /// The subtitle tracks of the program on now: null while they aren't
  /// known (or nothing plays, or a live channel is on).
  List<SubtitleTrack>? get subtitleTracks {
    final playing = _playing;
    if (isLive || playing == null) return null;
    return _subtitlesKnown[playing.item.sourceId];
  }

  /// The device's language, for the choice when nothing else decides it.
  @visibleForTesting
  String Function() deviceLanguage = () => PlatformDispatcher.instance.locale.languageCode;

  /// [item]'s tracks, asked of [client] once this session (shared with a
  /// request in flight). None when the server can't say; asked again later.
  Future<List<SubtitleTrack>> _subtitleTracksOf(MediaEntry item, MediaServer client) {
    final key = item.sourceId;
    return _subtitleLists[key] ??= () async {
      try {
        final list = await client.subtitleTracks(key);
        _subtitlesKnown[key] = list;
        _diagnostics?.event('subtitle tracks of $key: ${list.isEmpty ? 'none' : list.join(', ')}');
        return list;
      } on Object catch (e) {
        _subtitleLists.remove(key);
        _diagnostics?.event('subtitle tracks of $key failed: $e');
        return const <SubtitleTrack>[];
      }
    }();
  }

  /// Asks for the tracks of what's on now, captions on or off (the picker
  /// opens): null on a live channel or with nothing playing.
  Future<List<SubtitleTrack>?> loadSubtitleTracks() async {
    final playing = _playing;
    if (isLive || playing == null) return null;
    final list = await _subtitleTracksOf(playing.item, playing.client);
    notifyListeners();
    return list;
  }

  /// The track [item] shows with captions on, from its [tracks].
  SubtitleTrack? _trackFor(MediaEntry item, List<SubtitleTrack> tracks) {
    final picked = _picked;
    if (picked != null && picked.source == item.sourceId && tracks.contains(picked.track)) return picked.track;
    return chooseSubtitle(tracks, preferred: app.settings.playback.captionLanguage, device: deviceLanguage());
  }

  /// Whether a conversion of [item] opening now draws [track] in.
  static SubtitleTrack? _burnOf(SubtitleTrack? track) => track != null && track.burnsWhenConverting ? track : null;

  /// What the player shows for [track] of [pick]'s item: a track inside a
  /// file playing directly by its place, anything else loaded beside it
  /// from the server, timed to [job]'s stream when converting.
  SubtitleChoice? _choiceFor(SubtitleTrack? track, ({MediaEntry item, MediaServer client, String key}) pick, _Transcode? job) {
    if (track == null) return null;
    if (job == null && !track.isExternal) return EmbeddedSubtitle(track.position ?? 0, language: track.language);
    // A burned track is in the picture.
    if (job != null && _burnOf(track) != null) return null;
    final offset = job == null || job.sourceTime ? Duration.zero : job.joinedAt;
    final uri = pick.client.subtitleUri(pick.item.sourceId, track, startAt: offset);
    if (uri == null) return null;
    return SideLoadedSubtitle(uri,
        headers: pick.client.authHeaders,
        format: uri.path.endsWith('.vtt') ? 'vtt' : track.textFormat,
        language: track.language,
        label: subtitleLabel(track));
  }

  /// What an open of [pick]'s item (converted by [job]) shows, from what's
  /// known now: an open never waits for the tracks.
  SubtitleChoice? _openChoice(({MediaEntry item, MediaServer client, String key})? pick, _Transcode? job) {
    if (!captions || pick == null) return null;
    final known = _subtitlesKnown[pick.item.sourceId];
    if (known == null) return null;
    return _choiceFor(_trackFor(pick.item, known), pick, job);
  }

  /// Puts the choice on what plays now: the tracks asked first when they
  /// aren't known (the picture never waits; the track goes on when they
  /// arrive). A conversion that has to draw in a different track, or none,
  /// opens again where it is.
  Future<void> _applyCaptions() async {
    if (isLive || _live != null) {
      shownSubtitle = null;
      await media.setSubtitles(captions ? const StreamCaptions() : null);
      return;
    }
    final playing = _playing;
    final job = _active != null && playing != null && _active!.item.sourceId == playing.item.sourceId ? _active : null;
    if (!captions || playing == null) {
      shownSubtitle = null;
      if (job?.burn != null) {
        _reopenForSubtitles();
        return;
      }
      await media.setSubtitles(null);
      return;
    }
    final known = _subtitlesKnown[playing.item.sourceId];
    if (known == null) {
      final generation = _generation;
      unawaited(_subtitleTracksOf(playing.item, playing.client).then((_) {
        if (generation != _generation || !identical(_playing, playing) || !captions) return;
        unawaited(_applyCaptions());
        notifyListeners();
      }));
      return;
    }
    final track = _trackFor(playing.item, known);
    shownSubtitle = track;
    if (job != null && _burnOf(track) != job.burn) {
      _reopenForSubtitles();
      return;
    }
    await media.setSubtitles(_choiceFor(track, playing, job));
  }

  /// A burned conversion's subtitles changed: it opens again at the same
  /// place, drawing in the new choice (subtitles D4).
  void _reopenForSubtitles() {
    if (paused || status != TunerStatus.playing && status != TunerStatus.tuning) return;
    // Still opening: the player may not have asked for the stream yet, and
    // a job stopped before it's asked for starts all the same (Plex). It
    // opens again once its picture is up.
    if (status == TunerStatus.tuning) {
      _subtitleReopenPending = true;
      return;
    }
    _diagnostics?.event('subtitles changed during a burned conversion; reopening');
    unawaited(_playCurrent(++_generation, trigger: 'subtitles', quiet: true, exact: true));
  }

  /// A burn change came while the conversion was still opening.
  bool _subtitleReopenPending = false;

  /// Saves captions [on] (and [language], when given) for the profile.
  Future<void> _saveCaptions({required bool on, String? language}) => app.setPlayback(app.settings.playback
      .copyWith(captions: on, captionLanguage: language == null ? null : () => language));

  /// C, CC or the phone remote's `cc`: captions on (by the saved choice) or
  /// off. Returns what the toast says.
  Future<String> toggleCaptions() async {
    final on = !captions;
    _picked = null;
    await _saveCaptions(on: on);
    if (!on) {
      await _applyCaptions();
      notifyListeners();
      return 'Captions off';
    }
    final playing = _playing;
    List<SubtitleTrack>? tracks;
    if (!isLive && playing != null) {
      // The toast names the track: it waits a moment for the list, the
      // picture doesn't.
      tracks = await _subtitleTracksOf(playing.item, playing.client)
          .timeout(const Duration(seconds: 3), onTimeout: () => const <SubtitleTrack>[]);
    }
    await _applyCaptions();
    notifyListeners();
    if (tracks == null) return 'Captions on';
    final shown = shownSubtitle;
    if (shown == null) return tracks.isEmpty ? 'Captions on: no subtitles for this program' : 'Captions on';
    return 'Captions on: ${languageName(shown.language) ?? subtitleLabel(shown)}';
  }

  /// The captions picker's choice: [track] on, its language saved as the
  /// profile's preferred one; null for Off, keeping the language.
  Future<void> pickSubtitle(SubtitleTrack? track) async {
    final playing = _playing;
    if (track == null) {
      _picked = null;
      await _saveCaptions(on: false);
    } else {
      _picked = playing == null ? null : (source: playing.item.sourceId, track: track);
      await _saveCaptions(on: true, language: track.language);
    }
    await _applyCaptions();
    notifyListeners();
  }

  /// A live channel's picker: its own captions on or off.
  Future<void> setCaptions(bool on) async {
    if (on == captions) return;
    _picked = null;
    await _saveCaptions(on: on);
    await _applyCaptions();
    notifyListeners();
  }

  Future<void> channelUp() => _step(1);
  Future<void> channelDown() => _step(-1);

  Future<void> lastChannel() async {
    final prev = previousChannel;
    if (prev == null) return;
    // A channel merged into another since (lineup-dedup D6) tunes that one.
    final id = app.currentChannelId(prev.id);
    final ch = app.channels.where((c) => c.id == id).firstOrNull;
    if (ch != null) await tune(ch);
  }

  /// Tunes to channel [number] if it exists.
  Future<bool> tuneNumber(int number) async {
    final match = app.channels.where((c) => c.number == number).firstOrNull;
    if (match == null) return false;
    await tune(match);
    return true;
  }

  Future<void> _step(int delta) async {
    final list = app.channels;
    if (list.isEmpty) return;
    final index = channel == null ? -1 : list.indexWhere((c) => c.id == channel!.id);
    final next = index < 0 ? 0 : (index + delta) % list.length;
    await tune(list[next]);
  }

  /// Opens what's on now. [atSegmentEnd]: called because the previous
  /// segment played to its end (and nothing was preloaded to take over).
  /// [quiet]: a move within the channel (timeshift), with no channel number
  /// shown. [exact]: landing exactly on the viewing time, not on a keyframe.
  Future<void> _playCurrent(int generation,
      {bool atSegmentEnd = false, String? trigger, bool quiet = false, bool exact = false}) async {
    _subtitleReopenPending = false;
    _programEnd?.cancel();
    _cancelPrefetch();
    _awaitingFirstFrame = false;
    _keyframeJoin = null;
    final from = segment;
    _noteReached(atSegmentEnd: atSegmentEnd);
    final ch = channel;
    if (ch == null || app.client == null || generation != _generation) return;
    _planSeen = ch.isLive ? null : (channelId: ch.id, plan: app.planFor(ch));
    _diagnostics?.tuneStarted(trigger ?? (atSegmentEnd ? 'segment' : 'retune'), 'ch=${ch.number}');
    // Whatever was preloaded goes before anything else opens.
    await _dropPreload();
    if (generation != _generation) return;
    if (ch.isLive) {
      await _playLive(generation, ch);
      return;
    }
    // Leaving a live channel ends its stream (the next one doesn't wait).
    await _closeLive();
    if (generation != _generation) return;

    final schedule = this.schedule;
    if (schedule == null) {
      _diagnostics?.tuneFailed('no schedule');
      // Nothing opens, so nothing to wait for.
      _queueFinish();
      unawaited(flushReports());
      program = null;
      segment = null;
      // A channel with nothing in its playlist (a custom channel whose
      // collection is gone) is off the air, not out of signal.
      error = 'Nothing to play on this channel';
      _stopTranscode();
      _setStatus(TunerStatus.offAir);
      await media.stop();
      return;
    }
    final now = viewNow();
    var current = schedule.playbackAt(now);
    // Joining with only a moment left would just flash the end credits.
    if (current.end.difference(now) < const Duration(seconds: 4)) {
      current = schedule.playbackAt(current.end);
    }
    final startAt = current.positionAt(now);
    // The copy it plays from (multi-server): the first in Play from whose
    // server can be used.
    final pick = current.item == null ? null : _pick(current.item!);
    _setOnNow(generation, ch, schedule, current, now, startAt, pick);
    _handover = atSegmentEnd ? _Handover(_label(from), _label(current), preloaded: false, trigger: 'tuner') : null;

    // Whatever was transcoding stops before anything else opens.
    _stopTranscode();
    final item = pick?.item;
    final client = pick?.client;
    // Asked alongside the open, which never waits for it.
    if (captions && item != null && client != null) unawaited(_subtitleTracksOf(item, client));
    if (item == null || client == null) {
      _diagnostics?.tuneFailed('off air (nothing to open)');
      final handover = _handover;
      _handover = null;
      if (handover != null) _diagnostics?.handover(handover.from, handover.to, preloaded: false, trigger: 'tuner');
      unawaited(flushReports());
      _setStatus(TunerStatus.offAir);
      await media.stop();
      // What comes after the card loads while it shows.
      if (generation == _generation) _armPreload();
      return;
    }
    _changingChannel = !atSegmentEnd && !quiet;
    _setStatus(TunerStatus.tuning);

    final playback = app.settings.playback;
    final isProgram = _isProgramPart(current);
    // On Android every segment plays as Jellyfin decides for the device
    // (android-playback). The cap is only ever for program parts.
    final android = app.decidesEverySegment;
    final cap = isProgram ? _capFor(item) : null;
    // Elsewhere only program parts ever transcode; commercials and bumpers
    // always direct-play.
    final transcodable = playback.transcodeIfNeeded && isProgram;
    Uri? template;
    var directStream = false;
    if (transcodable || android) {
      final source = item.sourceId;
      final saved = app.savedDecision(source, cap);
      if (saved != null) {
        template = saved.template;
        directStream = saved.directStream;
        _diagnostics?.event('saved decision for $source at cap ${cap ?? 'none'}: ${_decided(template, directStream)}');
      } else if (cap != null || android) {
        _armStartup(generation);
        final waited = Stopwatch()..start();
        try {
          // Shared with a prefetch or the launch's early request in flight.
          final decision = await app.decide(source, cap, startAt: startAt);
          template = decision.template;
          directStream = decision.directStream;
          _diagnostics?.tuneWaited('playback-info', waited.elapsed);
          _diagnostics?.event('decision for $source at cap ${cap == null ? 'none' : '$cap kbps'}: ${_decided(template, directStream)}');
        } on Object catch (e) {
          // Can't ask: play it directly, as with the setting off.
          debugPrint('Playback decision failed: $e');
          _diagnostics?.tuneWaited('playback-info (failed)', waited.elapsed);
          _diagnostics?.event('decision for $source failed: $e');
          // Its server is down and another has a copy: that one plays.
          if (e is ServerException && e.unreachable && await _failOver(generation)) return;
        }
        // The job only starts once the stream is requested, so a decision
        // that arrives after a newer tune leaves nothing running.
        if (generation != _generation) return;
      }
    }

    if (template != null) {
      if (!await _openTranscode(generation, current, item, template, startAt, client,
          capKbps: cap, directStream: directStream)) {
        return;
      }
    } else {
      _startup?.cancel();
      // A program part that fails to open is converted instead: with the
      // setting on, and on Android whatever the setting.
      _mayFallBack = isProgram && (playback.transcodeIfNeeded || android);
      // Joining a show mid-way starts at the keyframe before the join point,
      // so the picture comes without decoding up to the exact second.
      // Whatever must start exactly keeps a precise seek: commercial clips
      // cut from reels, and segments starting on schedule.
      final keyframe = !exact && !atSegmentEnd && _isProgramPart(current) && startAt - current.itemFrom > _keyframeJoinMargin;
      _expectFirstFrame(startAt);
      _keyframeJoin = keyframe ? (startAt: startAt, end: current.end, generation: generation) : null;
      try {
        // A part of the show, or a clip inside a reel: mpv stops exactly at
        // the segment's end even if the timer runs late.
        final url = client.streamUri(item.sourceId);
        _diagnostics?.opened(current.isCommercial ? 'direct-commercial' : 'direct', url, start: startAt, end: current.itemTo);
        final (routed, headers) =
            await _route(url, client, cache: (source: item.sourceId, etag: item.etag, size: item.size), start: startAt);
        if (generation != _generation) return;
        _readingFrom(routed);
        await media.open(routed,
            headers: headers, start: startAt, end: current.itemTo, exact: !keyframe, subtitles: _openChoice(pick, null));
        _diagnostics?.openReturned();
      } on Object catch (e) {
        if (generation != _generation) return;
        _onPlaybackError('$e');
        return;
      }
    }
    if (generation != _generation) return;
    await _applyCaptions();
  }

  /// Makes [current] what's on now, whether it opens or was preloaded: the
  /// segment and program, the viewing's reports, break state and the
  /// hand-over timer. [startAt]: where in its item it starts.
  /// [pick]: the copy it plays from (see [_pick]).
  void _setOnNow(int generation, Channel ch, ProgramSchedule schedule, ScheduledProgram current, DateTime now,
      Duration startAt, ({MediaEntry item, MediaServer client, String key})? pick) {
    final step = reportStep(_report?.viewing, ch.id, current);
    // Sent after the new picture: the open doesn't wait for the server.
    if (step == ReportStep.finish || step == ReportStep.finishAndStart) _queueFinish();
    segment = current;
    _logNotice(ch, current);
    program = schedule.programAt(current.start.isAfter(now) ? current.start : now);
    error = null;
    _endSegmentAt(current.end, generation);
    _playing = pick;
    if (pick == null) return;
    final (:item, :client, :key) = pick;
    // A new viewing is reported from its first picture (see [_beginReport]);
    // one that never shows a picture isn't reported at all. A viewing that
    // moved to another server's copy is reported there (multi-server).
    final moved = step == ReportStep.keep && _report != null && _report!.key != key;
    if (step == ReportStep.start || step == ReportStep.finishAndStart || moved) {
      _report = _Report(client, item, _newSessionId().substring(0, 16), viewingOf(ch.id, current)!,
          key: key, reports: app.settings.playback.reportPlayback)
        ..reached = startAt
        ..cut = current.endsEarly;
    } else if (step == ReportStep.keep && !current.isBreak) {
      // Rewinding never lowers how far the viewing got.
      final report = _report;
      if (report != null && startAt > report.reached) report.reached = startAt;
    }
  }

  /// Hands over to the next segment at [end].
  void _endSegmentAt(DateTime end, int generation) {
    _programEnd?.cancel();
    _segmentEnd = end;
    // Paused, the viewing time stands still: [resume] sets it again.
    if (paused) return;
    _programEnd = Timer(end.difference(viewNow()), () => unawaited(_atHandover(generation)));
  }

  /// The schedule's hand-over: to the preloaded segment if there is one
  /// (the player may already be on it), else by opening what's on.
  Future<void> _atHandover(int generation) async {
    if (generation != _generation) return;
    final enqueueing = _enqueueing;
    if (enqueueing != null) await enqueueing.then((_) {}, onError: (Object _) {});
    if (generation != _generation || paused) return;
    final next = _preloaded;
    if (next != null && _mayPreload) {
      _advancing = true;
      var moved = false;
      try {
        moved = await media.advance();
      } on Object catch (e) {
        _diagnostics?.event('advance failed: $e');
      } finally {
        _advancing = false;
      }
      if (generation != _generation) return;
      if (moved) {
        // Unless the player's own move was handled meanwhile.
        if (identical(_preloaded, next)) _handOver(next, trigger: 'tuner');
        return;
      }
      _diagnostics?.event('the preloaded segment was dropped by the player; opening it');
    }
    await _playCurrent(generation, atSegmentEnd: true);
  }

  /// A break notice came up on screen, counting down to [at]; with
  /// diagnostics on, a `NOTICE` line follows when the segment changes
  /// (break-notices D7).
  void noteBreakNotice(BreakNoticeKind kind, DateTime at) {
    final ch = channel;
    if (_diagnostics == null || ch == null) return;
    _notice = (kind: kind, at: at, cut: at.add(_clock().difference(pictureNow())), channel: ch.number);
  }

  /// [current] is on now on [ch]: how far the change was from the cut a
  /// notice counted down to.
  void _logNotice(Channel ch, ScheduledProgram current) {
    final n = _notice;
    if (n == null) return;
    _notice = null;
    if (n.channel != ch.number || current.start != n.at) return;
    final off = _clock().difference(n.cut).inMilliseconds / 1000;
    final late = n.cut.difference(n.at).inMilliseconds;
    _diagnostics?.notice('kind=${n.kind.name} ch=${n.channel} at=${n.at.toIso8601String()} '
        '${late == 0 ? '' : 'shown-cut=+${late}ms '}change=${off >= 0 ? '+' : ''}${off.toStringAsFixed(3)}s');
  }

  /// The player reached the end of the segment on now and moved on to the
  /// preloaded one by itself.
  void _onAdvanced() {
    final next = _preloaded;
    if (_advancing || next == null || next.generation != _generation) return;
    _handOver(next, trigger: 'player');
  }

  /// The preloaded segment [next] is on now: what's on changes as at an
  /// open, but nothing opens, and the status stays `playing`.
  void _handOver(_Preload next, {required String trigger}) {
    _preloaded = null;
    final ch = channel;
    final schedule = this.schedule;
    if (ch == null || app.client == null || schedule == null || next.generation != _generation) return;
    final from = segment;
    final current = next.segment;
    _cancelPrefetch();
    _cancelPreloadTimers();
    _awaitingFirstFrame = false;
    _keyframeJoin = null;
    _noteReached(atSegmentEnd: true);
    _setOnNow(_generation, ch, schedule, current, viewNow(), next.start, next.pick);
    // A conversion the part before played from ends with it.
    _stopTranscode();
    _readingFrom(next.routed);
    _changingChannel = false;
    // Until its picture, a program part that fails converts instead, as at
    // an open.
    _mayFallBack = _isProgramPart(current) && (app.settings.playback.transcodeIfNeeded || app.decidesEverySegment);
    _handover = _Handover(_label(from), _label(current), preloaded: true, trigger: trigger);
    _diagnostics?.handedOver(current.isCommercial ? 'direct-commercial' : 'direct', next.url,
        start: next.start, end: current.itemTo);
    _expectFirstFrame(next.start);
    unawaited(_applyCaptions());
    notifyListeners();
  }

  // ---- Preloading ----------------------------------------------------------------

  /// The segment on now plays, or shows a card (off air) with nothing open:
  /// the next segment may load meanwhile.
  bool get _mayPreload => status == TunerStatus.playing || status == TunerStatus.offAir;

  /// Once the segment on now shows its picture: the next segment is added
  /// to the player's playlist [preloadLead] before the hand-over, and a
  /// decision it needs is asked [_decideLead] before.
  void _armPreload() {
    _cancelPreloadTimers();
    final end = _segmentEnd;
    if (!preload || end == null || _preloaded != null || channel == null || paused) return;
    final generation = _generation, serial = _preloadSerial;
    final now = viewNow();
    Duration before(Duration lead) {
      final d = end.subtract(lead).difference(now);
      return d.isNegative ? Duration.zero : d;
    }

    _decideTimer = Timer(before(_decideLead), () {
      final next = _nextSegment();
      if (next == null || next.segment.item == null) return;
      unawaited(_playsDirect(next.segment));
      // Its subtitle tracks too, while captions are on.
      final pick = _pick(next.segment.item!);
      if (captions && pick != null) unawaited(_subtitleTracksOf(pick.item, pick.client));
    });
    _preloadTimer = Timer(before(preloadLead), () => unawaited(_preloadNext(generation, serial)));
  }

  void _cancelPreloadTimers() {
    _preloadTimer?.cancel();
    _decideTimer?.cancel();
    _preloadTimer = _decideTimer = null;
  }

  /// Drops what's preloaded (and a preload on its way): the player's
  /// playlist holds only the segment on now.
  Future<void> _dropPreload() async {
    _cancelPreloadTimers();
    _preloadSerial++;
    final had = _preloaded != null || _enqueueing != null;
    _preloaded = null;
    final enqueueing = _enqueueing;
    if (enqueueing != null) await enqueueing.then((_) {}, onError: (Object _) {});
    if (had) await media.clearQueue();
  }

  /// The segment after the one on now, as the hand-over will find it, and
  /// where in its item it starts. A keyframe join that ended the part late
  /// comes out of the next segment's start, as an open there would. One with
  /// only a moment of it left at the hand-over is skipped, as an open skips
  /// it (a clip's last seconds), for the one after it.
  ({ScheduledProgram segment, Duration start})? _nextSegment() {
    final current = segment, end = _segmentEnd;
    final schedule = this.schedule;
    if (schedule == null || current == null || end == null) return null;
    var next = schedule.playbackAt(current.end);
    if (next.end.difference(end) < const Duration(seconds: 4)) next = schedule.playbackAt(next.end);
    if (next.end.difference(end) < const Duration(seconds: 4)) return null;
    return (segment: next, start: next.positionAt(end.isAfter(next.start) ? end : next.start));
  }

  /// Whether [s] plays from the static stream: by the rule (on Linux, all
  /// but program parts with the setting on, and those too with no cap), or
  /// by this session's decision, asked now if there's none (shared with a
  /// request in flight). False when it can't be asked.
  Future<bool> _playsDirect(ScheduledProgram s) async {
    final item = _pick(s.item!)?.item ?? s.item!;
    final source = item.sourceId;
    final isProgram = _isProgramPart(s);
    final android = app.decidesEverySegment;
    final cap = isProgram ? _capFor(item) : null;
    if (!android && !(app.settings.playback.transcodeIfNeeded && isProgram)) return true;
    final saved = app.savedDecision(source, cap);
    if (saved != null) return saved.template == null;
    if (cap == null && !android) return true;
    final asking = !app.deciding(source, cap);
    try {
      final d = await app.decide(source, cap, startAt: s.itemFrom);
      if (asking) _diagnostics?.event('decision for the next segment $source: ${_decided(d.template, d.directStream)}');
      return d.template == null;
    } on Object catch (e) {
      if (asking) _diagnostics?.event('decision for the next segment $source failed: $e');
      return false;
    }
  }

  /// Adds the next segment to the player's playlist when it qualifies: it
  /// has something to play, and plays from the static stream. Anything else
  /// opens at the hand-over as usual.
  Future<void> _preloadNext(int generation, int serial) async {
    bool stale() => generation != _generation || serial != _preloadSerial || !_mayPreload;
    final next = _nextSegment();
    if (stale() || app.client == null || next == null || _preloaded != null) return;
    final segment = next.segment;
    final pick = segment.item == null ? null : _pick(segment.item!);
    final item = pick?.item;
    final client = pick?.client;
    if (item == null || client == null) {
      _diagnostics?.event('next segment ${_label(segment)}: nothing to play, not preloaded');
      return;
    }
    if (!await _playsDirect(segment)) {
      _diagnostics?.event('next segment ${_label(segment)}: converted, not preloaded');
      return;
    }
    if (stale()) return;
    final url = client.streamUri(item.sourceId);
    final (routed, headers) = await _route(url, client,
        cache: (source: item.sourceId, etag: item.etag, size: item.size), start: next.start, preload: true);
    if (stale()) return;
    final enqueueing = _enqueueing =
        media.enqueue(routed, headers: headers, start: next.start, end: segment.itemTo, subtitles: _openChoice(pick, null));
    try {
      await enqueueing;
    } on Object catch (e) {
      _diagnostics?.event('preload of ${_label(segment)} failed: $e');
      return;
    } finally {
      if (identical(_enqueueing, enqueueing)) _enqueueing = null;
    }
    if (stale()) {
      await media.clearQueue();
      return;
    }
    _preloaded = _Preload(segment, next.start, generation, url, routed, pick);
    _diagnostics?.event('preloaded ${_label(segment)} from ${next.start} (hand-over in '
        '${_segmentEnd?.difference(viewNow()).inMilliseconds} ms)');
  }

  /// A segment as the diagnostics name it.
  static String _label(ScheduledProgram? s) {
    if (s == null) return '-';
    if (s.item == null) return 'off-air';
    String t(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
    return '${s.isCommercial ? 'commercial' : 'part'}:"${s.title}"@${t(s.itemFrom)}-${t(s.itemTo)}s';
  }

  /// The HANDOVER line, a second after [h]'s picture: with the longest time
  /// between two pictures since just before it started, and how long its
  /// picture took from the hand-over itself.
  void _logHandover(_Handover h) {
    final d = _diagnostics;
    if (d == null) return;
    final after = h.since.elapsed;
    Timer(const Duration(seconds: 1), () async {
      Duration? gap;
      try {
        gap = await media.debugFrameGap(h.since.elapsed + const Duration(seconds: 1));
      } on Object {
        gap = null;
      }
      d.handover(h.from, h.to, preloaded: h.preloaded, trigger: h.trigger, gap: gap, after: after);
    });
  }

  /// When the segment on now hands over to the next (tests).
  @visibleForTesting
  DateTime? get segmentEndsAt => _segmentEnd;

  /// Called just before each open; [landing] is where its position starts.
  void _expectFirstFrame(Duration landing) {
    _awaitingFirstFrame = true;
    _landing = landing;
    _lastTick = null;
    _keyframeJoin = null;
    // The new file's bitrate is read once it plays.
    app.playingBitrate.value = null;
  }

  /// The open's first frame: two position ticks in a row, near where the
  /// open should land, moving forward by less than a second. Seeks and resets
  /// jump or stand still, and a late tick from the file before is far away.
  void _onPosition(Duration position) {
    _live?.moved(position, _clock());
    _justResumed = false;
    if (!_awaitingFirstFrame) return;
    // A live stream's timeline starts wherever the broadcast is.
    if (_live == null && (position - _landing).abs() > const Duration(seconds: 30)) {
      _lastTick = null;
      return;
    }
    final last = _lastTick;
    _lastTick = position;
    if (last == null) return;
    final moved = position - last;
    if (moved <= Duration.zero || moved >= const Duration(seconds: 1)) return;
    _awaitingFirstFrame = false;
    _onFirstFrame(last);
  }

  /// Playback of the open now (or the preloaded segment handed over to)
  /// started at [startedAt] in its media.
  void _onFirstFrame(Duration startedAt) {
    if (_live != null) {
      _onLiveFirstFrame();
      return;
    }
    final handover = _handover;
    _handover = null;
    if (handover != null && handover.preloaded) {
      if (!_mayPreload) return;
      _mayFallBack = false;
      // From off air: the card goes once the picture is up.
      _setStatus(TunerStatus.playing);
      unawaited(flushReports());
      _beginReport();
      if (prefetch) _armPrefetch();
      _logHandover(handover);
      _armPreload();
      return;
    }
    // An open that reported an error but plays all the same counts too.
    if (status != TunerStatus.tuning && status != TunerStatus.error) return;
    final join = _keyframeJoin;
    _keyframeJoin = null;
    if (join != null && join.generation == _generation) {
      // The keyframe was before the join point: the part ends that much
      // later, so its ending isn't cut. The next segment opens at its
      // scheduled position, so the difference comes out of its start.
      final early = join.startAt - startedAt;
      if (early > const Duration(milliseconds: 500) && early < const Duration(seconds: 30)) {
        _endSegmentAt(join.end.add(early), join.generation);
        _diagnostics?.event('keyframe join ${early.inMilliseconds} ms early; the part ends that much later');
      }
    }
    _diagnostics?.firstPicture();
    _setStatus(TunerStatus.playing);
    // A conversion that has to draw in other subtitles opens again now
    // that its job surely runs (so stopping it can't miss).
    if (_subtitleReopenPending) {
      _subtitleReopenPending = false;
      _reopenForSubtitles();
      return;
    }
    // The stream is up: the app's own requests may go now.
    unawaited(flushReports());
    _beginReport();
    // Opened while paused: it holds here until the resume.
    if (paused) _holdPicture();
    if (prefetch) _armPrefetch();
    // A spare connection was used by this open.
    _warmConnections();
    _fillDue = _proxy != null;
    if (handover != null) _logHandover(handover);
    _armPreload();
  }

  void _armPrefetch() {
    _cancelPrefetch();
    _prefetchArmed = true;
    _prefetchTimer = Timer(prefetchAfter, _prefetchNow);
  }

  void _cancelPrefetch() {
    _prefetchArmed = false;
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
  }

  /// [_armPrefetch]'s time came (or mpv has enough buffered). A stream
  /// opening meanwhile has the network to itself; its picture arms it again.
  void _prefetchNow() {
    if (!_prefetchArmed) return;
    _cancelPrefetch();
    if (status == TunerStatus.playing) _prefetchDecisions();
  }

  /// Asks Jellyfin ahead of time for the decisions the next tunes are likely
  /// to need, so they don't wait for PlaybackInfo: the next program on this
  /// channel and what's on the channels one up and one down. Jellyfin still
  /// decides (design D1). Only with a cap set, or on Android; otherwise
  /// nothing is asked.
  void _prefetchDecisions() {
    if (app.client == null || channel == null) return;
    for (final p in _likelyNext()) {
      final item = _pick(p.item!)?.item;
      if (item == null) continue;
      // The profile's cap, lowered by the server's quality limit.
      final cap = _capFor(item);
      if (cap == null && !app.decidesEverySegment) continue;
      final source = item.sourceId;
      if (app.savedDecision(source, cap) != null || app.deciding(source, cap)) continue;
      // The join position doesn't matter: opening sets the real one. A tune
      // there meanwhile awaits this request.
      unawaited(app.decide(source, cap).then(
          (d) => _diagnostics?.event('prefetched decision for $source: ${_decided(d.template, d.directStream)}'),
          // Tuning there asks again.
          onError: (Object e) => debugPrint('Playback decision prefetch failed: $e')));
    }
  }

  /// Records how far the viewing got before the segment playing changes.
  void _noteReached({required bool atSegmentEnd}) {
    final report = _report;
    final previous = segment;
    final ch = channel;
    if (report == null || previous == null || ch == null) return;
    if (viewingOf(ch.id, previous) != report.viewing) return;
    // A part that played to its end reached its end; otherwise, as far as
    // the player got.
    final reached = atSegmentEnd ? previous.itemTo : _itemPosition;
    if (reached > report.reached) report.reached = reached;
  }

  // ---- Jellyfin playback reporting ---------------------------------------
  // Shows the stream on the server dashboard. Programs stopped partway are
  // reported at the resume point they had before, so channel surfing neither
  // fills the user's "Continue Watching" row nor wipes a resume point;
  // programs watched to the end count as watched. With "Update watch
  // status" off, nothing is reported (play-reporting).

  /// How long a viewing's resume point read may take before 0 is used.
  static const resumeReadTimeout = Duration(seconds: 5);

  /// Reports the viewing being opened, at its first picture: its resume
  /// point is read, then the start is sent, then progress every
  /// [progressEvery]. With reports off, nothing is sent: a conversion
  /// is kept alive with the server's ping instead.
  void _beginReport() {
    final report = _report;
    if (report == null || report.started) return;
    report.started = true;
    final client = report.client;
    _progress?.cancel();
    if (!report.reports) {
      _progress = Timer.periodic(progressEvery, (_) {
        final job = _active;
        if (job != null) _quietly(() => job.client.keepTranscodeAlive(job.playSessionId));
      });
      return;
    }
    // Read before the start report, so it's the point from before this
    // viewing; it never holds the picture. A viewing that ends before the
    // read does is never reported.
    unawaited(client.resumePoint(report.item.id).timeout(resumeReadTimeout).then<Duration>((d) => d,
        onError: (Object e) {
      debugPrint('Resume point of ${report.item.id} unread: $e');
      return Duration.zero;
    }).then((resume) async {
      if (report.ended) return;
      report.resumePoint = resume;
      report.startSent = true;
      await _quietly(() => client.reportPlaybackStart(_reportAt(report, report.reached)));
    }));
    _progress = Timer.periodic(progressEvery, (_) {
      if (!report.startSent) return;
      final current = segment;
      if (current != null && !current.isBreak && current.item?.id == report.item.id) {
        final position = _itemPosition;
        if (position > report.reached) report.reached = position;
        _quietly(() => client.reportPlaybackProgress(_reportAt(report, position, paused: paused)));
      } else {
        // During its breaks the program is paused where it stopped.
        _quietly(() => client.reportPlaybackProgress(_reportAt(report, report.reached, paused: true)));
      }
    });
  }

  /// Ends the viewing being reported: as watched when it got to the end,
  /// otherwise (or when Truncate cut it) at its earlier resume point (see
  /// [stoppedPosition]). The report is queued (see [flushReports]); a
  /// viewing that never started, or was opened with reports off, sends
  /// nothing.
  void _queueFinish() {
    _progress?.cancel();
    _progress = null;
    final report = _report;
    _report = null;
    if (report == null) return;
    report.ended = true;
    if (!report.started || !report.reports || !report.startSent) return;
    final position = stoppedPosition(report.item, report.reached, resumePoint: report.resumePoint, cut: report.cut);
    _stoppedQueue.add((report.client, _reportAt(report, position)));
    _stoppedTimer ??= Timer(stoppedReportDelay, () => unawaited(flushReports()));
  }

  /// Sends the queued "stopped" reports: at a picture, [stoppedReportDelay]
  /// after the tune that queued them, on stop, and when quitting (an exit
  /// hook, so a viewing is never left open on the server).
  Future<void> flushReports() async {
    _stoppedTimer?.cancel();
    _stoppedTimer = null;
    if (_stoppedQueue.isEmpty) return;
    final queued = [..._stoppedQueue];
    _stoppedQueue.clear();
    await Future.wait([for (final (client, report) in queued) _quietly(() => client.reportPlaybackStopped(report))]);
  }

  /// A report for [report]'s viewing: while one of its parts transcodes,
  /// with that job's session (which also keeps the job alive on the
  /// server); otherwise as the viewing's direct play.
  PlaybackReport _reportAt(_Report report, Duration position, {bool paused = false}) {
    final job = _active;
    final transcoding = job != null && job.itemId == report.item.id;
    return PlaybackReport(
      itemId: report.item.id,
      playSessionId: transcoding ? job.playSessionId : report.sessionId,
      position: position,
      isPaused: paused,
      runtime: report.item.runtime,
      playMethod: !transcoding
          ? PlayMethod.directPlay
          : job.directStream
              ? PlayMethod.directStream
              : PlayMethod.transcode,
    );
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (e) {
      debugPrint('Jellyfin request failed: $e');
    }
  }

  static String _newSessionId() {
    final rng = Random();
    return List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join();
  }

  // ---- Transcoding ---------------------------------------------------------

  static bool _isProgramPart(ScheduledProgram s) => !s.isBreak && s.item != null && !s.isCommercial;

  /// A decision as the diagnostics name it.
  static String _method(Uri? template, bool directStream) =>
      template == null ? 'direct' : (directStream ? 'direct-stream' : 'transcode');

  /// A decision for the diagnostics, with Jellyfin's reasons for a conversion.
  static String _decided(Uri? template, bool directStream) => template == null
      ? 'direct'
      : '${_method(template, directStream)} (${template.queryParameters['TranscodeReasons'] ?? 'no reasons given'})';

  /// Where in the program's video the player is. A transcode starts at 0
  /// where it joined.
  Duration get _itemPosition => _pausedPosition ?? media.position + (_active?.timeOffset ?? Duration.zero);

  /// Opens [current] as a new transcode job joined at [startAt] (Jellyfin
  /// seeks; mpv never does). False if it failed.
  /// [capKbps] is the cap it was decided under (null for none).
  Future<bool> _openTranscode(int generation, ScheduledProgram current, MediaEntry item, Uri template,
      Duration startAt, MediaServer client,
      {required int? capKbps, bool fallback = false, bool directStream = false}) async {
    // A track the server has to draw in, when it's the one captions show.
    final known = captions ? _subtitlesKnown[item.sourceId] : null;
    final job = _active = _Transcode(
        playSessionId: _newSessionId(),
        client: client,
        item: item,
        template: template,
        joinedAt: startAt,
        sourceTime: client.transcodeKeepsSourceTime,
        capKbps: capKbps,
        fallback: fallback,
        directStream: directStream,
        burn: known == null ? null : _burnOf(_trackFor(item, known)));
    _mayFallBack = false;
    _armStartup(generation, restart: false);
    try {
      final url = await client.transcodeUri(template, playSessionId: job.playSessionId, startAt: startAt, burn: job.burn);
      // A stream in the source's own times plays from the join point to the
      // part's end; one that starts where it joined, from 0.
      final start = job.sourceTime ? startAt : null;
      final end = job.sourceTime ? current.itemTo : current.itemTo - startAt;
      _diagnostics?.opened(
          '${fallback ? 'transcode-fallback' : _method(template, directStream)}${capKbps == null ? '' : '@${capKbps}kbps'}', url,
          start: start, end: end);
      _expectFirstFrame(start ?? Duration.zero);
      final (routed, headers) = await _route(url, client);
      if (generation != _generation) return false;
      _readingFrom(routed);
      final pick = _playing;
      await media.open(routed,
          headers: headers,
          start: start,
          end: end,
          subtitles: pick == null || pick.item.sourceId != item.sourceId ? null : _openChoice(pick, job));
      _diagnostics?.openReturned();
    } on Object catch (e) {
      if (generation != _generation) return false;
      _fail('$e');
      return false;
    }
    return generation == _generation;
  }

  /// The startup budget for a transcode, counted from its request.
  void _armStartup(int generation, {bool restart = true}) {
    if (!restart && (_startup?.isActive ?? false)) return;
    _startup?.cancel();
    _startup = Timer(transcodeStartup, () {
      if (generation != _generation || status != TunerStatus.tuning) return;
      _diagnostics?.event('transcode startup timeout');
      _fail('The server took too long to start converting this program.');
    });
  }

  /// A failure while opening falls back to a transcode once (with the
  /// setting on, or on Android); otherwise, and after playback started, the error state
  /// shows until the next segment.
  void _onPlaybackError(String message) {
    if (_live != null) {
      _onLiveError(message);
      return;
    }
    // A stream that gave up while paused opens again at the resume, and a
    // resume that fails reopens once before it counts.
    if (paused && status == TunerStatus.playing) {
      _reopenOnResume = true;
      return;
    }
    if (_justResumed) {
      _justResumed = false;
      _diagnostics?.event('resume failed ($message); reopening');
      unawaited(_playCurrent(++_generation, trigger: 'resume', quiet: true, exact: true));
      return;
    }
    final handingOver = _handover?.preloaded == true;
    if (!handingOver && status != TunerStatus.tuning && status != TunerStatus.playing) return;
    // Another server has a copy (multi-server): if this one can't be
    // reached, that copy opens at the same position.
    final playing = _playing;
    final entry = segment?.item;
    if (playing != null && entry != null && app.hasOtherCopy(entry, playing.key)) {
      final generation = _generation;
      unawaited(() async {
        if (await _failOver(generation) || generation != _generation) return;
        _onPlaybackErrorHere(message);
      }());
      return;
    }
    _onPlaybackErrorHere(message);
  }

  /// [_onPlaybackError] once no other copy is to be tried.
  void _onPlaybackErrorHere(String message) {
    if (_live != null) return;
    final handingOver = _handover?.preloaded == true;
    if (!handingOver && status != TunerStatus.tuning && status != TunerStatus.playing) return;
    if (status == TunerStatus.tuning && _mayFallBack) {
      _diagnostics?.event('fallback to transcode because of: $message');
      unawaited(_fallBack(_generation));
      return;
    }
    // A preloaded program part that fails before its picture converts, as
    // it would have at an open.
    if (_handover?.preloaded == true && _mayFallBack) {
      _diagnostics?.event('preloaded segment failed; fallback to transcode because of: $message');
      _handover = null;
      _setStatus(TunerStatus.tuning);
      unawaited(_fallBack(_generation));
      return;
    }
    _fail(message);
  }

  /// When the server the segment on now plays from doesn't answer and
  /// another server has a copy (multi-server D5): marks it Can't be reached
  /// and opens the next copy at the scheduled position. False when there's
  /// nothing to fail over to, or the server answers.
  Future<bool> _failOver(int generation) async {
    final playing = _playing;
    final entry = segment?.item;
    if (playing == null || entry == null || !app.hasOtherCopy(entry, playing.key)) return false;
    if (await app.serverAnswers(playing.key)) return false;
    if (generation != _generation) return true;
    app.markUnreachable(playing.key);
    final next = _pick(entry);
    _diagnostics?.event('server ${playing.key} unreachable');
    PlaybackDiagnostics.note('SERVER', '${playing.key} → ${next?.key ?? '-'}');
    await _playCurrent(++_generation, trigger: 'failover', quiet: true, exact: true);
    return true;
  }

  Future<void> _fallBack(int generation) async {
    _mayFallBack = false;
    final current = segment;
    final item = _playing?.item;
    final client = _playing?.client;
    if (current == null || item == null || client == null) return;
    _diagnostics?.tuneStarted('fallback', 'ch=${channel?.number}');
    _armStartup(generation);
    // Under the cap this open was decided with.
    final cap = _capFor(item);
    final PlaybackDecision decision;
    try {
      decision = await client.playbackDecision(item.sourceId,
          maxBitrate: cap == null ? null : cap * 1000,
          forceTranscode: true,
          startAt: current.positionAt(viewNow()),
          profile: app.decidesEverySegment ? await app.deviceProfile(cap) : null);
    } on Object catch (e) {
      if (generation != _generation) return;
      if (e is ServerException && e.unreachable && await _failOver(generation)) return;
      _fail('$e');
      return;
    }
    if (generation != _generation) return;
    // The scheduled position for this moment, not where the failed open was.
    final startAt = current.positionAt(viewNow());
    var template = decision.transcodeTemplate!;
    // On Android, with no cap, at what keeps the original picture.
    if (app.decidesEverySegment && cap == null) {
      template = limitConversion(template, sourceBitrate: decision.sourceBitrate, sourceCodec: decision.sourceCodec);
    }
    if (await _openTranscode(generation, current, item, template, startAt, client,
        capKbps: cap, fallback: true)) {
      await _applyCaptions();
    }
  }

  void _fail(String message) {
    _diagnostics?.event('fail while ${status.name}: $message (stops transcode ${_active?.playSessionId})');
    _diagnostics?.tuneFailed(message);
    _mayFallBack = false;
    // A time the viewer chose: they go live rather than wait on a card.
    if (shifted) {
      unawaited(goLive(notice: couldntPlayNotice));
      return;
    }
    _stopTranscode();
    unawaited(_dropPreload());
    error = message;
    _setStatus(TunerStatus.error);
    // A Plex server may answer at another address now: tune again there.
    final generation = _generation;
    unawaited(app.reachServerAgain().then((moved) {
      if (moved && generation == _generation && status == TunerStatus.error) unawaited(_retuneInPlace());
    }));
  }

  /// Stops the active transcode job, if any. Tuning doesn't wait for the
  /// server to answer.
  void _stopTranscode() {
    _startup?.cancel();
    final job = _active;
    _active = null;
    if (job == null) return;
    _diagnostics?.event('stop transcode ${job.playSessionId} (status ${status.name})');
    unawaited(_quietly(() => job.client.stopTranscode(job.playSessionId).timeout(const Duration(seconds: 5))));
  }

  /// Stops the active transcode job and waits (briefly) for the server, for
  /// when the app is quitting.
  Future<void> stopTranscodeForExit() async {
    _startup?.cancel();
    final job = _active;
    _active = null;
    if (job == null) return;
    await _quietly(() => job.client.stopTranscode(job.playSessionId).timeout(exitTimeout));
  }

  // ---- Timeshift (timeshift spec) ----------------------------------------------
  // A generated channel's schedule is arithmetic on the clock and its files
  // stay on the server, so watching behind it is a time offset: nothing is
  // recorded. All schedule work reads [viewNow]; timers are differences on
  // that one timeline.

  /// The furthest behind a viewer may be.
  static const maxBehind = Duration(hours: 4);

  /// How far back a program shorter than this can always be rewound.
  static const rewindWindow = Duration(minutes: 30);

  /// Paused this long, the stream reopens at the resume: its connections
  /// will have gone idle (the proxy's idle timeout).
  static const reopenAfter = Duration(minutes: 2);

  /// Key presses within this of each other make one seek.
  static const seekDebounce = Duration(milliseconds: 400);

  /// A paused transcode's job stops after this.
  @visibleForTesting
  Duration pausedJobStop = const Duration(seconds: 30);

  static const backToLiveNotice = 'Back to live';
  static const couldntPlayNotice = "Couldn't play that part. Back to live";

  Duration _shift = Duration.zero;

  /// The viewing time while paused.
  DateTime? _frozen;
  DateTime? _pausedWall;

  /// Where in the item the picture was held.
  Duration? _pausedPosition;
  Timer? _pausedJobTimer;

  /// The open stream can't go on from the pause (a stopped job, a stream
  /// that gave up).
  bool _reopenOnResume = false;
  bool _justResumed = false;

  /// The schedule in use while behind: scans and edits don't disturb it.
  ProgramSchedule? _pinned;

  /// Where key presses have moved to, until the seek happens.
  DateTime? _seekTarget;
  bool _seekToLive = false;
  Timer? _seekTimer;

  final _notices = StreamController<String>.broadcast();

  /// Short messages for the screen ("Back to live").
  Stream<String> get notices => _notices.stream;

  /// The schedule's time for what's being watched: the clock, behind it by
  /// the shift, or stopped while paused.
  DateTime viewNow() => _frozen ?? _clock().subtract(_shift);

  bool get paused => _frozen != null;

  /// Behind the schedule, or paused.
  bool get shifted => paused || _shift > Duration.zero;

  /// How far behind the schedule the viewer is.
  Duration get behind {
    final d = _clock().difference(viewNow());
    return d.isNegative ? Duration.zero : d;
  }

  /// The schedule what's on screen comes from.
  ProgramSchedule? get schedule {
    final ch = channel;
    return _pinned ?? (ch == null ? null : app.scheduleFor(ch));
  }

  /// The controls apply to what's on: a generated channel, with the setting
  /// on.
  bool get canTimeshift {
    final ch = channel;
    return ch != null && !ch.isLive && app.settings.playback.pauseAndRewind;
  }

  /// Where key presses have moved to, shown at once (null: none pending).
  DateTime? get seekTarget => _seekTarget;

  /// What the seek bar shows: the viewing position, within what can be
  /// reached, and where the program on screen started.
  ({DateTime from, DateTime to, DateTime position, DateTime? programStart}) get timeline {
    final position = _seekTarget ?? viewNow();
    final to = _clock();
    final earliest = earliestView();
    final programStart = program == null || program!.isOffAir ? null : _restartPoint(program!);
    var from = position.isBefore(earliest) ? position : earliest;
    if (programStart != null && programStart.isBefore(from)) from = programStart;
    return (from: from, to: to, position: position, programStart: programStart);
  }

  /// The earliest reachable viewing time: the earlier of 30 minutes ago and
  /// the start of the program on air now, within this session's schedule
  /// floor and the 4-hour limit.
  DateTime earliestView() {
    final now = _clock();
    var earliest = now.subtract(rewindWindow);
    final schedule = this.schedule;
    if (schedule == null) return now;
    final onAir = schedule.programAt(now);
    if (onAir.start.isBefore(earliest)) earliest = onAir.start;
    final floor = _floor(onAir);
    if (floor != null && earliest.isBefore(floor)) earliest = floor;
    final cap = now.subtract(maxBehind);
    return earliest.isBefore(cap) ? cap : earliest;
  }

  /// The start of the slot on air when the schedule in use last changed, so
  /// rewinding can't show a past that never aired. Never past [onAir]'s start:
  /// restarting what's on always works.
  DateTime? _floor(ScheduledProgram onAir) {
    final ch = channel;
    final changed = ch == null ? null : app.scheduleChangedAt(ch.id);
    final schedule = this.schedule;
    if (changed == null || schedule == null) return null;
    // A pinned schedule is older than any change since it was pinned.
    if (_pinned != null && _pinnedAt != null && changed.isAfter(_pinnedAt!)) return null;
    final start = schedule.programAt(changed).start;
    return start.isAfter(onAir.start) ? onAir.start : start;
  }

  DateTime? _pinnedAt;

  /// Holds on to the schedule in use: the viewer is about to be behind it.
  void _pin() {
    if (_pinned != null) return;
    _pinned = schedule;
    _pinnedAt = _clock();
  }

  /// Back on the clock: everything about being behind goes.
  void _endShift() {
    _seekTimer?.cancel();
    _seekTimer = null;
    _seekTarget = null;
    _seekToLive = false;
    _pausedJobTimer?.cancel();
    _pausedJobTimer = null;
    _shift = Duration.zero;
    _frozen = null;
    _pausedWall = null;
    _pausedPosition = null;
    _reopenOnResume = false;
    _justResumed = false;
    _pinned = null;
    _pinnedAt = null;
    _notice = null;
  }

  /// A viewer behind or paused: where they are, to come back to after the app
  /// was out of sight. Null at the live point.
  ViewingPlace? get place {
    if (!shifted || channel == null) return null;
    return ViewingPlace(pictureNow(), paused: paused, schedule: schedule);
  }

  void _noteShift(String action, {String? method}) {
    PlaybackDiagnostics.note(
        'SHIFT',
        'action=$action ch=${channel?.number} view=${viewNow().toIso8601String()} '
            'behind=${behind.inMilliseconds / 1000}s${method == null ? '' : ' method=$method'}');
  }

  /// Holds the picture and silences the sound. Only what's playing pauses:
  /// off-air, stand-by, error and tuning states don't.
  Future<void> pause() async {
    if (!canTimeshift || paused || status != TunerStatus.playing) return;
    _pin();
    _frozen = _seekTarget ?? viewNow();
    _seekToLive = false;
    _pausedWall = _clock();
    _notice = null;
    _programEnd?.cancel();
    _noteShift('pause');
    notifyListeners();
    _holdPicture();
    await _dropPreload();
    if (_seekTarget != null) await _applySeek();
  }

  /// The player holds what it shows; the server's told, and a transcode's job
  /// is stopped before long.
  void _holdPicture() {
    final seg = segment;
    _pausedPosition = seg?.item == null ? _itemPosition : seg!.positionAt(viewNow());
    unawaited(media.pause().catchError((Object e) {
      _diagnostics?.event('pause failed: $e');
      _reopenOnResume = true;
    }));
    _reportNow();
    _pausedJobTimer?.cancel();
    if (_active == null) return;
    _pausedJobTimer = Timer(pausedJobStop, () {
      if (!paused || _active == null) return;
      _reopenOnResume = true;
      _stopTranscode();
    });
  }

  /// A progress report at once: the dashboard shows a pause or resume now
  /// (none with reports off, or before the start is sent).
  void _reportNow() {
    final report = _report;
    if (report == null || !report.started || !report.reports || !report.startSent) return;
    final current = segment;
    final position = current != null && !current.isBreak && current.item?.id == report.item.id ? _itemPosition : report.reached;
    final client = report.client;
    final at = _reportAt(report, position, paused: paused);
    unawaited(_quietly(() => client.reportPlaybackProgress(at)));
  }

  /// Goes on from the paused place, now behind by the time paused.
  Future<void> resume() async {
    final frozen = _frozen;
    if (frozen == null) return;
    final now = _clock();
    if (now.difference(frozen) > maxBehind) {
      await goLive(notice: backToLiveNotice);
      return;
    }
    final pausedFor = now.difference(_pausedWall ?? now);
    final reopen = _reopenOnResume || pausedFor >= reopenAfter || status != TunerStatus.playing;
    // A reopen lands exactly where the picture was: a keyframe join's picture
    // runs behind the viewing time.
    final view = reopen ? pictureNow() : frozen;
    final seek = _seekTarget;
    _frozen = null;
    _pausedWall = null;
    _pausedPosition = null;
    _pausedJobTimer?.cancel();
    _pausedJobTimer = null;
    _reopenOnResume = false;
    _shift = now.difference(seek ?? view);
    if (_shift.isNegative) _shift = Duration.zero;
    _noteShift('resume', method: reopen ? 'reopen' : 'resume');
    notifyListeners();
    if (seek != null) {
      _seekTimer?.cancel();
      _seekTarget = null;
      _seekToLive = false;
      await _moveTo(seek, wasPaused: true);
      return;
    }
    if (_shift == Duration.zero) {
      _pinned = null;
      _pinnedAt = null;
    }
    if (reopen) {
      await _playCurrent(++_generation, trigger: 'resume', quiet: true, exact: true);
      return;
    }
    final generation = _generation;
    _justResumed = true;
    try {
      await media.resume();
    } on Object catch (e) {
      if (generation != _generation) return;
      _justResumed = false;
      _diagnostics?.event('resume failed ($e); reopening');
      await _playCurrent(++_generation, trigger: 'resume', quiet: true, exact: true);
      return;
    }
    if (generation != _generation) return;
    if (_segmentEnd case final end?) _endSegmentAt(end, generation);
    _armPreload();
    _reportNow();
  }

  Future<void> togglePause() => paused ? resume() : pause();

  /// Moves the pending seek by [by]; the seek happens [seekDebounce] after the
  /// last press.
  void skip(Duration by) {
    if (!canTimeshift) return;
    seekTo((_seekTarget ?? viewNow()).add(by));
  }

  /// Moves the pending seek to [target], within what can be reached: forward
  /// up to the live point, back to the start of the window (a viewer already
  /// earlier than that isn't moved forward).
  void seekTo(DateTime target) {
    if (!canTimeshift) return;
    final now = _clock();
    final from = _seekTarget ?? viewNow();
    final earliest = earliestView();
    final floor = from.isBefore(earliest) ? from : earliest;
    _seekToLive = !target.isBefore(now);
    _seekTarget = _seekToLive ? now : (target.isBefore(floor) ? floor : target);
    _seekTimer?.cancel();
    _seekTimer = Timer(seekDebounce, () => unawaited(_applySeek()));
    notifyListeners();
  }

  /// Plays the program on screen from its first picture.
  Future<void> restart() async {
    final slot = program;
    if (!canTimeshift || slot == null || slot.item == null) return;
    final wasPaused = paused;
    var target = _restartPoint(slot);
    final floor = _floor(schedule?.programAt(_clock()) ?? slot);
    if (floor != null && target.isBefore(floor)) target = floor;
    final cap = _clock().subtract(maxBehind);
    if (target.isBefore(cap)) target = cap;
    _seekTimer?.cancel();
    _seekTarget = null;
    _seekToLive = false;
    _noteShift('restart');
    // Restarting plays.
    _frozen = null;
    _pausedPosition = null;
    _pausedWall = null;
    _pausedJobTimer?.cancel();
    final lost = _reopenOnResume;
    _reopenOnResume = false;
    await _moveTo(target, wasPaused: wasPaused || lost);
  }

  DateTime _restartPoint(ScheduledProgram slot) => switch (schedule) {
        final ChannelSchedule s => s.firstPictureOf(slot),
        _ => slot.start,
      };

  /// Returns to what's airing now, playing. [notice]: shown as it does.
  Future<void> goLive({String? notice}) async {
    if (notice != null) _notices.add(notice);
    if (!shifted) {
      if (_seekTarget != null) {
        _endShift();
        notifyListeners();
      }
      return;
    }
    _noteShift('go-live', method: 'reopen');
    _endShift();
    notifyListeners();
    await _playCurrent(++_generation, trigger: 'go-live', quiet: true);
  }

  /// The pending seek's time has come.
  Future<void> _applySeek() async {
    final target = _seekTarget;
    if (target == null) return;
    final toLive = _seekToLive;
    _seekTimer?.cancel();
    _seekTarget = null;
    _seekToLive = false;
    if (paused) {
      _frozen = target;
      await _moveTo(target);
    } else if (toLive) {
      if (shifted) await _moveToLive();
    } else {
      await _moveTo(target);
    }
  }

  /// A forward skip reached the live point.
  Future<void> _moveToLive() async {
    final pinned = _pinned;
    final same = pinned == null || identical(pinned, channel == null ? null : app.scheduleFor(channel!));
    _pinned = null;
    _pinnedAt = null;
    _shift = Duration.zero;
    await _seekOrReopen(_clock(), reopen: !same);
    notifyListeners();
  }

  /// Watches from [target] on, behind the schedule by what that leaves.
  /// [wasPaused]: the picture is held and must play again.
  Future<void> _moveTo(DateTime target, {bool wasPaused = false}) async {
    _pin();
    if (!paused) {
      final d = _clock().difference(target);
      _shift = d.isNegative ? Duration.zero : d;
    }
    await _seekOrReopen(target, reopen: wasPaused);
    notifyListeners();
  }

  /// Inside the direct-played segment on screen, the open stream seeks;
  /// anywhere else the existing open path runs at the viewing time, exact and
  /// with no channel number.
  Future<void> _seekOrReopen(DateTime target, {bool reopen = false}) async {
    final seg = segment;
    final inSegment = !reopen &&
        status == TunerStatus.playing &&
        !_awaitingFirstFrame &&
        _active == null &&
        !_reopenOnResume &&
        seg != null &&
        seg.item != null &&
        seg.isOnAt(target);
    _noteShift('seek', method: inSegment ? 'seek' : 'reopen');
    _notice = null;
    if (!inSegment) {
      await _playCurrent(++_generation, trigger: 'seek', quiet: true, exact: true);
      return;
    }
    _noteReached(atSegmentEnd: false);
    final generation = ++_generation;
    await _dropPreload();
    if (generation != _generation) return;
    final position = seg.positionAt(target);
    if (paused) _pausedPosition = position;
    try {
      await media.seek(position);
    } on Object catch (e) {
      if (generation != _generation) return;
      _diagnostics?.event('seek failed ($e); reopening');
      await _playCurrent(++_generation, trigger: 'seek', quiet: true, exact: true);
      return;
    }
    if (generation != _generation) return;
    _keyframeJoin = null;
    _endSegmentAt(seg.end, generation);
    _armPreload();
  }

  // ---- Live channels (live-playback) -------------------------------------------

  /// The live stream on now (or opening), with its reports and reconnects.
  _LiveSession? _live;

  /// What the stand-by or failure card says on a live channel.
  String? liveMessage;

  /// The channel on now is live.
  bool get isLive => channel?.isLive ?? false;

  /// How long a live stream may take to show its first picture.
  @visibleForTesting
  Duration liveStartTimeout = const Duration(seconds: 20);

  /// A live picture that stands still this long reconnects; it's looked
  /// at every [liveStallCheck].
  @visibleForTesting
  Duration liveStall = const Duration(seconds: 10);
  @visibleForTesting
  Duration liveStallCheck = const Duration(seconds: 1);

  /// Server Live TV progress reports go this often.
  @visibleForTesting
  Duration liveReportEvery = _progressInterval;

  /// Waits between reconnects: these, then [liveRetryEvery].
  @visibleForTesting
  List<Duration> liveRetries = const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  @visibleForTesting
  Duration liveRetryEvery = const Duration(seconds: 30);

  /// Closing a live stream may hold up the next open, or quitting, this
  /// long at most.
  static const liveCloseTimeout = Duration(seconds: 2);

  Timer? _liveBoundary;
  Timer? _liveRetry;

  /// Live channel [ch]'s current programme as what's on, and the timer that
  /// moves it on at the guide's next boundary (the stream plays on).
  void _setLiveProgramme(Channel ch, int generation) {
    _liveBoundary?.cancel();
    final schedule = app.scheduleFor(ch);
    if (schedule == null) return;
    final now = _clock();
    program = segment = schedule.programAt(now);
    final wait = program!.end.difference(now);
    _liveBoundary = Timer(wait.isNegative ? Duration.zero : wait + const Duration(milliseconds: 1), () {
      if (generation != _generation || channel?.id != ch.id) return;
      _setLiveProgramme(ch, generation);
      notifyListeners();
    });
  }

  /// Opens live channel [ch] (design D8). [attempt] counts reconnects.
  Future<void> _playLive(int generation, Channel ch, {int attempt = 0}) async {
    _programEnd?.cancel();
    _segmentEnd = null;
    _liveRetry?.cancel();
    _queueFinish();
    unawaited(flushReports());
    _stopTranscode();
    _setLiveProgramme(ch, generation);
    if (attempt == 0) {
      liveMessage = null;
      error = null;
      _changingChannel = true;
      _setStatus(TunerStatus.tuning);
    }
    // One live stream at a time: the one open goes first, so its tuner or
    // connection is free for this one.
    await _closeLive(wait: true);
    if (generation != _generation) return;
    final found = app.live.lookup(ch);
    final source = found?.source;
    final client = source == null ? null : app.live.clientFor(source);
    if (found == null || source == null || client == null) {
      _liveFailed(generation, ch, LiveFailure.unreachable, 'the source is not available', source: source, attempt: attempt);
      return;
    }
    final info = found.info;
    if (PlatformInfo.isAndroid && source.kind == LiveSourceKind.m3u) {
      final scheme = Uri.tryParse(info.url ?? '')?.scheme.toLowerCase();
      if (!const {'http', 'https', 'rtsp'}.contains(scheme)) {
        _liveFailed(generation, ch, LiveFailure.unsupportedScheme, 'scheme $scheme', source: source, attempt: attempt, retry: false);
        return;
      }
    }
    final session = _live = _LiveSession(ch, source, client, generation, attempt);
    _diagnostics?.tuneStarted(attempt == 0 ? 'live' : 'live-reconnect', 'ch=${ch.number} ${source.kind.name}');
    session.startTimer = Timer(liveStartTimeout, () {
      if (!identical(_live, session) || session.pictured) return;
      _liveFailed(generation, ch, LiveFailure.other, 'no picture in ${liveStartTimeout.inSeconds} s',
          source: source, attempt: attempt, message: "${ch.name} didn't start");
    });
    final opening = Completer<LiveStream?>();
    session.opening = opening.future;
    final LiveStream stream;
    try {
      final cap = app.capInEffect;
      stream = await client.open(info,
          maxBitrate: cap == null ? null : cap * 1000,
          profile: PlatformInfo.isAndroid ? await app.deviceProfile(cap) : null);
    } on Object catch (e) {
      opening.complete(null);
      if (!identical(_live, session)) return;
      final failure = e is LiveTvException ? e.failure : LiveFailure.other;
      _liveFailed(generation, ch, failure, scrubUrlsIn('$e'), source: source, attempt: attempt);
      return;
    }
    opening.complete(stream);
    if (!identical(_live, session) || generation != _generation) {
      // Superseded while it opened: closed at once, so surfing leaves
      // nothing open on the server.
      _diagnostics?.event('live: superseded open of ${ch.number} closed');
      unawaited(_quietly(() => client.close(stream)));
      return;
    }
    session.stream = stream;
    _diagnostics?.opened('live-${source.kind.name}-${stream.method.json}', Uri.parse(scrubUrl(stream.uri.toString())));
    _expectFirstFrame(Duration.zero);
    try {
      await media.open(stream.uri, headers: stream.headers, live: true, subtitles: captions ? const StreamCaptions() : null);
      _diagnostics?.openReturned();
    } on Object catch (e) {
      if (identical(_live, session)) _onLiveError('$e');
      return;
    }
    if (identical(_live, session)) await _applyCaptions();
  }

  /// The live stream's first picture (or its first after a reconnect).
  void _onLiveFirstFrame() {
    final s = _live!;
    s.pictured = true;
    s.startTimer?.cancel();
    _diagnostics?.firstPicture();
    if (s.attempt > 0) _diagnostics?.event('live: reconnected on attempt ${s.attempt}');
    liveMessage = null;
    error = null;
    _setStatus(TunerStatus.playing);
    unawaited(flushReports());
    final stream = s.stream;
    if (stream != null && s.client.reports && (app.settings.playback.reportPlayback || s.client.needsReports)) {
      s.reportedAt = DateTime.now();
      _quietly(() => s.client.reportStart(stream));
      s.reportTimer = Timer.periodic(liveReportEvery, (_) {
        if (identical(_live, s)) _quietly(() => s.client.reportProgress(stream, s.watched));
      });
    } else if (stream != null && s.client.reports) {
      // "Update watch status" off: only what keeps the stream open.
      s.reportTimer = Timer.periodic(liveReportEvery, (_) {
        if (identical(_live, s)) _quietly(() => s.client.keepAlive(stream));
      });
    }
    // A picture that stands still is a stall.
    s.stallTimer = Timer.periodic(liveStallCheck, (_) {
      if (!identical(_live, s) || status != TunerStatus.playing) return;
      if (_clock().difference(s.lastMove ?? _clock()) >= liveStall) _liveLost('stalled for ${liveStall.inSeconds} s');
    });
    s.lastMove = _clock();
  }

  /// The player failed on a live stream: before the picture, a card naming
  /// the cause; after it, a reconnect.
  void _onLiveError(String message) {
    final s = _live;
    final ch = channel;
    if (s == null || ch == null) return;
    final failure = _playerFailure(message, s.source);
    if (!s.pictured) {
      if (failure == LiveFailure.other && s.source.kind == LiveSourceKind.m3u) {
        // mpv only says it couldn't open: the provider's answer says why.
        final info = app.live.lookup(ch)?.info;
        if (info != null) {
          unawaited(s.client.causeOfFailure(info).then((cause) {
            if (!identical(_live, s)) return;
            _liveFailed(s.generation, ch, cause ?? LiveFailure.other, scrubUrlsIn(message),
                source: s.source, attempt: s.attempt);
          }));
          return;
        }
      }
      _liveFailed(s.generation, ch, failure, scrubUrlsIn(message), source: s.source, attempt: s.attempt);
    } else {
      _liveLost(scrubUrlsIn(message), failure: failure == LiveFailure.other ? null : failure);
    }
  }

  /// What a player error says about a live stream (the provider's HTTP
  /// status, a connection that failed, a decoder).
  static LiveFailure _playerFailure(String message, LiveSource source) {
    final m = message.toLowerCase();
    if (RegExp(r'\b(403|458|509)\b').hasMatch(m) && source.kind == LiveSourceKind.m3u) return LiveFailure.providerRefused;
    if (RegExp(r'\b(401|403)\b').hasMatch(m)) return LiveFailure.refused;
    if (RegExp(r'decod|codec|unsupported format|no video|mediacodec').hasMatch(m)) return LiveFailure.cantDecode;
    if (RegExp(r'connection|resolve|timed out|timeout|unreachable|refused|network|host|eof|end of file|http 5\d\d|\b50[234]\b').hasMatch(m)) {
      return LiveFailure.unreachable;
    }
    return LiveFailure.other;
  }

  /// A live stream that played dropped (ended, stalled or failed):
  /// "Reconnecting…", then "Lost the signal", reopening from the source.
  void _liveLost(String cause, {LiveFailure? failure}) {
    final s = _live;
    final ch = channel;
    if (s == null || ch == null) return;
    _diagnostics?.event('live: $cause');
    _scheduleLiveRetry(s.generation, ch, s.attempt + 1, cause: cause, failure: failure, source: s.source);
  }

  /// Opening failed (or never showed a picture): a card naming [failure],
  /// and a retry as after a drop unless [retry] is off. While reconnecting
  /// after a drop, a reopen that fails for no stated reason keeps the
  /// reconnecting card.
  void _liveFailed(int generation, Channel ch, LiveFailure failure, String detail,
      {LiveSource? source, required int attempt, bool retry = true, String? message}) {
    if (generation != _generation) return;
    // A decoder that isn't there won't be on a retry.
    if (failure == LiveFailure.cantDecode) retry = false;
    _diagnostics?.tuneFailed('live ${failure.name}: $detail');
    if (retry && attempt > 0 && (failure == LiveFailure.other || failure == LiveFailure.unreachable)) {
      _scheduleLiveRetry(generation, ch, attempt + 1, cause: detail, source: source);
      return;
    }
    if (!retry) {
      unawaited(_closeLive());
      liveMessage = message ?? liveFailureText(failure, ch, source);
      error = liveMessage;
      _setStatus(TunerStatus.error);
      return;
    }
    _scheduleLiveRetry(generation, ch, attempt + 1, cause: detail, failure: failure, source: source, message: message);
  }

  void _scheduleLiveRetry(int generation, Channel ch, int attempt,
      {required String cause, LiveFailure? failure, LiveSource? source, String? message}) {
    unawaited(_closeLive());
    final wait = attempt <= liveRetries.length ? liveRetries[attempt - 1] : liveRetryEvery;
    if (failure != null || message != null) {
      // A card naming the cause, until a retry brings the picture back.
      liveMessage = message ?? liveFailureText(failure!, ch, source);
      error = liveMessage;
      _setStatus(TunerStatus.error);
    } else {
      liveMessage = attempt <= liveRetries.length ? 'Reconnecting…' : 'Lost the signal on ${ch.name}';
      _setStatus(TunerStatus.standby);
    }
    _diagnostics?.event('live: reopen #$attempt in ${wait.inSeconds} s ($cause)');
    _liveRetry?.cancel();
    _liveRetry = Timer(wait, () {
      if (generation != _generation || channel?.id != ch.id) return;
      unawaited(_playLive(generation, ch, attempt: attempt));
    });
    notifyListeners();
  }

  /// The card for [failure] on [ch] (live-playback "Live stand-by
  /// messages").
  String liveFailureText(LiveFailure failure, Channel ch, LiveSource? source) {
    final server = app.session?.serverName ?? 'the server';
    final name = source?.name ?? 'the source';
    return switch (failure) {
      LiveFailure.tunersBusy => "All of $server's tuners are in use",
      LiveFailure.unreachable => "Can't reach $name",
      LiveFailure.refused => "Your $server account can't watch this channel",
      LiveFailure.providerRefused => '$name refused the stream. It may be playing on another device.',
      LiveFailure.unsupportedScheme => "This channel's stream type isn't supported on this device",
      LiveFailure.cantDecode => "This device can't play this channel's video",
      LiveFailure.other => "${ch.name} didn't start",
    };
  }

  /// Ends the live stream on now, if any: reported stopped and closed at
  /// the source. With [wait], until that's done (or a stream still opening
  /// has opened and been closed), at most [liveCloseTimeout].
  Future<void> _closeLive({bool wait = false}) async {
    _liveRetry?.cancel();
    final s = _live;
    _live = null;
    if (s == null) return;
    s.cancelTimers();
    Future<void> close() async {
      final stream = s.stream ?? await s.opening;
      if (stream == null || stream.closed) return;
      _diagnostics?.event('live: close ${s.channel.number}');
      if (s.reportedAt != null && s.client.reports) await _quietly(() => s.client.reportStopped(stream, s.watched));
      await _quietly(() => s.client.close(stream));
      // An IPTV connection ends with the player's: before another live
      // open (an awaited close), the player stops first. Otherwise the next
      // open replaces the stream, and a late stop must not hit it.
      if (wait && s.source.kind == LiveSourceKind.m3u && _live == null) await media.stop();
    }

    final closing = close();
    if (wait) {
      await closing.timeout(liveCloseTimeout, onTimeout: () {});
    } else {
      unawaited(closing);
    }
  }

  /// Closes the live stream when the app quits, waiting at most
  /// [liveCloseTimeout].
  Future<void> closeLiveForExit() => _closeLive(wait: true);

  // ---- Sampling --------------------------------------------------------------

  /// A segment is open (opening or playing).
  bool get _segmentOpen =>
      segment?.item != null && (status == TunerStatus.tuning || status == TunerStatus.playing);

  /// Samples mpv once a second while a segment is open.
  void _syncSampler() {
    final run = _segmentOpen;
    if (run) {
      _sampler ??= Timer.periodic(sampleEvery, (_) => unawaited(_sampleNetwork()));
    } else {
      _sampler?.cancel();
      _sampler = null;
    }
  }

  /// One sample, as the sampling timer takes it (tests).
  @visibleForTesting
  Future<void> debugSample() => _sampleNetwork();

  /// The sampling timer is running (tests).
  @visibleForTesting
  bool get debugSampling => _sampler != null;

  Future<void> _sampleNetwork() async {
    if (_sampling) return;
    if (!_segmentOpen) {
      _syncSampler();
      return;
    }
    _sampling = true;
    try {
      if (status == TunerStatus.playing && app.playingBitrate.value == null) await _readBitrate();
      final buffered = await media.bufferedSeconds();
      if (buffered == null) return;
      _buffered = buffered;
      if (_prefetchArmed && buffered >= prefetchBuffered) _prefetchNow();
      // Fills go at the analyzer's budget, which waits for the bitrate.
      if (_fillDue && _mayFill && !app.analyzerBudgetNow.paused) unawaited(_fillPass());
    } finally {
      _sampling = false;
    }
  }

  /// The playing file's average bitrate, for the analyzer's budget with no
  /// cap: as mpv has it, or from the library when mpv can't tell (a
  /// transcode's size isn't known).
  Future<void> _readBitrate() async {
    final generation = _generation;
    var bitrate = await media.averageBitrate();
    if (bitrate == null) {
      final item = segment?.item;
      final size = item?.size, seconds = item?.runtime.inMilliseconds;
      if (size != null && seconds != null && seconds > 0) bitrate = (size * 8 * 1000 / seconds).round();
    }
    if (generation == _generation && status == TunerStatus.playing) app.playingBitrate.value = bitrate;
  }

  void _setStatus(TunerStatus s) {
    // Background analysis holds off while a stream opens.
    app.playbackBusy.value = s == TunerStatus.tuning;
    app.playbackActivity.value = switch (s) {
      TunerStatus.tuning => PlaybackActivity.tuning,
      TunerStatus.playing => PlaybackActivity.playing,
      _ => PlaybackActivity.none,
    };
    if (s == TunerStatus.playing) {
      _startup?.cancel();
      _mayFallBack = false;
      // A fallback that plays settles the program as a transcode, so its
      // later parts don't fail first.
      final job = _active;
      if (job != null && job.fallback) app.saveDecision(job.item.sourceId, job.capKbps, job.template);
    }
    if (status == s) {
      _syncSampler();
      return;
    }
    _diagnostics?.event('status ${status.name} -> ${s.name}${s == TunerStatus.error ? ' ($error)' : ''}');
    final wasTuning = status == TunerStatus.tuning, wasPlaying = status == TunerStatus.playing;
    status = s;
    _syncSampler();
    final proxy = _proxy;
    if (proxy != null && _proxyReady != null) {
      // Fills hold off while a stream opens; connections are kept warm while
      // one plays.
      if (wasTuning != (s == TunerStatus.tuning)) unawaited(proxy.setTuning(s == TunerStatus.tuning).catchError((Object _) {}));
      if (wasPlaying != (s == TunerStatus.playing)) unawaited(proxy.setPlaying(s == TunerStatus.playing).catchError((Object _) {}));
    }
    if (s == TunerStatus.playing) {
      _buffered = 0;
    } else if (_fillDue && _mayFill) {
      // Nothing plays: the pass may run now.
      unawaited(_fillPass());
    }
    notifyListeners();
  }

  /// The schedule's hand-over, as if the segment playing had just ended:
  /// to what's preloaded, or by opening what's on at [clock]'s time (tests
  /// drive the schedule with this instead of waiting).
  @visibleForTesting
  Future<void> debugSegmentEnded() => _atHandover(_generation);

  /// The segment preloaded after the one on now (tests).
  @visibleForTesting
  ScheduledProgram? get preloadedSegment => _preloaded?.segment;

  Future<void> stop() async {
    _diagnostics?.tuneFailed('stopped');
    _generation++;
    _programEnd?.cancel();
    _cancelPrefetch();
    _sampler?.cancel();
    _sampler = null;
    _segmentEnd = null;
    _awaitingFirstFrame = false;
    _keyframeJoin = null;
    _handover = null;
    _noteReached(atSegmentEnd: false);
    _endShift();
    await _dropPreload();
    // Nothing is opening: what's queued goes now.
    _queueFinish();
    await flushReports();
    _stopTranscode();
    // Android out of sight, or full-screen settings: the live stream's
    // tuner or connection is freed.
    _liveBoundary?.cancel();
    await _closeLive(wait: true);
    await media.stop();
    // Nothing plays (Android: out of sight): no pings, no fills.
    _fillDue = false;
    if (_proxyReady != null) unawaited(_proxy!.setBackground(true).catchError((Object _) {}));
    channel = null;
    program = null;
    segment = null;
    _setStatus(TunerStatus.idle);
  }

  @override
  void dispose() {
    _liveBoundary?.cancel();
    unawaited(_closeLive());
    _programEnd?.cancel();
    _cancelPreloadTimers();
    _progress?.cancel();
    _stoppedTimer?.cancel();
    _cancelPrefetch();
    unawaited(_proxyEvents?.cancel());
    unawaited(_proxy?.close());
    _sampler?.cancel();
    _stopTranscode();
    unawaited(_diagnostics?.close());
    app.volumeLeveling.removeListener(_onLevelingChanged);
    app.captionSize.removeListener(_onCaptionSizeChanged);
    app.removeListener(_onSettingsChanged);
    _seekTimer?.cancel();
    _pausedJobTimer?.cancel();
    unawaited(_notices.close());
    for (final s in _subscriptions) {
      s.cancel();
    }
    media.dispose();
    super.dispose();
  }
}

/// Where a viewer behind the schedule was, to return to (timeshift D12).
class ViewingPlace {
  const ViewingPlace(this.view, {required this.paused, required this.schedule});

  final DateTime view;
  final bool paused;

  /// The schedule they were watching.
  final ProgramSchedule? schedule;
}

/// One viewing being reported to Jellyfin, across the program's parts.
class _Report {
  _Report(this.client, this.item, this.sessionId, this.viewing,
      {this.key = ServerSet.mainKey, this.reports = true});

  final MediaServer client;

  /// The server [client] is (multi-server).
  final String key;
  final MediaEntry item;
  final String sessionId;
  Viewing viewing;

  /// "Update watch status" was on when the viewing opened: it's reported
  /// to its end, whatever the setting does meanwhile (play-reporting).
  final bool reports;

  /// It began reporting (at the viewing's first picture).
  bool started = false;

  /// The item's resume point from before the viewing (0 when there was
  /// none or it couldn't be read); read at [started], before the start
  /// report.
  Duration resumePoint = Duration.zero;

  /// The start report went (after the resume read): progress and the
  /// stopped report may follow.
  bool startSent = false;

  /// The viewing finished: a resume read still out sends no start.
  bool ended = false;

  /// The furthest position played.
  Duration reached = Duration.zero;

  /// Truncate cuts the program at its slot's end.
  bool cut = false;
}

/// The next segment, in the player's playlist: [segment] from [start] in its
/// item, read from [url] (through [routed]).
class _Preload {
  _Preload(this.segment, this.start, this.generation, this.url, this.routed, this.pick);

  final ScheduledProgram segment;

  /// The copy it plays from (multi-server).
  final ({MediaEntry item, MediaServer client, String key})? pick;
  final Duration start;
  final int generation;
  final Uri url;
  final Uri routed;
}

/// One segment changing to the next on a channel, until the new one's
/// picture (HANDOVER): by the player or the tuner ([trigger]).
class _Handover {
  _Handover(this.from, this.to, {required this.preloaded, required this.trigger});

  final String from, to;
  final bool preloaded;
  final String trigger;

  /// Since it began.
  final since = Stopwatch()..start();
}

/// A transcode job: one program part, joined at [joinedAt].
class _Transcode {
  _Transcode(
      {required this.playSessionId,
      required this.client,
      required this.item,
      required this.template,
      required this.joinedAt,
      required this.capKbps,
      this.sourceTime = false,
      this.fallback = false,
      this.directStream = false,
      this.burn});

  /// A new id per job, so stopping the last part's job can never stop the
  /// next one.
  final String playSessionId;

  /// The server it runs on (multi-server).
  final MediaServer client;
  final MediaEntry item;
  final Uri template;
  final Duration joinedAt;

  /// The stream keeps the source's times (see
  /// MediaServer.transcodeKeepsSourceTime).
  final bool sourceTime;

  /// What to add to the player's position for the item's own.
  Duration get timeOffset => sourceTime ? Duration.zero : joinedAt;

  /// The cap it was decided under, in kbps (null for none).
  final int? capKbps;

  /// Opened because direct play failed.
  final bool fallback;

  /// The conversion copies the video (reported as DirectStream).
  final bool directStream;

  /// The subtitle track the server draws into its picture (subtitles D4).
  final SubtitleTrack? burn;

  String get itemId => item.id;
}

/// A live stream being watched (or opened): its source, its reports, and
/// its reconnect state.
class _LiveSession {
  _LiveSession(this.channel, this.source, this.client, this.generation, this.attempt);

  final Channel channel;
  final LiveSource source;
  final LiveSourceClient client;
  final int generation;

  /// Reconnects so far (0: the tune itself).
  final int attempt;

  /// Opening; completes with the stream (null if it failed).
  Future<LiveStream?>? opening;
  LiveStream? stream;
  bool pictured = false;

  /// When "playing" was reported, for the stopped report's position.
  DateTime? reportedAt;
  Duration get watched => reportedAt == null ? Duration.zero : DateTime.now().difference(reportedAt!);

  Timer? startTimer;
  Timer? reportTimer;
  Timer? stallTimer;

  /// When the picture last moved, and where it was.
  DateTime? lastMove;
  Duration? _last;

  void moved(Duration position, DateTime now) {
    if (position == _last) return;
    _last = position;
    lastMove = now;
  }

  void cancelTimers() {
    startTimer?.cancel();
    reportTimer?.cancel();
    stallTimer?.cancel();
  }
}
