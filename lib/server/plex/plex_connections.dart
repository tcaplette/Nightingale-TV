import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../playback/playback_diagnostics.dart';
import 'plex_account.dart';

/// How long each address gets to answer.
const connectionTimeout = Duration(seconds: 3);

/// [r]'s addresses in the order they're preferred: local, then remote, then
/// the relay; HTTPS before plain HTTP within each.
///
/// A local HTTPS address also gets its plain-HTTP twin, as Plex's own apps
/// try it: a server whose certificate isn't issued or trusted yet still
/// answers there (servers allow it unless set to require secure
/// connections). Remote addresses stay HTTPS only.
List<PlexConnection> rankConnections(PlexResource r) {
  int rank(PlexConnection c) => (c.relay ? 4 : (c.local ? 0 : 2)) + (c.https ? 0 : 1);
  final ranked = [...r.connections];
  for (final c in r.connections) {
    if (!c.local || c.relay || !c.https || c.address == null || c.port == null) continue;
    final plain = PlexConnection(uri: 'http://${c.address}:${c.port}', local: true);
    if (!ranked.any((x) => x.uri == plain.uri)) ranked.add(plain);
  }
  // A stable sort keeps Plex's own order within a rank.
  final order = {for (final (i, c) in ranked.indexed) c: i};
  ranked.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : order[a]!.compareTo(order[b]!);
  });
  return ranked;
}

/// Whether the server [machineId] answers at [c] (its `/identity`).
Future<bool> answersAt(http.Client client, PlexConnection c, String machineId) async {
  try {
    final response = await client
        .get(Uri.parse('${c.uri}/identity'), headers: const {'Accept': 'application/json'})
        .timeout(connectionTimeout);
    if (response.statusCode != 200) {
      PlaybackDiagnostics.note('PLEX', '${c.uri}: status ${response.statusCode}');
      return false;
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final container = json['MediaContainer'] as Map<String, Object?>?;
    final ok = container?['machineIdentifier'] == machineId;
    PlaybackDiagnostics.note('PLEX', '${c.uri}: ${ok ? 'answers' : 'another server (${container?['machineIdentifier']})'}');
    return ok;
  } on Object catch (e) {
    PlaybackDiagnostics.note('PLEX', '${c.uri}: no answer ($e)');
    return false;
  }
}

/// The address to use for [r]: every address is tried at the same time, and
/// the best-ranked one that answers wins (see [rankConnections]). Null when
/// none answers.
Future<PlexConnection?> pickConnection(PlexResource r,
    {http.Client? client, Future<bool> Function(PlexConnection c)? probe}) async {
  final own = client == null && probe == null ? http.Client() : null;
  final test = probe ?? (c) => answersAt(client ?? own!, c, r.clientIdentifier);
  try {
    final ranked = rankConnections(r);
    PlaybackDiagnostics.note('PLEX', '${r.name}: trying ${[for (final c in ranked) '${c.uri}${c.local ? ' local' : ''}${c.relay ? ' relay' : ''}'].join(', ')}');
    final answers = [for (final c in ranked) test(c)];
    for (final (i, c) in ranked.indexed) {
      if (await answers[i]) return c;
    }
    return null;
  } finally {
    own?.close();
  }
}

/// Looks server [machineId] up again with [accountToken] and picks an
/// address for it (connection re-discovery). Null when the account can't see
/// the server any more or no address answers; the resource is returned
/// either way when the account still has it.
Future<({PlexResource? resource, PlexConnection? connection})> rediscover(PlexAccount account,
    {required String accountToken, required String machineId, http.Client? client}) async {
  final servers = await account.servers(accountToken);
  final resource = servers.where((s) => s.clientIdentifier == machineId).firstOrNull;
  if (resource == null) return (resource: null, connection: null);
  return (resource: resource, connection: await pickConnection(resource, client: client));
}
