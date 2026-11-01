// A collection as a channel source, and play counts, on the Jellyfin, Emby and
// Plex test servers (tool/test_servers; custom-channels 11.2, 11.5):
//
//   CC_KIND=jellyfin|emby CC_URL=http://127.0.0.1:8097 CC_USER=... CC_PW=... \
//     flutter test integration_test/custom_channels_servers_live_test.dart
//   CC_KIND=plex CC_URL=http://127.0.0.1:32400 CC_TOKEN=<the server's token> ...
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';

final _env = Platform.environment;

// ignore: avoid_print
void _say(String s) => print(s);

/// Every collection in [client]'s browsable libraries, as the pickers see them.
Future<List<({FolderNode node, ServerLibrary library})>> _collections(MediaServer client) async {
  final found = <({FolderNode node, ServerLibrary library})>[];
  for (final lib in (await client.libraries()).where((l) => l.isVideo || l.isCollections)) {
    void look(List<FolderNode> nodes) {
      for (final n in nodes) {
        if (n.type == 'BoxSet') found.add((node: n, library: lib));
        look(n.children);
      }
    }

    look(await client.folderTree(lib.id));
  }
  return found;
}

void main() {
  test('a collection plays exactly its programs, and play counts are read', () async {
    final kind = _env['CC_KIND'], url = _env['CC_URL'];
    if (kind == null || url == null) {
      markTestSkipped('Set CC_KIND and CC_URL to run against a test server.');
      return;
    }
    final MediaServer client;
    if (kind == 'plex') {
      client = PlexClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc', accessToken: _env['CC_TOKEN'] ?? '', userId: 'local');
    } else {
      final JellyfinClient c = kind == 'emby'
          ? EmbyClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc')
          : JellyfinClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc');
      await c.authenticateByName(_env['CC_USER']!, _env['CC_PW']!, serverName: kind);
      client = c;
    }
    final before = await client.fetchLibraryIndex();
    expect(before.movies.length, greaterThanOrEqualTo(2));
    final picks = [before.movies[0], before.movies[1]];
    final ids = [for (final m in picks) m.id];
    final name = 'CC Test ${DateTime.now().millisecondsSinceEpoch}';

    // Make the collection, and play one movie, on the server.
    if (client is JellyfinClient) {
      await client.request('POST', '/Collections', query: {'Name': name, 'Ids': ids.join(',')});
      await client.request('POST', '/Users/${client.userId}/PlayedItems/${ids[0]}');
    } else {
      final h = http.Client();
      final auth = {'Accept': 'application/json', ...client.authHeaders};
      final machine = (jsonDecode((await h.get(Uri.parse('$url/identity'), headers: auth)).body)
          as Map)['MediaContainer']['machineIdentifier'];
      final movies = (await client.libraries()).firstWhere((l) => l.collectionType == 'movies');
      final made = await h.post(
          Uri.parse('$url/library/collections').replace(queryParameters: {
            'type': '1',
            'title': name,
            'smart': '0',
            'sectionId': movies.id.split(':').last,
            'uri': 'server://$machine/com.plexapp.plugins.library/library/metadata/${ids.join(',')}',
          }),
          headers: auth);
      expect(made.statusCode, 200, reason: made.body);
      final played = await h.get(Uri.parse('$url/:/scrobble').replace(
          queryParameters: {'identifier': 'com.plexapp.plugins.library', 'key': ids[0]}), headers: auth);
      expect(played.statusCode, 200, reason: played.body);
      h.close();
    }
    // Servers file a new collection a moment later.
    ({FolderNode node, ServerLibrary library})? box;
    for (var i = 0; i < 40 && box == null; i++) {
      box = (await _collections(client)).where((c) => c.node.name == name).firstOrNull;
      if (box == null) await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(box, isNotNull, reason: 'the picker lists the collection');
    final found = box!;

    // A well-formed id no item has.
    const gone = '52a4d30379f0abaced3bcb2f70d45399';
    final index = await client.fetchLibraryIndex(channelRoots: {found.node.id, kind == 'plex' ? '99999999' : gone});
    expect(index.itemsByRoot[found.node.id], ids.toSet());
    expect(index.missingRoots, hasLength(1), reason: 'the root that is gone');
    final playlist = buildPlaylist(
        index,
        ChannelSource(roots: [
          PoolRoot(itemId: found.node.id, libraryId: found.library.id, label: '${found.node.name} (collection)')
        ], includeEpisodes: false),
        PlaybackOrder.weighted,
        seed: 1);
    expect(playlist.toSet(), ids.toSet());
    expect(index[ids[0]]!.playCount, greaterThanOrEqualTo(1), reason: 'played once on the server');
    expect(index[ids[1]]!.playCount, 0);
    _say('$kind: collection in "${found.library.name}" holds $playlist; plays ${index[ids[0]]!.playCount} and ${index[ids[1]]!.playCount}');
    client.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
