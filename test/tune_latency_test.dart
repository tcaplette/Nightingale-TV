// What may stand between a tune (at launch or a channel change) and its
// first picture. Each test is one failure point found in the playback
// diagnostics (TUNE lines, see lib/playback/tune_timeline.dart): the app
// waiting on, or competing with, its own traffic while a stream opens.
//
// The stream itself (how fast mpv gets its first frame from the server) is
// measured with real mpv in integration_test/startup_latency_test.dart.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakeClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;

  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
    },
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_latency');
    app = await signedInApp(dir, library);
    log = [];
    client = FakeClient(log);
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
  });

  tearDown(() async {
    if (!(client.holdReports?.isCompleted ?? true)) client.holdReports!.complete();
    tuner.dispose();
    await app.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();

  group('a tune never waits for the app\'s own requests', () {
    test('a channel change opens the new stream without waiting for the server to log the last one', () async {
      await tuner.tune(app.channels[0]);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(player.opens, hasLength(1));

      // On a slow link the "stopped" report takes seconds to answer.
      client.holdReports = Completer();
      unawaited(tuner.tune(app.channels[1]));
      await settle();
      expect(player.opens, hasLength(2),
          reason: 'the new channel\'s stream must open at once; it is waiting for '
              'POST /Sessions/Playing/Stopped (calls so far: $log)');
    });

    test('the stream has the connection to itself until its first picture', () async {
      // mpv is opening: no frame yet.
      player.onOpen = (_) => OpenResult.noPicture;
      await tuner.tune(app.channels[0]);
      await settle();
      expect(tuner.status, TunerStatus.tuning);
      expect(client.reports, isEmpty,
          reason: 'nothing but the stream should go to the server before the first picture; '
              'sent: ${client.reports.map((r) => r.$1).toList()}');

      player.showPicture(player.opens.single.start ?? Duration.zero);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(client.reports.map((r) => r.$1), ['start'], reason: 'the viewing is reported once it plays');
    });

    test('decisions for other channels are asked only after the first picture', () async {
      tuner.prefetch = true;
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
      player.onOpen = (_) => OpenResult.noPicture;
      await tuner.tune(app.channels[1]);
      await settle();
      final asked = client.decisions.length;
      expect(asked, 1, reason: 'only the channel being tuned is decided before its picture');
      player.showPicture(player.opens.single.start ?? Duration.zero);
      await settle();
      expect(client.decisions, hasLength(asked), reason: 'not at the picture itself: mpv is still filling its cache');
      // mpv has 10 s buffered (or 10 s have passed): now it may ask.
      player.buffered = 10.5;
      await tuner.debugSample();
      await settle();
      expect(client.decisions.length, greaterThan(asked));
    });

    test('decisions are asked ahead 10 s after the picture even if mpv never buffers 10 s', () async {
      tuner
        ..prefetch = true
        ..prefetchAfter = const Duration(milliseconds: 100);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
      await tuner.tune(app.channels[1]);
      await settle();
      final asked = client.decisions.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(client.decisions.length, greaterThan(asked));
    });

    test('surfing quickly asks nothing ahead until the last channel\'s picture', () async {
      tuner
        ..prefetch = true
        ..prefetchAfter = const Duration(milliseconds: 100);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
      await tuner.tune(app.channels[0]);
      await settle();
      // The next two opens show no picture; the timer armed by the first
      // picture is cancelled by the tune.
      player.onOpen = (_) => OpenResult.noPicture;
      await tuner.channelUp();
      await tuner.channelUp();
      await settle();
      final tuned = {for (final d in client.decisions) d.id};
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect({for (final d in client.decisions) d.id}, tuned, reason: 'only the tunes\' own decisions');
      player.showPicture(player.opens.last.start ?? Duration.zero);
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(client.decisions.length, greaterThan(tuned.length));
    });

    test('a tune whose decision is being asked ahead awaits that request', () async {
      tuner
        ..prefetch = true
        ..prefetchAfter = const Duration(milliseconds: 50);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000));
      // A moment when the neighbour airs another program (the same one would
      // already have its decision).
      String? on(int i) => app.scheduleFor(app.channels[i])!.programAt(now).item?.sourceId;
      for (var i = 0; i < 500 && (on(1) == null || on(0) == on(1)); i++) {
        now = now.add(const Duration(minutes: 7));
      }
      await tuner.tune(app.channels[0]);
      await settle();
      // The neighbours' requests, asked ahead, are slow to answer.
      client.holdDecisions = Completer();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final neighbour = app.scheduleFor(app.channels[1])!.programAt(now).item!.sourceId;
      expect([for (final d in client.decisions) d.id], contains(neighbour));
      unawaited(tuner.channelUp());
      await settle();
      expect(player.opens, hasLength(1), reason: 'waiting for the decision in flight');
      client.holdDecisions!.complete();
      await settle();
      expect(player.opens, hasLength(2));
      expect([for (final d in client.decisions) d.id].where((id) => id == neighbour), hasLength(1),
          reason: 'one PlaybackInfo request for the neighbour, shared by the prefetch and the tune');
    });
  });

  group('reports never hold up an open, and are never lost', () {
    test('an open that fails sends no start, and the queued "stopped" goes within 10 s of the tune', () async {
      tuner.stoppedReportDelay = const Duration(milliseconds: 100);
      await tuner.tune(app.channels[0]);
      await settle();
      expect(client.reports.map((r) => r.$1), ['start']);
      player.onOpen = (_) => OpenResult.errors;
      await tuner.tune(app.channels[1]);
      await settle();
      expect(tuner.status, TunerStatus.error);
      expect(client.reports.map((r) => r.$1), ['start'], reason: 'queued, not sent during the open');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(client.reports.map((r) => r.$1), ['start', 'stopped'],
          reason: 'the old viewing is closed; the failed one was never started');
      expect(client.reports.last.$2.itemId, client.reports.first.$2.itemId);
    });

    test('quitting right after a channel change sends the queued "stopped" report', () async {
      await tuner.tune(app.channels[0]);
      await settle();
      player.onOpen = (_) => OpenResult.noPicture;
      await tuner.tune(app.channels[1]);
      await settle();
      expect(client.reports.map((r) => r.$1), ['start']);
      // What the exit hook runs.
      await tuner.flushReports();
      expect(client.reports.map((r) => r.$1), ['start', 'stopped']);
    });

    test('the "stopped" report goes at the new channel\'s picture', () async {
      await tuner.tune(app.channels[0]);
      await settle();
      player.onOpen = (_) => OpenResult.noPicture;
      await tuner.tune(app.channels[1]);
      await settle();
      expect(client.reports.map((r) => r.$1), ['start']);
      player.showPicture(player.opens.last.start ?? Duration.zero);
      await settle();
      expect(client.reports.map((r) => r.$1), ['start', 'stopped', 'start']);
    });
  });

  group('background downloads hold off while a stream opens', () {
    for (final (name, playback) in [
      ('transcoding off', PlaybackSettings.off),
      ('Original (no cap)', const PlaybackSettings(transcodeIfNeeded: true)),
      ('a 4 Mbps cap', const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000)),
    ]) {
      test('the analyzer downloads nothing while tuning, with $name', () {
        expect(analyzerBudget(PlaybackActivity.tuning, playback, fileBitsPerSecond: 2000000), const Budget.paused(),
            reason: 'the analyzer\'s stream proxy may not compete with a stream that is opening');
      });
    }

    test('a launch with a stale library re-scans only after the first picture', () async {
      // A server that notes every request and answers 503 (the cached
      // lineup stays).
      final paths = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        paths.add(request.uri.path);
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      final dir2 = await Directory.systemTemp.createTemp('nightingale_tv_latency_stale');
      // 10 s after the picture in the app; shortened here.
      final after = AppState.launchAfterPicture;
      AppState.launchAfterPicture = const Duration(milliseconds: 300);
      addTearDown(() => AppState.launchAfterPicture = after);
      final stale = await signedInApp(dir2, library,
          serverUrl: 'http://127.0.0.1:${server.port}', libraryAge: AppState.libraryMaxAge + const Duration(hours: 1));
      try {
        // The TV screen tunes the last channel as soon as the lineup shows.
        stale.playbackActivity.value = PlaybackActivity.tuning;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(paths, isEmpty,
            reason: 'the library re-scan downloads the whole library; it started while the first '
                'stream was opening: $paths');

        // The picture is up: it may scan once the stream has settled.
        stale.playbackActivity.value = PlaybackActivity.playing;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(paths, isEmpty, reason: 'not at the picture itself');
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (paths.isEmpty && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(paths, isNotEmpty, reason: 'the stale library is re-scanned once the picture is up');
      } finally {
        await stale.close();
        await server.close(force: true);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir2.delete(recursive: true);
      }
    });
  });
}
