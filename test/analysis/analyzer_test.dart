import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/analysis/analysis_cache.dart';
import 'package:nightingale_tv/commercials/analysis/detections.dart';
import 'package:nightingale_tv/commercials/analysis/ffmpeg_runner.dart';
import 'package:nightingale_tv/commercials/analysis/media_analyzer.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/library/library_index.dart';

Duration _s(num s) => Duration(milliseconds: (s * 1000).round());

class _FakeScanner implements SceneScanner {
  _FakeScanner({this.installed = true});

  final bool installed;
  final scans = <String>[];
  final events = <String>[];
  int running = 0, maxRunning = 0;

  /// When set, scans wait for it.
  Completer<void>? gate;

  @override
  Future<bool> available() async => installed;

  @override
  Future<Detections> scan(Uri input, {Duration? from, Duration? length, required Duration runtime}) async {
    expect(input.host, '127.0.0.1');
    final id = input.pathSegments.last;
    scans.add(from == null ? id : '$id@${from.inSeconds}');
    running++;
    maxRunning = running > maxRunning ? running : maxRunning;
    try {
      await gate?.future;
      return Detections(blacks: [Span(_s(30), _s(30.5)), Span(_s(60), _s(60.5))], silences: [Span(_s(30), _s(31))]);
    } finally {
      running--;
    }
  }

  @override
  void pause() => events.add('pause');

  @override
  void resume() => events.add('resume');

  @override
  void cancel() {
    events.add('cancel');
    if (gate?.isCompleted == false) gate!.complete();
  }
}

MediaEntry _reel(String id) =>
    MediaEntry(id: id, kind: MediaKind.commercial, title: id, runtime: _s(90), etag: 'e', poolIds: const ['p']);

MediaEntry _show(String id) =>
    MediaEntry(id: id, kind: MediaKind.episode, title: id, runtime: const Duration(minutes: 22), etag: 'e');

