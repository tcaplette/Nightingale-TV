// Subtitles on a real server (subtitle-access 6.2–6.4): the four subtitle
// test movies (tool/test_servers/make_media.sh) on one channel, the Captions
// picker worked with the D-pad, and the cues the player really shows.
//
// On the Android TV emulator, with one Docker test server up:
//   flutter test integration_test/subtitles_live_test.dart -d emulator-5554 \
//     --dart-define=SUB_SERVER=emby --dart-define=SUB_URL=http://10.0.2.2:8096 \
//     --dart-define=SUB_USER=… --dart-define=SUB_PW=…
// SUB_SERVER is jellyfin, emby or plex (the unclaimed Docker Plex needs no
// user). On Linux the same variables come from the environment.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/exo_tuner_player.dart';
import 'package:nightingale_tv/playback/playback_diagnostics.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

/// From the environment, or on a device from --dart-define.
final _env = <String, String?>{
  ...Platform.environment,
  for (final (k, v) in const [
    ('SUB_SERVER', String.fromEnvironment('SUB_SERVER')),
    ('SUB_URL', String.fromEnvironment('SUB_URL')),
    ('SUB_USER', String.fromEnvironment('SUB_USER')),
    ('SUB_PW', String.fromEnvironment('SUB_PW')),
  ])
    if (v != '') k: v,
};

