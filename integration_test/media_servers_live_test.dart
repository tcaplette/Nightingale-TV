// End-to-end checks against the Emby and Plex test servers
// (tool/test_servers), one at a time:
//
//   EMBY_USER=... EMBY_PASSWORD=... MEDIA_SERVER=emby SNAP_DIR=/tmp/snaps \
//     flutter test integration_test/media_servers_live_test.dart -d linux \
//     --dart-define=NIGHTINGALE_TV_DEBUG_PLAYBACK=1
//   MEDIA_SERVER=plex [PLEX_SESSION=<a session.json, or its JSON, from a link-code sign-in>] ...
//
// Without PLEX_SESSION, Plex is reached as the local test server answers
// this machine (no plex.tv sign-in). Signs in through the address step,
// scans, then: the guide; ten channels by direct play; a pool from the
// Commercials folder (and on Plex, the Trailers collection); a commercial
// break from the analysis; a capped transcode that the server drops when the
// channel changes; an episode watched to its end and marked watched; a song
// that isn't reported; posters and a channel logo.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:nightingale_tv/app_scope.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/main.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/emby_client.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/live_tv.dart';
import 'package:nightingale_tv/server/server_clients.dart';
import 'package:nightingale_tv/ui/guide_view.dart';
import 'package:nightingale_tv/ui/tv_screen.dart';

final _env = Platform.environment;

/// The client the app uses, with a log of what the tuner asks of it.
class Recording implements MediaServer {
  Recording(this.inner);

  final MediaServer inner;
  final log = <String>[];

  @override
  ServerKind get kind => inner.kind;
  @override
  LiveTv? get liveTv => inner.liveTv;
  @override
  String get serverUrl => inner.serverUrl;
  @override
  String get deviceId => inner.deviceId;
  @override
  Map<String, String> get authHeaders => inner.authHeaders;
  @override
  Future<ServerInfo> publicInfo() => inner.publicInfo();
  @override
  Future<void> checkSession() => inner.checkSession();
  @override
  Future<void> logout() => inner.logout();
  @override
  Future<List<ServerLibrary>> libraries() => inner.libraries();
  @override
  Future<LibraryIndex> fetchLibraryIndex(
          {List<CommercialPool> pools = const [],
          Set<String> channelRoots = const {},
          bool providerIds = false,
          void Function(String status)? onStatus,
          void Function(List<ServerLibrary> libraries)? onLibraries}) =>
      inner.fetchLibraryIndex(
          pools: pools, channelRoots: channelRoots, providerIds: providerIds, onStatus: onStatus, onLibraries: onLibraries);
  @override
  Future<List<String>> idsUnder(String rootId) => inner.idsUnder(rootId);
  @override
  Future<List<FolderNode>> folderTree(String libraryId) => inner.folderTree(libraryId);
  @override
  Future<List<MediaSegment>> commercialSegments(String itemId) {
    log.add('segments:$itemId');
    return inner.commercialSegments(itemId);
  }

  @override
  Uri streamUri(String sourceId) {
    log.add('stream:$sourceId');
    return inner.streamUri(sourceId);
  }

