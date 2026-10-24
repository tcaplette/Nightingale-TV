// End-to-end Live TV checks against the test servers' fake tuner
// (tool/test_servers), one source kind at a time:
//
//   LIVE_SOURCE=m3u flutter test integration_test/live_tv_live_test.dart -d linux
//   JELLYFIN_USER=... JELLYFIN_PASSWORD=... LIVE_SOURCE=jellyfin ...
//   EMBY_USER=... EMBY_PASSWORD=... LIVE_SOURCE=emby ...
//   PLEX_TOKEN=... LIVE_SOURCE=plex ...
//
// With the fake tuner up (test_servers.sh up tuner, or beside a server):
// adds the source, checks its channels and guide, tunes every live channel
// (H.264, MPEG-2 1080i deinterlaced, CEA-608 captions, HLS), surfs in and
// out of generated channels and quickly through live ones, and checks the
// tuner has nothing left open. M3U also checks the user agent, a provider
// drop that reconnects, rotating stream URLs and a refused stream.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/live/live_schedule.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

/// Settings: environment variables on Linux; `--dart-define`s on Android,
/// where the test can't read the host's environment.
final _env = {
  ...Platform.environment,
  for (final k in const ['LIVE_SOURCE', 'TUNER', 'JELLYFIN_URL', 'JELLYFIN_USER', 'JELLYFIN_PASSWORD', 'PLEX_URL', 'PLEX_TOKEN'])
    if (_define(k) case final v? when v.isNotEmpty) k: v,
};

String? _define(String k) => switch (k) {
      'LIVE_SOURCE' => const String.fromEnvironment('LIVE_SOURCE'),
      'TUNER' => const String.fromEnvironment('TUNER'),
      'JELLYFIN_URL' => const String.fromEnvironment('JELLYFIN_URL'),
      'JELLYFIN_USER' => const String.fromEnvironment('JELLYFIN_USER'),
      'JELLYFIN_PASSWORD' => const String.fromEnvironment('JELLYFIN_PASSWORD'),
      'PLEX_URL' => const String.fromEnvironment('PLEX_URL'),
      'PLEX_TOKEN' => const String.fromEnvironment('PLEX_TOKEN'),
      _ => null,
    };

/// The host, as this device reaches it (the emulator's 10.0.2.2).
final _host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
final _tuner = _env['TUNER'] ?? 'http://$_host:5104';

Future<Map<String, Object?>> _tunerStatus([String control = 'status']) async {
  final client = HttpClient();
  try {
    final r = await (await client.getUrl(Uri.parse('$_tuner/control/$control'))).close();
    return jsonDecode(await r.transform(utf8.decoder).join()) as Map<String, Object?>;
  } finally {
    client.close();
  }
}

