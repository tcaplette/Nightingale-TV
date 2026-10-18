import 'dart:convert';
import 'dart:io';

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
}
