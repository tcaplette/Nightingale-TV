import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/convert/conversion_jobs.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_history.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_open.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

/// A share as a server, against the Samba test shares (tool/test_servers):
/// `SMB_LIVE=1 SMB_PASSWORD=… flutter test test/smb/smb_server_live_test.dart`.
final _live = Platform.environment['SMB_LIVE'] == '1';
final _password = Platform.environment['SMB_PASSWORD'] ?? '';
final _formats =
    Platform.environment['NIGHTINGALE_TEST_SMB_MEDIA'] ?? '${Platform.environment['HOME']}/.cache/nightingale-test-smb-media';

void main() {
  late Directory dir;
  late AppStorage storage;
  late SmbProfile profile;
  late SmbServer server;
  final ready = <bool>[];

  setUpAll(() async {
    if (!_live) return;
    IndexBuilder.useIsolate = false;
    // This test's own history from earlier runs; other devices' history on
    // the share (a phone's, a TV's) is theirs and stays.
    for (final name in ['Mom', 'Kids']) {
      final old = Directory('$_formats/${SmbHistory.folderFor(name)}');
      if (old.existsSync()) old.deleteSync(recursive: true);
    }
    dir = await Directory.systemTemp.createTemp('smb_server');
    storage = await AppStorage.at(Directory('${dir.path}/profile'),
        logosDir: Directory('${dir.path}/logos'), analysisDir: Directory('${dir.path}/analysis'));
    profile = SmbProfile(storage,
        profileName: () => 'Mom',
        hold: ValueNotifier(false),
        onFilesReady: (s, {required last}) => ready.add(last),
        onChanged: () {});
    final ref = await profile.secrets.put(SmbCredentials(user: 'smbtest', password: _password));
    const id = 'live-archive';
    profile.configOf(id).mappings = const [
      SmbMapping('Names/TV', SmbFolderType.tvShows),
      SmbMapping('Names/Movies', SmbFolderType.movies),
      SmbMapping('Formats', SmbFolderType.movies),
      SmbMapping('Home', SmbFolderType.homeVideos),
      SmbMapping('Commercials', SmbFolderType.commercials),
      SmbMapping('Bumpers', SmbFolderType.bumpers),
    ];
    await profile.saveConfig(id);
    await SmbGateway.ensureStarted();
    server = profile.client(ServerSession(
      kind: ServerKind.smb,
      serverUrl: 'smb://127.0.0.1:1445/archive',
      serverName: 'archive on 127.0.0.1',
      serverId: id,
      userId: 'smbtest',
      userName: 'smbtest',
      accessToken: ref,
      deviceId: 'dev',
    ));
  });

  tearDownAll(() async {
    if (!_live) return;
    server.close();
    await storage.flush();
    await SmbGateway.stop();
    await dir.delete(recursive: true);
  });

  final commercials = CommercialPool(id: 'pool', name: 'Commercials', roots: [
    PoolRoot(itemId: smbIdOf('Commercials/'), libraryId: smbIdOf('Commercials/'), label: 'Commercials'),
  ]);

  late LibraryIndex index;

  test('a scan indexes names, .nfo files, shows, movies and home videos', () async {
    index = await server.fetchLibraryIndex(pools: [commercials]);
    // Every video file of the share was read (and Can't play worked out)
    // before the second build.
    while (!ready.contains(true)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    server.rebuildNext();
    index = await server.fetchLibraryIndex(pools: [commercials]);
    MediaEntry episode(String show, int season, int number) =>
        index.episodes.firstWhere((e) => e.seriesName == show && e.season == season && e.episode == number);
    final showA = index.series.firstWhere((s) => s.name == 'Show A');
    expect((showA.year, showA.officialRating), (2001, 'TV-PG'));
    expect(showA.genres, ['Drama']);
    expect(showA.providerIds, ['tvdb:4242']);
    expect(showA.hasLogo, isTrue);
    expect(episode('Show A', 2, 3).title, 'The Third One');
    expect(episode('Show A', 2, 4).title, 'Episode 4 / Episode 5');
    expect(index.episodes.where((e) => e.seriesName == 'Show A' && e.episode == 5), isEmpty);
    expect(episode('Show A', 2, 6).title, 'Episode 6');
    expect(episode('Show B', 1, 2).title, 'The Second');
    expect(episode('Daily Show', 2024, 501).title, 'Monday Guest');
    expect(index.series.firstWhere((s) => s.name == 'Daily Show').providerIds, ['tvdb:71256']);
    expect(episode('Show C', 1, 1).title, 'Pilot');
    expect(index.episodes.where((e) => e.title.contains('Interview') || e.title.contains('Nope') || e.title == 'sample'), isEmpty);
    final movies = {for (final m in index.movies) m.title: m};
    expect(movies['Heat']!.providerIds, ['tmdb:949']);
    expect(movies['Heat']!.year, 1995);
    expect((movies['A Described Movie']!.year, movies['A Described Movie']!.officialRating), (1988, 'PG-13'));
    expect(movies['A Described Movie']!.genres, ['Comedy', 'Family']);
    expect(movies['Broken Info']!.year, 2003);
    expect(movies.keys, containsAll(['Alien', 'Yearless Movie', 'Captions', 'Windows Media', 'DivX Movie', 'Old Disc', 'Lossless TrueHD']));
    expect(movies.keys, isNot(contains('Captions trailer')));
    // Nothing of a file nobody can read is scheduled.
    expect(movies.keys, isNot(contains('Cut Off')));
    expect(movies.keys, isNot(contains('Sound Only')));
    // Home videos: each folder a show, never merged by name.
    final summer = index.episodes.where((e) => e.seriesName == 'Summer 2019').toList();
    expect(summer, hasLength(5));
    expect(summer.every((e) => e.isHome && e.episode == null), isTrue);
    // Commercials fill breaks and never air.
    expect(index.commercials.map((c) => c.title), containsAll(['Soda Spot 1', 'Old Spot 1', 'Old Spot 2']));
    expect(index.commercials.every((c) => c.poolIds.contains('pool')), isTrue);
    expect([...index.movies, ...index.episodes].where((e) => e.title.startsWith('Soda Spot')), isEmpty);
    expect(index.commercials.firstWhere((c) => c.title == 'Soda Spot 1').runtime.inMilliseconds, closeTo(20000, 100));
    // Lengths and chapters come from reading the files.
    expect(movies['Heat']!.runtime.inMilliseconds, closeTo(60000, 100));
    expect(ready, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 4)), skip: !_live);

  test('item ids are the same on every device and say nothing of the path', () async {
    final heat = index.movies.firstWhere((m) => m.title == 'Heat');
    expect(heat.id, smbIdOf('Names/Movies/Heat (1995) {tmdb-949}/Heat.mkv'));
    expect(heat.id, isNot(contains('Heat')));
    expect(heat.id, isNot(contains('~')));
  }, skip: !_live);

  test('the gateway serves files, ranges, images and subtitles', () async {
    final heat = index.movies.firstWhere((m) => m.title == 'Heat');
    final local = File('$_formats/Names/Movies/Heat (1995) {tmdb-949}/Heat.mkv');
    final client = HttpClient();
    addTearDown(client.close);
    Future<(int, List<int>, HttpHeaders)> get(Uri uri, {String? range, String method = 'GET'}) async {
      final r = await client.openUrl(method, uri);
      if (range != null) r.headers.set(HttpHeaders.rangeHeader, range);
      final a = await r.close();
      return (a.statusCode, await a.fold<List<int>>([], (b, c) => b..addAll(c)), a.headers);
    }

    final whole = await get(server.streamUri(heat.id));
    expect(whole.$1, 200);
    expect(sha1.convert(whole.$2), sha1.convert(await local.readAsBytes()));
    final part = await get(server.streamUri(heat.id), range: 'bytes=1000-2999');
    expect((part.$1, part.$2.length), (206, 2000));
    expect(part.$3.value(HttpHeaders.contentRangeHeader), 'bytes 1000-2999/${local.lengthSync()}');
    expect(part.$2, (await local.readAsBytes()).sublist(1000, 3000));
    final tail = await get(server.streamUri(heat.id), range: 'bytes=-100');
    expect(tail.$2.length, 100);
    expect((await get(server.streamUri(heat.id), range: 'bytes=99999999-')).$1, 416);
    final head = await get(server.streamUri(heat.id), method: 'HEAD');
    expect((head.$1, head.$3.contentLength, head.$2.length), (200, local.lengthSync(), 0));
    expect((await get(server.streamUri('nothing'))).$1, 404);
    final wrong = server.streamUri(heat.id).replace(pathSegments: ['0' * 40, ...server.streamUri(heat.id).pathSegments.skip(1)]);
    expect((await get(wrong)).$1, 404);
    expect((await get(server.pingUri)).$1, 204);

    final showA = index.series.firstWhere((s) => s.name == 'Show A');
    final poster = await get(server.imageUri(showA.id, ImageKind.primary));
    expect((poster.$1, poster.$2[0], poster.$2[1]), (200, 0xFF, 0xD8));
    expect((await get(server.imageUri(showA.id, ImageKind.logo))).$1, 200);
    expect((await get(server.imageUri(heat.id, ImageKind.primary))).$1, 404);

    final captions = index.movies.firstWhere((m) => m.title == 'Captions');
    final tracks = await server.subtitleTracks(captions.id);
    final forced = tracks.firstWhere((t) => t.isForced);
    expect((forced.language, forced.isExternal), ('eng', true));
    expect(tracks.where((t) => t.isExternal).map((t) => t.language), containsAll(['eng', 'spa', 'fre', 'ger']));
    final srt = await get(server.subtitleUri(captions.id, forced)!);
    expect(utf8.decode(srt.$2), contains('ENGLISH FORCED 10s'));
    final shifted = utf8.decode((await get(server.subtitleUri(captions.id, forced, startAt: const Duration(seconds: 10))!)).$2);
    expect(shifted, startsWith('WEBVTT'));
    expect(shifted, contains('00:00.000 --> 00:04.900\nENGLISH FORCED 10s'));
    final image = index.movies.firstWhere((m) => m.title == 'Image Captions');
    final inside = await server.subtitleTracks(image.id);
    expect([for (final t in inside) '${t.codec} ${t.burnsWhenConverting}'], ['hdmv_pgs_subtitle true', 'subrip false']);
    expect(utf8.decode((await get(server.subtitleUri(image.id, inside[1])!)).$2), contains('TEXT 5s'));
  }, timeout: const Timeout(Duration(minutes: 2)), skip: !_live);

  test('decisions follow the device, and conversions run and stop', () async {
    final android = androidDeviceProfile(DeviceCapabilities.fallback);
    MediaEntry movie(String title) => index.movies.firstWhere((m) => m.title == title);
    expect((await server.playbackDecision(movie('Heat').id, profile: android)).transcode, isFalse);
    final dts = await server.playbackDecision(movie('Surround DTS').id, profile: android);
    expect((dts.transcode, dts.directStream), (true, true));
    final wmv = await server.playbackDecision(movie('Windows Media').id, profile: android);
    expect((wmv.transcode, wmv.directStream), (true, false));
    expect((await server.playbackDecision(movie('Windows Media').id)).transcode, isFalse, reason: 'Linux plays it as it is');
    final hdr = await server.playbackDecision(movie('High Range HDR10').id, profile: android);
    expect(hdr.transcodeTemplate!.queryParameters['hdr'], '1');
    expect(hdr.transcodeTemplate!.queryParameters['h'], '720');

    final url = await server.transcodeUri(wmv.transcodeTemplate!, playSessionId: 'job1', startAt: const Duration(seconds: 30));
    final client = HttpClient();
    addTearDown(client.close);
    final answer = await (await client.getUrl(url)).close();
    expect((answer.statusCode, answer.headers.contentType?.mimeType), (200, 'video/mp2t'));
    final bytes = <int>[];
    final sub = answer.listen(bytes.addAll);
    while (bytes.length < 400000) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(bytes[0], 0x47);
    expect(await SmbGateway.instance.runningJobs(), 1);
    await server.stopTranscode('job1');
    await sub.cancel();
    expect(await SmbGateway.instance.runningJobs(), 0);
    // Stopped before it was asked for: it never starts.
    await server.stopTranscode('job2');
    final late = await (await client.getUrl(await server.transcodeUri(wmv.transcodeTemplate!, playSessionId: 'job2', startAt: Duration.zero))).close();
    expect(late.statusCode, 410);
    await late.drain<void>();
    final jobs = (await Process.run('pgrep', ['-x', 'ffmpeg'])).stdout.toString().trim();
    expect(jobs, isEmpty, reason: 'no conversion left running');
    expect(ConversionJobs.firstOutput, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)), skip: !_live);

  test('conversions tone-map HDR and draw picture captions in', () async {
    final android = androidDeviceProfile(DeviceCapabilities.fallback);
    final client = HttpClient();
    addTearDown(client.close);
    Future<Map<String, Object?>> convert(String title, {SubtitleTrack? burn}) async {
      final item = index.movies.firstWhere((m) => m.title == title);
      final d = await server.playbackDecision(item.id, profile: android);
      final url = await server.transcodeUri(d.transcodeTemplate!, playSessionId: 'p-$title', startAt: const Duration(seconds: 2), burn: burn);
      final out = File('${dir.path}/$title.ts');
      final answer = await (await client.getUrl(url)).close();
      final sink = out.openWrite();
      var n = 0;
      await for (final c in answer) {
        sink.add(c);
        n += c.length;
        if (n > 1500000) break;
      }
      await sink.close();
      await server.stopTranscode('p-$title');
      final probe = await Process.run('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,color_transfer', '-of', 'json', out.path]);
      return ((jsonDecode('${probe.stdout}') as Map)['streams'] as List).first as Map<String, Object?>;
    }

    final hdr = await convert('High Range HDR10');
    expect((hdr['codec_name'], hdr['width'], hdr['height']), ('h264', 1280, 720));
    expect(hdr['color_transfer'], isNot('smpte2084'));
    final image = index.movies.firstWhere((m) => m.title == 'Image Captions');
    final track = (await server.subtitleTracks(image.id)).firstWhere((t) => t.burnsWhenConverting);
    final burned = await convert('Image Captions', burn: track);
    expect(burned['codec_name'], 'h264');
  }, timeout: const Timeout(Duration(minutes: 2)), skip: !_live);

  test("Can't play lists damaged files and files with no picture", () async {
    final list = {for (final e in server.cantPlay.entries) e.key.title: e.value};
    expect(list['Cut Off'], CantPlayReason.damaged);
    expect(list['Sound Only'], CantPlayReason.noVideo);
  }, skip: !_live);

  test('history: watched, resumed, and two devices writing at once', () async {
    final heat = index.movies.firstWhere((m) => m.title == 'Heat');
    await server.reportPlaybackStopped(PlaybackReport(
        itemId: heat.id, playSessionId: 's', position: const Duration(seconds: 58), runtime: const Duration(seconds: 60)));
    final alien = index.movies.firstWhere((m) => m.title == 'Alien');
    await server.reportPlaybackStopped(PlaybackReport(
        itemId: alien.id, playSessionId: 's', position: const Duration(seconds: 20), runtime: const Duration(seconds: 60)));
    expect(await server.resumePoint(alien.id), const Duration(seconds: 20));
    final share = await openSmbShare(SmbAddress.parse('smb://127.0.0.1:1445/archive')!, SmbCredentials(user: 'smbtest', password: _password));
    addTearDown(share.close);
    // Two TVs of the same history name, writing at the same moment.
    final tv1 = SmbHistory(storage, serverId: 'live-archive', deviceFileId: 'tv1');
    final tv2 = SmbHistory(storage, serverId: 'live-archive', deviceFileId: 'tv2');
    await tv1.record('m|heat|1995', const Duration(seconds: 60), const Duration(seconds: 60));
    await tv2.record('m|heat|1995', const Duration(seconds: 60), const Duration(seconds: 60));
    await Future.wait([
      tv1.sync(share, historyName: 'Mom', keepLocal: false),
      tv2.sync(share, historyName: 'Mom', keepLocal: false),
    ]);
    await tv1.sync(share, historyName: 'Mom', keepLocal: false);
    expect(tv1.playsOf('m|heat|1995'), 3, reason: 'its own, tv2 and this profile');
    // Another history name doesn't see them.
    final kids = SmbHistory(storage, serverId: 'live-archive', deviceFileId: 'kids');
    await kids.sync(share, historyName: 'Kids', keepLocal: false);
    expect(kids.playsOf('m|heat|1995'), 0);
    // Nothing but .nightingale was written, and no name is readable in it.
    final folder = SmbHistory.folderFor('Mom');
    expect(folder, isNot(contains('Mom')));
    final files = [for (final e in await share.list(folder)) e.name]..sort();
    expect(files, hasLength(3));
    expect(files.any((f) => f.contains('Mom')), isFalse);
    await share.delete('$folder/tv1.json');
    await share.delete('$folder/tv2.json');
    // A file restored in place of the other keeps its history.
    server.rebuildNext();
    final again = await server.fetchLibraryIndex(pools: [commercials]);
    expect(again.movies.firstWhere((m) => m.title == 'Heat').playCount, 1);
  }, timeout: const Timeout(Duration(minutes: 2)), skip: !_live);

  test('the password is in no saved file', () async {
    final files = dir.listSync(recursive: true).whereType<File>();
    for (final f in files) {
      expect(utf8.decode(f.readAsBytesSync(), allowMalformed: true), isNot(contains(_password)), reason: f.path);
    }
    expect(File('${dir.path}/${SecretStore.keyFile}').existsSync(), isTrue);
    expect(File('${dir.path}/profile/${SecretStore.file}').statSync().modeString(), 'rw-------');
  }, skip: !_live);
}
