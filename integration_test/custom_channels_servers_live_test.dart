// A collection as a channel source, and play counts, on the Jellyfin, Emby and
// Plex test servers (tool/test_servers; custom-channels 11.2, 11.5):
//
//   CC_KIND=jellyfin|emby CC_URL=http://127.0.0.1:8097 CC_USER=... CC_PW=... \
//     flutter test integration_test/custom_channels_servers_live_test.dart
//   CC_KIND=plex CC_URL=http://127.0.0.1:32400 CC_TOKEN=<the server's token> ...
//
// Folder browsing (jellyfin-folder-browse 5.2, 5.3): every movie of the
// server's libraries is in the picker tree (read-only, any server). With
// CC_MEDIA (the host folder the server's Movies library reads, docker test
// servers only), a folder of 5 movies is added after the app's last scan,
// picked as a new channel's root, and must play at once.
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

import '../test/fixtures.dart';

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

/// The test server's client, signed in.
Future<MediaServer> _signIn(String kind, String url) async {
  if (kind == 'plex') {
    return PlexClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc', accessToken: _env['CC_TOKEN'] ?? '', userId: 'local');
  }
  final JellyfinClient c = kind == 'emby'
      ? EmbyClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc')
      : JellyfinClient(serverUrl: url, deviceId: 'cc-live', deviceName: 'cc');
  await c.authenticateByName(_env['CC_USER']!, _env['CC_PW']!, serverName: kind);
  return c;
}

/// Every node in [nodes], at any depth.
Iterable<FolderNode> _all(List<FolderNode> nodes) sync* {
  for (final n in nodes) {
    yield n;
    yield* _all(n.children);
  }
}

/// Asks the server to scan its libraries for new files.
Future<void> _scanServer(MediaServer client, String url) async {
  if (client is JellyfinClient) {
    await client.request('POST', '/Library/Refresh');
    return;
  }
  final h = http.Client();
  for (final lib in await client.libraries()) {
    await h.get(Uri.parse('$url/library/sections/${lib.id.split(':').last}/refresh'),
        headers: {'Accept': 'application/json', ...client.authHeaders});
  }
  h.close();
}

void main() {
  final kind = _env['CC_KIND'], url = _env['CC_URL'];

  test('every movie of every library is in the picker tree, with its folders', () async {
    if (kind == null || url == null) {
      markTestSkipped('Set CC_KIND and CC_URL to run against a test server.');
      return;
    }
    final client = await _signIn(kind, url);
    final index = await client.fetchLibraryIndex();
    final leaves = <String>{};
    var folders = 0;
    for (final lib in (await client.libraries()).where((l) => l.isVideo)) {
      final tree = await client.folderTree(lib.id);
      final nodes = _all(tree).toList();
      leaves.addAll([for (final n in nodes) if (n.type == FolderNode.movieType) n.id]);
      folders += nodes.where((n) => !n.isVideo).length;
      // Shows and seasons stay the finest level of a TV library (episodes
      // are no rows); a movie or video library lists every folder and video.
      if (client is JellyfinClient && lib.collectionType != 'tvshows') {
        // Each storage folder's own items, one level down, are its rows.
        // Collections are picked whole: their items are linked, not inside.
        for (final top in tree.where((n) => n.type == 'Folder')) {
          final direct = await client.allItems({'ParentId': top.id, 'Fields': 'ParentId'});
          final expected = {
            for (final i in direct)
              if (i['LocationType'] != 'Virtual' && const {'Folder', 'BoxSet', 'Movie', 'Video', 'MusicVideo', 'Trailer'}.contains(i['Type']))
                i['Id'] as String,
          };
          expect({for (final c in top.children) c.id}, containsAll(expected), reason: '${lib.name} › ${top.name}');
          _say('$kind ${lib.name} › ${top.name}: ${top.children.where((c) => !c.isVideo).length} folders, '
              '${top.children.where((c) => c.isVideo).length} videos at the top');
        }
      }
    }
    final missing = [for (final m in index.movies) if (!leaves.contains(m.id)) m.title];
    expect(missing, isEmpty, reason: 'movies the picker can\'t reach');
    _say('$kind: all ${index.movies.length} movies are in the picker, among $folders folders');
    client.close();
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('a folder of movies added after the last scan plays as a new channel at once', () async {
    final media = _env['CC_MEDIA'];
    if (kind == null || url == null || media == null) {
      markTestSkipped('Set CC_KIND, CC_URL and CC_MEDIA (docker test servers only) to run.');
      return;
    }
    final client = await _signIn(kind, url);
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_folder_browse');
    // The app's library, as of its last scan.
    final app = await signedInApp(dir, await client.fetchLibraryIndex());
    app.client = client;
    final name = 'CC New Picks ${DateTime.now().millisecondsSinceEpoch}';
    final folder = Directory('$media/$name');
    await folder.create();
    try {
      // Five loose movie files, straight in the folder. Each its own short
      // video (over 30 s: shorter is taken for bad metadata): Plex takes
      // copies of one file for one movie.
      for (final (i, title) in ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'].indexed) {
        final made = await Process.run('ffmpeg', [
          '-hide_banner', '-loglevel', 'error', '-y',
          '-f', 'lavfi', '-i', 'testsrc2=s=320x240:r=25:d=${40 + i}',
          '-f', 'lavfi', '-i', 'sine=f=${300 + 100 * i}:d=${40 + i}',
          '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'aac', '-metadata', 'title=$title Pick',
          '${folder.path}/$title Pick.mkv',
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
      }
      await _scanServer(client, url);
      final movies = (await client.libraries()).firstWhere((l) => l.collectionType == 'movies');
      FolderNode? node;
      for (var i = 0; i < 90 && (node?.children.length ?? 0) < 5; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        node = _all(await client.folderTree(movies.id)).where((n) => n.name == name).firstOrNull;
      }
      expect(node, isNotNull, reason: 'the picker lists the new folder');
      expect([for (final c in node!.children) (c.name, c.type)].length, 5);
      expect(node.children.every((c) => c.type == FolderNode.movieType), isTrue);
      expect(FolderNode.shown([node], programsOnly: true).single.children, hasLength(5));
      final ids = {for (final c in node.children) c.id};
      expect(ids.where((id) => app.library[id] != null), isEmpty, reason: 'not in the app\'s library yet');
      // The server lists new files in its folders before its library
      // listings: wait until it has taken them in, as it has by the time
      // someone picks the folder.
      var ready = false;
      for (var i = 0; i < 60 && !ready; i++) {
        final scan = await client.fetchLibraryIndex();
        ready = ids.every((id) => scan[id] != null);
        if (!ready) await Future<void>.delayed(const Duration(seconds: 2));
      }
      expect(ready, isTrue, reason: 'the server lists the new movies');

      final ch = await app.createCustomChannel(
          'New Picks',
          ChannelSource(
              roots: [PoolRoot(itemId: node.id, libraryId: movies.id, label: '${movies.name} › $name')],
              includeEpisodes: false));
      expect(ch.playlist.toSet(), ids);
      _say('$kind: "$name" holds ${node.children.map((c) => c.name).join(', ')}; the new channel plays ${ch.playlist.length}');
    } finally {
      // The server forgets the folder; the app closes its client last.
      await folder.delete(recursive: true);
      await _scanServer(client, url);
      await app.close();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('a collection plays exactly its programs, and play counts are read', () async {
    if (kind == null || url == null) {
      markTestSkipped('Set CC_KIND and CC_URL to run against a test server.');
      return;
    }
    final client = await _signIn(kind, url);
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
