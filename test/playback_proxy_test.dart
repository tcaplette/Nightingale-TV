import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/playback/index_cache.dart';
import 'package:nightingale_tv/playback/playback_proxy.dart';

import 'media_files.dart';

void main() {
  late ({File mp4, File faststart, File mkv}) videos;
  late FakeStreamServer upstream;
  late Directory dir;
  late PlaybackProxy proxy;
  late HttpClient mpv;
  final events = <ProxyEvent>[];
  const auth = {'Authorization': 'MediaBrowser Token="secret"'};

  setUpAll(() async => videos = await testVideos());

  setUp(() async {
    upstream = await FakeStreamServer.start({
      'index-at-end.mp4': videos.mp4.readAsBytesSync(),
      'faststart.mp4': videos.faststart.readAsBytesSync(),
      'movie.mkv': videos.mkv.readAsBytesSync(),
    });
    dir = await Directory.systemTemp.createTemp('nightingale_tv_proxy');
    proxy = PlaybackProxy(cacheDir: dir, inIsolate: false);
    await proxy.start();
    events.clear();
    proxy.events.listen(events.add);
    // ffmpeg's HTTP: a new connection for every request.
    mpv = HttpClient()..maxConnectionsPerHost = 8;
  });

  tearDown(() async {
    mpv.close(force: true);
    await proxy.close();
    await upstream.close();
    await dir.delete(recursive: true);
  });

  /// mpv reading [url] from [from] (to [to], or [take] bytes then leaving,
  /// as a seek does).
  Future<({int status, Map<String, String> headers, Uint8List body})> read(Uri url,
      {int? from, int? to, int? take}) async {
    final request = await mpv.getUrl(url);
    request.persistentConnection = false;
    if (from != null) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-${to ?? ''}');
    final response = await request.close();
    final headers = <String, String>{};
    response.headers.forEach((name, values) => headers[name] = values.join(','));
    final body = BytesBuilder(copy: false);
    if (take == null) {
      await for (final chunk in response) {
        body.add(chunk);
      }
    } else {
      final done = Completer<void>();
      late StreamSubscription<List<int>> sub;
      sub = response.listen((chunk) {
        body.add(chunk);
        if (body.length >= take && !done.isCompleted) {
          done.complete();
          unawaited(sub.cancel());
        }
      }, onDone: () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    }
    return (status: response.statusCode, headers: headers, body: body.takeBytes());
  }

  Future<void> settle([int ms = 100]) => Future<void>.delayed(Duration(milliseconds: ms));

  group('pass-through', () {
    test('ranges, status and headers pass through; mpv never sees the token', () async {
      final file = videos.mp4.readAsBytesSync();
      final url = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      expect(url.host, '127.0.0.1');
      expect(url.toString(), isNot(contains('secret')));
      final r = await read(url, from: 1000, to: 1999);
      expect(r.status, HttpStatus.partialContent);
      expect(r.headers['content-range'], 'bytes 1000-1999/${file.length}');
      expect(r.headers['content-length'], '1000');
      expect(r.headers['content-type'], 'video/mp4');
      expect(r.headers['accept-ranges'], 'bytes');
      expect(r.body, file.sublist(1000, 2000));
      expect(upstream.streamRequests.single.range, 'bytes=1000-1999');
      final whole = await read(url);
      expect(whole.status, HttpStatus.ok);
      expect(whole.body.length, file.length);
    });

    test('an unknown path gets a 404 and nothing goes upstream', () async {
      final url = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      final r = await read(url.replace(path: '/o/0123456789abcdef'));
      expect(r.status, HttpStatus.notFound);
      expect((await read(url.replace(path: '/'))).status, HttpStatus.notFound);
      expect(upstream.requests, isEmpty);
    });

    test('the open before stops being served', () async {
      final first = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      await proxy.open(upstream.streamUri('movie.mkv'), auth);
      expect((await read(first, from: 0, to: 10)).status, HttpStatus.notFound);
    });
  });

  group('warm connections', () {
    test('a seek after the first request starts on a connection already open', () async {
      await proxy.warm(Uri.parse('${upstream.url}/System/Ping'), auth);
      expect(upstream.connections, 2, reason: 'two spares warmed with /System/Ping');
      final url = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      // mpv reads the start, leaves it (a seek), then reads elsewhere.
      await read(url, from: 0, take: 100000);
      await read(url, from: 2000000, take: 100000);
      await read(url, from: 900000, take: 50000);
      await settle(300);
      final streams = upstream.streamRequests;
      expect(streams, hasLength(3));
      final pingPorts = {for (final r in upstream.requests.where((r) => r.path == '/System/Ping')) r.port};
      expect(pingPorts, contains(streams[0].port), reason: 'the first request used a warmed connection');
      expect(pingPorts, contains(streams[1].port), reason: 'so did the seek');
      final upstreamWarm = [for (final e in events.where((e) => e.kind == 'upstream')) e.data['warm']];
      expect(upstreamWarm, [true, true, true], reason: 'spares are topped up as they are used');
    });

    test('a response read to its end leaves its connection open for the next', () async {
      final url = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      await read(url, from: 0, to: 9999);
      await read(url, from: 10000, to: 19999);
      final streams = upstream.streamRequests;
      expect(streams[1].port, streams[0].port);
      final stats = await proxy.upstreamStats();
      expect(stats.requests, 2);
    });

    test('no pings in the background, and none until told where', () async {
      await proxy.setBackground(true);
      await proxy.warm(Uri.parse('${upstream.url}/System/Ping'), auth);
      final url = await proxy.open(upstream.streamUri('index-at-end.mp4'), auth);
      await read(url, from: 0, to: 9);
      await settle();
      expect(upstream.requests.where((r) => r.path == '/System/Ping'), isEmpty);
    });
  });

  group('index cache', () {
    for (final (name, file) in [
      ('MP4 with its moov at the end', 'index-at-end.mp4'),
      ('MP4 written for streaming', 'faststart.mp4'),
      ('Matroska', 'movie.mkv'),
    ]) {
      test('$name: a fill keeps the head and index, and they are served with no upstream traffic', () async {
        final bytes = upstream.files[file]!;
        final key = (source: file, etag: 'e1', size: bytes.length);
        final summary = await proxy.fill(key, upstream.streamUri(file), auth);
        expect(summary, contains(file));
        expect(await proxy.cached(file), isTrue);
        final found = await locateIndex((o, l) => Uint8List.sublistView(bytes, o, (o + l).clamp(0, bytes.length)), bytes.length)
            as IndexFound;
        upstream.requests.clear();

        final url = await proxy.open(upstream.streamUri(file), auth, cache: key, joins: true);
        final head = await read(url, from: 0, take: 4096);
        expect(head.status, HttpStatus.partialContent);
        expect(head.headers['content-range'], 'bytes 0-${bytes.length - 1}/${bytes.length}');
        expect(head.body.sublist(0, 4096), bytes.sublist(0, 4096));
        final index = await read(url, from: found.start, to: found.end - 1);
        expect(index.body, bytes.sublist(found.start, found.end));
        await settle();
        expect(upstream.streamRequests, isEmpty, reason: 'head and index come from the cache');
        expect(events.where((e) => e.kind == 'cache' && e.data['what'] == 'hit'), hasLength(2));

        // The join: the only upstream request.
        final join = await read(url, from: bytes.length ~/ 3, to: bytes.length ~/ 3 + 9999);
        expect(join.body, bytes.sublist(bytes.length ~/ 3, bytes.length ~/ 3 + 10000));
        expect(upstream.streamRequests, hasLength(1));
      });
    }

    test('an uncached file is learned from what mpv reads during its open', () async {
      const file = 'index-at-end.mp4';
      final bytes = upstream.files[file]!;
      final key = (source: file, etag: 'e1', size: bytes.length);
      final found = await locateIndex((o, l) => Uint8List.sublistView(bytes, o, (o + l).clamp(0, bytes.length)), bytes.length)
          as IndexFound;
      var url = await proxy.open(upstream.streamUri(file), auth, cache: key, joins: true);
      // What mpv does with this layout: the start, the index at the end,
      // then the join point.
      await read(url, from: 0, take: indexCacheHead + 50000);
      await read(url, from: found.start);
      await read(url, from: bytes.length ~/ 2, take: 10000);
      await settle(200);
      expect(await proxy.cached(file), isTrue);

      upstream.requests.clear();
      url = await proxy.open(upstream.streamUri(file), auth, cache: key, joins: true);
      await read(url, from: 0, take: 4096);
      expect((await read(url, from: found.start)).body, bytes.sublist(found.start));
      expect(upstream.streamRequests, isEmpty);
    });

    test('mpv reading only a little of the start, then the index, still teaches the cache the index', () async {
      const file = 'index-at-end.mp4';
      final bytes = upstream.files[file]!;
      final key = (source: file, etag: 'e1', size: bytes.length);
      final found = await locateIndex((o, l) => Uint8List.sublistView(bytes, o, (o + l).clamp(0, bytes.length)), bytes.length)
          as IndexFound;
      var url = await proxy.open(upstream.streamUri(file), auth, cache: key, joins: true);
      // As on a slow link: a few KB of the start, then straight to the end.
      await read(url, from: 0, take: 4096);
      await settle();
      await read(url, from: found.start);
      await read(url, from: bytes.length ~/ 2, take: 10000);
      await settle(200);

      upstream.requests.clear();
      url = await proxy.open(upstream.streamUri(file), auth, cache: key, joins: true);
      expect((await read(url, from: found.start)).body, bytes.sublist(found.start), reason: 'the index is kept already');
      expect(upstream.streamRequests, isEmpty);

      // A fill reads at most the rest of the head.
      final summary = await proxy.fill(key, upstream.streamUri(file), auth);
      expect(await proxy.cached(file), isTrue);
      expect(upstream.streamRequests.every((r) => r.range!.startsWith('bytes=') && !r.range!.startsWith('bytes=${found.start}')),
          isTrue, reason: summary);
    });

    test('reads past a cached head go on upstream at once when the open plays from the start', () async {
      const file = 'movie.mkv';
      final bytes = upstream.files[file]!;
      final key = (source: file, etag: null, size: bytes.length);
      await proxy.fill(key, upstream.streamUri(file), auth);
      upstream.requests.clear();
      final url = await proxy.open(upstream.streamUri(file), auth, cache: key);
      final all = await read(url, from: 0);
      expect(all.body, bytes);
      expect(upstream.streamRequests.single.range, 'bytes=$indexCacheHead-');
    });

    test('a replaced file (new size upstream) drops its entry', () async {
      const file = 'movie.mkv';
      final bytes = upstream.files[file]!;
      await proxy.fill((source: file, etag: 'e1', size: bytes.length), upstream.streamUri(file), auth);
      // The library now says another version.
      final url = await proxy.open(upstream.streamUri(file), auth, cache: (source: file, etag: 'e2', size: null));
      await read(url, from: 0, to: 99);
      expect(upstream.streamRequests.last.range, 'bytes=0-99', reason: 'read from upstream, not the cache');
    });

    test('fills hold off while a stream opens', () async {
      const file = 'faststart.mp4';
      final bytes = upstream.files[file]!;
      await proxy.setTuning(true);
      final summary = await proxy.fill((source: file, etag: null, size: bytes.length), upstream.streamUri(file), auth);
      expect(summary, contains('stopped'));
      expect(upstream.streamRequests, isEmpty);
      expect(await proxy.cached(file), isFalse);
    });

    test('fills keep to their rate', () async {
      const file = 'faststart.mp4';
      final bytes = upstream.files[file]!;
      final clock = Stopwatch()..start();
      // The head alone is 256 KB: at 1 MB/s, about a quarter of a second.
      await proxy.fill((source: file, etag: null, size: bytes.length), upstream.streamUri(file), auth,
          bytesPerSecond: 1000000);
      expect(clock.elapsed, greaterThan(const Duration(milliseconds: 240)));
    });
  });
}
