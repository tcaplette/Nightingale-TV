import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/playback_diagnostics.dart';

/// A player whose position and frame gap the test sets.
class _FakePlayer implements PlayerReadings {
  double? position = 0;
  Duration? gap = const Duration(milliseconds: 33);

  @override
  Future<double?> debugPosition() async => position;

  @override
  Future<Duration?> debugFrameGap(Duration window) async => gap;

  @override
  Future<FrameCounts> debugFrames() async => (dropped: 0, decoderDropped: 0, delayed: 0, mistimed: 0);

  @override
  Future<List<String>> debugLive() async => const [];

  @override
  Future<List<String>> debugStall() async => const ['state=ready'];

  @override
  Future<String?> debugStream() async => null;
}

/// Collects what the diagnostics write.
class _Lines implements StreamConsumer<List<int>> {
  final buffer = StringBuffer();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
    }
  }

  @override
  Future<void> close() async {}

  List<String> freezes() =>
      buffer.toString().split('\n').where((l) => l.contains('\tFREEZE\t')).map((l) => l.split('\t').last).toList();
}

void main() {
  late _FakePlayer player;
  late _Lines lines;
  late IOSink sink;
  late PlaybackDiagnostics diagnostics;
  late DateTime now;
  var playing = true;

  setUp(() {
    player = _FakePlayer();
    lines = _Lines();
    sink = IOSink(lines);
    now = DateTime(2026, 11, 8, 20);
    playing = true;
    diagnostics = PlaybackDiagnostics.forTest(sink, player, () => playing, now: () => now);
  });

  /// One freeze check 250 ms after the last, with the position moving 0.25 s
  /// (the audio clock), and the frame gap from [gap].
  Future<void> tick(Duration Function() gap) async {
    now = now.add(const Duration(milliseconds: 250));
    player.position = player.position! + 0.25;
    player.gap = gap();
    await diagnostics.checkFreeze();
  }

  Future<List<String>> freezes() async {
    await sink.flush();
    return lines.freezes();
  }

  test('the picture stops while the position moves: one started, one ended of about 2000 ms', () async {
    for (var i = 0; i < 8; i++) {
      await tick(() => const Duration(milliseconds: 40));
    }
    // The last picture shows at `stop`; nothing more for 2 s.
    final stop = now;
    while (now.difference(stop) < const Duration(seconds: 2)) {
      await tick(() => now.difference(stop));
    }
    // Pictures move again: the window still holds the 2 s gap for 750 ms.
    final frozenFor = now.difference(stop);
    for (var i = 0; i < 3; i++) {
      await tick(() => frozenFor);
    }
    for (var i = 0; i < 8; i++) {
      await tick(() => const Duration(milliseconds: 40));
    }
    final lines = await freezes();
    expect(lines, hasLength(2));
    expect(lines[0], startsWith('started at pos='));
    final ms = int.parse(RegExp(r'ended after (\d+) ms').firstMatch(lines[1])!.group(1)!);
    expect(ms, inInclusiveRange(1900, 2400));
  });

  test('the started line comes within 1 s of the picture stopping', () async {
    for (var i = 0; i < 4; i++) {
      await tick(() => const Duration(milliseconds: 40));
    }
    final stop = now;
    String? started;
    while (started == null && now.difference(stop) < const Duration(seconds: 2)) {
      await tick(() => now.difference(stop));
      final l = await freezes();
      if (l.isNotEmpty) started = l.first;
    }
    expect(started, isNotNull);
    expect(now.difference(stop), lessThanOrEqualTo(const Duration(seconds: 1)));
  });

  test('a moving picture gives no FREEZE', () async {
    for (var i = 0; i < 40; i++) {
      await tick(() => Duration(milliseconds: 33 + (i % 3) * 100));
    }
    expect(await freezes(), isEmpty);
  });

  test('a pause and resume gives no FREEZE', () async {
    for (var i = 0; i < 4; i++) {
      await tick(() => const Duration(milliseconds: 40));
    }
    playing = false;
    final stop = now;
    for (var i = 0; i < 20; i++) {
      now = now.add(const Duration(milliseconds: 250));
      player.gap = now.difference(stop);
      await diagnostics.checkFreeze();
    }
    playing = true;
    // The first picture after the resume comes within 250 ms; the window
    // holds the pause's gap for a moment.
    final gapAtResume = now.add(const Duration(milliseconds: 100)).difference(stop);
    for (var i = 0; i < 3; i++) {
      await tick(() => gapAtResume);
    }
    for (var i = 0; i < 8; i++) {
      await tick(() => const Duration(milliseconds: 40));
    }
    expect(await freezes(), isEmpty);
  });

  test('no frame gap: the position decides', () async {
    player.gap = null;
    for (var i = 0; i < 4; i++) {
      now = now.add(const Duration(milliseconds: 250));
      player.position = player.position! + 0.25;
      await diagnostics.checkFreeze();
    }
    // The position stops for 1.5 s.
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(milliseconds: 250));
      await diagnostics.checkFreeze();
    }
    now = now.add(const Duration(milliseconds: 250));
    player.position = player.position! + 0.25;
    await diagnostics.checkFreeze();
    final lines = await freezes();
    expect(lines, hasLength(2));
    expect(lines[0], startsWith('started'));
    expect(lines[1], startsWith('ended after'));
  });

  test('no frame gap and a moving position gives no FREEZE', () async {
    player.gap = null;
    for (var i = 0; i < 20; i++) {
      now = now.add(const Duration(milliseconds: 250));
      player.position = player.position! + 0.25;
      await diagnostics.checkFreeze();
    }
    expect(await freezes(), isEmpty);
  });
}
