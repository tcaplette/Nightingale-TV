import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../jellyfin/jellyfin_client.dart';
import '../library/library_index.dart';
import 'android_device_profile.dart';
import 'index_cache.dart';
import 'playback_diagnostics.dart';
import 'playback_proxy.dart';
import 'report_plan.dart';
import 'tuner_player.dart';

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
      : media = player ?? TunerPlayer.create(),
        _clock = clock ?? DateTime.now,
        _proxy = proxy ?? (player == null && !PlaybackProxy.disabled ? PlaybackProxy() : null) {
    _diagnostics = PlaybackDiagnostics.start(
        app.storage.root, media, app.analyzerDebugState, () => status == TunerStatus.playing);
    if (_diagnostics != null) debugPrint('Playback diagnostics: ${_diagnostics!.path}');
    _subscriptions.addAll([
      // Tuned in once the picture moves: mpv reports "playing" (and not
      // "buffering") right after an open, seconds before the first frame.
      media.positionStream.listen(_onPosition),
      // mpv auto-selects "default" subtitle tracks on every new file; keep
      // them off unless captions are on.
      media.tracksStream.listen((_) => _applyCaptions()),
      media.completedStream.listen((completed) {
        if (!completed || status != TunerStatus.playing) return;
        // A commercial shorter than its listed length holds its last
        // picture until the hand-over; a program part shows stand-by.
        if (inBreak) {
          _diagnostics?.event('${_label(segment)} ended early; holding its last picture');
          return;
        }
        _setStatus(TunerStatus.standby);
      }),
      media.logStream.listen((line) => _diagnostics?.mpvLog(line)),
      // The player moved on to the preloaded segment by itself.
      media.advanced.listen((_) => _onAdvanced()),
      media.errorStream.listen((message) {
        debugPrint('Playback error: $message');
        _diagnostics?.event('player error: "$message" while ${status.name} (mayFallBack=$_mayFallBack, transcoding=${_active?.playSessionId})');
        _onPlaybackError(message);
      }),
    ]);
    _startProxy();
  }

  static const _progressInterval = Duration(seconds: 10);

  /// How long a transcoded part may take to start playing.
  @visibleForTesting
  Duration transcodeStartup = const Duration(seconds: 10);

  /// How long stopping a transcode job may hold up quitting.
  static const exitTimeout = Duration(seconds: 2);

  final AppState app;
  final TunerPlayer media;
  final DateTime Function() _clock;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// With NIGHTINGALE_TV_DEBUG_PLAYBACK=1, a log of how playback is going.
  PlaybackDiagnostics? _diagnostics;

  Channel? channel;
  Channel? previousChannel;

  /// Closed captions (subtitles). Off by default, like a TV.
  bool captions = false;
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
  final _stoppedQueue = <(JellyfinClient, PlaybackReport)>[];
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

  /// Keeps connections to the server warm: at start and after each open.
  void _warmConnections() {
    final client = app.client;
    final proxy = _proxy;
    if (client == null || proxy == null || !proxy.running) return;
    unawaited(proxy.warm(client.uri('/System/Ping'), client.authHeaders).catchError((Object e) {
      debugPrint('Playback proxy: warm-up failed: $e');
    }));
  }

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
  Future<(Uri, Map<String, String>)> _route(Uri url, JellyfinClient client,
      {IndexCacheKey? cache, Duration start = Duration.zero, bool preload = false}) async {
    final proxy = _proxy;
    final ready = _proxyReady;
    if (proxy != null && ready != null) {
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
    final schedule = app.scheduleFor(ch);
    final current = program;
    if (schedule != null && current != null) programs.add(schedule.next(current));
    final list = app.channels;
    final index = list.indexWhere((c) => c.id == ch.id);
    if (index >= 0 && list.length > 1) {
      for (final delta in const [1, -1]) {
        programs.add(app.scheduleFor(list[(index + delta) % list.length])?.programAt(now));
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
      final schedule = ch == null ? null : app.scheduleFor(ch);
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
    final client = app.client;
    if (proxy == null || client == null || !proxy.running || _filling) return;
    _fillDue = false;
    _filling = true;
    final generation = _generation;
    try {
      for (final item in _fillCandidates()) {
        if (generation != _generation || !_mayFill) break;
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

  Future<void> tune(Channel ch) async {
    // Diagnostics: the first tune is the launch's; one after [stop] (Android
    // coming back to the front) is a resume.
    final trigger = !_tunedOnce ? 'launch' : (channel == null ? 'resume' : 'channel');
    _tunedOnce = true;
    // How far the program on the channel being left got.
    _noteReached(atSegmentEnd: false);
    if (channel != null && channel!.id != ch.id) previousChannel = channel;
    channel = ch;
    _recent
      ..remove(ch.id)
      ..insert(0, ch.id);
    if (_recent.length > 5) _recent.removeLast();
    // In front again (Android) if it was hidden.
    if (_proxyReady != null) unawaited(_proxy!.setBackground(false).catchError((Object _) {}));
    unawaited(app.setLastChannel(ch));
    await _playCurrent(++_generation, trigger: trigger);
  }

  /// Re-tunes the current channel, e.g. after its playlist changed.
  Future<void> retune() async {
    if (channel != null) await _playCurrent(++_generation, trigger: 'retune');
  }

  /// After a schedule change that keeps the program on air (e.g. a new break
  /// plan): the segment playing now plays on, and the new schedule takes
  /// over when it ends (a stream that failed is retried then, as usual).
  /// Falls back to [retune] when nothing is on.
  Future<void> reschedule() async {
    final ch = channel;
    final current = segment;
    if (ch == null) return;
    final schedule = app.scheduleFor(ch);
    final now = _clock();
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

  Future<void> toggleCaptions() async {
    captions = !captions;
    await _applyCaptions();
    notifyListeners();
  }

  Future<void> _applyCaptions() => media.showCaptions(captions);

  Future<void> channelUp() => _step(1);
  Future<void> channelDown() => _step(-1);

  Future<void> lastChannel() async {
    final prev = previousChannel;
    if (prev != null && app.channels.any((c) => c.id == prev.id)) await tune(prev);
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
  Future<void> _playCurrent(int generation, {bool atSegmentEnd = false, String? trigger}) async {
    _programEnd?.cancel();
    _cancelPrefetch();
    _awaitingFirstFrame = false;
    _keyframeJoin = null;
    final from = segment;
    _noteReached(atSegmentEnd: atSegmentEnd);
    final ch = channel;
    final client = app.client;
    if (ch == null || client == null || generation != _generation) return;
    _diagnostics?.tuneStarted(trigger ?? (atSegmentEnd ? 'segment' : 'retune'), 'ch=${ch.number}');
    // Whatever was preloaded goes before anything else opens.
    await _dropPreload();
    if (generation != _generation) return;

    final schedule = app.scheduleFor(ch);
    if (schedule == null) {
      _diagnostics?.tuneFailed('no schedule');
      // Nothing opens, so nothing to wait for.
      _queueFinish();
      unawaited(flushReports());
      program = null;
      segment = null;
      error = 'Nothing to play on this channel.';
      _stopTranscode();
      _setStatus(TunerStatus.error);
      await media.stop();
      return;
    }
    final now = _clock();
    var current = schedule.playbackAt(now);
    // Joining with only a moment left would just flash the end credits.
    if (current.end.difference(now) < const Duration(seconds: 4)) {
      current = schedule.playbackAt(current.end);
    }
    final startAt = current.positionAt(now);
    _setOnNow(generation, ch, client, schedule, current, now, startAt);
    _handover = atSegmentEnd ? _Handover(_label(from), _label(current), preloaded: false, trigger: 'tuner') : null;

    // Whatever was transcoding stops before anything else opens.
    _stopTranscode();
    final item = current.item;
    if (item == null) {
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
    _changingChannel = !atSegmentEnd;
    _setStatus(TunerStatus.tuning);

    final playback = app.settings.playback;
    final isProgram = _isProgramPart(current);
    // On Android every segment plays as Jellyfin decides for the device
    // (android-playback). The cap is only ever for program parts.
    final android = app.decidesEverySegment;
    final cap = isProgram ? app.capInEffect : null;
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
      final keyframe = !atSegmentEnd && _isProgramPart(current) && startAt - current.itemFrom > _keyframeJoinMargin;
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
        await media.open(routed, headers: headers, start: startAt, end: current.itemTo, exact: !keyframe);
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
  void _setOnNow(int generation, Channel ch, JellyfinClient client, ChannelSchedule schedule, ScheduledProgram current,
      DateTime now, Duration startAt) {
    final step = reportStep(_report?.viewing, ch.id, current);
    // Sent after the new picture: the open doesn't wait for the server.
    if (step == ReportStep.finish || step == ReportStep.finishAndStart) _queueFinish();
    segment = current;
    program = schedule.programAt(current.start.isAfter(now) ? current.start : now);
    error = null;
    _endSegmentAt(current.end, generation);
    final item = current.item;
    if (item == null) return;
    // A new viewing is reported from its first picture (see [_beginReport]);
    // one that never shows a picture isn't reported at all.
    if (step == ReportStep.start || step == ReportStep.finishAndStart) {
      _report = _Report(client, item, _newSessionId().substring(0, 16), viewingOf(ch.id, current)!)..reached = startAt;
    } else if (step == ReportStep.keep && !current.isBreak) {
      _report?.reached = startAt;
    }
  }

  /// Hands over to the next segment at [end].
  void _endSegmentAt(DateTime end, int generation) {
    _programEnd?.cancel();
    _segmentEnd = end;
    _programEnd = Timer(end.difference(_clock()), () => unawaited(_atHandover(generation)));
  }

  /// The schedule's hand-over: to the preloaded segment if there is one
  /// (the player may already be on it), else by opening what's on.
  Future<void> _atHandover(int generation) async {
    if (generation != _generation) return;
    final enqueueing = _enqueueing;
    if (enqueueing != null) await enqueueing.then((_) {}, onError: (Object _) {});
    if (generation != _generation) return;
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
    final ch = channel, client = app.client;
    final schedule = ch == null ? null : app.scheduleFor(ch);
    if (ch == null || client == null || schedule == null || next.generation != _generation) return;
    final from = segment;
    final current = next.segment;
    _cancelPrefetch();
    _cancelPreloadTimers();
    _awaitingFirstFrame = false;
    _keyframeJoin = null;
    _noteReached(atSegmentEnd: true);
    _setOnNow(_generation, ch, client, schedule, current, _clock(), next.start);
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
    if (!preload || end == null || _preloaded != null || channel == null) return;
    final generation = _generation, serial = _preloadSerial;
    final now = _clock();
    Duration before(Duration lead) {
      final d = end.subtract(lead).difference(now);
      return d.isNegative ? Duration.zero : d;
    }

    _decideTimer = Timer(before(_decideLead), () {
      final next = _nextSegment();
      if (next != null && next.segment.item != null) unawaited(_playsDirect(next.segment));
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
    final ch = channel, current = segment, end = _segmentEnd;
    final schedule = ch == null ? null : app.scheduleFor(ch);
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
    final source = s.item!.sourceId;
    final isProgram = _isProgramPart(s);
    final android = app.decidesEverySegment;
    final cap = isProgram ? app.capInEffect : null;
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
    final client = app.client;
    final next = _nextSegment();
    if (stale() || client == null || next == null || _preloaded != null) return;
    final segment = next.segment;
    final item = segment.item;
    if (item == null) {
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
    final enqueueing = _enqueueing = media.enqueue(routed, headers: headers, start: next.start, end: segment.itemTo);
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
    _preloaded = _Preload(segment, next.start, generation, url, routed);
    _diagnostics?.event('preloaded ${_label(segment)} from ${next.start} (hand-over in '
        '${_segmentEnd?.difference(_clock()).inMilliseconds} ms)');
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
    if (!_awaitingFirstFrame) return;
    if ((position - _landing).abs() > const Duration(seconds: 30)) {
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
    // The stream is up: the app's own requests may go now.
    unawaited(flushReports());
    _beginReport();
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
    final cap = app.capInEffect;
    if ((cap == null && !app.decidesEverySegment) || app.client == null || channel == null) return;
    for (final p in _likelyNext()) {
      final source = p.item!.sourceId;
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
  // reported at position 0 so channel surfing doesn't fill the user's
  // "Continue Watching" row; programs watched to the end count as watched.

  /// Reports the viewing being opened, at its first picture: the start, then
  /// progress every [_progressInterval].
  void _beginReport() {
    final report = _report;
    if (report == null || report.started) return;
    report.started = true;
    final client = report.client;
    _quietly(() => client.reportPlaybackStart(_reportAt(report, report.reached)));
    _progress?.cancel();
    _progress = Timer.periodic(_progressInterval, (_) {
      final current = segment;
      if (current != null && !current.isBreak && current.item?.id == report.item.id) {
        final position = _itemPosition;
        if (position > report.reached) report.reached = position;
        _quietly(() => client.reportPlaybackProgress(_reportAt(report, position)));
      } else {
        // During its breaks the program is paused where it stopped.
        _quietly(() => client.reportPlaybackProgress(_reportAt(report, report.reached, paused: true)));
      }
    });
  }

  /// Ends the viewing being reported: as watched when it got to the end,
  /// otherwise at position 0 (see [stoppedPosition]). The report is queued
  /// (see [flushReports]); a viewing that never started sends nothing.
  void _queueFinish() {
    _progress?.cancel();
    _progress = null;
    final report = _report;
    _report = null;
    if (report == null || !report.started) return;
    _stoppedQueue.add((report.client, _reportAt(report, stoppedPosition(report.item, report.reached))));
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
  Duration get _itemPosition => media.position + (_active?.joinedAt ?? Duration.zero);

  /// Opens [current] as a new transcode job joined at [startAt] (Jellyfin
  /// seeks; mpv never does). False if it failed.
  /// [capKbps] is the cap it was decided under (null for none).
  Future<bool> _openTranscode(int generation, ScheduledProgram current, MediaEntry item, Uri template,
      Duration startAt, JellyfinClient client,
      {required int? capKbps, bool fallback = false, bool directStream = false}) async {
    final job = _active = _Transcode(
        playSessionId: _newSessionId(),
        item: item,
        template: template,
        joinedAt: startAt,
        capKbps: capKbps,
        fallback: fallback,
        directStream: directStream);
    _mayFallBack = false;
    _armStartup(generation, restart: false);
    try {
      final url = JellyfinClient.transcodeUri(template, playSessionId: job.playSessionId, startAt: startAt);
      _diagnostics?.opened(
          '${fallback ? 'transcode-fallback' : _method(template, directStream)}${capKbps == null ? '' : '@${capKbps}kbps'}', url,
          end: current.itemTo - startAt);
      _expectFirstFrame(Duration.zero);
      final (routed, headers) = await _route(url, client);
      if (generation != _generation) return false;
      _readingFrom(routed);
      await media.open(routed, headers: headers, end: current.itemTo - startAt);
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

  Future<void> _fallBack(int generation) async {
    _mayFallBack = false;
    final current = segment;
    final item = current?.item;
    final client = app.client;
    if (current == null || item == null || client == null) return;
    _diagnostics?.tuneStarted('fallback', 'ch=${channel?.number}');
    _armStartup(generation);
    // Under the cap this open was decided with.
    final cap = app.capInEffect;
    final PlaybackDecision decision;
    try {
      decision = await client.playbackInfo(item.sourceId,
          maxBitrate: cap == null ? null : cap * 1000,
          forceTranscode: true,
          startAt: current.positionAt(_clock()),
          profile: app.decidesEverySegment ? await app.deviceProfile(cap) : null);
    } on Object catch (e) {
      if (generation == _generation) _fail('$e');
      return;
    }
    if (generation != _generation) return;
    // The scheduled position for this moment, not where the failed open was.
    final startAt = current.positionAt(_clock());
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
    _stopTranscode();
    unawaited(_dropPreload());
    error = message;
    _setStatus(TunerStatus.error);
  }

  /// Stops the active transcode job, if any. Tuning doesn't wait for the
  /// server to answer.
  void _stopTranscode() {
    _startup?.cancel();
    final job = _active;
    _active = null;
    final client = app.client;
    if (job == null || client == null) return;
    _diagnostics?.event('stop transcode ${job.playSessionId} (status ${status.name})');
    unawaited(_quietly(() => client.stopEncoding(job.playSessionId).timeout(const Duration(seconds: 5))));
  }

  /// Stops the active transcode job and waits (briefly) for the server, for
  /// when the app is quitting.
  Future<void> stopTranscodeForExit() async {
    _startup?.cancel();
    final job = _active;
    _active = null;
    final client = app.client;
    if (job == null || client == null) return;
    await _quietly(() => client.stopEncoding(job.playSessionId).timeout(exitTimeout));
  }

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
    await _dropPreload();
    // Nothing is opening: what's queued goes now.
    _queueFinish();
    await flushReports();
    _stopTranscode();
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
    for (final s in _subscriptions) {
      s.cancel();
    }
    media.dispose();
    super.dispose();
  }
}

/// One viewing being reported to Jellyfin, across the program's parts.
class _Report {
  _Report(this.client, this.item, this.sessionId, this.viewing);

  final JellyfinClient client;
  final MediaEntry item;
  final String sessionId;
  Viewing viewing;

  /// The start was sent (at the viewing's first picture).
  bool started = false;

  /// The furthest position played.
  Duration reached = Duration.zero;
}

/// The next segment, in the player's playlist: [segment] from [start] in its
/// item, read from [url] (through [routed]).
class _Preload {
  _Preload(this.segment, this.start, this.generation, this.url, this.routed);

  final ScheduledProgram segment;
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
      required this.item,
      required this.template,
      required this.joinedAt,
      required this.capKbps,
      this.fallback = false,
      this.directStream = false});

  /// A new id per job, so stopping the last part's job can never stop the
  /// next one.
  final String playSessionId;
  final MediaEntry item;
  final Uri template;
  final Duration joinedAt;

  /// The cap it was decided under, in kbps (null for none).
  final int? capKbps;

  /// Opened because direct play failed.
  final bool fallback;

  /// The conversion copies the video (reported as DirectStream).
  final bool directStream;

  String get itemId => item.id;
}
