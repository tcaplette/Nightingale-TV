// Time from "open" to a moving picture with the app's real player (mpv
// through MediaKitTunerPlayer), stage by stage, on a link of a known speed:
// a local server serves episode-length test files (made with ffmpeg once,
// then kept in the system temp folder) at LINK_MBPS, adding LATENCY_MS
// before each response, as a remote server's connection set-up does. Every
// HTTP request mpv makes (each seek is a new one) is counted.
//
// Each case prints a TUNE line (see TuneTimeline). Opens go through the
// app's playback proxy (as the tuner's do): first each file uncached, then,
// after a background fill of its head and index, cached. Cached opens, and
// the Matroska file's uncached one, fail when the first picture takes longer
// than BUDGET_MS or (joins) make more than one upstream request. No Jellyfin
// server is involved.
//
//   flutter test integration_test/startup_latency_test.dart -d linux
//   LINK_MBPS=1 LATENCY_MS=300 BUDGET_MS=2500 flutter test integration_test/startup_latency_test.dart -d linux
//   NIGHTINGALE_TV_NO_PROXY=1 flutter test integration_test/startup_latency_test.dart -d linux   (mpv straight to the server)
//
// Linux only (it needs ffmpeg to make the files).
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nightingale_tv/playback/playback_proxy.dart';
import 'package:nightingale_tv/playback/tune_timeline.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';

double _env(String name, double fallback) => double.tryParse(Platform.environment[name] ?? '') ?? fallback;

/// The test link: shared by every connection, like one home connection.
final _linkBitsPerSecond = _env('LINK_MBPS', 2.5) * 1e6;
final _latency = Duration(milliseconds: _env('LATENCY_MS', 250).round());
final _budget = Duration(milliseconds: _env('BUDGET_MS', 2000).round());

/// Episode length, so an MP4's index is as big as a real episode's.
const _length = Duration(minutes: 22);

/// The files, by name: how each is made from the first (an MP4 written the
/// way ffmpeg and most encoders write it, index last).
const _files = {
  'mp4-index-at-end': <String>[],
  'mp4-faststart': ['-c', 'copy', '-movflags', '+faststart'],
  'mkv': ['-c', 'copy'],
};

Future<Directory> _media() async {
  final dir = Directory('${Directory.systemTemp.path}/nightingale_tv_latency_media_v1');
  await dir.create(recursive: true);
  final base = File('${dir.path}/mp4-index-at-end.mp4');
  if (!base.existsSync()) {
    final r = await Process.run('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'testsrc2=size=480x270:rate=24000/1001',
      '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
      '-t', '${_length.inSeconds}',
      // Noise, so the video really is ~1.4 Mbps, like a compressed episode.
      '-vf', 'noise=alls=20:allf=t',
      '-c:v', 'libx264', '-preset', 'ultrafast', '-b:v', '1400k', '-maxrate', '1400k', '-bufsize', '2800k', '-g', '48',
      '-c:a', 'aac', '-b:a', '128k',
      '${base.path}.part.mp4',
    ]);
    if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
    await File('${base.path}.part.mp4').rename(base.path);
  }
  for (final MapEntry(key: name, value: args) in _files.entries) {
    if (args.isEmpty) continue;
    final ext = name == 'mkv' ? 'mkv' : 'mp4';
    final out = File('${dir.path}/$name.$ext');
    if (out.existsSync()) continue;
    final r = await Process.run(
        'ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', base.path, ...args, '${out.path}.part.$ext']);
    if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
    await File('${out.path}.part.$ext').rename(out.path);
  }
  return dir;
}

/// Serves files with Range support over one shared, paced link.
class _SlowServer {
  _SlowServer._(this._server, this._dir);

  final HttpServer _server;
  final Directory _dir;
  DateTime _linkFreeAt = DateTime.now();

