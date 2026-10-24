import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../jellyfin/jellyfin_client.dart';
import '../../platform/platform_info.dart';
import '../media_server.dart';

/// The headers Plex wants from every client, on plex.tv and on servers.
Map<String, String> plexHeaders({required String clientId, required String deviceName, String? token}) => {
      'Accept': 'application/json',
      'X-Plex-Product': JellyfinClient.clientName,
      'X-Plex-Version': JellyfinClient.clientVersion,
      'X-Plex-Client-Identifier': clientId,
      'X-Plex-Platform': PlatformInfo.isAndroid ? 'Android' : 'Linux',
      'X-Plex-Device-Name': deviceName,
      'X-Plex-Device': PlatformInfo.isAndroid ? 'Android' : 'Linux',
      if (token != null && token.isNotEmpty) 'X-Plex-Token': token,
    };

/// A link code: shown on screen, entered at plex.tv/link.
class PlexPin {
  const PlexPin({required this.id, required this.code, this.expiresAt, this.authToken});

  factory PlexPin.fromJson(Map<String, Object?> j) => PlexPin(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
        authToken: j['authToken'] as String?,
      );

  final int id;
  final String code;
  final DateTime? expiresAt;

  /// Set once someone has linked the code.
  final String? authToken;

  bool get linked => authToken != null && authToken!.isNotEmpty;
}

/// One address Plex lists for a server.
class PlexConnection {
  const PlexConnection({required this.uri, this.local = false, this.relay = false, this.address, this.port});

  factory PlexConnection.fromJson(Map<String, Object?> j) => PlexConnection(
        uri: (j['uri'] as String).replaceFirst(RegExp(r'/+$'), ''),
        local: j['local'] == true,
        relay: j['relay'] == true,
        address: j['address'] as String?,
        port: (j['port'] as num?)?.toInt(),
      );

  final String uri;
  final bool local;
  final bool relay;

  /// The plain IP address and port behind a `plex.direct` name.
  final String? address;
  final int? port;

  @override
  bool operator ==(Object other) =>
      other is PlexConnection && other.uri == uri && other.local == local && other.relay == relay;

  @override
  int get hashCode => Object.hash(uri, local, relay);

  bool get https => uri.startsWith('https:');
}

/// A server the account can use, owned or shared.
class PlexResource {
  const PlexResource({
    required this.name,
    required this.clientIdentifier,
    required this.accessToken,
    this.owned = true,
    this.ownerName,
    this.online = false,
    this.connections = const [],
  });

  factory PlexResource.fromJson(Map<String, Object?> j) => PlexResource(
        name: j['name'] as String? ?? 'Plex',
        clientIdentifier: j['clientIdentifier'] as String,
        accessToken: j['accessToken'] as String? ?? '',
        owned: j['owned'] == true,
        ownerName: j['owned'] == true ? null : j['sourceTitle'] as String?,
        online: j['presence'] == true,
        connections: [
          for (final c in (j['connections'] as List? ?? const []).cast<Map<String, Object?>>())
            PlexConnection.fromJson(c)
        ],
      );

  final String name;

  /// The server's machine identifier.
  final String clientIdentifier;

  /// The token for this server (differs from the account's on shared ones).
  final String accessToken;
  final bool owned;

  /// Who shared it, for shared servers.
  final String? ownerName;
  final bool online;
  final List<PlexConnection> connections;

  /// "Basement", or "Grandpa's Plex — Shared by gramps".
  String get label => ownerName == null ? name : '$name — Shared by $ownerName';
}

/// A user of the account's Plex Home.
class PlexHomeUser {
  const PlexHomeUser(
      {required this.id, required this.uuid, required this.title, this.thumb, this.protected = false, this.admin = false});

  factory PlexHomeUser.fromJson(Map<String, Object?> j) => PlexHomeUser(
        id: '${j['id']}',
        uuid: j['uuid'] as String,
        title: (j['title'] ?? j['username'] ?? j['friendlyName']) as String? ?? 'User',
        thumb: j['thumb'] as String?,
        protected: j['protected'] == true || j['hasPassword'] == true,
        admin: j['admin'] == true,
      );

  /// The plex.tv user id (a sign-in's user id).
  final String id;
  final String uuid;
  final String title;
  final String? thumb;

  /// Needs its 4-digit PIN to switch to.
  final bool protected;
  final bool admin;
}

