import 'dart:async';

import 'package:flutter/foundation.dart';

import '../reporting/error_reports.dart';
import 'playback_diagnostics.dart';
import 'youtube_player.dart';

/// What a YouTube channel wants on air: [videoId] (the library's [itemId]),
/// whose start is at [videoStart] on the schedule's clock.
typedef YouTubeWant = ({String videoId, String itemId, DateTime videoStart});

/// Why a video was given up on.
enum YouTubeSkip {
  /// 100, 101, 150: removed, private, or not allowed in embedded players.
  refused,

  /// 2, or 5 twice: it couldn't be loaded.
  failed,
}

/// Drives YouTube's one player for the tuner (youtube-playback D8, D9):
/// plays what the tuned YouTube channel's schedule says, only while its
/// frame is more than half on screen and nothing holds it (Pause, another
/// screen, the background); corrects drift once; reports refusals; and
/// hands over to the next video the moment the wanted one ends.
class YouTubeTuning extends ChangeNotifier {
  YouTubeTuning({
    required this.clock,
    required this.onPlaying,
    required this.onEnding,
    required this.onSkip,
    required this.onRefusedPlayer,
    required this.onNoWebView,
    YouTubePlayer? player,
  }) : player = player ?? YouTubePlayer.instance {
    _events = this.player.events.listen(_onEvent);
  }

  final YouTubePlayer player;

  /// The schedule's clock (the tuner's view time).
  final DateTime Function() clock;

  /// The wanted video shows its first picture.
  final VoidCallback onPlaying;

  /// [itemId]'s video played to its end: the channel goes on to the next
  /// one now, not when the schedule's slot ends, so YouTube's end screen
  /// is up for as little as it takes the next video to load.
  final void Function(String itemId) onEnding;

  /// [itemId] can't play: the channel moves on.
  final void Function(String itemId, YouTubeSkip why) onSkip;

  /// Error 153: YouTube refused the player itself.
  final VoidCallback onRefusedPlayer;

  /// No Android System WebView.
  final VoidCallback onNoWebView;

  late final StreamSubscription<YouTubeEvent> _events;

  YouTubeWant? _want;
  YouTubeWant? get want => _want;

  /// The frame is laid out with more than half of it on screen.
  bool _visible = false;
  bool get visible => _visible;

  /// Paused: the player is stopped until Resume.
  bool _held = false;
  bool get held => _held;

  /// A video of a neighbouring channel readied while nothing plays.
  ({String videoId, Duration at})? _cued;

  int _retries = 0;
  bool _driftFixed = false;
  Timer? _driftTimer;
  bool _endingSent = false;

  /// The page with the profile's caption setting, made at most once per
  /// setting.
  bool captions = false;
  String? captionLanguage;

  /// Captions on or off, in [language]: the page is made again with
  /// YouTube's caption parameters, and what plays goes on.
  void setCaptions(bool on, String? language) {
    if (on == captions && language == captionLanguage) return;
    captions = on;
    captionLanguage = language;
    if (_want != null) _apply(restart: true);
  }

