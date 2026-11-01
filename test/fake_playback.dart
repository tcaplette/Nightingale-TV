import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/playback_diagnostics.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/server/media_server.dart';

/// A Jellyfin that decides on bitrate the way the real one does, and logs
/// every call the tuner makes as it's made.
class FakeClient extends JellyfinClient {
  FakeClient(this.log, {super.serverUrl = 'https://jf.example', super.httpClient, super.userId, String accessToken = 't'})
      : super(deviceId: 'dev', deviceName: 'pc', accessToken: accessToken);

  /// Shared with the player, so the order of calls and opens shows.
  final List<String> log;

  /// Source bitrates (bits per second); 25 Mbps unless set.
  final bitrates = <String, int>{};
  final decisions = <({String id, int? maxBitrate, bool force, Map<String, Object?>? profile})>[];

  /// What [playbackDecision] answers for a source that plays directly (unless
  /// it's over the cap or forced): direct play when null, else a
  /// conversion, a direct stream if true.
  final converts = <String, bool>{};
  final stopped = <String>[];
  final reports = <(String kind, PlaybackReport report)>[];

  /// Answers [playbackDecision] only once this completes (when set).
  Completer<void>? holdDecisions;

  /// Answers the playback reports only once this completes (when set): a
  /// slow link, where each request takes seconds.
  Completer<void>? holdReports;

  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate,
      bool forceTranscode = false,
      Duration startAt = Duration.zero,
      Map<String, Object?>? profile}) async {
    decisions.add((id: itemId, maxBitrate: maxBitrate, force: forceTranscode, profile: profile));
    log.add('decide:$itemId');
    await holdDecisions?.future;
    final over = maxBitrate != null && (bitrates[itemId] ?? 25000000) > maxBitrate;
    final template = transcodeTemplate('/videos/$itemId/stream.ts?DeviceId=dev&ApiKey=t&MediaSourceId=$itemId');
    final source = bitrates[itemId] ?? 25000000;
    if (forceTranscode || over) return PlaybackDecision.transcode(template, sourceBitrate: source, sourceCodec: 'hevc');
    final converted = converts[itemId];
    if (converted == null) return const PlaybackDecision.direct();
    return PlaybackDecision.transcode(template, directStream: converted, sourceBitrate: source, sourceCodec: 'hevc');
  }

  /// Transcodes in the source's own times, as Plex's are.
  bool sourceTime = false;

  @override
  bool get transcodeKeepsSourceTime => sourceTime;

  @override
  Future<void> stopTranscode(String playSessionId) async {
    stopped.add(playSessionId);
    log.add('stop:$playSessionId');
  }

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) async {
    reports.add(('start', report));
    log.add('report:start');
    if (holdReports case final hold?) await hold.future;
  }

  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) async {
    reports.add(('progress', report));
    if (holdReports case final hold?) await hold.future;
  }

  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) async {
    reports.add(('stopped', report));
    log.add('report:stopped');
    if (holdReports case final hold?) await hold.future;
  }
}

/// What [FakePlayer.open] does with a URL.
/// [noPicture]: mpv says "playing" but no frame comes (yet).
enum OpenResult { plays, throws, errors, hangs, noPicture }

class FakePlayer implements TunerPlayer {
  FakePlayer(this.log);

  final List<String> log;
  final opens = <({Uri url, Map<String, String> headers, Duration? start, Duration? end, bool exact})>[];

  /// URLs opened as live streams.
  final liveOpens = <Uri>[];
  OpenResult Function(Uri url) onOpen = (_) => OpenResult.plays;

  /// How far before [start] a keyframe join lands.
  Duration keyframeEarly = Duration.zero;

  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  bool _isPlaying = false;

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<void> get tracksStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Stream<String> get errorStream => _error.stream;
  @override
  Stream<String> get logStream => const Stream.empty();

  @override
  bool get playing => _isPlaying;
  @override
  bool get buffering => false;
  @override
  Duration position = Duration.zero;

  @override
  Future<void> open(Uri url,
      {required Map<String, String> headers,
      Duration? start,
      Duration? end,
      bool exact = true,
      bool live = false}) async {
    opens.add((url: url, headers: headers, start: start, end: end, exact: exact));
    if (live) liveOpens.add(url);
    log.add('open:${url.path}');
    queued = null;
    _moved = false;
    _isPlaying = false;
    paused = false;
    position = Duration.zero;
    final landed = (start ?? Duration.zero) - (exact ? Duration.zero : keyframeEarly);
    switch (onOpen(url)) {
      case OpenResult.plays:
        scheduleMicrotask(() {
          _isPlaying = true;
          _playing.add(true);
          showPicture(landed);
        });
      case OpenResult.noPicture:
        scheduleMicrotask(() {
          _isPlaying = true;
          _playing.add(true);
        });
      case OpenResult.throws:
        throw Exception('could not open');
      case OpenResult.errors:
        scheduleMicrotask(() => _error.add('could not open'));
      case OpenResult.hangs:
        break;
    }
  }

