import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';

void main() {
  late LoopbackStreamProxy proxy;
  final upstreamCalls = <http.BaseRequest>[];
  final client = HttpClient();

  setUp(() async {
    upstreamCalls.clear();
    proxy = LoopbackStreamProxy(
      upstream: (id) => Uri.parse('https://jf.example/Videos/$id/stream?static=true'),
      headers: () => {'Authorization': 'MediaBrowser Token="secret-token"'},
      httpClient: () => MockClient.streaming((request, body) async {
        upstreamCalls.add(request);
        final range = request.headers['range'];
        if (range == 'bytes=10-19') {
          return http.StreamedResponse(Stream.value(utf8.encode('0123456789')), 206,
              contentLength: 10,
              headers: {'content-type': 'video/mp4', 'content-range': 'bytes 10-19/3061635386', 'accept-ranges': 'bytes'});
        }
        return http.StreamedResponse(Stream.value(utf8.encode('whole file')), 200,
            contentLength: 10, headers: {'content-type': 'video/mp4'});
      }),
    );
    await proxy.start();
  });

  tearDown(() => proxy.close());

  Future<(int, String, HttpHeaders)> get(Uri url, {String? range, String method = 'GET'}) async {
    final request = await client.openUrl(method, url);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    return (response.statusCode, await utf8.decodeStream(response), response.headers);
  }

  test('listens on the loopback address only, with a 128-bit path secret', () async {
    await proxy.allow('reel');
    final url = proxy.urlFor('reel');
    expect(url.host, '127.0.0.1');
    expect(url.pathSegments.first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(url.toString(), isNot(contains('secret-token')));
  });

  test('a wrong secret gets 404, and nothing reaches Jellyfin', () async {
    await proxy.allow('reel');
    final url = proxy.urlFor('reel');
    final wrong = url.replace(path: '/${'0' * 32}/reel');
    expect((await get(wrong)).$1, 404);
    expect((await get(url.replace(path: '/reel'))).$1, 404);
    expect(upstreamCalls, isEmpty);
  });

  test('an item not queued for analysis gets 404', () async {
    await proxy.allow('reel');
    final other = proxy.urlFor('other-item');
    expect((await get(other)).$1, 404);
    await proxy.disallow('reel');
    expect((await get(proxy.urlFor('reel'))).$1, 404);
    expect(upstreamCalls, isEmpty);
  });

  test('only GET is served', () async {
    await proxy.allow('reel');
    expect((await get(proxy.urlFor('reel'), method: 'POST')).$1, 405);
    expect(upstreamCalls, isEmpty);
  });

  test('a Range request is forwarded with the auth headers, and the 206 relayed', () async {
    await proxy.allow('reel');
    final (status, body, headers) = await get(proxy.urlFor('reel'), range: 'bytes=10-19');
    expect(status, 206);
    expect(body, '0123456789');
    expect(headers.value('content-range'), 'bytes 10-19/3061635386');
    expect(headers.value('accept-ranges'), 'bytes');
    expect(headers.contentType?.mimeType, 'video/mp4');
    expect(headers.contentLength, 10);
    final forwarded = upstreamCalls.single;
    expect(forwarded.url.toString(), 'https://jf.example/Videos/reel/stream?static=true');
    expect(forwarded.headers['range'], 'bytes=10-19');
    expect(forwarded.headers['Authorization'], contains('secret-token'));
  });

  test('closing stops it; a restart has a new secret', () async {
    await proxy.allow('reel');
    final before = proxy.urlFor('reel');
    await proxy.close();
    expect(() => proxy.urlFor('reel'), throwsStateError);
    await proxy.start();
    await proxy.allow('reel');
    expect(proxy.urlFor('reel').pathSegments.first, isNot(before.pathSegments.first));
  });

  test('in its own isolate, it serves the same way', () async {
    // A one-off upstream on loopback stands in for Jellyfin.
    final jellyfin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <String?>[];
    jellyfin.listen((r) async {
      seen.add(r.headers.value('authorization'));
      r.response
        ..statusCode = 206
        ..headers.set('content-range', 'bytes 0-4/10')
        ..write('hello');
      await r.response.close();
    });
    final isolated = LoopbackStreamProxy(
      upstream: (id) => Uri.parse('http://127.0.0.1:${jellyfin.port}/Videos/$id/stream'),
      headers: () => {'Authorization': 'MediaBrowser Token="secret-token"'},
    );
    await isolated.start();
    await isolated.allow('reel');
    final (status, body, headers) = await get(isolated.urlFor('reel'), range: 'bytes=0-4');
    expect((status, body), (206, 'hello'));
    expect(headers.value('content-range'), 'bytes 0-4/10');
    expect(seen.single, contains('secret-token'));
    expect((await get(isolated.urlFor('other'))).$1, 404);
    await isolated.close();
    expect(isolated.running, isFalse);
    await jellyfin.close(force: true);
  });

  group('budget', () {
    /// A 300 KB video with a recognizable pattern, in 16 KB chunks.
    final body = List<int>.generate(300 * 1024, (i) => (i * 31) % 251);
    late LoopbackStreamProxy metered;

    setUp(() async {
      metered = LoopbackStreamProxy(
        upstream: (id) => Uri.parse('https://jf.example/Videos/$id/stream?static=true'),
        headers: () => const {},
        httpClient: () => MockClient.streaming((request, _) async => http.StreamedResponse(
            Stream.fromIterable([for (var i = 0; i < body.length; i += 16384) body.sublist(i, min(i + 16384, body.length))]),
            200,
            contentLength: body.length)),
      );
      await metered.start();
      await metered.allow('reel');
    });

    tearDown(() => metered.close());

    /// Reads [url], noting when each byte arrived (ms since the request).
    Future<(List<int>, List<(int, int)>)> read(Uri url, {void Function(int ms)? tick}) async {
      final watch = Stopwatch()..start();
      // From the request on: headers only come with the first bytes.
      final ticker = tick == null ? null : Timer.periodic(const Duration(milliseconds: 50), (_) => tick(watch.elapsedMilliseconds));
      final response = await (await client.getUrl(url)).close();
      final bytes = <int>[];
      final arrivals = <(int, int)>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        arrivals.add((watch.elapsedMilliseconds, chunk.length));
      }
      ticker?.cancel();
      return (bytes, arrivals);
    }

    /// The most bytes that arrived in any 1-second window.
    int busiestSecond(List<(int, int)> arrivals) {
      var most = 0;
      for (final (start, _) in arrivals) {
        final inWindow = arrivals.where((a) => a.$1 >= start && a.$1 < start + 1000).fold(0, (n, a) => n + a.$2);
        most = max(most, inWindow);
      }
      return most;
    }

    test('limited: no 1-second window gets more than the budget', () async {
      await metered.setBudget(const Budget.limited(100 * 1024));
      final (bytes, arrivals) = await read(metered.urlFor('reel'));
      expect(bytes, body);
      expect(busiestSecond(arrivals), lessThanOrEqualTo(100 * 1024));
      expect(arrivals.last.$1, greaterThan(2500), reason: '300 KB at 100 KB/s takes about 3 s');
    });

    test('paused, limited, paused, unlimited: each change applies within 1 s, and every byte arrives intact', () async {
      await metered.setBudget(const Budget.paused());
      final changes = <(int, Budget)>[];
      void at(int ms, Budget b) {
        if (changes.any((c) => c.$2 == b && c.$1 <= ms) || changes.isNotEmpty && changes.last.$1 > ms) return;
        changes.add((ms, b));
        unawaited(metered.setBudget(b));
      }

      final (bytes, arrivals) = await read(metered.urlFor('reel'), tick: (ms) {
        if (ms >= 500 && changes.isEmpty) at(ms, const Budget.limited(50 * 1024));
        if (ms >= 2000 && changes.length == 1) at(ms, const Budget.paused());
        if (ms >= 4000 && changes.length == 2) at(ms, const Budget.unlimited());
      });
      expect(bytes, body, reason: 'nothing lost or reordered');
      final (toLimited, _) = changes[0];
      final (toPaused, _) = changes[1];
      final (toUnlimited, _) = changes[2];
      expect(arrivals.where((a) => a.$1 < toLimited), isEmpty, reason: 'nothing while paused');
      expect(arrivals.where((a) => a.$1 >= toLimited && a.$1 < toLimited + 1000), isNotEmpty);
      expect(arrivals.where((a) => a.$1 >= toPaused + 1000 && a.$1 < toUnlimited), isEmpty,
          reason: 'stopped within 1 s of pausing');
      expect(arrivals.last.$1, lessThan(toUnlimited + 1000), reason: 'the rest at once');
    });

    test('unlimited: the whole file at full speed', () async {
      final (bytes, arrivals) = await read(metered.urlFor('reel'));
      expect(bytes, body);
      expect(arrivals.last.$1, lessThan(500));
    });
  });

  test('in its own isolate, the budget holds a transfer until lifted', () async {
    final jellyfin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    jellyfin.listen((r) async {
      r.response.add(List<int>.filled(64 * 1024, 7));
      await r.response.close();
    });
    final isolated = LoopbackStreamProxy(
      upstream: (id) => Uri.parse('http://127.0.0.1:${jellyfin.port}/Videos/$id/stream'),
      headers: () => const {},
    )..budget = const Budget.paused();
    await isolated.start();
    await isolated.allow('reel');
    var received = 0;
    final done = () async {
      final response = await (await client.getUrl(isolated.urlFor('reel'))).close();
      await response.forEach((c) => received += c.length);
    }();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(received, 0);
    await isolated.setBudget(const Budget.unlimited());
    await done.timeout(const Duration(seconds: 2));
    expect(received, 64 * 1024);
    await isolated.close();
    await jellyfin.close(force: true);
  });
}
