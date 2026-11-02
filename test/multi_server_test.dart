import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/analysis/analysis_cache.dart';
import 'package:nightingale_tv/commercials/analysis/server_analysis.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/library/library_merge.dart';
import 'package:nightingale_tv/library/pool_root.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/live/live_source_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/plex/plex_library.dart';
import 'package:nightingale_tv/server/server_set.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';

String s2(String id) => ServerSet.globalId('s2', id);

ServerSession _session(String name, {String? serverId, ServerKind kind = ServerKind.jellyfin}) => ServerSession(
    serverUrl: 'https://$name.example',
    serverName: name,
    userId: 'u',
    userName: 'tester',
    accessToken: 'secret-$name',
    deviceId: 'dev',
    serverId: serverId,
    kind: kind);

/// [items] as an index; with [key], as that added server's part.
LibraryIndex _part(FakeItems items, {String? key, Map<String, List<String>> ids = const {}}) {
  final index = LibraryIndex.fromJellyfinItems(
    seriesItems: items.series,
    episodeItems: [
      for (final e in items.episodes) {...e, if (ids[e['Id']] case final p?) 'ProviderIds': {for (final x in p) x.split(':')[0]: x.split(':')[1]}}
    ],
    movieItems: [
      for (final m in items.movies) {...m, if (ids[m['Id']] case final p?) 'ProviderIds': {for (final x in p) x.split(':')[0]: x.split(':')[1]}}
    ],
    commercialItems: items.commercials,
    poolsByItem: {for (final c in items.commercials) c['Id'] as String: [fakePoolId]},
    fetchedAt: DateTime(2026),
  );
  return key == null ? index : index.withServerKey((id) => ServerSet.globalId(key, id));
}

