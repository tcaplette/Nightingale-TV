import 'dart:async';

import 'package:flutter/widgets.dart';

import 'youtube_frame.dart';

/// Off the web there's no YouTube player: an empty frame.
YouTubeFrame createFrame() => _NoFrame();

class _NoFrame extends YouTubeFrame {
  @override
  Widget view() => const SizedBox.expand();
  @override
  Future<void> load(String videoId, Duration start) async {}
  @override
  void pause() {}
  @override
  void dispose() {}
  @override
  Stream<YouTubeFrameEvent> get events => const Stream.empty();
  @override
  Stream<void> get escapes => const Stream.empty();
  @override
  Stream<bool> get hiddenChanges => const Stream.empty();
  @override
  bool get hidden => false;
}