Future<List<Map<String, Object?>>> _tunerStreams() async =>
    [for (final s in (await _tunerStatus())['streams'] as List) s as Map<String, Object?>];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final kind = _env['LIVE_SOURCE'];

  testWidgets('Live TV from ${kind ?? '(LIVE_SOURCE unset)'}', (tester) async {
    if (!const {'jellyfin', 'emby', 'plex', 'm3u'}.contains(kind)) {
      markTestSkipped('Set LIVE_SOURCE=jellyfin, emby, plex or m3u, with the fake tuner up.');
      return;
    }
    // Android plays with ExoPlayer; mpv is the desktop player.
    if (!Platform.isAndroid) MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_live');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;
    final timings = <String>[];

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<T> io<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    Future<void> until(bool Function() done, {Duration max = const Duration(seconds: 30), String? what}) async {
      final end = DateTime.now().add(max);
      while (!done() && DateTime.now().isBefore(end)) {
        await wait(const Duration(milliseconds: 200));
      }
      expect(done(), isTrue, reason: what);
    }

    await tester.pumpWidget(const SizedBox());
    await io(household.start);
    app = household.app!;

    // ---- Sign-in (generated channels from the test library) ----
    // M3U sources work beside any server: Jellyfin when its user is set.
    await io(() async {
      final serverKind = kind == 'm3u' ? (_env['JELLYFIN_USER'] != null ? 'jellyfin' : 'emby') : kind;
      switch (serverKind) {
        case 'jellyfin' || 'emby':
          final url = _env[serverKind == 'jellyfin' ? 'JELLYFIN_URL' : 'EMBY_URL'] ??
              (serverKind == 'jellyfin' ? 'http://$_host:8097' : 'http://$_host:8096');
          final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
          final client = found.client as JellyfinClient;
          final user = _env[serverKind == 'jellyfin' ? 'JELLYFIN_USER' : 'EMBY_USER']!;
          final pw = _env[serverKind == 'jellyfin' ? 'JELLYFIN_PASSWORD' : 'EMBY_PASSWORD'] ?? '';
          await app.completeSignIn(await client.authenticateByName(user, pw, serverName: found.info.name), client);
        case 'plex':
          final url = _env['PLEX_URL'] ?? 'http://$_host:32400';
          final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
          found.client.close();
          final session = ServerSession(
            kind: ServerKind.plex,
            serverUrl: url,
            serverName: found.info.name,
            serverId: found.info.id,
            userId: 'local',
            userName: 'local',
            accessToken: _env['PLEX_TOKEN'] ?? '',
            deviceId: app.settings.installId,
          );
          await app.completeSignIn(session, app.clientForSession(session));
      }
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final generated = [for (final c in app.channels) if (!c.isLive) c];
    expect(generated, isNotEmpty);

    // ---- Adding the source ----
    late final LiveSource source;
    final watch = Stopwatch()..start();
    if (kind == 'm3u') {
      source = await io(() => app.addM3uSource(name: 'Fake tuner', playlistUrl: '$_tuner/channels.m3u'));
      expect(source.guideUrl, '$_tuner/xmltv.xml.gz', reason: "the playlist header's guide");
      expect(source.guideFromPlaylist, isTrue);
    } else {
      final availability = await io(app.liveTvAvailability);
      expect(availability, LiveTvAvailability.available);
      source = await io(app.addServerLiveSource);
    }
    await until(() => !app.live.isRefreshing(source), what: 'the first guide refresh');
    timings.add('add+guide ${watch.elapsedMilliseconds} ms');
    final entry = app.live.entryFor(source);
    debugPrint('Source: ${entry.channels.length} channels, '
        '${entry.guide.values.fold(0, (n, l) => n + l.length)} programmes, error ${entry.state.lastError}');
    expect(entry.state.lastError, isNull);
    final live = [for (final c in app.channels) if (c.isLive) c];
    final expected = switch (kind) {
      'plex' => ['2.1', '4.1', '7.1'],
      'm3u' => ['2.1', '4.1', '7.1', '9.1', '11.1'],
      _ => ['2.1', '4.1', '7.1', '9.1', '11.1'],
    };
    expect([for (final c in live) c.live!.sourceNumber], expected);
    expect(live.first.number % 100, 0, reason: 'a block after the generated channels');
    expect(live.first.number, greaterThan(generated.last.number));
    LiveSchedule scheduleOf(String number) => app.scheduleFor(live.firstWhere((c) => c.live!.sourceNumber == number))! as LiveSchedule;
    final now = DateTime.now();
    expect(scheduleOf('2.1').programAt(now).title, 'The News');
    expect(scheduleOf('4.1').programAt(now).title, 'Fake Drama');
    expect(scheduleOf('7.1').programAt(now).title, isNot(LiveSchedule.noGuide), reason: '7.1 matches by name');
    if (expected.contains('11.1')) {
      expect(scheduleOf('11.1').programAt(now).detail, LiveSchedule.noGuide);
    }
    expect(scheduleOf('2.1').guideUntil!.difference(now), greaterThan(const Duration(hours: 23)));

    // ---- Live TV export (desktop) leaves live channels out ----
    if (PlatformInfo.isDesktop) {
      await io(() async {
        final service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
        try {
          await service.load();
          await service.setProfileExported(household.current!.id, true);
          final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
          final port = free.port;
          await free.close();
          await service.setPort(household.current!.id, port);
          await service.setEnabled(true);
          final http = HttpClient();
          Future<HttpClientResponse> get(String path) async =>
              (await http.getUrl(Uri.parse('http://127.0.0.1:$port$path'))).close();
          final m3u = await utf8.decodeStream(await get('/lineup.m3u'));
          final guide = await utf8.decodeStream(await get('/xmltv.xml'));
          expect(m3u, contains('/stream/${generated.first.number}.ts'));
          for (final c in live) {
            expect(m3u, isNot(contains('/stream/${c.number}.ts')), reason: '${c.name} is not exported');
            expect(m3u, isNot(contains(c.name)));
            expect(guide, isNot(contains(c.name)));
          }
          expect(guide, isNot(contains('The News')), reason: "no live programmes in the export's guide");
          final stream = await get('/stream/${live.first.number}.ts');
          expect(stream.statusCode, HttpStatus.notFound);
          await stream.drain<void>();
          http.close(force: true);
          debugPrint('Export: ${'#EXTINF'.allMatches(m3u).length} channels exported, none of the ${live.length} live');
        } finally {
          await service.stop();
          await household.setExportedProfiles({});
        }
      });
    }

    // ---- The TV, tuning each live channel ----
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    await until(() => tuner.status == TunerStatus.playing, what: 'the launch tune: ${tuner.error}');

    Future<String> mpv(String property) async {
      final player = tuner.media;
      if (player is! MediaKitTunerPlayer) return '';
      final native = player.player.platform;
      return native is NativePlayer ? await native.getProperty(property) : '';
    }

    Future<void> tuneLive(Channel ch) async {
      final t = Stopwatch()..start();
      await io(() => tuner.tune(ch));
      await until(() => tuner.status == TunerStatus.playing,
          max: const Duration(seconds: 25), what: '${ch.name}: ${tuner.liveMessage ?? tuner.error}');
      timings.add('${ch.live!.sourceNumber} first picture ${t.elapsedMilliseconds} ms');
      expect(tuner.program!.isLive, isTrue);
      expect(tuner.isLive, isTrue);
    }

    for (final ch in live) {
      if (Platform.isAndroid && kind == 'm3u' && ch.live!.sourceNumber == '4.1') {
        // An IPTV stream can't be converted, and this device has no MPEG-2
        // decoder: the card says so (live-playback "M3U streams").
        await io(() => tuner.tune(ch));
        await until(() => tuner.status == TunerStatus.error, what: 'the MPEG-2 card');
        expect(tuner.liveMessage, "This device can't play this channel's video");
        continue;
      }
      await tuneLive(ch);
      await wait(const Duration(seconds: 3));
      final number = ch.live!.sourceNumber;
      final interlaced = await io(() => mpv('deinterlace'));
      final codec = await io(() => mpv('video-codec'));
      debugPrint('$number: ${tuner.program!.title} · codec $codec · deinterlace $interlaced');
      if (!Platform.isAndroid) expect(interlaced, 'yes', reason: 'live opens deinterlace');
      if (Platform.isAndroid && kind == 'jellyfin' && number == '4.1') {
        // The Android profile has no MPEG-2: Jellyfin converts it.
        final client = app.client! as JellyfinClient;
        final sessions = await io(() => client.request('GET', '/Sessions', query: {'DeviceId': client.deviceId})) as List;
        final method = ((sessions.first as Map)['PlayState'] as Map?)?['PlayMethod'];
        debugPrint('4.1 on Android: $method');
        expect(method, 'Transcode');
      }
      if (number == '7.1' && !Platform.isAndroid) {
        await io(tuner.toggleCaptions);
        await wait(const Duration(seconds: 3));
        final tracks = jsonDecode(await io(() => mpv('track-list'))) as List;
        final subs = [for (final t in tracks) if ((t as Map)['type'] == 'sub') t];
        debugPrint('7.1 caption tracks: $subs');
        expect(subs, isNotEmpty, reason: 'the CEA-608 captions');
        await io(tuner.toggleCaptions);
      }
      if (kind == 'm3u' && number == '2.1') {
        final streams = await io(_tunerStreams);
        expect(streams.single['ua'], 'NightingaleFakeTuner/1.0', reason: 'the #EXTVLCOPT user agent');
      }
      if (kind != 'm3u' && number != '9.1') {
        expect(await io(_tunerStreams), hasLength(1), reason: 'one tuner in use');
      }
    }

    // ---- Out to a generated channel: the live stream is closed ----
    await io(() => tuner.tune(generated.first));
    await until(() => tuner.status == TunerStatus.playing, what: 'a generated channel');
    await until(() => !tuner.isLive);
    final freed = Stopwatch()..start();
    var left = await io(_tunerStreams);
    while (left.isNotEmpty && freed.elapsed < const Duration(seconds: 10)) {
      await wait(const Duration(milliseconds: 250));
      left = await io(_tunerStreams);
    }
    timings.add('tuner freed ${freed.elapsedMilliseconds} ms after leaving');
    expect(left, isEmpty, reason: "the source's stream is closed when leaving");

    // ---- Surfing quickly through live channels ----
    for (final ch in live.take(3)) {
      await io(() => tuner.tune(ch));
      await wait(const Duration(milliseconds: 300));
    }
    await until(() => tuner.status == TunerStatus.playing, what: 'the channel surfed to');
    await wait(const Duration(seconds: 3));
    final afterSurf = await io(_tunerStreams);
    debugPrint('After surfing: $afterSurf');
    expect(afterSurf.length, lessThanOrEqualTo(1), reason: 'nothing left open but the channel on');

    if (kind == 'm3u') {
      // ---- A provider drop reconnects by itself ----
      final drama = live.firstWhere((c) => c.live!.sourceNumber == (Platform.isAndroid ? '2.1' : '4.1'));
      await tuneLive(drama);
      await wait(const Duration(seconds: 2));
      final dropped = Stopwatch()..start();
      await io(() => _tunerStatus('drop'));
      await until(() => tuner.status != TunerStatus.playing, max: const Duration(seconds: 15), what: 'the drop is seen');
      debugPrint('Dropped: ${tuner.liveMessage}');
      await until(() => tuner.status == TunerStatus.playing, max: const Duration(seconds: 20), what: 'reconnected');
      timings.add('reconnected ${dropped.elapsedMilliseconds} ms after the drop');

      // ---- Rotating stream URLs keep identity ----
      final numbers = {for (final c in live) c.id: c.number};
      await io(() => app.updateChannel(drama, favorite: true));
      await io(() => _tunerStatus('rotate'));
      await io(() => app.refreshLiveNow(source));
      await until(() => !app.live.isRefreshing(source));
      expect(app.live.entryFor(source).channels.firstWhere((c) => c.number == '11.1').url, contains('?t='));
      expect({for (final c in app.channels) if (c.isLive) c.id: c.number}, numbers);
      expect(app.channelById(drama.id)!.favorite, isTrue);

      // ---- A refused stream says so ----
      await io(() => _tunerStatus('refuse?code=458'));
      final h264 = live.firstWhere((c) => c.live!.sourceNumber == '11.1');
      await io(() => tuner.tune(h264));
      await until(() => tuner.status == TunerStatus.error || tuner.status == TunerStatus.standby,
          what: 'the refusal shows');
      debugPrint('Refused: ${tuner.liveMessage}');
      expect(tuner.liveMessage, 'Fake tuner refused the stream. It may be playing on another device.');
      await io(() => _tunerStatus('reset'));
      await until(() => tuner.status == TunerStatus.playing, max: const Duration(seconds: 15), what: 'the retry plays');
    }

    await io(tuner.stop);
    await wait(const Duration(seconds: 2));
    expect(await io(_tunerStreams), isEmpty, reason: 'stopping closes the stream');
    debugPrint('Timings: ${timings.join('; ')}');

    await io(() async {
      await app.removeLiveSource(source);
      await app.close();
    });
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 500));
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
