import 'dart:convert';
import 'dart:io';

import 'package:nightingale_tv/setup/setup_server.dart';

// The setup server's tests' HTTP client.

/// A free TCP port.
Future<int> freePort() async {
  final s = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// One API answer.
typedef Answer = ({int status, Object? json, HttpHeaders headers, List<int> bytes});

class Client {
  Client(this.port);
  final int port;
  final _http = HttpClient();
  String? cookie;

  Future<Answer> call(String method, String path,
      {Object? body, List<int>? bytes, bool header = true, String? useCookie, Map<String, String>? headers}) async {
    final r = await _http.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    if (header) r.headers.set('X-Nightingale-TV', '1');
    headers?.forEach(r.headers.set);
    final c = useCookie ?? cookie;
    if (c != null) r.headers.set(HttpHeaders.cookieHeader, '${SetupServer.sessionCookie}=$c');
    if (body != null && method != 'GET') {
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode(body));
    } else if (bytes != null) {
      r.add(bytes);
    }
    final res = await r.close();
    final data = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    for (final c in res.cookies) {
      if (c.name == SetupServer.sessionCookie) cookie = c.value.isEmpty ? null : c.value;
    }
    Object? json;
    if (res.headers.contentType?.mimeType == 'application/json') json = jsonDecode(utf8.decode(data));
    return (status: res.statusCode, json: json, headers: res.headers, bytes: data);
  }

  Future<Answer> get(String path) => call('GET', path);

  /// The revision [path] answers with, for `If-Match`.
  Future<String> etag(String path) async => (await get(path)).headers.value(HttpHeaders.etagHeader)!;

  /// A PUT or DELETE with the current revision of [revisionOf] (default:
  /// [path] itself).
  Future<Answer> edit(String method, String path, {Object? body, String? revisionOf}) async =>
      call(method, path, body: body, headers: {'If-Match': await etag(revisionOf ?? path)});
  Future<Answer> post(String path, [Object? body]) => call('POST', path, body: body ?? const {});
  void close() => _http.close(force: true);
}

/// Sends a [method] request to [path] with a [contentLength]-byte body
/// straight over a socket, and returns the answer's first bytes (a refused
/// upload's 413).
Future<String> oversize(int port, String method, String path, int contentLength, {String? cookie}) async {
  final socket = await Socket.connect('127.0.0.1', port);
  socket.write('$method $path HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Nightingale-TV: 1\r\n'
      '${cookie == null ? '' : 'Cookie: ${SetupServer.sessionCookie}=$cookie\r\n'}'
      'Content-Length: $contentLength\r\n\r\n');
  socket.add(List.filled(contentLength, 0));
  await socket.flush();
  final answer = utf8.decode(await socket.first.timeout(const Duration(seconds: 10)));
  socket.destroy();
  return answer;
}
