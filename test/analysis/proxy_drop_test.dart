import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';

void main() {
  // Quitting closes the proxy's connections: the server's transfer breaks
  // after the reader (ffmpeg) has already gone. That must end quietly, not
  // as an unhandled error (which the test zone would report).
  for (final readerFirst in [true, false]) {
    test('a transfer the server drops ends quietly (reader gone first: $readerFirst)', () async {
      final body = StreamController<List<int>>();
      final proxy = LoopbackStreamProxy(
        upstream: (id) => Uri.parse('https://jf.example/Videos/$id/stream?static=true&api_key=secret-token'),
        headers: () => const {},
        httpClient: () => MockClient.streaming((request, _) async => http.StreamedResponse(body.stream, 200)),
      );
      await proxy.start();
      addTearDown(proxy.close);
      await proxy.allow('reel');
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, proxy.urlFor('reel').port);
      socket.write('GET ${proxy.urlFor('reel').path} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      await socket.flush();
      final got = Completer<void>();
      final sub = socket.listen((_) {
        if (!got.isCompleted) got.complete();
      }, onError: (_) {});
      body.add(List.filled(1024, 1));
      await got.future.timeout(const Duration(seconds: 5));
      if (readerFirst) {
        await sub.cancel();
        socket.destroy();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      body.addError(http.ClientException('Connection closed while receiving data', Uri.parse('https://jf.example/x?api_key=secret-token')));
      await body.close();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!readerFirst) {
        await sub.cancel();
        socket.destroy();
      }
    });
  }
}
