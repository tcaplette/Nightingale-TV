// The YouTube player probe (youtube-subscriptions task 1.1/1.2): the app's
// player page in its WebView, a public video, every event and key logged.
//   flutter run -d linux -t tool/youtube_probe.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nightingale_tv/playback/youtube_player.dart';

const _video = String.fromEnvironment('NTV_PROBE_VIDEO', defaultValue: 'M7lc1UVf-VE');
const _cue = String.fromEnvironment('NTV_PROBE_CUE', defaultValue: 'aqz-KE-bpKQ');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final player = YouTubePlayer.instance;
  player.events.listen((e) => debugPrint('PROBE event ${switch (e) {
        YouTubeState(:final state, :final videoId) => 'state $state $videoId',
        YouTubeError(:final code, :final videoId) => 'error $code $videoId',
        YouTubePosition(:final position, :final state, :final videoId) =>
          'pos ${position.inMilliseconds} s$state $videoId',
        _ => e.runtimeType,
      }}'));
  runApp(const _Probe());
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  bool _small = false;
  bool _active = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(YouTubePlayer.instance.ensurePage());
  }

  void _visible(bool v) {
    debugPrint('PROBE visible $v');
    if (v && !_started) {
      _started = true;
      unawaited(YouTubePlayer.instance.load(_video, const Duration(seconds: 30)));
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    debugPrint('PROBE key ${e.logicalKey.keyLabel}');
    final p = YouTubePlayer.instance;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.keyS:
        unawaited(p.stop());
      case LogicalKeyboardKey.keyC:
        unawaited(p.cue(_cue, const Duration(seconds: 10)));
      case LogicalKeyboardKey.keyL:
        unawaited(p.load(_video, const Duration(seconds: 60)));
      case LogicalKeyboardKey.keyH:
        setState(() => _active = !_active);
      case LogicalKeyboardKey.keyR:
        setState(() => _small = !_small);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Focus(
          autofocus: true,
          onKeyEvent: _key,
          child: ColoredBox(
            color: const Color(0xFF203040),
            child: Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 40,
                top: 40,
                width: _small ? 480 : 960,
                height: _small ? 270 : 540,
                child: YouTubeFrame(active: _active, onVisible: _visible),
              ),
              const Positioned(
                left: 40,
                bottom: 20,
                child: Text('S stop · C cue · L load · H hide · R resize', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
}
