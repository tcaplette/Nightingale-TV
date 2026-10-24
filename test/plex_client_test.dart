import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_account.dart';
import 'package:nightingale_tv/server/plex/plex_client.dart';
import 'package:nightingale_tv/server/plex/plex_connections.dart';
import 'package:nightingale_tv/server/plex/plex_library.dart';

/// Recorded from the Plex Media Server test container and plex.tv (see
/// test/fixtures/plex/README.md for the few written by hand).
Object? fixture(String name) => jsonDecode(File('test/fixtures/plex/$name.json').readAsStringSync());

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

final empty = {'MediaContainer': {'size': 0}};

PlexClient plex(Future<http.Response> Function(http.Request r) handler) => PlexClient(
      serverUrl: 'http://192.168.1.20:32400',
      deviceId: 'dev1',
      deviceName: 'Living room',
      accessToken: 'server-token',
      userId: '1001',
      httpClient: MockClient(handler),
    );

/// The test library's server: section listings by type, paged as Plex
/// pages them, and batched metadata.
Future<http.Response> testServer(http.Request r) async {
  final path = r.url.path;
  final q = r.url.queryParameters;
  if (path == '/library/sections') return json(fixture('sections'));
  if (path == '/library/sections/1/all' && q['type'] == '2') return json(fixture('shows'));
  if (path == '/library/sections/1/all' && q['type'] == '4') {
    return json(fixture(r.headers['X-Plex-Container-Start'] == '0' ? 'episodes_page1' : 'episodes_page2'));
  }
  if (path == '/library/sections/2/all' && q['type'] == '1') return json(fixture('movies'));
  if (path == '/library/sections/4/all' && q['type'] == '10') return json(fixture('tracks'));
  if (path == '/library/sections/4/all' && q['type'] == '8') return json(fixture('artists'));
  if (path.startsWith('/library/metadata/') && q['includeExtras'] == '1') return json(fixture('artists_extras'));
  if (path.startsWith('/library/metadata/') && q['includeChapters'] == '1') return json(fixture('metadata_chapters'));
  return json(empty);
}

