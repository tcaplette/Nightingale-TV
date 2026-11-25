import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/youtube_player.dart';
import 'package:nightingale_tv/playback/youtube_tuning.dart';

/// The `ntv/youtube_view` channel as the platform side sees it: the calls
/// the app makes, and the page's messages sent back.
class FakeView {
  FakeView() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  }

  static const channel = MethodChannel('ntv/youtube_view');
  final calls = <MethodCall>[];

  List<String> get scripts => [for (final c in calls) if (c.method == 'run') (c.arguments as Map)['js'] as String];
  List<Map> get frames => [for (final c in calls) if (c.method == 'frame') c.arguments as Map];
  List<Map> get loads => [for (final c in calls) if (c.method == 'load') c.arguments as Map];

  /// The page posts [event] (as player.html does).
  Future<void> post(Map<String, Object?> event) => send('message', jsonEncode(event));

  Future<void> send(String method, Object? args) async {
    final data = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel.name, data, (_) {});
  }

  void dispose() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeView view;
  final player = YouTubePlayer.instance;

  setUp(() async {
    view = FakeView();
    await player.recreate();
    view.calls.clear();
  });
  tearDown(() => view.dispose());

  test('the page is identified by the app id, and nothing plays before the player is ready', () async {
    await player.ensurePage(captions: true, captionLanguage: 'de');
    final load = view.loads.single;
    expect(load['baseUrl'], 'https://com.coffeehauslabs.nightingale_tv/');
    final html = load['html'] as String;
    expect(html, contains('"origin":"https://com.coffeehauslabs.nightingale_tv"'));
    expect(html, contains('"ccLoad":true'));
    expect(html, contains('"ccLang":"de"'));
    for (final p in ['playsinline: 1', 'controls: 0', 'disablekb: 1', 'fs: 0', 'rel: 0', 'iv_load_policy: 3', 'widget_referrer']) {
      expect(html, contains(p));
    }
    await player.load('abc', const Duration(seconds: 90));
    expect(view.scripts, isEmpty, reason: 'held until ready');
    await view.post({'e': 'ready'});
    await pumpEventQueue();
    expect(view.scripts, ['ntvLoad("abc", 90.0)']);
    // The same settings again: the page isn't made again.
    await player.ensurePage(captions: true, captionLanguage: 'de');
    expect(view.loads, hasLength(1));
  });

  test('a cued neighbour never plays; stop, seek and volume are the documented calls', () async {
    await player.ensurePage();
    await view.post({'e': 'ready'});
    await player.cue('n1', const Duration(seconds: 5));
    expect(player.playing, isFalse);
    await player.stop();
    await player.seek(const Duration(seconds: 12));
    await player.setVolume(40);
    expect(view.scripts, ['ntvCue("n1", 5.0)', 'ntvStop()', 'ntvSeek(12.0)', 'ntvVolume(40)']);
  });

  test('the player is placed and hidden by frame, in physical pixels on Android only', () async {
    await player.place(const Rect.fromLTWH(10, 20, 640, 360), devicePixelRatio: 2);
    await player.place(null);
    expect(view.frames.first, {'x': 10, 'y': 20, 'w': 640, 'h': 360, 'visible': true});
    expect(view.frames.last['visible'], isFalse);
  });

  group('tuning', () {
    late DateTime clock;
    late List<String> events;
    late YouTubeTuning tuning;

    setUp(() async {
      clock = DateTime(2026, 11, 23, 20);
      events = [];
      tuning = YouTubeTuning(
        clock: () => clock,
        onPlaying: () => events.add('playing'),
        onEnding: (id) => events.add('ending $id'),
        onSkip: (id, why) => events.add('skip $id ${why.name}'),
        onRefusedPlayer: () => events.add('refused player'),
        onNoWebView: () => events.add('no webview'),
      );
      await player.ensurePage();
      await view.post({'e': 'ready'});
      view.calls.clear();
    });
    tearDown(() => tuning.dispose());

    Future<void> settle() => pumpEventQueue();

    test('plays only once the frame is mostly on screen, at the scheduled offset', () async {
      tuning.wantVideo((videoId: 'v1', itemId: 's2~v1', videoStart: clock.subtract(const Duration(minutes: 4))));
      await settle();
      expect(view.scripts, isEmpty, reason: 'not seen yet');
      tuning.setVisible(true);
      await settle();
      expect(view.scripts, ['ntvLoad("v1", 240.0)']);
      await view.post({'e': 'state', 's': 1, 'id': 'v1'});
      await settle();
      expect(events, ['playing']);
    });

    test('hidden, paused or nothing wanted: it stops; coming back joins at the scheduled point', () async {
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      tuning.setVisible(false);
      await settle();
      expect(view.scripts.last, 'ntvStop()');
      clock = clock.add(const Duration(minutes: 10));
      tuning.setVisible(true);
      await settle();
      expect(view.scripts.last, 'ntvLoad("v1", 600.0)');
      tuning.hold(true);
      await settle();
      expect(view.scripts.last, 'ntvStop()');
      tuning.hold(false);
      await settle();
      expect(view.scripts.last, startsWith('ntvLoad("v1"'));
      tuning.wantVideo(null);
      await settle();
      expect(view.scripts.last, 'ntvStop()');
    });

    test('errors: 100, 101 and 150 refused, 2 failed, 5 retried once, 153 refuses the player', () async {
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      for (final code in [100, 101, 150]) {
        await view.post({'e': 'error', 'c': code, 'id': 'v1'});
      }
      await view.post({'e': 'error', 'c': 2, 'id': 'v1'});
      await settle();
      expect(events, ['skip v1 refused', 'skip v1 refused', 'skip v1 refused', 'skip v1 failed']);
      events.clear();
      view.calls.clear();
      await view.post({'e': 'error', 'c': 5, 'id': 'v1'});
      await settle();
      expect(events, isEmpty);
      expect(view.scripts, ['ntvLoad("v1", 0.0)'], reason: 'tried once more');
      await view.post({'e': 'error', 'c': 5, 'id': 'v1'});
      await settle();
      expect(events, ['skip v1 failed']);
      events.clear();
      await view.post({'e': 'error', 'c': 153, 'id': 'v1'});
      await settle();
      expect(events, ['refused player']);
    });

    test('a renderer crash makes the WebView again and tunes again', () async {
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      view.calls.clear();
      await view.send('crashed', 1);
      await settle();
      expect(view.calls.map((c) => c.method), containsAllInOrder(['recreate', 'load']));
      await view.post({'e': 'ready'});
      await settle();
      expect(view.scripts.last, startsWith('ntvLoad("v1"'));
    });

    test('no Android System WebView is reported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(FakeView.channel,
          (call) async => call.method == 'load' ? 'noWebView' : null);
      await player.recreate();
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      expect(events, ['no webview']);
    });

    test('a drift over 5 seconds is corrected once, at the next 10-second mark', () async {
      // 39.9 s into the video: the next 10-second mark is 100 ms away.
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock.subtract(const Duration(milliseconds: 39900))))
        ..setVisible(true);
      await settle();
      view.calls.clear();
      // 4 s off: left alone.
      await view.post({'e': 'pos', 't': 36, 'd': 600, 's': 1, 'id': 'v1'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(view.scripts, isEmpty);
      // 9.9 s behind: corrected at the mark.
      await view.post({'e': 'pos', 't': 30, 'd': 600, 's': 1, 'id': 'v1'});
      await settle();
      expect(view.scripts, isEmpty, reason: 'not before the mark');
      clock = clock.add(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(view.scripts, ['ntvSeek(40.0)']);
      // Only once.
      await view.post({'e': 'pos', 't': 0, 'd': 600, 's': 1, 'id': 'v1'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(view.scripts, hasLength(1));
    });

    test('a video played to its end hands over at once, once, and only for the wanted video', () async {
      tuning
        ..wantVideo((videoId: 'v1', itemId: 's2~v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      // Near the end, still playing: the video isn't cut short.
      await view.post({'e': 'pos', 't': 599.7, 'd': 600, 's': 1, 'id': 'v1'});
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(events, isEmpty);
      await view.post({'e': 'state', 's': 0, 'id': 'other'});
      await view.post({'e': 'state', 's': 0, 'id': 'v1'});
      await view.post({'e': 'state', 's': 0, 'id': 'v1'});
      await settle();
      expect(events, ['ending s2~v1']);
      // The next video wanted: its end counts again.
      tuning.wantVideo((videoId: 'v2', itemId: 's2~v2', videoStart: clock));
      await view.post({'e': 'state', 's': 0, 'id': 'v2'});
      await settle();
      expect(events, ['ending s2~v1', 'ending s2~v2']);
      // Paused, an end is the pause's, not the channel's.
      tuning
        ..wantVideo((videoId: 'v3', itemId: 's2~v3', videoStart: clock))
        ..hold(true);
      await view.post({'e': 'state', 's': 0, 'id': 'v3'});
      await settle();
      expect(events, hasLength(2));
    });

    test('a neighbour is only cued, and only while no YouTube channel is on', () async {
      tuning.cueNeighbour('n1', const Duration(seconds: 30));
      await settle();
      expect(view.scripts, ['ntvCue("n1", 30.0)']);
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      view.calls.clear();
      tuning.cueNeighbour('n2', Duration.zero);
      await settle();
      expect(view.scripts, isEmpty);
    });

    test('captions change the page and what plays goes on', () async {
      tuning
        ..wantVideo((videoId: 'v1', itemId: 'v1', videoStart: clock))
        ..setVisible(true);
      await settle();
      view.calls.clear();
      tuning.setCaptions(true, 'fr');
      await settle();
      expect((view.loads.single['html'] as String), contains('"ccLang":"fr"'));
      await view.post({'e': 'ready'});
      await settle();
      expect(view.scripts.last, startsWith('ntvLoad("v1"'));
    });
  });

  testWidgets('the frame keeps clear of overlays, and stops when they leave too little room', (tester) async {
    tester.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seen = <bool>[];
    var banner = false;
    late StateSetter set;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(builder: (context, s) {
        set = s;
        return Stack(fit: StackFit.expand, children: [
          YouTubeFrame(active: true, minSize: const Size(480, 270), onVisible: seen.add),
          if (banner)
            const Positioned(left: 0, right: 0, bottom: 0, height: 260, child: YouTubeObstacle(child: SizedBox.expand())),
        ]);
      }),
    ));
    await tester.pump();
    expect(view.frames.last, {'x': 0, 'y': 0, 'w': 1920, 'h': 1080, 'visible': true});
    expect(seen, [true]);
    set(() => banner = true);
    await tester.pump();
    await tester.pump();
    final f = view.frames.last;
    expect(f['y'] + f['h'], lessThanOrEqualTo(820));
    expect(f['w'] / f['h'], closeTo(16 / 9, 0.01));
    expect(f['h'], 820);
    // The banner gone, the picture fills the screen again.
    set(() => banner = false);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(view.frames.last, {'x': 0, 'y': 0, 'w': 1920, 'h': 1080, 'visible': true});
    set(() => banner = true);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(YouTubeObstacles.fit(const Rect.fromLTWH(0, 0, 1920, 1080), [const Rect.fromLTWH(0, 0, 1920, 900)]),
        const Rect.fromLTRB(800, 900, 1120, 1080));
    // Too little room: not shown, and so not playing.
    // As an obstacle does, the change asks for a frame.
    YouTubeObstacles.instance.set('prompt', const Rect.fromLTWH(0, 100, 1920, 900));
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(view.frames.last['visible'], isFalse);
    expect(seen.last, isFalse);
    YouTubeObstacles.instance.set('prompt', null);
    set(() => banner = false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