  @override
  Uri get pingUri => inner.pingUri;
  @override
  Future<PlaybackDecision> playbackDecision(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero, Map<String, Object?>? profile}) {
    log.add('decide:$itemId@${maxBitrate ?? '-'}');
    return inner.playbackDecision(itemId,
        maxBitrate: maxBitrate, forceTranscode: forceTranscode, startAt: startAt, profile: profile);
  }

  @override
  Future<Uri> transcodeUri(Uri template,
      {required String playSessionId, required Duration startAt, SubtitleTrack? burn}) {
    log.add('transcode:$playSessionId${burn == null ? '' : ' burn:${burn.id}'}');
    return inner.transcodeUri(template, playSessionId: playSessionId, startAt: startAt, burn: burn);
  }

  @override
  Future<List<SubtitleTrack>> subtitleTracks(String itemId) {
    log.add('subtitles:$itemId');
    return inner.subtitleTracks(itemId);
  }

  @override
  Uri? subtitleUri(String itemId, SubtitleTrack track, {Duration startAt = Duration.zero, String? format}) =>
      inner.subtitleUri(itemId, track, startAt: startAt, format: format);

  @override
  bool get transcodeKeepsSourceTime => inner.transcodeKeepsSourceTime;

  @override
  Future<void> stopTranscode(String playSessionId) {
    log.add('stop:$playSessionId');
    return inner.stopTranscode(playSessionId);
  }

  @override
  Future<void> keepTranscodeAlive(String playSessionId) {
    log.add('ping:$playSessionId');
    return inner.keepTranscodeAlive(playSessionId);
  }

  @override
  Future<Duration> resumePoint(String itemId) => inner.resumePoint(itemId);

  @override
  Uri imageUri(String itemId, ImageKind kind, {int? maxHeight, String? tag}) =>
      inner.imageUri(itemId, kind, maxHeight: maxHeight, tag: tag);
  @override
  Future<void> reportPlaybackStart(PlaybackReport report) {
    log.add('start:${report.itemId}');
    return inner.reportPlaybackStart(report);
  }

  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) => inner.reportPlaybackProgress(report);
  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) {
    log.add('stopped:${report.itemId}@${report.position.inSeconds}');
    return inner.reportPlaybackStopped(report);
  }

  @override
  void close() => inner.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final kind = _env['MEDIA_SERVER'];

  testWidgets('a profile on the ${kind ?? '(MEDIA_SERVER unset)'} test server', (tester) async {
    if (kind != 'emby' && kind != 'plex') {
      markTestSkipped('Set MEDIA_SERVER=emby or plex, with that test server up.');
      return;
    }
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('nightingale_tv_servers');
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

    Future<void> snap(String name) async {
      final snapDir = _env['SNAP_DIR'];
      if (snapDir == null) return;
      await tester.pump();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1920 / view.size.width));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      await Directory(snapDir).create(recursive: true);
      await File('$snapDir/$kind-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    }

    // ---- Sign-in, through the address step's identification ----
    await io(() async {
      await household.start();
      app = household.app!;
      final url = _env[kind == 'emby' ? 'EMBY_URL' : 'PLEX_URL'] ??
          (kind == 'emby' ? 'http://127.0.0.1:8096' : 'http://127.0.0.1:32400');
      // A saved Plex sign-in: a session.json's path, or its JSON itself.
      final saved = _env['PLEX_SESSION'];
      if (kind == 'plex' && saved != null) {
        final text = saved.trimLeft().startsWith('{') ? saved : await File(saved).readAsString();
        final session = ServerSession.fromJson(jsonDecode(text) as Map<String, Object?>)
            .withServerUrl(url);
        await app.completeSignIn(session, app.clientForSession(session));
        return;
      }
      final found = await identifyServer(url, deviceId: app.settings.installId, deviceName: app.deviceName);
      expect(found.info.kind.name, kind, reason: 'the address step identifies the server');
      if (kind == 'emby') {
        expect(found.client, isA<EmbyClient>());
        final client = found.client as JellyfinClient;
        expect(await client.quickConnectEnabled(), isFalse);
        final session = await client.authenticateByName(_env['EMBY_USER']!, _env['EMBY_PASSWORD']!, serverName: found.info.name);
        await app.completeSignIn(session, client);
      } else {
        found.client.close();
        // The local test server, as it answers this machine without a token.
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
      }
    });
    expect(app.phase, AppPhase.ready, reason: app.syncError ?? '');
    final inner = app.client!;
    final server = Recording(inner);
    app.client = server;
    final lib = app.library;
    debugPrint('Index: ${lib.series.length} shows, ${lib.episodes.length} episodes, ${lib.movies.length} movies, '
        '${lib.songs.length} songs, ${lib.musicVideos.length} music videos; ${app.channels.length} channels');
    expect(lib.episodes, hasLength(24));
    expect(lib.series.map((s) => s.name).toSet(), {'Maple Street', 'Signal Hill', 'Night Desk'});
    expect(lib.movies, hasLength(6), reason: '2 movies and 4 subtitle test movies');
    expect(lib.songs, hasLength(30));
    expect(lib.musicVideos, hasLength(6));
    expect(lib.episodes.where((e) => e.chapters.length >= 3), hasLength(24), reason: 'every episode has its acts');
    expect(lib.series.firstWhere((s) => s.name == 'Maple Street').hasLogo, isTrue);
    expect(app.channels.where((c) => c.isMusic), isNotEmpty, reason: 'music channels');

    // Server-side checks, outside the app.
    final http.Client web = http.Client();
    Future<Map<String, Object?>> getJson(String path) async {
      final r = await web.get(Uri.parse('${inner.serverUrl}$path'), headers: {...inner.authHeaders, 'Accept': 'application/json'});
      expect(r.statusCode, 200, reason: path);
      return jsonDecode(r.body) as Map<String, Object?>;
    }

    final embyUser = kind == 'emby' ? app.session!.userId : null;
    Future<int> playCount(String id) async {
      if (kind == 'emby') {
        final item = await getJson('/Users/$embyUser/Items/$id');
        return ((item['UserData'] as Map?)?['PlayCount'] as num?)?.toInt() ?? 0;
      }
      final m = ((await getJson('/library/metadata/$id'))['MediaContainer'] as Map)['Metadata'] as List;
      return ((m.first as Map)['viewCount'] as num?)?.toInt() ?? 0;
    }

    Future<bool> watched(String id) async {
      if (kind == 'emby') {
        return ((await getJson('/Users/$embyUser/Items/$id'))['UserData'] as Map?)?['Played'] == true;
      }
      return await playCount(id) > 0;
    }

    /// Conversions running on the server: Emby's ffmpeg processes in the
    /// test container (its session list fills in late), Plex's transcode
    /// sessions.
    Future<int> transcodesOnServer({String? session}) async {
      if (kind == 'emby') {
        final r = await Process.run('sg', [
          'docker',
          '-c',
          'docker exec nightingale-emby sh -c "ps -o args | grep -v EmbyServer | grep -c [f]fmpeg"',
        ]);
        return int.tryParse('${r.stdout}'.trim()) ?? 0;
      }
      final c = (await getJson('/transcode/sessions'))['MediaContainer'] as Map;
      return [
        for (final t in (c['TranscodeSession'] as List? ?? const []).cast<Map<String, Object?>>())
          if (session == null || t['key'] == session) t
      ].length;
    }

    /// [transcodesOnServer] once it meets [ok], within ten seconds.
    Future<int> settled(bool Function(int n) ok, {String? session}) async {
      var n = await io(() => transcodesOnServer(session: session));
      for (var i = 0; i < 10 && !ok(n); i++) {
        await wait(const Duration(seconds: 1));
        n = await io(() => transcodesOnServer(session: session));
      }
      return n;
    }

    // ---- Posters and a channel logo ----
    final maple = lib.series.firstWhere((s) => s.name == 'Maple Street');
    for (final (what, uri) in [
      ('logo', inner.imageUri(maple.id, ImageKind.logo, maxHeight: 160)),
      ('poster', inner.imageUri(maple.id, ImageKind.primary, maxHeight: 640)),
    ]) {
      final r = await io(() => web.get(uri, headers: inner.authHeaders));
      debugPrint('Maple Street $what: ${r.statusCode} ${r.headers['content-type']} ${r.bodyBytes.length} bytes');
      expect(r.statusCode, 200, reason: 'the show\'s $what');
      expect(r.headers['content-type'], startsWith('image/'));
    }

    // ---- Commercial pools ----
    final libraries = await io(inner.libraries);
    final home = libraries.firstWhere((l) => l.name == 'Home Videos');
    final tree = await io(() => inner.folderTree(home.id));
    FolderNode? named(List<FolderNode> nodes, String name) {
      for (final n in nodes) {
        if (n.name == name) return n;
        if (named(n.children, name) case final inside?) return inside;
      }
      return null;
    }

    final folder = named(tree, 'Commercials');
    expect(folder, isNotNull, reason: 'the Commercials folder is offered: ${tree.map((n) => n.name)}');
    final pool = await io(app.createPool);
    await io(() => app.setPoolRoots(pool, [PoolRoot(itemId: folder!.id, libraryId: home.id, label: 'Home Videos › Commercials')]));
    for (var i = 0; i < 600 && (app.refreshing || app.library.commercials.isEmpty); i++) {
      await wait(const Duration(milliseconds: 500));
    }
    expect(app.library.commercials, hasLength(41), reason: '40 clips and a reel');
    expect(app.library.movies, hasLength(6), reason: 'the pool\'s videos are no longer programs');
    if (kind == 'plex') {
      final trailers = tree.firstWhere((n) => n.type == 'BoxSet' && n.name == 'Trailers');
      final second = await io(app.createPool);
      await io(() => app.setPoolRoots(second, [PoolRoot(itemId: trailers.id, libraryId: home.id, label: 'Trailers')]));
      for (var i = 0; i < 600 && app.refreshing; i++) {
        await wait(const Duration(milliseconds: 500));
      }
      expect(app.library.commercials.where((c) => c.poolIds.contains(second.id)), hasLength(20),
          reason: 'the Trailers collection is a pool of 20');
    }
    // The reel splits at its black, silent gaps.
    for (var i = 0; i < 600 && app.analysisProgress.value.reelsDone < 1; i++) {
      await wait(const Duration(seconds: 1));
    }
    final reel = app.library.commercials.firstWhere((c) => c.runtime > LibraryIndex.maxClip);
    final cuts = [for (final c in app.catalog.clipsFor(pool.id)) if (c.sourceId == reel.id) c];
    debugPrint('Reel split into ${cuts.length} clips: ${[for (final c in cuts) c.runtime.inSeconds]}');
    expect(cuts.length, inInclusiveRange(6, 9));
    final reelPlays = await io(() => playCount(reel.id));

    // ---- The guide, and ten channels by direct play ----
    await tester.pumpWidget(NightingaleTvApp(household: household));
    await wait(const Duration(seconds: 2));
    final tuner = AppScope.tunerOf(tester.element(find.byType(TvScreen)));
    // The TV powers on to a channel; keys work once it plays.
    for (var i = 0; i < 60 && tuner.status != TunerStatus.playing; i++) {
      await wait(const Duration(milliseconds: 250));
    }
    expect(tuner.status, TunerStatus.playing, reason: 'the launch tune: ${tuner.error}');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await wait(const Duration(seconds: 2));
    expect(find.byType(GuideView), findsOneWidget);
    await snap('guide');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(const Duration(seconds: 1));

    Future<void> tuneAndPlay(Channel ch) async {
      await io(() => tuner.tune(ch));
      for (var i = 0; i < 60 && tuner.status != TunerStatus.playing; i++) {
        await wait(const Duration(milliseconds: 250));
      }
      expect(tuner.status, TunerStatus.playing, reason: '${ch.name}: ${tuner.error}');
    }

    server.log.clear();
    // The test library makes only a few channels: ten tunes, around them.
    final ten = [for (var i = 0; i < 10; i++) app.channels[i % app.channels.length]];
    for (final ch in ten) {
      await tuneAndPlay(ch);
      await wait(const Duration(seconds: 2));
    }
    await snap('direct-play');
    debugPrint('Ten channels: ${server.log.where((l) => !l.startsWith('segments')).join(' ')}');
    expect(server.log.where((l) => l.startsWith('decide') || l.startsWith('transcode') || l.startsWith('stop:')), isEmpty,
        reason: 'direct play asks for no decision or conversion');
    expect(server.log.where((l) => l.startsWith('stream:')), isNotEmpty);
    expect(server.log.where((l) => l.startsWith('segments:')), kind == 'emby' ? isEmpty : anything,
        reason: 'Emby has no media segments to ask for');

    // ---- A song isn't reported ----
    final music = app.channels.firstWhere((c) => c.isMusic && app.scheduleFor(c)!.playbackAt(DateTime.now()).item?.kind == MediaKind.song,
        orElse: () => app.channels.firstWhere((c) => c.isMusic));
    final song = app.scheduleFor(music)!.playbackAt(DateTime.now()).item!;
    final songPlays = await io(() => playCount(song.id));
    server.log.clear();
    await tuneAndPlay(music);
    await wait(const Duration(seconds: 8));
    await io(() => tuner.tune(ten.first));
    await wait(const Duration(seconds: 3));
    expect(server.log.where((l) => l.endsWith(':${song.id}') || l.contains(':${song.id}@')), everyElement(startsWith('stream:')),
        reason: '${song.title} is played but never reported');
    expect(await io(() => playCount(song.id)), songPlays);

    // ---- A commercial break from the analysis ----
    await io(() => app.setGlobalPlan(BreakPlan.automatic));
    final now = DateTime.now();
    var best = (channel: app.channels.first, at: now.add(const Duration(days: 1)));
    for (final ch in app.channels) {
      final schedule = app.scheduleFor(ch);
      if (schedule == null || !app.breaksFor(ch)) continue;
      var t = now;
      for (var i = 0; i < 40; i++) {
        final p = schedule.playbackAt(t);
        if (p.isCommercial && p.end.difference(now) > const Duration(seconds: 20)) {
          final at = p.start.isAfter(now) ? p.start : now;
          if (at.isBefore(best.at)) best = (channel: ch, at: at);
          break;
        }
        t = p.end;
      }
    }
    debugPrint('Next break on ${best.channel.name} at ${best.at}');
    await tuneAndPlay(best.channel);
    while (!tuner.inBreak || !tuner.segment!.isCommercial) {
      await wait(const Duration(seconds: 1));
      expect(DateTime.now().isBefore(best.at.add(const Duration(minutes: 2))), isTrue, reason: 'the break came');
    }
    for (var i = 0; i < 40 && tuner.status != TunerStatus.playing; i++) {
      await wait(const Duration(milliseconds: 250));
    }
    expect(tuner.status, TunerStatus.playing, reason: 'the clip plays: ${tuner.error}');
    await snap('break');
    debugPrint('In a break: ${tuner.segment!.item!.title}');

    // ---- A capped transcode, dropped when the channel changes ----
    await io(() => app.setPlayback(app.settings.playback.copyWith(transcodeIfNeeded: true, bitrate: PlaybackSettings.presets.last)));
    // Brings the next Maple Street part (the one show over the cap) on the
    // air now, by moving its channel's anchor, rather than waiting for it.
    Channel bringMapleOnAir() {
      final now = DateTime.now();
      for (final c in app.channels.where((c) => !c.isMusic)) {
        final schedule = app.scheduleFor(c)!;
        var t = now;
        for (var i = 0; i < 400; i++) {
          final p = schedule.playbackAt(t);
          final from = t.isAfter(p.start) ? t : p.start;
          if (!p.isCommercial && p.item?.seriesName == 'Maple Street' && p.end.difference(from) > const Duration(seconds: 90)) {
            c.anchor = c.anchor.subtract(from.add(const Duration(seconds: 5)).difference(now));
            return c;
          }
          t = p.end;
        }
      }
      throw StateError('Maple Street is on no channel');
    }

    final mapleChannel = bringMapleOnAir();
    await io(() => app.updateChannel(mapleChannel));
    server.log.clear();
    await tuneAndPlay(mapleChannel);
    await wait(const Duration(seconds: 4));
    final playing = tuner.segment!;
    debugPrint('Capped on ${mapleChannel.name}: ${playing.item!.title} — ${server.log.join(' ')}');
    if (playing.item!.seriesName == 'Maple Street' && !playing.isCommercial) {
      expect(server.log.where((l) => l.startsWith('decide:') && l.endsWith('@4000000')), isNotEmpty);
      expect(server.log.where((l) => l.startsWith('transcode:')), isNotEmpty, reason: 'the 5 Mbps show converts under 4 Mbps');
      expect(await settled((n) => n > 0), greaterThan(0), reason: 'the server is converting');
      await snap('transcode');
      await io(() => tuner.tune(app.channels.firstWhere((c) => c != mapleChannel)));
      await wait(const Duration(seconds: 5));
      expect(server.log.where((l) => l.startsWith('stop:')), isNotEmpty);
      // Emby: none left (the next channel plays directly). Plex: the stopped
      // job is gone (Plex may convert the next channel by its own rules).
      final job = server.log.firstWhere((l) => l.startsWith('transcode:')).substring('transcode:'.length);
      expect(await settled((n) => n == 0, session: kind == 'plex' ? job : null), 0,
          reason: 'the server dropped the conversion');
    } else {
      fail('Maple Street was not on the air on ${mapleChannel.name} (${playing.item?.title})');
    }
    await io(() => app.setPlayback(app.settings.playback.copyWith(transcodeIfNeeded: false)));

    // ---- An episode watched to its end ----
    ({Channel channel, MediaEntry item, DateTime end})? soonest;
    final at = DateTime.now();
    for (final ch in app.channels.where((c) => !c.isMusic)) {
      final schedule = app.scheduleFor(ch)!;
      final p = schedule.playbackAt(at);
      final item = p.item;
      if (p.isCommercial || item == null || item.kind != MediaKind.episode) continue;
      var t = p.end;
      var end = p.end;
      for (var i = 0; i < 20; i++) {
        final next = schedule.playbackAt(t);
        if (next.item?.id != item.id && !next.isCommercial) break;
        if (next.item?.id == item.id) end = next.end;
        t = next.end;
      }
      if (soonest == null || end.isBefore(soonest.end)) soonest = (channel: ch, item: item, end: end);
    }
    expect(soonest, isNotNull);
    debugPrint('Watching ${soonest!.item.seriesName} ${soonest.item.subtitle} on ${soonest.channel.name} to ${soonest.end}');
    // Unwatched first: an earlier run may have watched it.
    await io(() async {
      final id = soonest!.item.id;
      final r = kind == 'emby'
          ? await web.delete(Uri.parse('${inner.serverUrl}/Users/$embyUser/PlayedItems/$id'), headers: inner.authHeaders)
          : await web.get(Uri.parse('${inner.serverUrl}/:/unscrobble?key=$id&identifier=com.plexapp.plugins.library'),
              headers: inner.authHeaders);
      expect(r.statusCode, lessThan(300), reason: 'marking it unwatched');
    });
    final wasWatched = await io(() => watched(soonest!.item.id));
    server.log.clear();
    await tuneAndPlay(soonest.channel);
    await wait(soonest.end.difference(DateTime.now()) + const Duration(seconds: 8));
    debugPrint('Reports: ${server.log.where((l) => !l.startsWith('stream') && !l.startsWith('segments')).join(' ')}');
    expect(wasWatched, isFalse);
    expect(await io(() => watched(soonest!.item.id)), isTrue, reason: 'the episode played to its end is watched');
    expect(await io(() => playCount(reel.id)), reelPlays, reason: 'commercials are never reported');

    await io(() async {
      await tuner.stop();
      await app.close();
    });
    await tester.pumpWidget(const SizedBox());
    await wait(const Duration(milliseconds: 500));
    web.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 40)));
}