void main() {
  late Directory dir;
  late AnalysisCache cache;
  late LoopbackStreamProxy proxy;
  var now = DateTime(2026, 10, 17, 18);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_analyzer');
    cache = await AnalysisCache.open(dir, 'srv');
    // In this isolate (with a client that never gets called: the scanner
    // is fake).
    proxy = LoopbackStreamProxy(
        upstream: (id) => Uri.parse('https://jf.example/$id'),
        headers: () => const {},
        httpClient: () => MockClient((_) async => http.Response('', 500)));
  });
  tearDown(() async {
    await proxy.close();
    await cache.close();
    await dir.delete(recursive: true);
  });

  Future<void> settle(MediaAnalyzer a, {int rounds = 40}) async {
    for (var i = 0; i < rounds && (a.progress.value.busy || !a.progress.value.complete); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // Reels of 5 minutes, so the cutter needs ffmpeg.
  MediaEntry longReel(String id) => MediaEntry(
      id: id, kind: MediaKind.commercial, title: id, runtime: const Duration(minutes: 5), etag: 'e', poolIds: const ['p']);

  test('reels first, then programs airing soon, then the rest; one at a time', () async {
    final scanner = _FakeScanner();
    final reads = <String>[];
    final analyzer = MediaAnalyzer(
      cache: cache,
      scanner: scanner,
      proxy: proxy,
      clock: () => now,
      segments: (id) async {
        reads.add(id);
        return const [];
      },
      work: () => AnalysisWork(
        reels: [longReel('reel-a'), longReel('reel-b')],
        programs: [
          ProgramNeed(_show('later'), const {2}),
          ProgramNeed(_show('tonight'), const {2}, soon: true),
        ],
      ),
    );
    analyzer.start();
    await settle(analyzer);
    expect(reads, ['reel-a', 'reel-b', 'tonight', 'later']);
    // Each program gets two 2-minute windows around its even points.
    expect(scanner.scans, ['reel-a', 'reel-b', 'tonight@380', 'tonight@820', 'later@380', 'later@820']);
    expect(scanner.maxRunning, 1);
    final p = analyzer.progress.value;
    expect((p.reelsDone, p.reelsTotal, p.programsDone, p.programsTotal), (2, 2, 2, 2));
    expect(cache.latest(longReel('reel-a'))!.cuts, isNotEmpty);
    expect(cache.pointsFor(_show('tonight'), now).scanned, hasLength(2));
    await analyzer.stop();
    expect(proxy.running, isFalse);
  });

  test('holds off while the TV is tuning, freezing a running scan', () async {
    final scanner = _FakeScanner()..gate = Completer<void>();
    final busy = ValueNotifier(true);
    final analyzer = MediaAnalyzer(
      cache: cache,
      scanner: scanner,
      proxy: proxy,
      busy: busy,
      clock: () => now,
      segments: (id) async => const [],
      work: () => AnalysisWork(reels: [longReel('reel')]),
    );
    analyzer.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(scanner.scans, isEmpty, reason: 'nothing starts while tuning');
    busy.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(scanner.scans, ['reel']);
    busy.value = true;
    expect(scanner.events.last, 'pause');
    busy.value = false;
    expect(scanner.events.last, 'resume');
    scanner.gate!.complete();
    await settle(analyzer);
    expect(cache.isAnalyzed(longReel('reel')), isTrue);
    await analyzer.stop();
  });

  test('stopping cancels the scan and keeps finished results', () async {
    final scanner = _FakeScanner()..gate = Completer<void>();
    final analyzer = MediaAnalyzer(
      cache: cache,
      scanner: scanner,
      proxy: proxy,
      clock: () => now,
      segments: (id) async => const [],
      work: () => AnalysisWork(reels: [_reel('short-reel'), longReel('long')]),
    );
    // A 90-second "reel" can't be split and is one clip; only the 5-minute
    // one is scanned.
    analyzer.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(analyzer.progress.value.current, isNotNull);
    await analyzer.stop();
    expect(scanner.events, contains('cancel'));
    expect(analyzer.running, isFalse);
    expect(analyzer.progress.value.busy, isFalse);
    expect(cache.isAnalyzed(longReel('long')), isFalse, reason: 'the cancelled scan left nothing behind');
    expect(cache.failuresOf(longReel('long')).$1, 0, reason: 'stopping is not a failure');
  });

  test('failures back off 1 min, 10 min, 1 h, then give up until the file changes', () async {
    var reads = 0;
    final analyzer = MediaAnalyzer(
      cache: cache,
      scanner: _FakeScanner(),
      proxy: proxy,
      clock: () => now,
      segments: (id) async {
        reads++;
        throw const SocketException('unreachable');
      },
      work: () => AnalysisWork(programs: [ProgramNeed(_show('ep'), const {2})]),
    );
    analyzer.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reads, 1);
    for (final wait in MediaAnalyzer.backoff) {
      now = now.add(wait - const Duration(seconds: 1));
      analyzer.poke();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final before = reads;
      now = now.add(const Duration(seconds: 1));
      analyzer.poke();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reads, before + 1, reason: 'retried after $wait');
    }
    expect(cache.gaveUpOn(_show('ep')), isTrue);
    expect(analyzer.progress.value.failed, 1);
    now = now.add(const Duration(days: 1));
    analyzer.poke();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(reads, 4, reason: 'given up on');
    await analyzer.stop();
  });

  test('without ffmpeg: chapters and segments still work; other reels wait', () async {
    final scanner = _FakeScanner(installed: false);
    final chaptered = MediaEntry(
        id: 'chaptered',
        kind: MediaKind.commercial,
        title: 'c',
        runtime: _s(120 * 4),
        etag: 'e',
        chapters: [for (var i = 0; i < 16; i++) _s(i * 30)]);
    final analyzer = MediaAnalyzer(
      cache: cache,
      scanner: scanner,
      proxy: proxy,
      clock: () => now,
      segments: (id) async => const [],
      work: () => AnalysisWork(reels: [chaptered, longReel('plain')], programs: [ProgramNeed(_show('ep'), const {2})]),
    );
    analyzer.start();
    await settle(analyzer);
    expect(scanner.scans, isEmpty);
    expect(cache.latest(chaptered)!.cuts, hasLength(16));
    expect(cache.isAnalyzed(longReel('plain')), isFalse);
    expect(cache.isAnalyzed(_show('ep')), isTrue, reason: 'segments were read; points stay unsnapped');
    final p = analyzer.progress.value;
    expect(p.ffmpegMissing, isTrue);
    expect(p.reelsNeedingFfmpeg, 1);
    expect((p.programsDone, p.programsTotal), (1, 1));
    await analyzer.stop();
  });
}
