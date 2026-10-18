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
import 'report_plan.dart';

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
  Tuner(this.app) {
    player = Player(configuration: const PlayerConfiguration(title: 'Nightingale TV'));
    video = VideoController(player);
    _subscriptions.addAll([
      player.stream.playing.listen((playing) {
        if (playing && !player.state.buffering) _setStatus(TunerStatus.playing);
      }),
      player.stream.buffering.listen((buffering) {
        if (!buffering && player.state.playing) _setStatus(TunerStatus.playing);
      }),
      // Switching files doesn't always toggle playing/buffering, so the first
      // position tick of a playing stream also counts as "tuned in".
      player.stream.position.listen((_) {
        if (status == TunerStatus.tuning && player.state.playing && !player.state.buffering) {
          _setStatus(TunerStatus.playing);
        }
      }),
      // mpv auto-selects "default" subtitle tracks on every new file; keep
      // them off unless captions are on.
      player.stream.tracks.listen((_) => _applyCaptions()),
      player.stream.completed.listen((completed) {
        if (completed && status == TunerStatus.playing) _setStatus(TunerStatus.standby);
      }),
      player.stream.error.listen((message) {
        debugPrint('Playback error: $message');
        if (status == TunerStatus.tuning || status == TunerStatus.playing) {
          error = message;
          _setStatus(TunerStatus.error);
        }
      }),
    ]);
  }

  static const _progressInterval = Duration(seconds: 10);

  final AppState app;
  late final Player player;
  late final VideoController video;
  final _subscriptions = <StreamSubscription<Object?>>[];

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
    final now = DateTime.now();
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

  Future<void> _applyCaptions() async {
    final wanted = captions ? SubtitleTrack.auto() : SubtitleTrack.no();
    if (player.state.track.subtitle != wanted) await player.setSubtitleTrack(wanted);
  }

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
      _setStatus(TunerStatus.error);
      await player.stop();
      return;
    }
    final now = DateTime.now();
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

    final item = current.item;
    if (item == null) {
      _setStatus(current.isIdent ? TunerStatus.ident : TunerStatus.offAir);
      await player.stop();
      return;
    }
    _setStatus(TunerStatus.tuning);
    final startAt = current.positionAt(now);

    try {
      // A part of the show, or a clip inside a reel: mpv stops exactly at
      // the segment's end even if the timer runs late.
      await player.open(
        Media(client.streamUri(item.sourceId).toString(),
            httpHeaders: client.authHeaders, start: startAt, end: current.itemTo),
      );
    } on Object catch (e) {
      if (generation != _generation) return;
      error = '$e';
      _setStatus(TunerStatus.error);
      return;
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
    final reached = atSegmentEnd ? previous.itemTo : player.state.position;
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
    _quietly(() => client.reportPlaybackStart(report.at(startAt)));
    _progress = Timer.periodic(_progressInterval, (_) {
      final current = segment;
      if (current != null && !current.isBreak && current.item?.id == report.item.id) {
        final position = player.state.position;
        if (position > report.reached) report.reached = position;
        _quietly(() => client.reportPlaybackProgress(report.at(position)));
      } else {
        // During its breaks the program is paused where it stopped.
        _quietly(() => client.reportPlaybackProgress(report.at(report.reached, paused: true)));
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
    await _quietly(() => report.client.reportPlaybackStopped(report.at(stoppedPosition(report.item, report.reached))));
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (e) {
      debugPrint('Playback report failed: $e');
    }
  }

  void _setStatus(TunerStatus s) {
    // Background analysis holds off while a stream opens.
    app.playbackBusy.value = s == TunerStatus.tuning;
    if (status == s) return;
    status = s;
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    _programEnd?.cancel();
    _noteReached(atSegmentEnd: false);
    await _finishReport();
    await player.stop();
    channel = null;
    program = null;
    segment = null;
    _setStatus(TunerStatus.idle);
  }

  @override
  void dispose() {
    _programEnd?.cancel();
    _progress?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    player.dispose();
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

  PlaybackReport at(Duration position, {bool paused = false}) =>
      PlaybackReport(itemId: item.id, playSessionId: sessionId, position: position, isPaused: paused);
}