  /// Requests since the last [reset]: (path, range).
  final requests = <(String, String?)>[];
  int bytesSent = 0;
  int pings = 0;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_SlowServer> start(Directory dir) async {
    final s = _SlowServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), dir);
    s._server.listen(s._handle);
    return s;
  }

  void reset() {
    requests.clear();
    bytesSent = 0;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (request.uri.path == '/System/Ping') {
      // The proxy's warm-up: connection set-up is what it pays for.
      pings++;
      await Future<void>.delayed(_latency);
      response.write('Jellyfin Server');
      await response.close();
      return;
    }
    requests.add((request.uri.path, range));
    // /Videos/<file>/stream, like Jellyfin's static stream.
    final name = request.uri.pathSegments.length > 1 ? request.uri.pathSegments[1] : '';
    final file = File('${_dir.path}/$name');
    await Future<void>.delayed(_latency);
    if (!file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final size = file.lengthSync();
    var from = 0;
    var to = size - 1;
    if (range != null) {
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (m != null) {
        from = int.parse(m.group(1)!);
        if (m.group(2)!.isNotEmpty) to = min(int.parse(m.group(2)!), size - 1);
      }
    }
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..contentType = ContentType('video', name.endsWith('.mkv') ? 'x-matroska' : 'mp4')
      ..contentLength = to - from + 1;
    if (range != null) {
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $from-$to/$size');
    }
    final raf = await file.open();
    try {
      await raf.setPosition(from);
      const piece = 16 * 1024;
      var left = to - from + 1;
      while (left > 0) {
        final chunk = await raf.read(min(piece, left));
        left -= chunk.length;
        if (chunk.isEmpty) break;
        // The link is shared: each piece waits for the ones before it.
        final now = DateTime.now();
        final start = _linkFreeAt.isAfter(now) ? _linkFreeAt : now;
        _linkFreeAt = start.add(Duration(microseconds: (chunk.length * 8 / _linkBitsPerSecond * 1e6).round()));
        final wait = _linkFreeAt.difference(now);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        response.add(chunk);
        await response.flush();
        bytesSent += chunk.length;
      }
      await response.close();
    } on Object {
      // mpv closed the connection (it seeks with a new one).
    } finally {
      await raf.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory media;
  late _SlowServer server;
  late MediaKitTunerPlayer player;
  late Directory cacheDir;
  PlaybackProxy? proxy;

  setUpAll(() async {
    MediaKit.ensureInitialized();
    media = await _media();
    server = await _SlowServer.start(media);
    cacheDir = await Directory.systemTemp.createTemp('nightingale_tv_latency_index');
    if (!PlaybackProxy.disabled) {
      proxy = PlaybackProxy(cacheDir: cacheDir);
      await proxy!.start();
      await proxy!.warm(Uri.parse('${server.url}/System/Ping'), const {});
    }
  });

  tearDownAll(() async {
    await proxy?.close();
    await server.close();
    await cacheDir.delete(recursive: true);
  });

  /// Opens [file] at [start] the way the tuner does (through the proxy,
  /// with its cache key), and times it to the first moving picture (or the
  /// timeout).
  Future<TuneTimeline> open(WidgetTester tester, String file, Duration start, {required bool exact, String? label}) async {
    server.reset();
    final clock = Stopwatch()..start();
    final timeline = TuneTimeline('test', label ?? file, Duration.zero)..kind = exact ? 'direct' : 'direct-keyframe';
    final subs = <StreamSubscription<Object?>>[];
    Duration? last;
    subs.add(player.logStream.listen((line) => timeline.mpvLine(line, clock.elapsed)));
    final p = proxy;
    timeline.proxy = p != null;
    if (p != null) {
      subs.add(p.events.listen((e) {
        if (e.kind == 'upstream') timeline.upstreamRequest(e.data['warm'] == true);
        if (e.kind == 'cache') timeline.cache('${e.data['what']}');
      }));
    }
    subs.add(player.positionStream.listen((p) {
      // The tuner's rule: two ticks near the landing point, moving forward.
      if (timeline.done || (p - start).abs() > const Duration(seconds: 30)) return;
      final before = last;
      last = p;
      if (before != null && p > before && p - before < const Duration(seconds: 1)) {
        timeline.finish('picture', clock.elapsed);
      }
    }));
    timeline.openCalled = clock.elapsed;
    final real = Uri.parse('${server.url}/Videos/$file/stream?static=true');
    final url = p == null
        ? real
        : (await tester.runAsync(() => p.open(real, const {},
            cache: (source: file, etag: null, size: File('${media.path}/$file').lengthSync()),
            joins: start > const Duration(seconds: 1))))!;
    await tester.runAsync(() => player.open(url, headers: const {}, start: start, exact: exact));
    final limit = _budget * 4 + const Duration(seconds: 20);
    while (!timeline.done && clock.elapsed < limit) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    timeline.finish('timeout', clock.elapsed);
    for (final s in subs) {
      await s.cancel();
    }
    await tester.runAsync(() => player.stop());
    // ignore: avoid_print
    print('TUNE\t${timeline.summary()} | requests=${server.requests.length} '
        '${server.requests.map((r) => r.$2 ?? 'whole').join(',')} | sent=${(server.bytesSent / 1e6).toStringAsFixed(2)} MB');
    return timeline;
  }

  testWidgets('first picture within the budget, by file layout and join', (tester) async {
    player = MediaKitTunerPlayer(verboseLog: true);
    await tester.pumpWidget(MaterialApp(home: Video(controller: player.video, controls: NoVideoControls)));
    // ignore: avoid_print
    print('link ${_linkBitsPerSecond / 1e6} Mbps, ${_latency.inMilliseconds} ms per request, budget ${_budget.inMilliseconds} ms');

    final misses = <String>[];
    final rng = Random(7);
    void check(TuneTimeline t, String what, {bool join = false}) {
      final took = t.total!;
      final upstream = server.requests.length;
      if (t.outcome != 'picture' || took > _budget) {
        misses.add('$what: ${t.outcome} after ${took.inMilliseconds} ms, slowest ${t.slowest?.$1} '
            '${t.slowest?.$2.inMilliseconds} ms, problems ${t.problems.join(',')}');
      }
      if (join && proxy != null && upstream > 1) misses.add('$what: $upstream upstream requests (one expected)');
    }

    for (final MapEntry(:key) in _files.entries) {
      final file = '$key.${key == 'mkv' ? 'mkv' : 'mp4'}';
      // A segment opening on schedule (exact, from its start), and a mid-show
      // join (keyframe, somewhere in the middle).
      final join = Duration(seconds: 300 + rng.nextInt(600));
      final p = proxy;
      if (p != null) {
        // The first open of a file nobody has opened: it plays as it would
        // without the cache, and teaches the cache its head and index. Only
        // the Matroska file's is held to the budget (an MP4's index is
        // read in full before any picture, so it's what the fill is for).
        final first = await open(tester, file, join, exact: false, label: '$file uncached');
        if (key == 'mkv') check(first, '$file uncached join at $join', join: false);
        // What the tee kept is dropped, so the fill below is what's timed.
        await tester.runAsync(() async {
          for (final f in cacheDir.listSync()) {
            f.deleteSync();
          }
        });
        await tester.runAsync(() => p.close());
        proxy = PlaybackProxy(cacheDir: cacheDir);
        await tester.runAsync(() async {
          await proxy!.start();
          await proxy!.warm(Uri.parse('${server.url}/System/Ping'), const {});
          // The pre-fill: what the app does in the background for what's on
          // soon.
          server.reset();
          final summary = await proxy!.fill((source: file, etag: null, size: File('${media.path}/$file').lengthSync()),
              Uri.parse('${server.url}/Videos/$file/stream?static=true'), const {});
          // ignore: avoid_print
          print('CACHE\t$summary | requests=${server.requests.length} sent=${(server.bytesSent / 1e6).toStringAsFixed(2)} MB');
        });
      }
      for (final (start, exact) in [(Duration.zero, true), (join, false)]) {
        final t = await open(tester, file, start, exact: exact);
        check(t, '$file at $start (${exact ? 'exact' : 'keyframe'})', join: !exact);
      }
    }
    // As in the app: the video leaves the screen before its player goes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => player.dispose());
    expect(misses, isEmpty, reason: 'opens over the ${_budget.inMilliseconds} ms budget:\n${misses.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
