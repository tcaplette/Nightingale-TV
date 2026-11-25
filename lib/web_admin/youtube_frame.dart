import 'dart:async';

import 'package:flutter/widgets.dart';

import 'youtube_frame_stub.dart' if (dart.library.js_interop) 'youtube_frame_web.dart' as impl;

/// What YouTube's player says (its IFrame Player API).
sealed class YouTubeFrameEvent {
  const YouTubeFrameEvent();
}

/// [videoId] played to its end.
class YouTubeFrameEnded extends YouTubeFrameEvent {
  const YouTubeFrameEnded(this.videoId);
  final String videoId;
}

/// [videoId] shows its picture.
class YouTubeFramePlaying extends YouTubeFrameEvent {
  const YouTubeFramePlaying(this.videoId);
  final String videoId;
}

/// YouTube's error [code] on [videoId] (100, 101, 150: it won't play
/// here; 153: the player was refused).
class YouTubeFrameError extends YouTubeFrameEvent {
  const YouTubeFrameError(this.code, this.videoId);
  final int code;
  final String? videoId;
}

/// YouTube's embedded player in the page (docker-youtube D5): an iframe of
/// `youtube.com/embed`, driven through the IFrame Player API, and whether
/// the browser tab is hidden. The only way the web admin plays YouTube.
abstract class YouTubeFrame {
  /// The player's frame, for the page to lay out.
  Widget view();

  /// Plays [videoId] from [start].
  Future<void> load(String videoId, Duration start);

  void pause();

  /// Stops and lets go of the player.
  void dispose();

  Stream<YouTubeFrameEvent> get events;

  /// Escape pressed on the page outside Flutter's key handling (focus left
  /// with the body after the viewer used YouTube's controls).
  Stream<void> get escapes;

  /// The tab is hidden (true) or shown again (false).
  Stream<bool> get hiddenChanges;

  bool get hidden;

  /// The player for this platform; tests set [override].
  static YouTubeFrame create() => override?.call() ?? impl.createFrame();

  @visibleForTesting
  static YouTubeFrame Function()? override;
}
