import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../jellyfin/jellyfin_client.dart';
import '../library/library_index.dart';
import 'playback_diagnostics.dart';
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

  /// The station ID card at the end of a commercial break.
  ident,
}

/// Plays whatever a channel's schedule says is on air right now, joining
/// mid-program, and moves to the next program when the slot ends.
class Tuner extends ChangeNotifier {
  /// [player] and [clock] are for tests; the app uses mpv and the real time.
  Tuner(this.app, {TunerPlayer? player, DateTime Function()? clock})
      : media = player ?? MediaKitTunerPlayer(),
        _clock = clock ?? DateTime.now {
    _diagnostics = PlaybackDiagnostics.start(
        app.storage.root, media.debugProperty, app.analyzerDebugState, () => status == TunerStatus.playing);
    if (_diagnostics != null) debugPrint('Playback diagnostics: ${_diagnostics!.path}');
    _subscriptions.addAll([
      media.playingStream.listen((playing) {
        if (playing && !media.buffering) _setStatus(TunerStatus.playing);
      }),
      media.bufferingStream.listen((buffering) {
        if (!buffering && media.playing) _setStatus(TunerStatus.playing);
      }),
      // Switching files doesn't always toggle playing/buffering, so the first
      // position tick of a playing stream also counts as "tuned in".
      media.positionStream.listen((_) {
        if (status == TunerStatus.tuning && media.playing && !media.buffering) {
          _setStatus(TunerStatus.playing);
        }
      }),
      // mpv auto-selects "default" subtitle tracks on every new file; keep
      // them off unless captions are on.
      media.tracksStream.listen((_) => _applyCaptions()),
      media.completedStream.listen((completed) {
        if (completed && status == TunerStatus.playing) _setStatus(TunerStatus.standby);
      }),
      media.logStream.listen((line) => _diagnostics?.mpvLog(line)),
      media.errorStream.listen((message) {
        debugPrint('Playback error: $message');
        _diagnostics?.event('mpv error: "$message" while ${status.name} (mayFallBack=$_mayFallBack, transcoding=${_active?.playSessionId})');
        _onPlaybackError(message);
      }),
    ]);
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

  /// mpv itself (the app's player; tests use a fake [media]).
  Player get player => (media as MediaKitTunerPlayer).player;
  VideoController get video => (media as MediaKitTunerPlayer).video;

  Channel? channel;
  Channel? previousChannel;

  /// Closed captions (subtitles). Off by default, like a TV.
  bool captions = false;
  /// The guide slot on air (the program and its breaks).
  ScheduledProgram? program;

  /// What's actually playing within [program]: a part of the show, a
  /// commercial, or the station ID.
  ScheduledProgram? segment;

  /// A commercial break (or its station ID) is on.
  bool get inBreak => segment?.isBreak ?? false;
  TunerStatus status = TunerStatus.idle;
  String? error;

  Timer? _programEnd;
  Timer? _progress;
  _Report? _report;

  /// Bumped on every tune so stale async work can tell it was superseded.
  int _generation = 0;

  // ---- Transcoding (only with "Transcode only if needed" on) --------------

  /// Per program video: its transcode URL template, or null for direct play.
  /// Decided once and reused for the program's later parts, re-tunes and
  /// later airings, until the setting changes.
  final _decisions = <String, Uri?>{};
  PlaybackSettings? _decisionsFor;

  /// The one transcode job this app may have running.
  _Transcode? _active;

  /// The part opening now is a direct-played program part that may still
  /// fall back to a transcode.
  bool _mayFallBack = false;
  Timer? _startup;

  Future<void> tune(Channel ch) async {
    // How far the program on the channel being left got.
    _noteReached(atSegmentEnd: false);
    if (channel != null && channel!.id != ch.id) previousChannel = channel;
    channel = ch;
    unawaited(app.setLastChannel(ch));
    await _playCurrent(++_generation);
  }

  /// Re-tunes the current channel, e.g. after its playlist changed.
  Future<void> retune() async {
    if (channel != null) await _playCurrent(++_generation);
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
    program = slot;
    // The rebased slot is still the same viewing of the same program.
    final report = _report;
    if (report != null && report.viewing.itemId == slot.item?.id && report.viewing.channelId == ch.id) {
      report.viewing = (channelId: ch.id, itemId: report.viewing.itemId, layoutStart: slot.layoutStart);
    }
    _programEnd?.cancel();
    final generation = _generation;
    _programEnd = Timer(current.end.difference(now), () {
      if (generation == _generation) _playCurrent(generation, atSegmentEnd: true);
    });
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

  /// Plays what's on now. [atSegmentEnd]: called because the previous
  /// segment played to its end.
  Future<void> _playCurrent(int generation, {bool atSegmentEnd = false}) async {
    _programEnd?.cancel();
    _noteReached(atSegmentEnd: atSegmentEnd);
    final ch = channel;
    final client = app.client;
    if (ch == null || client == null || generation != _generation) return;

    final schedule = app.scheduleFor(ch);
    if (schedule == null) {
      await _finishReport();
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
    final step = reportStep(_report?.viewing, ch.id, current);
    if (step == ReportStep.finish || step == ReportStep.finishAndStart) await _finishReport();
    if (generation != _generation) return;
    segment = current;
    program = schedule.programAt(current.start.isAfter(now) ? current.start : now);
    error = null;

    final untilEnd = current.end.difference(now);
    _programEnd = Timer(untilEnd, () {
      if (generation == _generation) _playCurrent(generation, atSegmentEnd: true);
    });

    // Whatever was transcoding stops before anything else opens.
    _stopTranscode();
    final item = current.item;
    if (item == null) {
      _setStatus(current.isIdent ? TunerStatus.ident : TunerStatus.offAir);
      await media.stop();
      return;
    }
    _setStatus(TunerStatus.tuning);
    final startAt = current.positionAt(now);

    final playback = app.settings.playback;
    if (_decisionsFor != playback) {
      _decisions.clear();
      _decisionsFor = playback;
    }
    // Only program parts ever transcode; commercials, bumpers and the
    // station ID always direct-play.
    final transcodable = playback.transcodeIfNeeded && _isProgramPart(current);
    Uri? template;
    if (transcodable) {
      final source = item.sourceId;
      final cap = playback.capBitsPerSecond;
      if (_decisions.containsKey(source)) {
        template = _decisions[source];
      } else if (cap != null) {
        _armStartup(generation);
        try {
          template = (await client.playbackInfo(source, maxBitrate: cap, startAt: startAt)).transcodeTemplate;
          _decisions[source] = template;
          _diagnostics?.event('decision for $source at cap $cap: ${template == null ? 'direct' : 'transcode'}');
        } on Object catch (e) {
          // Can't ask: play it directly, as with the setting off.
          debugPrint('Playback decision failed: $e');
          _diagnostics?.event('decision for $source failed: $e');
        }
        // The job only starts once the stream is requested, so a decision
        // that arrives after a newer tune leaves nothing running.
        if (generation != _generation) return;
      }
    }

    if (template != null) {
      if (!await _openTranscode(generation, current, item, template, startAt, client)) return;
    } else {
      _startup?.cancel();
      _mayFallBack = transcodable;
      try {
        // A part of the show, or a clip inside a reel: mpv stops exactly at
        // the segment's end even if the timer runs late.
        final url = client.streamUri(item.sourceId);
        _diagnostics?.opened(current.isCommercial ? 'direct-commercial' : 'direct', url, start: startAt, end: current.itemTo);
        await media.open(url, headers: client.authHeaders, start: startAt, end: current.itemTo);
      } on Object catch (e) {
        if (generation != _generation) return;
        _onPlaybackError('$e');
        return;
      }
    }
    if (generation != _generation) return;
    await _applyCaptions();
    // Commercials stay out of the user's Jellyfin history.
    if (step == ReportStep.start || step == ReportStep.finishAndStart) {
      _startReport(client, ch, current, startAt);
    } else if (step == ReportStep.keep && !current.isBreak) {
      _report?.reached = startAt;
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

  void _startReport(JellyfinClient client, Channel ch, ScheduledProgram p, Duration startAt) {
    final rng = Random();
    final sessionId = List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
    final report = _Report(client, p.item!, sessionId, viewingOf(ch.id, p)!)..reached = startAt;
    _report = report;
    _quietly(() => client.reportPlaybackStart(_reportAt(report, startAt)));
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
  /// otherwise at position 0 (see [stoppedPosition]).
  Future<void> _finishReport() async {
    _progress?.cancel();
    final report = _report;
    _report = null;
    if (report == null) return;
    await _quietly(() => report.client.reportPlaybackStopped(_reportAt(report, stoppedPosition(report.item, report.reached))));
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
      playMethod: transcoding ? PlayMethod.transcode : PlayMethod.directPlay,
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

  /// Where in the program's video the player is. A transcode starts at 0
  /// where it joined.
  Duration get _itemPosition => media.position + (_active?.joinedAt ?? Duration.zero);

  /// Opens [current] as a new transcode job joined at [startAt] (Jellyfin
  /// seeks; mpv never does). False if it failed.
  Future<bool> _openTranscode(int generation, ScheduledProgram current, MediaEntry item, Uri template,
      Duration startAt, JellyfinClient client, {bool fallback = false}) async {
    final job = _active = _Transcode(
        playSessionId: _newSessionId(), item: item, template: template, joinedAt: startAt, fallback: fallback);
    _mayFallBack = false;
    _armStartup(generation, restart: false);
    try {
      final url = JellyfinClient.transcodeUri(template, playSessionId: job.playSessionId, startAt: startAt);
      _diagnostics?.opened(fallback ? 'transcode-fallback' : 'transcode', url, end: current.itemTo - startAt);
      await media.open(url, headers: client.authHeaders, end: current.itemTo - startAt);
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
  /// setting on); otherwise, and after playback started, the error state
  /// shows until the next segment.
  void _onPlaybackError(String message) {
    if (status != TunerStatus.tuning && status != TunerStatus.playing) return;
    if (status == TunerStatus.tuning && _mayFallBack) {
      _diagnostics?.event('fallback to transcode because of: $message');
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
    _armStartup(generation);
    final PlaybackDecision decision;
    try {
      decision = await client.playbackInfo(item.sourceId,
          maxBitrate: app.settings.playback.capBitsPerSecond, forceTranscode: true, startAt: current.positionAt(_clock()));
    } on Object catch (e) {
      if (generation == _generation) _fail('$e');
      return;
    }
    if (generation != _generation) return;
    // The scheduled position for this moment, not where the failed open was.
    final startAt = current.positionAt(_clock());
    if (await _openTranscode(generation, current, item, decision.transcodeTemplate!, startAt, client, fallback: true)) {
      await _applyCaptions();
    }
  }

  void _fail(String message) {
    _diagnostics?.event('fail while ${status.name}: $message (stops transcode ${_active?.playSessionId})');
    _mayFallBack = false;
    _stopTranscode();
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
      if (job != null && job.fallback) _decisions[job.item.sourceId] = job.template;
    }
    if (status == s) return;
    _diagnostics?.event('status ${status.name} -> ${s.name}${s == TunerStatus.error ? ' ($error)' : ''}');
    status = s;
    notifyListeners();
  }

  /// Plays what's on at [clock]'s time as if the segment playing had just
  /// ended (tests drive the schedule with this instead of waiting).
  @visibleForTesting
  Future<void> debugSegmentEnded() => _playCurrent(_generation, atSegmentEnd: true);

  Future<void> stop() async {
    _generation++;
    _programEnd?.cancel();
    _noteReached(atSegmentEnd: false);
    await _finishReport();
    _stopTranscode();
    await media.stop();
    channel = null;
    program = null;
    segment = null;
    _setStatus(TunerStatus.idle);
  }

  @override
  void dispose() {
    _programEnd?.cancel();
    _progress?.cancel();
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

  /// The furthest position played.
  Duration reached = Duration.zero;
}

/// A transcode job: one program part, joined at [joinedAt].
class _Transcode {
  _Transcode(
      {required this.playSessionId, required this.item, required this.template, required this.joinedAt, this.fallback = false});

  /// A new id per job, so stopping the last part's job can never stop the
  /// next one.
  final String playSessionId;
  final MediaEntry item;
  final Uri template;
  final Duration joinedAt;

  /// Opened because direct play failed.
  final bool fallback;

  String get itemId => item.id;
}
