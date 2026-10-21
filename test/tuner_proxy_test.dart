// The tuner and the playback proxy (fast-tune spec, "Playback goes through a
// local proxy with warm connections" and "Direct-play index cache").
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/playback/index_cache.dart';
import 'package:nightingale_tv/playback/playback_proxy.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'media_files.dart';

/// A proxy that starts but never answers an open.
class _StuckProxy extends PlaybackProxy {
  _StuckProxy(Directory dir) : super(cacheDir: dir, inIsolate: false);

  @override
  Future<Uri> open(Uri url, Map<String, String> headers, {IndexCacheKey? cache, bool joins = false, Uri? alongside}) =>
      Completer<Uri>().future;
}

/// A proxy that can't start.
class _BrokenProxy extends PlaybackProxy {
  _BrokenProxy() : super(inIsolate: false);

  @override
  Future<void> start() => Future.error(const SocketException('no loopback'));
}

void main() {
  late Directory dir;
  late Directory cacheDir;
  late AppState app;
  late FakeStreamServer server;
  late FakeClient client;
  late FakePlayer player;
  Tuner? tuner;
  late DateTime now;

  final library = fakeLibrary(shows: {
    'Alpha': 20,
    'Beta': 20,
    'Gamma': 20,
    'Delta': 20,
  }, genres: {
    'Alpha': ['Comedy'],
    'Beta': ['Comedy'],
    'Gamma': ['Drama'],
    'Delta': ['Drama'],
  });

  setUp(() async {
    final videos = await testVideos();
    final bytes = videos.mkv.readAsBytesSync();
    server = await FakeStreamServer.start({for (final e in library.episodes) e.id: bytes});
    dir = await Directory.systemTemp.createTemp('nightingale_tv_tuner_proxy');
    cacheDir = await Directory.systemTemp.createTemp('nightingale_tv_tuner_proxy_cache');
    app = await signedInApp(dir, library);
    client = FakeClient([], serverUrl: server.url);
    app.client = client;
    player = FakePlayer([]);
    now = DateTime.now();
  });

  tearDown(() async {
    tuner?.dispose();
    tuner = null;
    await app.close();
    await server.close();
    // Tuning saves the last channel in the background.
    await app.storage.flush();
    await dir.delete(recursive: true);
    await cacheDir.delete(recursive: true);
  });

  Tuner make(PlaybackProxy? proxy) => tuner = Tuner(app, player: player, clock: () => now, proxy: proxy)
    ..prefetch = false
    ..preload = false
    ..sampleEvery = const Duration(hours: 1);

  Future<void> settle([int ms = 50]) => Future<void>.delayed(Duration(milliseconds: ms));

  test('mpv opens a loopback URL without the access token, and the proxy warms two connections first', () async {
    final t = make(PlaybackProxy(cacheDir: cacheDir, inIsolate: false));
    await settle(200);
    expect(server.requests.where((r) => r.path == '/System/Ping'), hasLength(2), reason: 'warmed at start');
    await t.tune(app.channels.first);
    await settle();
    final open = player.opens.single;
    expect(open.url.host, '127.0.0.1');
    expect(open.url.path, startsWith('/o/'));
    expect(open.headers, isEmpty, reason: 'the proxy adds the auth headers itself');
    expect(t.status, TunerStatus.playing);
  });

  test('a proxy that doesn\'t answer an open within 1 s: the real URL opens', () async {
    final t = make(_StuckProxy(cacheDir));
    await settle(100);
    final clock = Stopwatch()..start();
    await t.tune(app.channels.first);
    await settle();
    final open = player.opens.single;
    expect(open.url.host, '127.0.0.1');
    expect(open.url.port, isNot(server.url.split(':').last), reason: 'not the proxy');
    expect(open.url.toString(), startsWith('${server.url}/Videos/'));
    expect(open.headers['Authorization'], isNotNull);
    expect(clock.elapsed, lessThan(const Duration(milliseconds: 1500)));
  });

  test('a proxy that fails to start: streams open from their real URLs', () async {
    final t = make(_BrokenProxy());
    await t.tune(app.channels.first);
    await settle();
    expect(player.opens.single.url.toString(), startsWith('${server.url}/Videos/'));
    expect(t.status, TunerStatus.playing);
  });

  test('without a proxy (tests, NIGHTINGALE_TV_NO_PROXY=1) real URLs open', () async {
    final t = make(null);
    await t.tune(app.channels.first);
    await settle();
    expect(player.opens.single.url.toString(), startsWith('${server.url}/Videos/'));
  });

  test('index fills start only once the picture is up and mpv has 10 s buffered', () async {
    final proxy = PlaybackProxy(cacheDir: cacheDir, inIsolate: false);
    final t = make(proxy);
    await settle(100);
    player.onOpen = (_) => OpenResult.noPicture;
    await t.tune(app.channels.first);
    await settle();
    final before = server.streamRequests.length;
    expect(before, 0, reason: 'mpv (a fake here) reads nothing; no fill while tuning');
    // mpv knows the file's bitrate: fills get a quarter of it (a fast
    // file here, so the test needn't wait on the budget).
    player.fileBitrate = 400000000;
    player.showPicture(player.opens.last.start ?? Duration.zero);
    await settle();
    player.buffered = 3.0;
    await t.debugSample();
    await settle(200);
    expect(server.streamRequests, isEmpty, reason: 'only 3 s buffered');

    player.buffered = 12.0;
    await t.debugSample();
    for (var i = 0; i < 40 && !await proxy.cached(app.scheduleFor(app.channels[1])!.programAt(now).item!.sourceId); i++) {
      await settle();
    }
    final neighbour = app.scheduleFor(app.channels[1])!.programAt(now).item!.sourceId;
    expect(await proxy.cached(neighbour), isTrue, reason: 'the channel one up is filled');
    expect(server.streamRequests.every((r) => r.range != null), isTrue, reason: 'range reads of the static stream only');
    expect(server.streamRequests.every((r) => r.path.endsWith('/stream')), isTrue);
  });
}