void main() {
  group('server set and ids', () {
    test('global ids round-trip: raw for the main server, key-prefixed for added ones', () {
      expect(ServerSet.globalId('main', 'abc'), 'abc');
      expect(ServerSet.globalId('s2', '1234'), 's2~1234');
      expect(ServerSet.keyOf('s2~1234'), 's2');
      expect(ServerSet.rawId('s2~1234'), '1234');
      expect(ServerSet.keyOf('0f4a48d1dabeb96fedd676f0c2977bca'), 'main');
      expect(ServerSet.rawId('0f4a48d1dabeb96fedd676f0c2977bca'), '0f4a48d1dabeb96fedd676f0c2977bca');
      // A Plex library id keeps its own prefix.
      expect(ServerSet.rawId('s3~library:2'), 'library:2');
    });

    test('resolve gives the server and its own id; unknown keys resolve to nothing', () {
      final set = ServerSet();
      final mainClient = FakeClient([]);
      final added = FakeClient([], serverUrl: 'https://plex.example');
      set.main
        ..session = _session('Home')
        ..client = mainClient;
      final server = set.add(_session('Basement'), added);
      expect(server.key, 's2');
      expect(set.resolve('abc')!.client, same(mainClient));
      expect(set.resolve('abc')!.rawId, 'abc');
      expect(set.resolve('s2~48213')!.client, same(added));
      expect(set.resolve('s2~48213')!.rawId, '48213');
      expect(set.resolve('s9~1'), isNull);
    });

    test('keys are never reused, even after a restart', () {
      final set = ServerSet();
      set.add(_session('A'), FakeClient([]));
      set.add(_session('B'), FakeClient([]));
      set.remove('s3');
      final json = set.toJson();
      final reloaded = ServerSet()..load(json, (s, key) => FakeClient([]));
      expect(reloaded.added.map((s) => s.key), ['s2']);
      expect(reloaded.add(_session('C'), FakeClient([])).key, 's4');
    });

    test('servers.json keeps order, quality limits and sign-ins; one server saves nothing', () {
      final set = ServerSet();
      expect(set.toJson(), isNull);
      set.add(_session('Plex', serverId: 'm1', kind: ServerKind.plex), FakeClient([]));
      set.move('s2', -1);
      set.byKey('s2')!.qualityLimit = 2000000;
      final reloaded = ServerSet()..load(set.toJson(), (s, key) => FakeClient([]));
      expect(reloaded.order, ['s2', 'main']);
      expect(reloaded.byKey('s2')!.qualityLimit, 2000000);
      expect(reloaded.byKey('s2')!.qualityLimitKbps, 2000);
      expect(reloaded.byKey('s2')!.session!.kind, ServerKind.plex);
      expect(reloaded.byKey('s2')!.state, ServerState.ok);
    });

    test('an added server restored without a sign-in needs signing in, with its hint', () {
      final set = ServerSet()
        ..load({
          'servers': [
            {
              'key': 's2',
              'hint': {'kind': 'plex', 'serverName': 'Basement', 'serverId': 'm1', 'userName': 'dad'}
            }
          ],
          'order': ['main', 's2'],
        }, (s, key) => FakeClient([]));
      final server = set.byKey('s2')!;
      expect(server.state, ServerState.needsSignIn);
      expect(server.client, isNull);
      expect(server.name, 'Basement');
      expect(server.kind, ServerKind.plex);
      expect(set.resolve('s2~1'), isNull);
    });

    test('withServerKey prefixes every id: entries, sources, series, albums and roots', () {
      final index = LibraryIndex(
        series: const [SeriesEntry(key: 'show|2000', id: '7', name: 'Show')],
        episodes: [
          const MediaEntry(
              id: '10', kind: MediaKind.episode, title: 'E', runtime: Duration(minutes: 22), seriesKey: 'show|2000', seriesId: '7')
        ],
        movies: const [],
        commercials: [
          const MediaEntry(id: '30', sourceId: '31', kind: MediaKind.commercial, title: 'Ad', runtime: Duration(seconds: 30))
        ],
        songs: [
          const MediaEntry(id: '40', kind: MediaKind.song, title: 'S', runtime: Duration(minutes: 3), albumId: '41')
        ],
        rootsByItem: const {
          '10': ['box']
        },
        roots: const {'box', 'gone'},
        missingRoots: const {'gone'},
        fetchedAt: DateTime(2026),
      ).withServerKey(s2);
      expect(index.series.single.id, 's2~7');
      expect(index.episodes.single.id, 's2~10');
      expect(index.episodes.single.seriesId, 's2~7');
      expect(index.episodes.single.seriesKey, 'show|2000');
      expect(index.commercials.single.sourceId, 's2~31');
      expect(index.songs.single.albumId, 's2~41');
      expect(index.rootsByItem, {
        's2~10': ['s2~box']
      });
      expect(index.roots, {'s2~box', 's2~gone'});
      expect(index.missingRoots, {'s2~gone'});
    });

    test('Plex rating keys and Jellyfin ids on several servers never collide', () {
      Map<String, Object?> plexMovie(String key, String title) => {
            'ratingKey': key,
            'title': title,
            'year': 1999,
            'duration': 5400000,
            'Media': [
              {
                'Part': [
                  {'id': 1, 'key': '/library/parts/1/file.mkv'}
                ]
              }
            ]
          };
      Map<String, Object?> plexEpisode(String key) => {
            'ratingKey': key,
            'title': 'Pilot',
            'grandparentTitle': 'Show',
            'grandparentRatingKey': '9',
            'parentIndex': 1,
            'index': 1,
            'duration': 1320000,
          };
      final a = libraryIndexFromPlex(episodes: [plexEpisode('1234')], fetchedAt: DateTime(2026))
          .withServerKey((id) => ServerSet.globalId('s2', id));
      final b = libraryIndexFromPlex(movies: [plexMovie('1234', 'Heat')], fetchedAt: DateTime(2026))
          .withServerKey((id) => ServerSet.globalId('s3', id));
      final main = _part(fakeItems(shows: const {'Alpha': 1}, movies: 1));
      final merged = mergeLibraries([main, a, b]);
      expect(merged['s2~1234']!.kind, MediaKind.episode);
      expect(merged['s3~1234']!.kind, MediaKind.movie);
      expect(merged['movie-1']!.kind, MediaKind.movie);
      expect(merged.episodes.length + merged.movies.length, 4);
    });

    test("analysis results go to each server's own cache, under the ids it knows", () async {
      final tmp = Directory.systemTemp.createTempSync('multi_analysis');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final home = await AnalysisCache.open(tmp, 'home');
      final plex = await AnalysisCache.open(tmp, 'plex-machine');
      final store = ServerAnalysis({'main': home, 's2': plex});
      const a = MediaEntry(id: 'abc', kind: MediaKind.episode, title: 'A', runtime: Duration(minutes: 22));
      const b = MediaEntry(id: 's2~123', kind: MediaKind.episode, title: 'B', runtime: Duration(minutes: 22));
      const c = MediaEntry(id: 's3~9', kind: MediaKind.episode, title: 'C', runtime: Duration(minutes: 22));
      store.recordSegments(a, const [], at: DateTime(2026));
      store.recordSegments(b, const [], at: DateTime(2026));
      store.recordSegments(c, const [], at: DateTime(2026));
      expect(home.ids, ['abc']);
      expect(plex.ids, ['123']);
      expect(store.isAnalyzed(b), isTrue);
      expect(store.isAnalyzed(c), isFalse);
      await store.flush();
      expect(File('${tmp.path}/plex-machine.json').readAsStringSync(), contains('"123"'));
      await home.close();
      await plex.close();
    });

    test('Plex Guid arrays become provider ids', () {
      expect(
          plexProviderIds([
            {'id': 'imdb://tt0088763'},
            {'id': 'tmdb://105'},
            {'id': 'tvdb://299'},
            {'id': 'plex://movie/5d77'},
          ]),
          ['imdb:tt0088763', 'tmdb:105', 'tvdb:299']);
      expect(LibraryIndex.providerIdsOf({'Tvdb': '79488', 'Imdb': 'tt0496424', 'TvdbSlug': '30-rock', 'Tmdb': ''}),
          ['tvdb:79488', 'imdb:tt0496424']);
    });
  });

  group('one-server profile, unchanged', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('multi_one'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('its files are byte-identical after a load and save, and no servers.json is written', () async {
      final app = await signedInApp(dir, fakeLibrary(movies: 2));
      final files = ['session.json', 'library.json', 'channels.json'];
      final before = {for (final f in files) f: File('${dir.path}/$f').readAsBytesSync()};
      await app.setLastChannel(app.channels.first);
      await app.close();
      final again = AppState(await AppStorage.at(dir));
      await again.start();
      expect(again.servers.multiple, isFalse);
      await again.close();
      for (final f in ['session.json', 'library.json']) {
        expect(File('${dir.path}/$f').readAsBytesSync(), before[f], reason: f);
      }
      expect(File('${dir.path}/${ServerSet.file}').existsSync(), isFalse);
      expect(Directory('${dir.path}/library_parts').existsSync(), isFalse);
    });

    test('a refresh asks for provider ids only for shows and writes no part', () async {
      final items = fakeItems(shows: const {'Alpha': 3});
      final server = FakeServer('Home', items: items);
      final app = await signedInApp(dir, _part(items));
      app.client = server.client;
      await app.refreshLibrary(background: true);
      // Shows always (lineup-dedup D1); episodes and movies only with
      // several servers.
      expect(server.requests.where((r) => r.contains('ProviderIds') && !r.contains('IncludeItemTypes=Series')), isEmpty);
      expect(server.requests.where((r) => r.contains('IncludeItemTypes=Series')).every((r) => r.contains('ProviderIds')),
          isTrue);
      expect(Directory('${dir.path}/library_parts').existsSync(), isFalse);
      await app.close();
    });
  });

  group('merging', () {
    final alpha = fakeItems(shows: const {'Alpha': 8}, movies: 2);

    test('a mirrored show is one show, its copies kept as alternates in Play from order', () {
      final merged = mergeLibraries([_part(alpha), _part(renamed(alpha, 'x'), key: 's2')]);
      expect(merged.series.length, 1);
      expect(merged.episodes.length, 8);
      expect(merged.movies.length, 2);
      final e1 = merged['Alpha-e1']!;
      expect(e1.alternates.map((a) => a.id), ['s2~xAlpha-e1']);
      expect(merged.copyById('s2~xAlpha-e1')!.sourceId, 's2~xAlpha-e1');
      expect(merged.primaryIdOf('s2~xAlpha-e1'), 'Alpha-e1');
    });

    test('the id a merged item had before is kept, whichever server is first now', () {
      final first = mergeLibraries([_part(renamed(alpha, 'x'), key: 's2'), _part(alpha)]);
      expect(first['s2~xAlpha-e1'], isNotNull);
      final previous = _part(alpha);
      final again = mergeLibraries([_part(renamed(alpha, 'x'), key: 's2'), _part(alpha)], previous: previous);
      expect(again['Alpha-e1'], isNotNull);
      expect(again['Alpha-e1']!.alternates.single.id, 's2~xAlpha-e1');
    });

    test('provider ids decide first: shared ids merge, different ids keep titles apart', () {
      final main = _part(fakeItems(shows: const {}, movies: 2), ids: const {
        'movie-1': ['tmdb:1'],
        'movie-2': ['tmdb:2'],
      });
      // Same titles and years, but movie-2 is a different film (another TMDB id).
      final other = _part(renamed(fakeItems(shows: const {}, movies: 2), 'x'), key: 's2', ids: const {
        'xmovie-1': ['imdb:tt1', 'tmdb:1'],
        'xmovie-2': ['tmdb:99'],
      });
      final merged = mergeLibraries([main, other]);
      expect(merged.movies.length, 3);
      expect(merged['movie-1']!.alternates.single.id, 's2~xmovie-1');
      expect(merged['movie-2']!.alternates, isEmpty);
    });

    test('colliding ids from two servers stay separate items', () {
      final a = _part(fakeItems(shows: const {'Alpha': 2}));
      final b = _part(fakeItems(shows: const {'Zeta': 2}), key: 's2');
      final merged = mergeLibraries([a, b]);
      expect(merged.episodes.length, 4);
      expect(merged.series.length, 2);
    });

    test('episodes without numbers and movies without a year are never merged', () {
      FakeItems strip(FakeItems i) => (
            series: i.series,
            episodes: [for (final e in i.episodes) {...e}..remove('IndexNumber')],
            movies: [for (final m in i.movies) {...m}..remove('ProductionYear')],
            commercials: i.commercials,
          );
      final items = strip(fakeItems(shows: const {'Alpha': 1}, movies: 1));
      final merged = mergeLibraries([_part(items), _part(renamed(items, 'x'), key: 's2')]);
      expect(merged.episodes.length, 2);
      expect(merged.movies.length, 2);
    });

    test('commercials are never merged', () {
      final ads = fakeItems(shows: const {'Alpha': 1}, commercials: const [Duration(seconds: 30)]);
      final merged = mergeLibraries([_part(ads), _part(renamed(ads, 'x'), key: 's2')]);
      expect(merged.commercials.map((c) => c.id), ['ad-1', 's2~xad-1']);
    });

    test("play count is the highest copy's, added date the earliest", () {
      FakeItems played(FakeItems i, int count, String created) => (
            series: i.series,
            episodes: [
              for (final e in i.episodes) {...e, 'UserData': {'PlayCount': count}, 'DateCreated': created}
            ],
            movies: i.movies,
            commercials: i.commercials,
          );
      final items = fakeItems(shows: const {'Alpha': 1});
      final merged = mergeLibraries([
        _part(played(items, 2, '2026-05-01T00:00:00Z')),
        _part(played(renamed(items, 'x'), 3, '2025-01-01T00:00:00Z'), key: 's2'),
      ]);
      expect(merged['Alpha-e1']!.playCount, 3);
      expect(merged['Alpha-e1']!.added, DateTime.utc(2025).toLocal());
    });

    test("roots stay per server, and a merged item is under every copy's roots", () {
      final a = _part(alpha).withRoots({
        'box': {'Alpha-e1'}
      });
      final b = _part(renamed(alpha, 'x'), key: 's2').withRoots({
        's2~box': {'s2~xAlpha-e2'}
      });
      final merged = mergeLibraries([a, b]);
      expect(merged.rootsByItem['Alpha-e1'], ['box']);
      expect(merged.rootsByItem['Alpha-e2'], ['s2~box']);
      expect(merged.roots, {'box', 's2~box'});
    });
  });

  group('the app with several servers', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('multi_app'));
    tearDown(() => dir.deleteSync(recursive: true));

    final alpha = fakeItems(shows: const {'Alpha': 30, 'Beta': 24}, movies: 2);

    Future<(AppState, FakeServer)> start() async {
      final home = FakeServer('Home', items: alpha, serverId: 'home');
      final app = await signedInApp(dir, _part(alpha));
      app.client = home.client;
      app.session = home.session;
      return (app, home);
    }

    test('adding a mirror leaves every channel airing the same programs at the same times', () async {
      final (app, _) = await start();
      final now = DateTime.now();
      String? onAir(DateTime t) => app.scheduleFor(app.channels.first)?.programAt(t).item?.id;
      final times = [for (var m = 0; m < 600; m += 37) now.add(Duration(minutes: m))];
      final before = [for (final t in times) onAir(t)];
      final mirror = FakeServer('Mirror', items: renamed(alpha, 'x'), url: 'https://mirror.example', serverId: 'mirror');
      await app.addServer(mirror.session, mirror.client, refresh: false);
      await app.refreshLibrary(background: true);
      expect(app.library.episodes.length, 54);
      expect(app.library['Alpha-e1']!.alternates.single.id, 's2~xAlpha-e1');
      expect([for (final t in times) onAir(t)], before);
      expect(File('${dir.path}/library_parts/main.json').existsSync(), isTrue);
      expect(File('${dir.path}/library_parts/s2.json').existsSync(), isTrue);
      // Every request to a server carries only its own ids.
      expect(mirror.requests.where((r) => r.contains('~')), isEmpty);
      expect(mirror.requests.where((r) => r.contains('ProviderIds')), isNotEmpty);
      await app.close();
    });

    test('a genre channel takes shows from both servers', () async {
      final (app, _) = await start();
      final other = FakeServer('Plex',
          items: renamed(fakeItems(shows: const {'Gamma': 4, 'Delta': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      final keys = app.library.series.map((s) => s.key).toSet();
      expect(keys, containsAll(['alpha|2000', 'gamma|2000', 'delta|2000']));
      expect(app.library['s2~pGamma-e1'], isNotNull);
      await app.close();
    });

    test('a server down at refresh keeps its items; one never scanned adds nothing', () async {
      final (app, _) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      expect(app.library['s2~pZed-e1'], isNotNull);
      other.down = true;
      await app.refreshLibrary(background: true);
      expect(app.syncError, isNull);
      expect(app.library['s2~pZed-e1'], isNotNull);
      expect(app.servers.byKey('s2')!.state, ServerState.unreachable);

      final third = FakeServer('Far', items: renamed(fakeItems(shows: const {'Delta': 3}), 'f'), url: 'https://far.example', serverId: 'f')
        ..down = true;
      await app.addServer(third.session, third.client, refresh: false);
      await app.refreshLibrary(background: true);
      expect(app.library.episodes.where((e) => e.id.startsWith('s3~')), isEmpty);
      expect(app.servers.byKey('s3')!.state, ServerState.unreachable);

      // Back up: tried again, and used.
      other.down = false;
      await app.pingUnreachable();
      expect(app.servers.byKey('s2')!.state, ServerState.ok);
      await app.close();
    });

    test("a revoked sign-in marks that server Needs sign-in and keeps the profile signed in", () async {
      final (app, home) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      home.revoked = true;
      await app.refreshLibrary(background: true);
      expect(app.phase, AppPhase.ready);
      expect(app.session, isNotNull);
      expect(app.servers.main.state, ServerState.needsSignIn);
      expect(app.library['Alpha-e1'], isNotNull);
      expect(app.library['s2~pZed-e1'], isNotNull);
      await app.close();
    });

    test('the same server twice is refused', () async {
      final (app, home) = await start();
      final again = FakeServer('Home', items: alpha, serverId: 'home', url: 'https://other-address.example');
      await expectLater(app.addServer(again.session, again.client, refresh: false),
          throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Home is already in this profile')));
      expect(app.servers.multiple, isFalse);
      expect(home.requests, isEmpty);
      await app.close();
    });

    test('removing a mirror keeps every channel on the same programs, under the remaining copies', () async {
      final (app, _) = await start();
      final mirror = FakeServer('Mirror', items: renamed(alpha, 'x'), url: 'https://mirror.example', serverId: 'mirror');
      await app.addServer(mirror.session, mirror.client, refresh: false);
      await app.moveServer('s2', -1);
      await app.refreshLibrary(background: true);
      final ch = app.channels.first;
      final playlist = [...ch.playlist];
      await app.removeServer('s2');
      expect(app.servers.multiple, isFalse);
      expect(ch.playlist, playlist);
      expect(app.library['Alpha-e1']!.alternates, isEmpty);
      expect(File('${dir.path}/${ServerSet.file}').existsSync(), isFalse);
      await app.close();
    });

    test('removing a server takes its own items out of the channels', () async {
      final (app, _) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      expect(app.allChannels.expand((c) => c.playlist).where((id) => id.startsWith('s2~')), isNotEmpty);
      await app.removeServer('s2');
      expect(app.library.episodes.where((e) => e.id.startsWith('s2~')), isEmpty);
      expect(app.allChannels.expand((c) => c.playlist).where((id) => id.startsWith('s2~')), isEmpty);
      await app.close();
    });

    test('custom channel roots resolve through their own server', () async {
      final (app, home) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p')
        ..collection = ['pZed-e1', 'pZed-e2'];
      home.collection = ['Alpha-e1'];
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      final ch = await app.createCustomChannel(
          'Mix',
          const ChannelSource(roots: [
            PoolRoot(itemId: 'box', libraryId: 'tv', label: 'Box'),
            PoolRoot(itemId: 's2~box', libraryId: 's2~tv', label: 'Box'),
          ]));
      expect(ch.playlist.toSet(), {'Alpha-e1', 's2~pZed-e1', 's2~pZed-e2'});
      expect(other.requests.where((r) => r.contains('~')), isEmpty);
      expect(home.requests.where((r) => r.contains('~')), isEmpty);
      await app.close();
    });

    test('signing out ends every sign-in and forgets the added servers', () async {
      final (app, _) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.refreshLibrary(background: true);
      await app.signOut();
      expect(other.requests.where((r) => r.startsWith('/Sessions/Logout')), isNotEmpty);
      expect(app.servers.multiple, isFalse);
      expect(File('${dir.path}/${ServerSet.file}').existsSync(), isFalse);
      expect(Directory('${dir.path}/library_parts').listSync(), isEmpty);
    });

    test("each server's Live TV source plays through its own server, and leaves with it", () async {
      final (app, home) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      LiveSource source(String serverId) => LiveSource(
          id: LiveSource.newId(), kind: LiveSourceKind.server, name: 'TV', serverKind: ServerKind.jellyfin, serverId: serverId);
      final a = source('home'), b = source('p');
      await app.live.addSource(a, const []);
      await app.live.addSource(b, const []);
      expect(app.live.isActive(a), isTrue);
      expect(app.live.isActive(b), isTrue);
      expect((app.live.clientFor(a)! as ServerLiveSource).tv, same(home.client.liveTv));
      expect((app.live.clientFor(b)! as ServerLiveSource).tv, same(other.client.liveTv));
      expect(app.live.serverSourceFor('p'), same(b));
      await app.removeServer('s2');
      expect(app.live.sources.map((s) => s.id), [a.id]);
      await app.close();
    });

    test('added servers come back after a restart', () async {
      final (app, _) = await start();
      final other = FakeServer('Plex', items: renamed(fakeItems(shows: const {'Zed': 4}), 'p'), url: 'https://plex.example', serverId: 'p');
      await app.addServer(other.session, other.client, refresh: false);
      await app.moveServer('s2', -1);
      await app.close();
      final again = AppState(await AppStorage.at(dir));
      await again.start();
      expect(again.servers.order, ['s2', 'main']);
      expect(again.servers.byKey('s2')!.session!.serverId, 'p');
      await again.close();
    });
  });
}
