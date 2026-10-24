import 'dart:async';

import '../jellyfin/jellyfin_client.dart';
import 'emby_client.dart';
import 'media_server.dart';
import 'plex/plex_client.dart';

/// A client for the [kind] of server at [serverUrl], not signed in yet.
MediaServer serverClient(ServerKind kind, String serverUrl,
        {required String deviceId, required String deviceName}) =>
    switch (kind) {
      ServerKind.jellyfin => JellyfinClient(serverUrl: serverUrl, deviceId: deviceId, deviceName: deviceName),
      ServerKind.emby => EmbyClient(serverUrl: serverUrl, deviceId: deviceId, deviceName: deviceName),
      ServerKind.plex => PlexClient(serverUrl: serverUrl, deviceId: deviceId, deviceName: deviceName),
    };

/// A client for a saved sign-in.
MediaServer sessionClient(ServerSession session, {required String deviceName}) => switch (session.kind) {
      ServerKind.jellyfin => JellyfinClient.fromSession(session, deviceName: deviceName),
      ServerKind.emby => EmbyClient.fromSession(session, deviceName: deviceName),
      ServerKind.plex => PlexClient.fromSession(session, deviceName: deviceName),
    };

/// The addresses to try for what the user typed: as typed when it names a
/// scheme; otherwise HTTPS, then plain HTTP (home servers are often only
/// that, on a local address or a port like Plex's 32400).
List<String> candidateUrls(String input) {
  final typed = input.trim();
  final https = JellyfinClient.normalizeServerUrl(typed);
  if (RegExp(r'^https?:', caseSensitive: false).hasMatch(typed)) return [https];
  return [https, https.replaceFirst('https://', 'http://')];
}

/// Works out what server answers at [input]: Jellyfin or Emby (from
/// `/System/Info/Public`) or Plex (from `/identity`), asking every candidate
/// address at the same time. The first match decides; preferred addresses
/// (see [candidateUrls]) win ties. Throws [ServerException] when nothing
/// answers like a media server.
Future<({MediaServer client, ServerInfo info})> identifyServer(String input,
    {required String deviceId, required String deviceName}) async {
  final urls = candidateUrls(input);
  if (urls.first == 'https://') throw ServerException('Enter your server address.');
  final attempts = <Future<({MediaServer client, ServerInfo info})?>>[];
  final clients = <MediaServer>[];
  String? reason;
  for (final url in urls) {
    for (final kind in const [ServerKind.jellyfin, ServerKind.plex]) {
      final client = serverClient(kind, url, deviceId: deviceId, deviceName: deviceName);
      clients.add(client);
      attempts.add(() async {
        try {
          final info = await client.publicInfo();
          if (info.kind == ServerKind.emby) {
            client.close();
            final emby = serverClient(ServerKind.emby, url, deviceId: deviceId, deviceName: deviceName);
            clients.add(emby);
            return (client: emby, info: info);
          }
          return (client: client, info: info);
        } on ServerException catch (e) {
          // The reason worth showing comes from the address as typed.
          if (url == urls.first && kind == ServerKind.jellyfin) reason = e.message;
          return null;
        }
      }());
    }
  }
  // The best-ranked answer wins, as soon as every better-ranked address has
  // failed (a wrong scheme fails at once).
  final found = Completer<({MediaServer client, ServerInfo info})?>();
  final results = List<({MediaServer client, ServerInfo info})?>.filled(attempts.length, null);
  final done = List<bool>.filled(attempts.length, false);
  void settle() {
    for (var i = 0; i < attempts.length; i++) {
      if (!done[i]) return;
      if (results[i] case final r?) return found.complete(r);
    }
    found.complete(null);
  }

  for (final (i, a) in attempts.indexed) {
    unawaited(a.then((r) {
      results[i] = r;
      done[i] = true;
      if (!found.isCompleted) settle();
    }));
  }
  final match = await found.future;
  for (final c in clients) {
    if (!identical(c, match?.client)) c.close();
  }
  if (match == null) {
    final address = urls.first.replaceFirst(RegExp('^https?://'), '');
    throw ServerException('No Jellyfin, Emby or Plex server found at $address.'
        '${reason == null ? '' : ' ${reason!.replaceFirst(RegExp(r'^No Jellyfin server found at \S+ '), '')}'}');
  }
  return match;
}