/// The signed-in plex.tv user.
class PlexUser {
  const PlexUser({required this.id, required this.uuid, required this.title});

  factory PlexUser.fromJson(Map<String, Object?> j) => PlexUser(
        id: '${j['id']}',
        uuid: j['uuid'] as String? ?? '',
        title: (j['title'] ?? j['username']) as String? ?? 'Plex user',
      );

  final String id;
  final String uuid;
  final String title;
}

/// A Home user's PIN was wrong.
class PlexWrongPin extends ServerException {
  PlexWrongPin() : super('Wrong PIN', statusCode: 403);
}

/// plex.tv: link codes, the account's servers and its Home users.
class PlexAccount {
  PlexAccount({required this.clientId, required this.deviceName, http.Client? httpClient, this.base = 'https://plex.tv'})
      : _http = httpClient ?? http.Client();

  final String clientId;
  final String deviceName;
  final String base;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<Object?> _send(String method, String path, {String? token, Map<String, String>? query}) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll(plexHeaders(clientId: clientId, deviceName: deviceName, token: token));
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ServerException('plex.tv took too long to respond.');
    } on Exception catch (e) {
      throw ServerException('Could not reach plex.tv ($e).');
    }
    if (response.statusCode >= 400) {
      throw ServerException(
          response.statusCode == 401 ? 'Your Plex sign-in expired.' : 'plex.tv error ${response.statusCode}.',
          statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  /// A new link code.
  Future<PlexPin> createPin() async =>
      PlexPin.fromJson(await _send('POST', '/api/v2/pins', query: {'strong': 'false'}) as Map<String, Object?>);

  /// [pin] as it is now; null once Plex has expired it.
  Future<PlexPin?> checkPin(PlexPin pin) async {
    try {
      return PlexPin.fromJson(await _send('GET', '/api/v2/pins/${pin.id}') as Map<String, Object?>);
    } on ServerException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 410) return null;
      rethrow;
    }
  }

  Future<PlexUser> user(String token) async =>
      PlexUser.fromJson(await _send('GET', '/api/v2/user', token: token) as Map<String, Object?>);

  /// The servers [token]'s user can use, owned and shared.
  Future<List<PlexResource>> servers(String token) async {
    final json = await _send('GET', '/api/v2/resources',
        token: token, query: {'includeHttps': '1', 'includeRelay': '1', 'includeIPv6': '0'});
    return [
      for (final r in (json as List? ?? const []).cast<Map<String, Object?>>())
        if ('${r['provides']}'.split(',').contains('server')) PlexResource.fromJson(r),
    ];
  }

  /// The users of [token]'s Plex Home; empty when the account isn't in one.
  Future<List<PlexHomeUser>> homeUsers(String token) async {
    final Object? json;
    try {
      json = await _send('GET', '/api/v2/home/users', token: token);
    } on ServerException catch (e) {
      // Not in a Home.
      if (e.statusCode == 400 || e.statusCode == 404) return const [];
      rethrow;
    }
    final users = switch (json) {
      final Map<String, Object?> m => m['users'] as List? ?? const [],
      final List<Object?> l => l,
      _ => const [],
    };
    return [for (final u in users.cast<Map<String, Object?>>()) PlexHomeUser.fromJson(u)];
  }

  /// [user]'s token, switching from [token]'s; throws [PlexWrongPin] for a
  /// wrong [pin].
  Future<String> switchUser(String token, PlexHomeUser user, {String? pin}) async {
    final Object? json;
    try {
      json = await _send('POST', '/api/v2/home/users/${user.uuid}/switch',
          token: token, query: {'pin': ?pin});
    } on ServerException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) throw PlexWrongPin();
      rethrow;
    }
    final t = (json as Map<String, Object?>?)?['authToken'] as String?;
    if (t == null || t.isEmpty) throw ServerException('Plex did not switch users.');
    return t;
  }

  /// Signs this device out of the account: plex.tv forgets it, so it leaves
  /// the account's device list.
  Future<void> signOut(String token) async {
    final devices = await _send('GET', '/api/v2/devices', token: token);
    for (final d in (devices as List? ?? const []).cast<Map<String, Object?>>()) {
      if (d['clientIdentifier'] == clientId && d['id'] != null) {
        await _send('DELETE', '/api/v2/devices/${d['id']}', token: token);
      }
    }
  }

  void close() => _http.close();
}