void main() {
  test('libraries: TV, movies, home videos and music; photos are left out', () async {
    final libs = await plex(testServer).libraries();
    expect({for (final l in libs) l.name: (l.id, l.collectionType)}, {
      'TV': ('library:1', 'tvshows'),
      'Music': ('library:4', 'music'),
      'Home Videos': ('library:3', 'homevideos'),
      'Movies': ('library:2', 'movies'),
    });
  });

  test('the scan maps every kind of item into the index', () async {
    final pages = <String?>[];
    final client = plex((r) {
      if (r.url.path == '/library/sections/1/all' && r.url.queryParameters['type'] == '4') {
        pages.add(r.headers['X-Plex-Container-Start']);
        expect(r.headers['X-Plex-Container-Size'], '500');
        expect(r.headers['X-Plex-Token'], 'server-token');
      }
      return testServer(r);
    });
    final index = await client.fetchLibraryIndex();
    expect(pages, ['0', '5'], reason: 'pages until totalSize');
    expect(index.episodes, hasLength(24));
    expect(index.series.map((s) => s.name).toSet(), {'Maple Street', 'Signal Hill', 'Night Desk'});
    final maple = index.episodesBySeries[index.series.firstWhere((s) => s.name == 'Maple Street').key]!;
    expect([for (final e in maple) 'S${e.season}E${e.episode}'],
        ['S1E1', 'S1E2', 'S1E3', 'S1E4', 'S2E1', 'S2E2', 'S2E3', 'S2E4']);
    final first = maple.first;
    expect(first.id, '3');
    expect(first.runtime, const Duration(milliseconds: 435001));
    expect(first.streamPath, '/library/parts/1/1792606547/file.mp4');
    expect(first.container, 'mp4');
    expect(first.size, 276576195);
    expect(first.etag, startsWith('1-'));
    expect(first.added, isNotNull);
    // Chapters come from the batched metadata, not the listing.
    expect(first.chapters, [Duration.zero, const Duration(seconds: 145), const Duration(seconds: 290)]);
    // As Plex's Personal Media agent names them: the MP4's title tag, the MKV's file name.
    expect(index.movies.map((m) => m.title).toSet(), {'The Long Hallway', 'Copper Moon (1991)'});
    expect(index.commercials, isEmpty, reason: 'home videos are neither programs nor commercials without a pool');
    final song = index.songs.first;
    expect(song.artist, isNotNull);
    expect(song.album, isNotNull);
    expect(song.albumId, isNotNull);
    expect(index.musicVideos, hasLength(6));
    expect(index.musicVideos.every((m) => m.artist != null && m.streamPath != null), isTrue);
    // Part paths are known from the scan before the index is handed over.
    expect(client.streamUri('3').toString(), 'http://192.168.1.20:32400/library/parts/1/1792606547/file.mp4');
  });

  test('saved Jellyfin entries load and save without a part path', () {
    const entry = {'id': 'a', 'kind': 'episode', 'title': 't', 'runtimeMs': 1000};
    final e = MediaEntry.fromJson(entry);
    expect(e.streamPath, isNull);
    expect(e.toJson(), entry);
    final plexEntry = MediaEntry.fromJson({...entry, 'streamPath': '/library/parts/1/2/file.mkv'});
    expect(plexEntry.toJson()['streamPath'], '/library/parts/1/2/file.mkv');
  });

  test('the stream comes from the loaded library\'s part path', () {
    final client = plex((r) async => json(empty));
    final index = libraryIndexFromPlex(movies: [
      {
        'ratingKey': '9',
        'title': 'M',
        'duration': 600000,
        'Media': [
          {
            'Part': [
              {'id': 4, 'key': '/library/parts/4/1/file.mkv'}
            ]
          }
        ]
      }
    ]);
    client.index = () => index;
    expect(client.streamUri('9').path, '/library/parts/4/1/file.mkv');
    expect(() => client.streamUri('nope'), throwsA(isA<ServerException>()));
  });

  group('commercial pools', () {
    test('a folder contributes every video under it, sub-folders included', () async {
      final parents = <String?>[];
      final client = plex((r) async {
        if (r.url.path == '/library/sections/3/folder') {
          parents.add(r.url.queryParameters['parent']);
          return switch (r.url.queryParameters['parent']) {
            null => json(fixture('folder_root')),
            '15' => json(fixture('folder_commercials')),
            _ => json(empty),
          };
        }
        return testServer(r);
      });
      final tree = await client.folderTree('library:3');
      expect(tree.single.name, 'Commercials');
      expect(tree.single.id, 'folder:3:15');
      expect(tree.single.children.single.name, 'Reels');
      parents.clear();
      final pool = CommercialPool(id: 'p', name: 'Commercials', roots: [
        PoolRoot(itemId: tree.single.id, libraryId: 'library:3', label: 'Home Videos › Commercials'),
      ]);
      final index = await client.fetchLibraryIndex(pools: [pool]);
      expect(parents, ['15', '16']);
      expect(index.commercials.map((c) => c.id), ['50', '70'], reason: 'the two clips the trimmed listing holds');
      expect(index.commercials.every((c) => c.poolIds.contains('p')), isTrue);
    });

    test('a collection contributes its items', () async {
      final client = plex((r) async {
        if (r.url.path == '/library/metadata/128') return json(fixture('collection_item'));
        if (r.url.path == '/library/metadata/128/children') return json(fixture('collection_children'));
        if (r.url.path == '/library/sections/3/collections') return json(fixture('collections'));
        return testServer(r);
      });
      final pool = CommercialPool(
          id: 'p', name: 'Trailers', roots: [const PoolRoot(itemId: '128', libraryId: 'library:3', label: 'Trailers')]);
      final index = await client.fetchLibraryIndex(pools: [pool]);
      expect(index.commercials, hasLength(20));
    });

    test('shows and seasons are folders in a TV library, with collections', () async {
      final client = plex((r) async {
        if (r.url.path == '/library/sections/1/all' && r.url.queryParameters['type'] == '3') {
          return json({
            'MediaContainer': {
              'size': 2,
              'Metadata': [
                {'ratingKey': '7', 'title': 'Season 2', 'parentRatingKey': '1', 'index': 2},
                {'ratingKey': '2', 'title': 'Season 1', 'parentRatingKey': '1', 'index': 1},
              ]
            }
          });
        }
        return testServer(r);
      });
      final tree = await client.folderTree('library:1');
      final maple = tree.firstWhere((n) => n.name == 'Maple Street');
      expect(maple.type, 'Series');
      expect(maple.children.map((c) => c.name), ['Season 1', 'Season 2']);
    });
  });

  test('commercial markers are the item\'s commercial segments, in order', () async {
    final segments = await plex((r) async {
      expect(r.url.queryParameters['includeMarkers'], '1');
      return json(fixture('metadata_markers'));
    }).commercialSegments('3');
    expect(segments, [
      (start: const Duration(seconds: 145), end: const Duration(seconds: 265)),
      (start: const Duration(seconds: 290), end: const Duration(seconds: 410)),
    ]);
  });

  group('playback', () {
    late List<http.Request> sent;
    PlexClient deciding(String decision) {
      sent = [];
      return plex((r) async {
        sent.add(r);
        if (r.url.path.endsWith('/decision')) return json(fixture(decision));
        if (r.url.path == '/library/metadata/3') return json(fixture('metadata_source'));
        return json(empty);
      });
    }

    test('direct play', () async {
      final d = await deciding('decision_direct').playbackDecision('3');
      expect(d.transcode, isFalse);
      final q = sent.single.url.queryParameters;
      expect(q['path'], '/library/metadata/3');
      expect(q['X-Plex-Client-Profile-Name'], 'Generic');
      expect(q['X-Plex-Client-Profile-Extra'], contains('add-direct-play-profile'));
      expect(q.containsKey('maxVideoBitrate'), isFalse);
      expect(q['copyts'], '1', reason: 'whole-item playlists in source time');
    });

    test('a capped transcode asks in kbps, and starts at the join point after its own decision', () async {
      final client = deciding('decision_transcode');
      final d = await client.playbackDecision('3', maxBitrate: 4000000);
      expect(sent.first.url.queryParameters['maxVideoBitrate'], '4000');
      expect((d.transcode, d.directStream), (true, false));
      // The original's bitrate and codec (the item's), not the conversion's.
      expect((d.sourceBitrate, d.sourceCodec), (2452000, 'hevc'));
      final t = d.transcodeTemplate!;
      expect(t.path, '/video/:/transcode/universal/start.m3u8');
      sent.clear();
      final job = await client.transcodeUri(t, playSessionId: 'job1', startAt: const Duration(seconds: 90));
      expect(sent.single.url.path, '/video/:/transcode/universal/decision');
      expect(sent.single.url.queryParameters['session'], 'job1');
      expect(sent.single.headers['X-Plex-Session-Identifier'], 'job1');
      expect(job.queryParameters['session'], 'job1');
      expect(job.queryParameters['offset'], '90.0');
      expect(job.queryParameters['X-Plex-Session-Identifier'], 'job1');
      expect(job.queryParameters['maxVideoBitrate'], '4000');
    });

    test('video copy is a direct stream', () async {
      final d = await deciding('decision_copy').playbackDecision('3');
      expect((d.transcode, d.directStream), (true, true));
    });

    test('forced conversions rule out direct play', () async {
      final d = await deciding('decision_transcode').playbackDecision('3', forceTranscode: true);
      expect(sent.first.url.queryParameters['directPlay'], '0');
      expect(sent.first.url.queryParameters['directStream'], '0');
      expect(d.transcode, isTrue);
    });

    test('stop, reports, keep-warm and artwork', () async {
      final client = deciding('decision_direct');
      await client.stopTranscode('job1');
      expect(sent.last.url.path, '/video/:/transcode/universal/stop');
      expect(sent.last.url.queryParameters, {'session': 'job1'});
      const report = PlaybackReport(
          itemId: '3', playSessionId: 's1', position: Duration(seconds: 61), isPaused: true, runtime: Duration(minutes: 7));
      await client.reportPlaybackStart(report);
      await client.reportPlaybackProgress(report);
      await client.reportPlaybackStopped(report);
      final states = [for (final r in sent.skip(1)) r.url.queryParameters['state']];
      expect(states, ['playing', 'paused', 'stopped']);
      final q = sent.last.url.queryParameters;
      expect(sent.last.url.path, '/:/timeline');
      expect((q['ratingKey'], q['key'], q['time'], q['duration']), ('3', '/library/metadata/3', '61000', '420000'));
      expect(sent.last.headers['X-Plex-Session-Identifier'], 's1');
      expect(client.pingUri.path, '/identity');
      final logo = client.imageUri('1', ImageKind.logo, maxHeight: 160);
      expect(logo.path, '/photo/:/transcode');
      expect(logo.queryParameters['url'], '/library/metadata/1/clearLogo');
      expect(logo.queryParameters['format'], 'png');
      expect(client.imageUri('3', ImageKind.primary).queryParameters['url'], '/library/metadata/3/thumb');
    });

    test('media requests carry the token but ask for no JSON', () {
      final h = plex((r) async => json(empty)).authHeaders;
      expect(h['X-Plex-Token'], 'server-token');
      expect(h['X-Plex-Client-Identifier'], 'dev1');
      expect(h.containsKey('Accept'), isFalse);
    });
  });

  test('a 401 is an expired sign-in', () async {
    final client = plex((r) async => http.Response('<html>Unauthorized</html>', 401));
    await expectLater(client.checkSession(), throwsA(isA<ServerException>().having((e) => e.statusCode, 'status', 401)));
  });

  test('the identity answer names a Plex server', () async {
    final info = await plex((r) async => json(fixture('identity'))).publicInfo();
    expect(info.kind, ServerKind.plex);
    expect(info.id, 'a3d6b40a0ad0cc860ae7dc0c6d6a0139a5518e21');
  });

  test('the Android profile becomes Plex limitations', () {
    const caps = DeviceCapabilities(
      video: [VideoDecoderCaps(codec: 'hevc', profiles: ['main'], bitDepth: 8, maxWidth: 1920, maxHeight: 1080, maxFps: 60)],
      audio: {'aac', 'ac3'},
      passthrough: {'dts'},
    );
    final extra = PlexClient.profileExtra(androidDeviceProfile(caps));
    expect(extra, contains('add-direct-play-profile(type=videoProfile&container=mkv,webm&videoCodec=h264,hevc'));
    expect(extra, contains('audioCodec=aac,ac3,dca'));
    expect(extra, contains('add-limitation(scope=videoCodec&scopeName=hevc&type=upperBound&name=video.bitDepth&value=8)'));
    expect(extra, contains('add-limitation(scope=videoCodec&scopeName=hevc&type=match&name=video.profile&list=main)'));
    expect(extra, contains('add-transcode-target(type=videoProfile&context=streaming&protocol=hls&container=mpegts'));
    // Songs too: Plex answers 4005 ("no conversion profile") without one.
    expect(extra, contains('add-direct-play-profile(type=musicProfile&container=mp3,'));
    expect(extra, contains('add-transcode-target(type=musicProfile'));
    expect(PlexClient.profileExtra(null), contains('type=musicProfile'));
  });

  test('a conversion with no cap is held to what keeps the picture, in kbps on Plex', () {
    final t = Uri.parse('http://p/video/:/transcode/universal/start.m3u8?maxVideoBitrate=20000&path=x');
    expect(limitConversion(t, sourceBitrate: 2200000, sourceCodec: 'hevc').queryParameters['maxVideoBitrate'], '4400');
    final none = Uri.parse('http://p/video/:/transcode/universal/start.m3u8?path=x');
    expect(limitConversion(none, sourceBitrate: 3000000, sourceCodec: 'h264').queryParameters['maxVideoBitrate'], '3000');
  });

  group('plex.tv', () {
    PlexAccount account(Future<http.Response> Function(http.Request r) handler) =>
        PlexAccount(clientId: 'dev1', deviceName: 'Living room', httpClient: MockClient(handler));

    test('a link code, then its expiry', () async {
      final a = account((r) async => r.method == 'POST' ? json(fixture('pin_unlinked'), 201) : http.Response('', 404));
      final pin = await a.createPin();
      expect(pin.code, 'KZ84');
      expect(pin.linked, isFalse);
      expect(await a.checkPin(pin), isNull, reason: 'Plex answers 404 for an expired code');
    });

    test('a linked code holds the token', () async {
      final linked = {...fixture('pin_unlinked') as Map<String, Object?>, 'authToken': 'acct'};
      final pin = await account((r) async => json(linked)).checkPin(const PlexPin(id: 1, code: 'KZ84'));
      expect(pin!.authToken, 'acct');
    });

    test('servers, owned and shared, and a relay-only one', () async {
      final servers = await account((r) async {
        expect(r.url.queryParameters['includeRelay'], '1');
        expect(r.headers['X-Plex-Token'], 'acct');
        return json(fixture('resources'));
      }).servers('acct');
      expect(servers.map((s) => s.label), ['Basement', "Grandpa's Plex — Shared by gramps"]);
      final shared = servers.last;
      expect((shared.online, shared.accessToken), (false, 'shared-server-token'));
      expect(await pickConnection(shared, probe: (c) async => true), shared.connections.single);
      expect((await pickConnection(shared, probe: (c) async => true))!.relay, isTrue);
      final basement = servers.first;
      expect(rankConnections(basement).map((c) => c.uri).first, 'https://192-168-1-20.0123abc.plex.direct:32400');
    });

    test('a local HTTPS address with a certificate not trusted yet falls back to plain HTTP there', () async {
      // As plex.tv listed the just-claimed test server: HTTPS only.
      const r = PlexResource(name: 'Inspiron', clientIdentifier: 'm', accessToken: 't', connections: [
        PlexConnection(uri: 'https://10-0-0-39.abc.plex.direct:32400', local: true, address: '10.0.0.39', port: 32400),
        PlexConnection(uri: 'https://203-0-113-7.abc.plex.direct:32400', address: '203.0.113.7', port: 32400),
      ]);
      expect(rankConnections(r).map((c) => c.uri), [
        'https://10-0-0-39.abc.plex.direct:32400',
        'http://10.0.0.39:32400',
        'https://203-0-113-7.abc.plex.direct:32400',
      ], reason: 'no plain HTTP over the internet');
      final picked = await pickConnection(r, probe: (c) async => !c.https);
      expect(picked!.uri, 'http://10.0.0.39:32400');
      expect(picked.local, isTrue);
    });

    test('Home users, and a wrong PIN', () async {
      final a = account((r) async {
        if (r.url.path == '/api/v2/home/users') return json(fixture('home_users'));
        if (r.url.queryParameters['pin'] == '1234') return json({'authToken': 'dad-token'});
        return json({'errors': [{'code': 1041, 'message': 'Invalid PIN', 'status': 403}]}, 403);
      });
      final users = await a.homeUsers('acct');
      expect(users.map((u) => (u.title, u.protected)), [('Dad', true), ('Kids', false)]);
      expect(users.first.id, '1001');
      await expectLater(a.switchUser('acct', users.first, pin: '9999'), throwsA(isA<PlexWrongPin>()));
      expect(await a.switchUser('acct', users.first, pin: '1234'), 'dad-token');
    });

    test('sign-out removes this device from the account', () async {
      final sent = <String>[];
      await account((r) async {
        sent.add('${r.method} ${r.url.path}');
        return r.method == 'GET'
            ? json([
                {'id': 5, 'clientIdentifier': 'other'},
                {'id': 6, 'clientIdentifier': 'dev1'},
              ])
            : http.Response('', 204);
      }).signOut('acct');
      expect(sent, ['GET /api/v2/devices', 'DELETE /api/v2/devices/6']);
    });

    test('the address is looked up again, and a removed share is noticed', () async {
      final a = account((r) async => json(fixture('resources')));
      final found = await rediscover(a, accountToken: 'acct', machineId: 'f00dfeed');
      expect(found.resource!.name, "Grandpa's Plex");
      final gone = await rediscover(a, accountToken: 'acct', machineId: 'no-longer-shared');
      expect(gone.resource, isNull);
    });
  });
}