  /// What the channel plays now; null: nothing (another kind of channel, or
  /// off the air).
  void wantVideo(YouTubeWant? want) {
    final same = want?.videoId == _want?.videoId && want?.videoStart == _want?.videoStart;
    _want = want;
    if (!same) {
      _retries = 0;
      _driftFixed = false;
      _driftTimer?.cancel();
      _endingSent = false;
    }
    _apply(restart: !same);
  }

  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    PlaybackDiagnostics.note('YOUTUBE', 'frame ${visible ? 'shown' : 'hidden'}');
    _apply(restart: visible);
  }

  void hold(bool held) {
    if (held == _held) return;
    _held = held;
    _apply(restart: !held);
  }

  /// Readies a neighbour's video without playing it (channel preload);
  /// only while no YouTube channel is on.
  void cueNeighbour(String videoId, Duration at) {
    if (_want != null || player.playing) return;
    if (_cued?.videoId == videoId) return;
    _cued = (videoId: videoId, at: at);
    PlaybackDiagnostics.note('YOUTUBE', 'cue neighbour $videoId at ${at.inSeconds}s');
    unawaited(_page().then((_) => player.cue(videoId, at)));
  }

  Future<void> _page() => player.ensurePage(captions: captions, captionLanguage: captionLanguage);

  Duration _offsetNow(YouTubeWant w) {
    final d = clock().difference(w.videoStart);
    return d.isNegative ? Duration.zero : d;
  }

  void _apply({bool restart = false}) {
    final w = _want;
    if (w == null || !_visible || _held) {
      if (player.playing) {
        PlaybackDiagnostics.note('YOUTUBE', 'stop (${w == null ? 'nothing wanted' : _held ? 'paused' : 'not on screen'})');
        unawaited(player.stop());
      }
      return;
    }
    if (!restart && player.playing && player.videoId == w.videoId) return;
    _cued = null;
    final at = _offsetNow(w);
    PlaybackDiagnostics.note('YOUTUBE', 'load ${w.videoId} at ${at.inSeconds}s');
    unawaited(_page().then((_) {
      // Still wanted, still seen.
      if (identical(_want, w) && _visible && !_held) unawaited(player.load(w.videoId, _offsetNow(w)));
    }));
  }

  void _onEvent(YouTubeEvent e) {
    final w = _want;
    switch (e) {
      case YouTubeState(:final state, :final videoId):
        if (w != null && videoId == w.videoId && state == YouTubeState.playing) {
          _retries = 0;
          onPlaying();
        }
        if (w != null && videoId == w.videoId && state == YouTubeState.ended && _visible && !_held) _ending(w);
      case YouTubePosition(:final position, :final state, :final videoId):
        if (w == null || videoId != w.videoId || state != YouTubeState.playing || _driftFixed) return;
        final expected = _offsetNow(w);
        final drift = (position - expected).abs();
        if (drift <= const Duration(seconds: 5)) return;
        // Corrected once, at the next 10-second mark of the schedule.
        _driftFixed = true;
        final toMark = 10000 - expected.inMilliseconds % 10000;
        PlaybackDiagnostics.note('YOUTUBE', 'drift ${drift.inMilliseconds} ms; seek in $toMark ms');
        _driftTimer?.cancel();
        _driftTimer = Timer(Duration(milliseconds: toMark), () {
          if (identical(_want, w) && player.playing) unawaited(player.seek(_offsetNow(w)));
        });
      case YouTubeError(:final code, :final videoId):
        if (w == null || (videoId != null && videoId != w.videoId)) return;
        PlaybackDiagnostics.note('YOUTUBE', 'error $code on ${w.videoId}');
        switch (code) {
          case 100 || 101 || 150:
            onSkip(w.itemId, YouTubeSkip.refused);
          case 153:
            ErrorReports.capture(StateError('YouTube refused the player (153)'), StackTrace.current, area: 'youtube');
            onRefusedPlayer();
          case 5 when _retries == 0:
            _retries++;
            _apply(restart: true);
          default:
            onSkip(w.itemId, YouTubeSkip.failed);
        }
      case YouTubeCrashed():
        // A new WebView, tuned again.
        PlaybackDiagnostics.note('YOUTUBE', 'renderer stopped; making it again');
        unawaited(player.recreate().then((_) => _apply(restart: true)));
      case YouTubeNoWebView():
        onNoWebView();
      case YouTubeReady() || YouTubeApiFailed():
        break;
    }
  }

  void _ending(YouTubeWant w) {
    if (_endingSent) return;
    _endingSent = true;
    PlaybackDiagnostics.note('YOUTUBE', 'ended ${w.videoId}: next video');
    onEnding(w.itemId);
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    unawaited(_events.cancel());
    super.dispose();
  }
}
