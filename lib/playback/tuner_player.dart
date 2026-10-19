import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// What the [Tuner] needs from a video player. [MediaKitTunerPlayer] is the
/// real one; tests use a fake.
abstract class TunerPlayer {
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<Duration> get positionStream;
  Stream<void> get tracksStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;

  /// mpv's log messages, as "level prefix: text" (diagnostics).
  Stream<String> get logStream;

  bool get playing;
  bool get buffering;

  /// Position in the media opened last (0-based, like mpv's playback time).
  Duration get position;

  /// Opens [url], from [start], stopping at [end]. [exact]: start exactly at
  /// [start]; else at the keyframe before it, which shows a picture sooner.
  Future<void> open(Uri url,
      {required Map<String, String> headers, Duration? start, Duration? end, bool exact = true});
  Future<void> stop();
  Future<void> showCaptions(bool on);
  Future<void> dispose();

  /// An mpv property, for diagnostics ("" when there's none).
  Future<String> debugProperty(String name);
}

/// mpv through media_kit. Its configuration is the same whatever the
/// playback mode (direct-play spec): nothing here reads settings. Only seek
/// precision is chosen per open, by the kind of open (see [open]).
class MediaKitTunerPlayer implements TunerPlayer {
  MediaKitTunerPlayer() {
    player = Player(configuration: configuration);
    video = VideoController(player);
  }

  static const configuration = PlayerConfiguration(title: 'Nightingale TV');

  late final Player player;
  late final VideoController video;

  @override
  Stream<bool> get playingStream => player.stream.playing;
  @override
  Stream<bool> get bufferingStream => player.stream.buffering;
  @override
  Stream<Duration> get positionStream => player.stream.position;
  @override
  Stream<void> get tracksStream => player.stream.tracks;
  @override
  Stream<bool> get completedStream => player.stream.completed;
  @override
  Stream<String> get errorStream => player.stream.error;
  @override
  Stream<String> get logStream => player.stream.log.map((l) => '${l.level} ${l.prefix}: ${l.text}');

  @override
  bool get playing => player.state.playing;
  @override
  bool get buffering => player.state.buffering;
  @override
  Duration get position => player.state.position;

  @override
  Future<void> open(Uri url,
      {required Map<String, String> headers, Duration? start, Duration? end, bool exact = true}) async {
    // mpv's own default (precise for a start position), or keyframes.
    final native = player.platform;
    if (native is NativePlayer) await native.setProperty('hr-seek', exact ? 'default' : 'no');
    await player.open(Media(url.toString(), httpHeaders: headers, start: start, end: end));
  }

  @override
  Future<void> stop() => player.stop();

  /// mpv auto-selects "default" subtitle tracks on every new file.
  @override
  Future<void> showCaptions(bool on) async {
    final wanted = on ? SubtitleTrack.auto() : SubtitleTrack.no();
    if (player.state.track.subtitle != wanted) await player.setSubtitleTrack(wanted);
  }

  @override
  Future<void> dispose() => player.dispose();

  @override
  Future<String> debugProperty(String name) async {
    final native = player.platform;
    return native is NativePlayer ? native.getProperty(name, waitForInitialization: false) : '';
  }
}
