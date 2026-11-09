import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../accounts.dart';
import '../../l10n/tr.dart';

/// Who may call a route (user-accounts, design D7). The setup server checks
/// it before the handler runs.
enum Access {
  /// Health, sign-in state, signing in, and the setup link's password.
  public,

  /// Any signed-in account.
  signedIn,

  /// Admins only.
  admin,

  /// The path's `{id}` profile must be the caller's (admins pass), and a
  /// non-admin must have given its PIN this session if it has one.
  profile,

  /// [profile], and for a kid profile a non-admin must have given a
  /// grown-up's PIN this session.
  profileSettings,
}

/// Which revision a route reads and changes (design D5).
enum Revision {
  none,

  /// The path's `{id}` profile's.
  profile,

  /// The household's: profiles, users and export.
  household,
}

/// An API refusal: the status and the TV's message, sent as
/// `{"error": message, ...extra}`.
class ApiError implements Exception {
  ApiError(this.status, [this.message, this.extra]);
  final int status;
  final String? message;
  final Map<String, Object?>? extra;
  @override
  String toString() => '$status ${message ?? ''}';
}

typedef ApiHandler = Future<Object?> Function(ApiRequest request);

/// One endpoint under `/api/v1/`: method, path pattern (`{name}` matches a
/// segment), access level and handler.
class ApiRoute {
  ApiRoute(this.method, this.pattern, this.access, this.handler, {Revision? revision, this.checkIfMatch = true})
      : _segments = pattern.split('/'),
        revision = revision ?? (pattern.startsWith('profiles/{id}/') ? Revision.profile : Revision.none);

  final String method;
  final String pattern;
  final Access access;
  final ApiHandler handler;
  final Revision revision;

  /// False for PUT and DELETE routes that aren't edits of saved data
  /// (signing out).
  final bool checkIfMatch;

  final List<String> _segments;

  bool get changes => method != 'GET';

  /// PUT, PATCH and DELETE need `If-Match` with the current revision.
  bool get needsIfMatch => (method == 'PUT' || method == 'PATCH' || method == 'DELETE') && revision != Revision.none && checkIfMatch;

  /// The `{name}` values when [path] matches.
  Map<String, String>? match(List<String> path) {
    if (path.length != _segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < path.length; i++) {
      final s = _segments[i];
      if (s.startsWith('{')) {
        if (path[i].isEmpty) return null;
        params[s.substring(1, s.length - 1)] = path[i];
      } else if (s != path[i]) {
        return null;
      }
    }
    return params;
  }

  @override
  String toString() => '$method $pattern';
}

/// Every route, in one table, so none can be added without an access level.
class ApiRoutes {
  ApiRoutes(this.all);

  final List<ApiRoute> all;

  ({ApiRoute route, Map<String, String> params})? find(String method, List<String> path) {
    for (final route in all) {
      if (route.method != method) continue;
      final params = route.match(path);
      if (params != null) return (route: route, params: params);
    }
    return null;
  }
}

/// A matched API request.
class ApiRequest {
  ApiRequest(this.http, this.params, {this.account, this.session});

  /// Returned by a handler that wrote its own response (files, pictures).
  static const handled = _Handled();

  /// The most a JSON body may be.
  static const maxBody = 4 << 20;

  final HttpRequest http;
  final Map<String, String> params;

  /// The signed-in account, if any.
  final Account? account;

  /// The session cookie's value, if any.
  final String? session;

  String operator [](String name) => params[name]!;

  HttpResponse get response => http.response;
  Map<String, String> get query => http.uri.queryParameters;
  String get from => http.connectionInfo!.remoteAddress.address;
  bool get isAdmin => account?.isAdmin ?? false;

  Map<String, Object?>? _body;

  /// The JSON object sent (an empty one when nothing was).
  Future<Map<String, Object?>> body() async {
    if (_body case final b?) return b;
    final bytes = await this.bytes(maxBody, tr.thatIsToo);
    if (bytes.isEmpty) return _body = const {};
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is Map<String, Object?>) return _body = json;
    } on FormatException {
      // Below.
    }
    throw ApiError(HttpStatus.badRequest, tr.expectedAJson);
  }

  /// The body's bytes; more than [max] is refused with 413 and
  /// [tooBigMessage] before the rest is read.
  Future<Uint8List> bytes(int max, String tooBigMessage) async {
    Never tooBig() {
      // Answered at once, without reading the rest: the connection closes.
      response.persistentConnection = false;
      throw ApiError(HttpStatus.requestEntityTooLarge, tooBigMessage);
    }

    if (http.contentLength > max) tooBig();
    final body = BytesBuilder(copy: false);
    await for (final chunk in http) {
      body.add(chunk);
      if (body.length > max) tooBig();
    }
    return body.takeBytes();
  }
}

class _Handled {
  const _Handled();
}

/// Reads typed fields from a request body, refusing with 400 when one has
/// the wrong type.
extension BodyFields on Map<String, Object?> {
  String? string(String key) => switch (this[key]) {
        null => null,
        final String s => s,
        _ => throw ApiError(HttpStatus.badRequest, tr.shouldBeText(key)),
      };

  int? integer(String key) => switch (this[key]) {
        null => null,
        final int i => i,
        final double d when d == d.roundToDouble() => d.toInt(),
        _ => throw ApiError(HttpStatus.badRequest, tr.shouldBeANumber(key)),
      };

  bool? boolean(String key) => switch (this[key]) {
        null => null,
        final bool b => b,
        _ => throw ApiError(HttpStatus.badRequest, tr.shouldBeTrue(key)),
      };

  Map<String, Object?>? object(String key) => switch (this[key]) {
        null => null,
        final Map<String, Object?> m => m,
        _ => throw ApiError(HttpStatus.badRequest, tr.shouldBeAn(key)),
      };

  List<String>? strings(String key) => switch (this[key]) {
        null => null,
        final List<Object?> l when l.every((e) => e is String) => l.cast<String>(),
        _ => throw ApiError(HttpStatus.badRequest, tr.shouldBeA(key)),
      };
}