// ignore: avoid_print
void _say(String s) => print('${DateTime.now().toIso8601String()} SUBTEST $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final kind = _env['SUB_SERVER'];

  testWidgets('subtitles on the ${kind ?? '(SUB_SERVER unset)'} test server', (tester) async {
    if (!const {'jellyfin', 'emby', 'plex'}.contains(kind)) {
      markTestSkipped('Set SUB_SERVER (jellyfin, emby or plex) and SUB_URL, with that test server up.');
      return;
    }
    if (!Platform.isAndroid) MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_subtitles_live');
    var household = Household(await AppStorage.at(dir), runAnalysis: false);
    late AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<void> snap(String name) async {
      final snapDir = _env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image =
          await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await File('$snapDir/$kind-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    // ---- Sign in ---------------------------------------------------------------
    final url = _env['SUB_URL']!;
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
      final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
      if (kind == 'plex') {
        found.client.close();
        // The unclaimed Docker Plex, as it answers the emulator.
        final session = ServerSession(
          kind: ServerKind.plex,
          serverUrl: url,
          serverName: found.info.name,
          serverId: found.info.id,
          userId: 'local',
          userName: 'local',
          accessToken: '',
          deviceId: app.settings.installId,
        );
        await app.completeSignIn(session, app.clientForSession(session));
      } else {
        final client = found.client as JellyfinClient;
        await app.completeSignIn(
            await client.authenticateByName(_env['SUB_USER']!, _env['SUB_PW']!, serverName: found.info.name), client);
      }
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');

    // ---- A channel of the four subtitle movies, no breaks -----------------------
    MediaEntry movie(String name) => app.library.movies.firstWhere((m) => m.title.contains('Sub Test $name'));
    final embedded = movie('Embedded'), external = movie('External'), byDefault = movie('Default');
    final converts = movie('Transcode');
    final movies = (await tester.runAsync(app.client!.libraries))!.firstWhere((l) => l.name == 'Movies');
    await tester.runAsync(() => app.setGlobalPlan(BreakPlan.off));
    final ch = (await tester.runAsync(() => app.createCustomChannel('Subtitles',
        ChannelSource(roots: [PoolRoot(itemId: movies.id, libraryId: movies.id, label: 'Movies')], includeMovies: true),
        order: PlaybackOrder.cyclic)))!;
    ch.playlist = [embedded.id, external.id, byDefault.id, converts.id];
    await tester.runAsync(() => app.updateChannel(ch));

    /// The first airing of [item] from now on [ch].
    ScheduledProgram airing(MediaEntry item) {
      final s = app.scheduleFor(ch)!;
      var seg = s.playbackAt(DateTime.now());
      for (var i = 0; i < 500; i++) {
        if (seg.item?.id == item.id) return seg;
        seg = s.playbackAt(seg.end);
      }
      throw StateError('${item.title} not on ${ch.name}');
    }

    /// Moves the schedule so [item] has been on for [into] now.
    Future<ScheduledProgram> joinAt(MediaEntry item, Duration into) async {
      final seg = airing(item);
      ch.anchor = ch.anchor.add(DateTime.now().subtract(into).difference(seg.start));
      ch.slotCarry = null;
      await tester.runAsync(() => app.updateChannel(ch));
      return airing(item).start.isAfter(DateTime.now()) ? airing(item) : app.scheduleFor(ch)!.playbackAt(DateTime.now());
    }

    late Tuner tuner;
    Future<void> showApp() async {
      await tester.pumpWidget(NightingaleTvApp(household: household));
      await wait(const Duration(seconds: 2));
      tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    }

    /// The cue text on screen now.
    String cues() {
      final media = tuner.media;
      if (media is ExoTunerPlayer) return media.cues.value.text.join(' / ');
      if (media is MediaKitTunerPlayer) return media.player.state.subtitle.where((l) => l.isNotEmpty).join(' / ');
      return '';
    }

    /// Waits up to [within] for a cue reading [track] and "<n>s" with n within
    /// 15 s of [at] (where in the item the picture is).
    Future<String> cueOf(String track, {required Duration Function() at, Duration within = const Duration(seconds: 20)}) async {
      final end = DateTime.now().add(within);
      var seen = '';
      while (DateTime.now().isBefore(end)) {
        await wait(const Duration(milliseconds: 250));
        seen = cues();
        final m = RegExp('$track (\\d+)s').firstMatch(seen);
        if (m != null) {
          final secs = int.parse(m.group(1)!);
          final want = at().inSeconds;
          if ((secs - want).abs() <= 15) return seen;
          _say('cue "$seen" but the picture is at ${want}s');
        }
      }
      fail('no "$track" cue in time within $within (saw "$seen", status ${tuner.status.name} ${tuner.error ?? ''})');
    }

    Duration itemPosition() => tuner.segment!.positionAt(DateTime.now());

    // A remote's OK; Enter on a computer (the desktop key map has no Select).
    final ok = Platform.isAndroid ? LogicalKeyboardKey.select : LogicalKeyboardKey.enter;

    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await wait(const Duration(milliseconds: 400));
    }

    Future<void> playing() async {
      for (var i = 0; i < 200 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 100));
      }
      expect(tuner.status, TunerStatus.playing, reason: tuner.error ?? '');
    }

    // ---- 6.3: captions off, surfing asks for no subtitles ----------------------
    // (A diagnostics run logs every server request between these marks.)
    await showApp();
    PlaybackDiagnostics.note('SUBTEST', 'surf start');
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(tuner.channelUp);
      await wait(const Duration(milliseconds: 1500));
    }
    PlaybackDiagnostics.note('SUBTEST', 'surf end');
    _say('surfed 10 channels with captions off');
    expect(tuner.shownSubtitle, isNull);

    // ---- 6.2: the not-default embedded track, by D-pad only ---------------------
    await joinAt(embedded, const Duration(minutes: 2));
    await tester.runAsync(() => tuner.tune(ch));
    await playing();
    expect(tuner.captions, isFalse);
    expect(tuner.segment?.item?.id, embedded.id);
    // Right shows the row, Up reaches Guide; Menu, Sleep, then Captions.
    for (final k in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      ok,
    ]) {
      await key(k);
    }
    await wait(const Duration(seconds: 2));
    expect(find.text('Spanish'), findsOneWidget, reason: 'the picker lists the tracks');
    await snap('picker');
    // Off (focused), English, Spanish.
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    final picked = DateTime.now();
    await key(ok);
    final seen = await cueOf('EMBEDDED SPANISH', at: itemPosition);
    _say('embedded Spanish after ${DateTime.now().difference(picked).inMilliseconds} ms: "$seen"');
    expect(DateTime.now().difference(picked), lessThan(const Duration(seconds: 3)));
    expect((app.settings.playback.captions, app.settings.playback.captionLanguage), (true, 'spa'));
    await snap('embedded-spanish');

    // ---- The next program: captions stay on, by the saved language ------------
    // Tuned in 15 s before Embedded ends; the next one is handed over to.
    final length = airing(embedded).duration;
    await joinAt(embedded, length - const Duration(seconds: 15));
    await tester.runAsync(() => tuner.tune(ch));
    await playing();
    await wait(const Duration(seconds: 22));
    final next = tuner.segment?.item?.id;
    _say('next program: ${tuner.segment?.title}');
    expect(next, isNot(embedded.id));
    expect(tuner.captions, isTrue);
    final cueOfNext = {
      external.id: 'EXTERNAL SIDECAR',
      byDefault.id: 'EMBEDDED DEFAULT',
      if (kind != 'plex') converts.id: 'EMBEDDED TRANSCODE',
    }[next];
    if (cueOfNext != null) _say('next: ${await cueOf(cueOfNext, at: itemPosition, within: const Duration(seconds: 30))}');

    // ---- The external sidecar, mid-program ----------------------------------------
    await joinAt(external, const Duration(minutes: 2, seconds: 30));
    await tester.runAsync(() => tuner.tune(ch));
    await playing();
    _say('external: ${await cueOf('EXTERNAL SIDECAR', at: itemPosition)}');
    await snap('external');

    // ---- The default-flagged track, mid-program -----------------------------------
    await joinAt(byDefault, const Duration(minutes: 3));
    await tester.runAsync(() => tuner.tune(ch));
    await playing();
    _say('default: ${await cueOf('EMBEDDED DEFAULT', at: itemPosition)}');

    // ---- 6.4: converted (HEVC Main10 on a device without a 10-bit decoder) ------
    await joinAt(converts, const Duration(minutes: 4));
    await tester.runAsync(() => tuner.tune(ch));
    await playing();
    _say('converted: converting=${tuner.converting}');
    if (Platform.isAndroid) expect(tuner.converting, isTrue, reason: 'no 10-bit HEVC decoder on the emulator');
    if (kind == 'plex' && tuner.converting) {
      // Plex hands out no track inside the file: it's burned into the
      // picture, which has no cues to read.
      await wait(const Duration(seconds: 8));
      final sessions = await tester.runAsync(() async {
        final c = HttpClient();
        try {
          final r = await (await c.getUrl(Uri.parse('$url/transcode/sessions'))
                ..headers.set('Accept', 'application/json'))
              .close();
          return await r.transform(const SystemEncoding().decoder).join();
        } finally {
          c.close();
        }
      });
      _say('plex transcode sessions: $sessions');
      expect(sessions, contains('"subtitleDecision":"burn"'));
      // The first open (before the track list came) is stopped, not left
      // converting on the server.
      expect(RegExp('"key":').allMatches(sessions!), hasLength(1), reason: 'one conversion on the server');
      await snap('converted-burned');
      // SUB_HOLD: time to look at the burned picture (adb screencap).
      if (const String.fromEnvironment('SUB_HOLD') != '') await wait(const Duration(seconds: 20));
    } else {
      _say('converted: ${await cueOf('EMBEDDED TRANSCODE', at: itemPosition, within: const Duration(seconds: 30))}');
      await snap('converted');
    }

    // ---- 6.2: after a restart, captions are on and Spanish shows ----------------
    await tester.runAsync(() async {
      await tuner.stop();
      await household.app?.close();
    });
    await tester.pumpWidget(const SizedBox());
    household = Household(await tester.runAsync(() => AppStorage.at(dir)) as AppStorage, runAnalysis: false);
    await tester.runAsync(() async {
      await household.start();
      app = household.app!;
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    expect((app.settings.playback.captions, app.settings.playback.captionLanguage), (true, 'spa'));
    final again = app.channels.firstWhere((c) => c.name == 'Subtitles');
    final s = app.scheduleFor(again)!;
    var seg = s.playbackAt(DateTime.now());
    for (var i = 0; i < 500 && seg.item?.id != embedded.id; i++) {
      seg = s.playbackAt(seg.end);
    }
    again.anchor = again.anchor.add(DateTime.now().subtract(const Duration(minutes: 5)).difference(seg.start));
    again.slotCarry = null;
    await tester.runAsync(() => app.updateChannel(again));
    await showApp();
    await tester.runAsync(() => tuner.tune(again));
    await playing();
    _say('after restart: ${await cueOf('EMBEDDED SPANISH', at: itemPosition)}');
    await snap('restart');

    await tester.runAsync(() async {
      await tuner.stop();
      await household.app?.close();
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
