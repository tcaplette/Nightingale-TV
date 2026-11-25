// SMB shares in the Linux app (smb-sources 10.2), against the Samba test
// shares (tool/test_servers, `up samba`) and the test-data.md Jellyfin:
//
//   SMB_PASSWORD=… JF_URL=… JF_USER=… JF_PASSWORD=… \
//     flutter test integration_test/smb_linux_live_test.dart -d linux
//
// A profile signed in to a share only (history name "Living room", as the
// phone's), then a second share and Jellyfin added. Programs are brought on
// the air by moving their channel's anchor, never waited for. The share
// container is stopped and started again for the failover check.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/server/server_set.dart';
import 'package:nightingale_tv/server/sign_in_flow.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

final _env = Platform.environment;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a profile with shares and Jellyfin, on Linux', (tester) async {
    final password = _env['SMB_PASSWORD'];
    if (password == null || _env['JF_URL'] == null) {
      markTestSkipped('Set SMB_PASSWORD and JF_URL, JF_USER, JF_PASSWORD, with the Samba shares up.');
      return;
    }
    MediaKit.ensureInitialized();
    AppState.serverPingInterval = const Duration(seconds: 5);
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_smb');
    final household = Household(await AppStorage.at(dir));
    late final AppState app;

    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      do {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      } while (DateTime.now().isBefore(end));
    }

    Future<T> io<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    Future<void> refreshed() async {
      await wait(const Duration(milliseconds: 300));
      for (var i = 0; i < 2400 && app.refreshing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
    }

    /// Signs in to [address] (a share) on [flow], maps [types], and finishes.
    Future<void> share(SignInFlow flow, String address, Map<String, SmbFolderType?> types, {String? history}) async {
      await flow.smbConnect(address);
      if (flow.step.stage == SignInStage.smbSignIn) await flow.smbSignIn('smbtest', password);
      expect(flow.step.stage, SignInStage.smbFolders, reason: flow.step.error ?? '');
      for (final e in types.entries) {
        flow.mapSmbFolder(e.key, e.value);
      }
      await flow.finishSmb(historyName: history);
      expect(flow.finished, isTrue, reason: flow.step.error ?? '');
      flow.dispose();
    }

    // ---- A share only, then a second share and Jellyfin ----
    await io(() async {
      await household.start();
      app = household.app!;
      await share(
          SignInFlow(app),
          'smb://127.0.0.1:1445/archive',
          {
            'Names/TV': SmbFolderType.tvShows,
            'Names/Movies': SmbFolderType.movies,
            'Formats': SmbFolderType.movies,
            'Home': SmbFolderType.homeVideos,
          },
          history: 'Living room');
    });
    await refreshed();
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    expect(app.session!.kind, ServerKind.smb);
    await io(() async {
      await share(SignInFlow(app, adding: true), 'smb://127.0.0.1:1445/media', {'Music': SmbFolderType.music, 'Movies': SmbFolderType.movies});
      final found = await identifyServer(_env['JF_URL']!, deviceId: app.settings.installId, deviceName: app.deviceName);
      final client = found.client as JellyfinClient;
      final session = await client.authenticateByName(_env['JF_USER']!, _env['JF_PASSWORD']!, serverName: found.info.name);
      await app.addServer(session.withServerId(found.info.id ?? 'jf'), client, refresh: false);
      await app.refreshLibrary(background: true);
    });
    await refreshed();
    final keys = [for (final s in app.servers.ordered) s.key];
    final archive = app.servers.main.key;
    final media = app.servers.ordered.firstWhere((s) => s.kind == ServerKind.smb && s.key != archive).key;
    final jellyfin = app.servers.ordered.firstWhere((s) => s.kind == ServerKind.jellyfin).key;
    debugPrint('SMB-LINUX servers: ${[for (final s in app.servers.ordered) '${s.key}=${s.name}']}');
    expect(keys, hasLength(3));
    // Every share's files read before the checks.
    await wait(const Duration(seconds: 20));
    await io(() => app.refreshLibrary(background: true));
    await refreshed();

    // ---- History from the phone, through the share ----
    // Nothing has played here yet: what counts as played came from the phone.
    final played = [
      for (final e in [...app.library.episodes, ...app.library.movies])
        if (e.playCount > 0 && ServerSet.keyOf(e.id) == archive) e.title
    ];
    debugPrint('SMB-LINUX played on the phone: $played');
    expect(played, isNotEmpty, reason: 'the phone watched under "Living room"');

    // ---- Guide colours: each server its own ----
    expect(app.guideColorsOn, isTrue);
    final colours = {for (final k in [archive, media, jellyfin]) k: app.serverColors[k]!.name};
    debugPrint('SMB-LINUX colours: $colours');
    expect(colours.values.toSet(), hasLength(3));

    // ---- The TV ----
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    Future<void> playing(String what) async {
      for (var i = 0; i < 120 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
      expect(tuner.status, TunerStatus.playing, reason: '$what: ${tuner.error}');
    }

    /// A channel whose next part matching [want] is brought on the air
    /// [lead] from now, and tuned.
    Future<Channel> onAir(bool Function(ScheduledProgram p) want, {Duration lead = Duration.zero, String what = ''}) async {
      final now = DateTime.now();
      for (final c in app.channels.where((c) => !c.isLive)) {
        final schedule = app.scheduleFor(c);
        if (schedule == null) continue;
        var t = now;
        for (var i = 0; i < 600; i++) {
          final p = schedule.playbackAt(t);
          if (want(p) && p.end.difference(t.isAfter(p.start) ? t : p.start) > const Duration(seconds: 25)) {
            final from = t.isAfter(p.start) ? t : p.start;
            c.anchor = c.anchor.subtract(from.difference(now.add(lead)) + const Duration(seconds: 2));
            await io(() => app.updateChannel(c));
            await io(() => tuner.tune(app.channelById(c.id)!));
            return app.channelById(c.id)!;
          }
          t = p.end;
        }
      }
      throw StateError('Nothing like $what is on any channel');
    }

    bool fromKey(ScheduledProgram p, String key) =>
        p.item != null && !p.isCommercial && !p.isBreak && p.item!.copies.every((x) => ServerSet.keyOf(x.id) == key);

    // A share's program: tune, pause, rewind, live again.
    await onAir((p) => fromKey(p, archive) && p.item!.kind == MediaKind.movie, what: 'an archive movie');
    await playing('a share movie');
    debugPrint('SMB-LINUX playing ${tuner.program?.item?.title} from the share');
    await wait(const Duration(seconds: 4));
    await io(tuner.pause);
    await wait(const Duration(seconds: 3));
    expect(tuner.paused, isTrue);
    await io(tuner.resume);
    await playing('after pause');
    tuner.skip(const Duration(seconds: -10));
    await wait(const Duration(seconds: 4));
    await playing('after Back 10');
    expect(tuner.behind, greaterThan(const Duration(seconds: 5)), reason: 'rewound');
    await io(() => tuner.goLive());
    await playing('live again');

    // Captions: the movie with its subtitle files beside it.
    await onAir((p) => p.item?.title == 'Captions' && ServerSet.keyOf(p.item!.id) == archive, what: 'Captions');
    await playing('Captions');
    await io(() => tuner.setCaptions(true));
    for (var i = 0; i < 40 && (tuner.subtitleTracks?.isEmpty ?? true); i++) {
      await wait(const Duration(milliseconds: 250));
    }
    final tracks = tuner.subtitleTracks ?? const [];
    debugPrint('SMB-LINUX caption tracks: ${[for (final t in tracks) '${t.language} ${t.isExternal ? 'file' : 'inside'}']}');
    expect(tracks.where((t) => t.isExternal).map((t) => t.language), containsAll(['eng', 'spa']));
    await io(() => tuner.pickSubtitle(tracks.firstWhere((t) => t.language == 'spa')));
    await wait(const Duration(seconds: 3));
    await playing('Captions with Spanish captions');
    await io(() => tuner.setCaptions(false));

    // Music from the second share.
    final music = app.channels.where((c) => c.isMusic).toList();
    expect(music, isNotEmpty, reason: "the media share's Music folder");
    await io(() => tuner.tune(music.first));
    await playing('music from a share');
    debugPrint('SMB-LINUX music: ${tuner.program?.item?.title}');

    // Breaks from the share's commercials.
    await io(() => app.setGlobalPlan(BreakPlan.automatic));
    await refreshed();
    final shareAds = app.library.commercials.where((c) => ServerSet.keyOf(c.id) == archive).length;
    expect(shareAds, greaterThan(0), reason: "the archive share's Commercials pool");
    await onAir((p) => p.isCommercial && ServerSet.keyOf(p.item!.id) == archive, lead: const Duration(seconds: 3), what: 'a share commercial');
    for (var i = 0; i < 60 && !(tuner.segment?.isCommercial ?? false); i++) {
      await wait(const Duration(milliseconds: 250));
    }
    await playing('a break');
    expect(tuner.segment?.isCommercial, isTrue);
    debugPrint('SMB-LINUX in a break: ${tuner.segment?.item?.title}');
    await io(() => app.setGlobalPlan(BreakPlan.off));

    // ---- Failover: the shares stopped ----
    // A program on the share and on Jellyfin plays from Jellyfin while the
    // share is down; one on the share only shows no signal; other servers'
    // programs play.
    bool onBoth(ScheduledProgram p) =>
        p.item != null &&
        !p.isCommercial &&
        !p.isBreak &&
        p.item!.copies.any((x) => ServerSet.keyOf(x.id) == archive) &&
        p.item!.copies.any((x) => ServerSet.keyOf(x.id) == jellyfin);
    final both = app.library.movies.where((m) =>
        m.copies.any((x) => ServerSet.keyOf(x.id) == archive) && m.copies.any((x) => ServerSet.keyOf(x.id) == jellyfin));
    debugPrint('SMB-LINUX on the share and Jellyfin: ${both.map((m) => m.title).toList()}');
    // The test clips are small enough for the player to hold all of one, so
    // the shares stop first: a program on both opens from Jellyfin.
    if (both.isEmpty) {
      await onAir((p) => fromKey(p, archive) && p.item!.kind == MediaKind.movie, what: 'an archive movie');
      await playing('before the share stops');
    }
    await io(() => Process.run('sg', ['docker', '-c', 'docker stop nightingale-samba']));
    if (both.isNotEmpty) {
      await onAir(onBoth, what: 'a program on both');
      for (var i = 0; i < 240 && tuner.debugPlayingKey != jellyfin; i++) {
        await wait(const Duration(milliseconds: 500));
      }
      expect(tuner.debugPlayingKey, jellyfin, reason: 'it plays from Jellyfin: ${tuner.error}');
      await playing('failed over to Jellyfin');
      final copies = {for (final m in both) ...m.copies.map((c) => c.id)};
      expect(copies, contains(tuner.segment?.item?.id), reason: 'the same program, its Jellyfin copy');
      expect(app.servers.byKey(archive)!.state, ServerState.unreachable);
      debugPrint('SMB-LINUX failed over to Jellyfin: ${tuner.program?.item?.title}');
    } else {
      for (var i = 0; i < 120 && tuner.status == TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 500));
      }
      expect(tuner.status, isNot(TunerStatus.playing), reason: 'a share-only program shows no signal');
    }
    await onAir((p) => fromKey(p, jellyfin), what: 'a Jellyfin program');
    await playing('Jellyfin with the shares down');
    await io(() => Process.run('sg', ['docker', '-c', 'docker start nightingale-samba']));
    for (var i = 0; i < 240 && app.servers.byKey(archive)!.state != ServerState.ok; i++) {
      await wait(const Duration(milliseconds: 500));
    }
    expect(app.servers.byKey(archive)!.state, ServerState.ok, reason: 'the share answers again');
    await wait(const Duration(seconds: 3));
    await onAir((p) => fromKey(p, archive), what: 'an archive program');
    await playing('the share again');

    // ---- The password: in no file, no process ----
    await io(tuner.stop);
    await io(household.closeAll);
    await io(AppStorage.flushAll);
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final text = String.fromCharCodes(f.readAsBytesSync());
      expect(text.contains(password), isFalse, reason: f.path);
    }
    final ps = await io(() => Process.run('ps', ['-eo', 'args']));
    expect('${ps.stdout}'.contains(password), isFalse, reason: 'a process has the password in its arguments');
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
