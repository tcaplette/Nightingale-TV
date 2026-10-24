import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A refused API call: the server's message (the TV's wording), and what
/// it needs (`pin`, `grownUp`) when a PIN would let it through.
class ApiException implements Exception {
  ApiException(this.status, this.message, {this.needs});
  final int status;
  final String message;
  final String? needs;
  @override
  String toString() => message;
}

/// A save refused as stale (409): [current] is the latest data.
class ApiConflict extends ApiException {
  ApiConflict(String message, this.current) : super(409, message);
  final Object? current;
}

/// The web admin's calls to `/api/v1/` (design D8): the session cookie
/// goes with every request, every change carries the `X-Nightingale-TV`
/// header and, for PUT and DELETE, `If-Match` with the revision last read.
class ApiClient {
  ApiClient(this._http, {Uri? base}) : base = base ?? Uri.base.replace(path: '/', query: '', fragment: '');

  final http.Client _http;
  final Uri base;

  /// Called when the session has ended (401), before the call throws.
  void Function()? onSignedOut;

  /// The last revision read, by scope: a profile id, or `''` for the
  /// household (profiles, users, export).
  final _revisions = <String, String>{};

  /// What [path] reads and changes the revision of, mirroring the server.
  static String? scopeOf(String path) {
    final p = path.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
    if (p.length >= 3 && p[0] == 'profiles' && !(p.length == 3 && p[2] == 'export')) return p[1];
    if (p.isNotEmpty && const {'profiles', 'users', 'export'}.contains(p[0])) return '';
    return null;
  }

  Uri url(String path, [Map<String, String>? query]) =>
      base.replace(path: '/api/v1/$path', queryParameters: query == null || query.isEmpty ? null : query);

  /// A picture or file the server serves, for `Image.network` and links.
  String href(String path, [Map<String, String>? query]) => url(path, query).toString();

  Future<Object?> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);

  Future<Object?> post(String path, [Object? body, Map<String, String>? query]) =>
      _send('POST', path, body: body ?? const {}, query: query);

  Future<Object?> put(String path, Object? body) => _send('PUT', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  /// Sends [bytes] as the body (uploads).
  Future<Object?> upload(String path, Uint8List bytes, {Map<String, String>? query}) =>
      _send('POST', path, bytes: bytes, query: query);

  Future<Object?> _send(String method, String path,
      {Object? body, Uint8List? bytes, Map<String, String>? query}) async {
    final request = http.Request(method, url(path, query));
    if (method != 'GET') request.headers['X-Nightingale-TV'] = '1';
    final scope = scopeOf(path);
    if ((method == 'PUT' || method == 'DELETE') && scope != null) {
      request.headers['If-Match'] = _revisions[scope] ?? await _readRevision(scope);
    }
    if (bytes != null) {
      request.headers['Content-Type'] = 'application/octet-stream';
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on Object {
      throw ApiException(0, "Can't reach the server. Check that it's running.");
    }
    final etag = response.headers['etag'];
    if (scope != null && etag != null && etag.isNotEmpty) _revisions[scope] = etag;
    Object? json;
    if ((response.headers['content-type'] ?? '').startsWith('application/json') && response.body.isNotEmpty) {
      json = jsonDecode(response.body);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final message = map['error'] as String? ?? _plain(response.statusCode);
    switch (response.statusCode) {
      case 401:
        onSignedOut?.call();
      case 409 when map.containsKey('current'):
        throw ApiConflict(message, map['current']);
    }
    throw ApiException(response.statusCode, message, needs: map['needs'] as String?);
  }

  /// Reads a revision when none is known yet.
  Future<String> _readRevision(String scope) async {
    await get(scope.isEmpty ? 'profiles' : 'profiles/$scope/logo');
    return _revisions[scope] ?? '""';
  }

  static String _plain(int status) => switch (status) {
        401 => 'Sign in first.',
        403 => "You can't do that.",
        404 => 'Not found.',
        413 => 'That is too big.',
        _ => 'Something went wrong ($status).',
      };
}