  /// The first frames, from [at]: the position moves on from where it landed.
  void showPicture(Duration at) {
    _position.add(at);
    _position.add(at + const Duration(milliseconds: 40));
  }

  /// A playback error some time after starting.
  void failNow() => _error.add('stream broke');

  /// A playback error saying [message].
  void debugError(String message) => _error.add(message);

  /// The file ends with nothing queued (before its scheduled end).
  void complete() => _completed.add(true);

  @override
  Future<void> stop() async {
    _isPlaying = false;
    queued = null;
    _moved = false;
    log.add('stop-player');
  }

  /// Paused now, and every [seek]'s position.
  bool paused = false;
  final seeks = <Duration>[];

  /// What [resume] does: throws when set.
  bool failResume = false;

  @override
  Future<void> pause() async {
    paused = true;
    log.add('pause');
  }

  @override
  Future<void> resume() async {
    log.add('resume');
    if (failResume) throw Exception('could not resume');
    paused = false;
  }

  @override
  Future<void> seek(Duration to) async {
    seeks.add(to);
    position = to;
    log.add('seek:${to.inSeconds}');
  }

  // ---- The playlist ------------------------------------------------------------

  /// Every [enqueue], and what's queued now.
  final enqueued = <({Uri url, Map<String, String> headers, Duration? start, Duration? end})>[];
  ({Uri url, Map<String, String> headers, Duration? start, Duration? end})? queued;
  bool _moved = false;
  final _advanced = StreamController<void>.broadcast();

  @override
  Stream<void> get advanced => _advanced.stream;

  @override
  Future<void> enqueue(Uri url, {required Map<String, String> headers, Duration? start, Duration? end}) async {
    final item = (url: url, headers: headers, start: start, end: end);
    enqueued.add(item);
    queued = item;
    _moved = false;
    log.add('enqueue:${url.path}');
  }

  @override
  Future<bool> advance() async {
    if (_moved) return true;
    if (queued == null) return false;
    log.add('advance');
    _moveOn();
    return true;
  }

  @override
  Future<void> clearQueue() async {
    if (queued != null) log.add('clear-queue');
    queued = null;
  }

  /// The item playing reached its end: on to the queued one, if any, as
  /// the player does by itself.
  void reachEnd() {
    if (queued == null) return;
    log.add('moved-on');
    _moveOn();
  }

  void _moveOn() {
    final item = queued!;
    queued = null;
    _moved = true;
    position = item.start ?? Duration.zero;
    _advanced.add(null);
    scheduleMicrotask(() => showPicture(item.start ?? Duration.zero));
  }

  @override
  Future<void> showCaptions(bool on) async {}

  /// Every [setVolumeLeveling], in order.
  final leveling = <bool>[];

  @override
  Future<void> setVolumeLeveling(bool on) async => leveling.add(on);

  /// Every [setVolume], in order.
  final volumes = <double>[];

  /// The volume last set.
  double get volume => volumes.isEmpty ? 1 : volumes.last;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> dispose() async {}

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    lastFit = fit;
    return const SizedBox.expand();
  }

  /// How the picture last asked for the video to fit.
  BoxFit? lastFit;

  @override
  Future<double?> debugPosition() async => position.inMilliseconds / 1000;
  @override
  Future<FrameCounts> debugFrames() async => (dropped: 0, decoderDropped: 0, delayed: 0, mistimed: 0);
  @override
  Future<List<String>> debugLive() async => const [];
  @override
  Future<List<String>> debugStall() async => const [];
  @override
  Future<String?> debugStream() async => null;
  @override
  Future<Duration?> debugFrameGap(Duration window) async => null;

  /// What [bufferedSeconds] says (as the player would right now), and how often
  /// it was read.
  double? buffered;
  int bufferedReads = 0;

  @override
  Future<double?> bufferedSeconds() async {
    bufferedReads++;
    return buffered;
  }

  /// The open file's average bitrate (bits per second).
  int? fileBitrate;

  @override
  Future<int?> averageBitrate() async => fileBitrate;
}
