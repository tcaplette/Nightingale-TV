import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_generator.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/lineup_server.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/reporting/report_scrubber.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/server_set.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/youtube/google_sign_in.dart';
import 'package:nightingale_tv/server/youtube/youtube_api.dart';
import 'package:nightingale_tv/server/youtube/youtube_catalog.dart';
import 'package:nightingale_tv/server/youtube/youtube_client_config.dart';
import 'package:nightingale_tv/server/youtube/youtube_server.dart';

import '../integration_test/fake_google.dart';
import 'fixtures.dart';

const own = GoogleClient(id: 'own-client', secret: 'own-client-secret', own: true);

const shared = GoogleClient(id: 'shared-client', secret: 'shared-client-secret');

/// Signs [sub] in on [google] with [client] (the user's own unless told)
/// and adds it to [app] as a YouTube server.
Future<ProfileServer> addYouTube(AppState app, FakeGoogle google, String sub, {GoogleClient client = own}) async {
  final signIn = GoogleDeviceSignIn(client, delay: (_) async {});
  google.approveAs = sub;
  final tokens = (await signIn.waitForTokens(await signIn.requestCode()))!;
  final ref = await app.youtube.saveTokens(tokens, client);
  final session = ServerSession(
    kind: ServerKind.youtube,
    serverUrl: 'https://www.youtube.com',
    serverName: 'YouTube',
    serverId: 'yt:${tokens.subject}',
    userId: tokens.subject!,
    userName: google.accounts[sub]?.title ?? 'YouTube account',
    accessToken: ref,
    deviceId: app.settings.installId,
    clientId: client.own ? client.id : null,
  );
  return app.addServer(session, app.clientForSession(session, key: app.servers.peekKey()), refresh: false);
}

YouTubeSubscription sub(FakeGoogle google, String id) =>
    YouTubeSubscription(channelId: id, title: google.channels[id]!.title, avatarUrl: 'https://yt3.ggpht.com/$id=s88');

void main() {
  late Directory dir;
  late FakeGoogle google;
  late AppState app;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('youtube_app');
    google = await FakeGoogle.start();
    GoogleEndpoints.override = GoogleEndpoints(oauth: google.url, api: google.url);
    for (var c = 0; c < 12; c++) {
      google.channels['UCch$c'] = FakeChannel('UCch$c', 'Channel $c', videos: [
        for (var v = 0; v < 3; v++)
          FakeVideo('c${c}v$v', published: DateTime.utc(2026, 11, 20 - v), length: const Duration(minutes: 10)),
      ]);
    }
    google.accounts['mom'] =
        FakeAccount('mom', title: 'Mom Cooks', subscriptions: [for (var c = 0; c < 12; c++) 'UCch$c']);
    google.accounts['sam'] = FakeAccount('sam', title: 'Sam', subscriptions: ['UCch0', 'UCch1']);
    app = await signedInApp(dir, fakeLibrary(shows: {'Alpha': 30, 'Beta': 30}, movies: 6));
  });

  tearDown(() async {
    await app.close();
    await google.close();
    GoogleEndpoints.override = null;
    dir.deleteSync(recursive: true);
  });

  Future<ProfileServer> momWithPicks(List<String> ids) async {
    final yt = await addYouTube(app, google, 'mom');
    await app.setYouTubePicks(yt.key, [for (final id in ids) sub(google, id)], refresh: false);
    await app.refreshLibrary(background: true);
    return yt;
  }

  test('a YouTube server: its tokens in the secret store only, never in session or servers files', () async {
    final yt = await momWithPicks(['UCch0', 'UCch1', 'UCch2']);
    expect(yt.kind, ServerKind.youtube);
    expect(yt.serverId, 'yt:mom');
    expect(yt.userName, 'Mom Cooks');
    final servers = File('${dir.path}/servers.json').readAsStringSync();
    final session = File('${dir.path}/session.json').readAsStringSync();
    for (final token in google.refreshTokens.keys) {
      expect(servers, isNot(contains(token)));
      expect(session, isNot(contains(token)));
    }
    expect(servers, isNot(contains(own.secret)));
    expect(servers, contains('"clientId":"own-client"'));
    final secrets = File('${dir.path}/smb_secrets.json').readAsStringSync();
    expect(secrets, isNot(contains(google.refreshTokens.keys.first)), reason: 'encrypted');
    expect(await app.youtube.secrets.values(yt.session!.accessToken), containsPair('clientSecret', own.secret));
  });

  test('the same Google account twice is refused; another account can be added', () async {
    await addYouTube(app, google, 'mom');
    await expectLater(addYouTube(app, google, 'mom'), throwsA(isA<ServerException>()));
    final sam = await addYouTube(app, google, 'sam');
    expect(sam.serverId, 'yt:sam');
    expect(app.servers.added.where((s) => s.kind == ServerKind.youtube), hasLength(2));
  });

  test('picks become channels: named, badged, numbered after the highest, playing newest first', () async {
    final highest = app.channels.map((c) => c.number).reduce((a, b) => a > b ? a : b);
    final yt = await momWithPicks(['UCch0', 'UCch1']);
    final channels = app.youTubeChannels;
    expect([for (final c in channels) c.name], ['Channel 0', 'Channel 1']);
    expect([for (final c in channels) c.number], [highest + 1, highest + 2]);
    expect(channels.first.id, 'yt:${yt.key}:UCch0');
    expect(channels.first.icon.kind, ChannelIconKind.remote);
    expect(channels.first.playlist, ['${yt.key}~c0v0', '${yt.key}~c0v1', '${yt.key}~c0v2']);
    expect(app.planFor(channels.first).isOff, isTrue);
    expect(app.configuredPlanFor(channels.first).isOff, isTrue);
    // Saved in channels.json, and back the same after a restart.
    final saved = jsonDecode(File('${dir.path}/channels.json').readAsStringSync()) as List;
    expect(saved.where((c) => (c as Map)['youtube'] != null), hasLength(2));
    final again = AppState(await AppStorage.at(dir));
    await again.start();
    expect([for (final c in again.youTubeChannels) c.playlist.length], [3, 3]);
    await again.close();
  });

  test('no generated, custom, block, genre or reset lineup ever holds a YouTube video', () async {
    await momWithPicks(['UCch0', 'UCch1', 'UCch2']);
    expect(app.library.youtubeVideos, hasLength(9));
    final youTubeIds = {for (final v in app.library.youtubeVideos) v.id};
    bool clean(List<String> ids) => ids.every((id) => !youTubeIds.contains(id));
    for (final c in ChannelGenerator(app.library).generate()) {
      expect(clean(c.playlist), isTrue, reason: c.id);
    }
    for (final c in app.channels.where((c) => !c.isYouTube)) {
      expect(clean(c.playlist), isTrue, reason: c.id);
    }
    final custom = await app.createCustomChannel('Mine', ChannelSource(seriesKeys: [app.library.series.first.key]));
    expect(clean(custom.playlist), isTrue);
    await app.resetChannels();
    expect(app.youTubeChannels, hasLength(3), reason: 'reset keeps them');
    for (final c in app.channels.where((c) => !c.isYouTube)) {
      expect(clean(c.playlist), isTrue, reason: c.id);
    }
    // Generated show/genre/decade channels never come from YouTube's series.
    expect(app.channels.where((c) => c.source.seriesKeys.any((k) => k.startsWith('yt:'))), isEmpty);
  });

  test('a refresh puts new videos right after the program on air, and never changes what is on air', () async {
    final yt = await momWithPicks(['UCch0']);
    final ch = app.youTubeChannels.single;
    final onAirBefore = app.scheduleFor(ch)!.programAt(DateTime.now()).item!.id;
    google.channels['UCch0']!.videos.insertAll(0, [
      FakeVideo('c0new2', published: DateTime.utc(2026, 11, 23, 2)),
      FakeVideo('c0new1', published: DateTime.utc(2026, 11, 23, 1)),
    ]);
    app.youtube.serverOf(yt.key)!.catalog.refreshedAt = DateTime.now().subtract(const Duration(hours: 7));
    await app.refreshLibrary(background: true);
    final after = app.youTubeChannels.single;
    final now = DateTime.now();
    expect(app.scheduleFor(after)!.programAt(now).item!.id, onAirBefore);
    final at = after.playlist.indexOf(onAirBefore);
    expect(after.playlist.sublist(at + 1, at + 3), ['${yt.key}~c0new2', '${yt.key}~c0new1']);
    expect(
        AppState.mergeYouTubePlaylist(['a', 'b', 'c'], ['n2', 'n1', 'a', 'b', 'c'], onAir: 'b'), ['a', 'b', 'n2', 'n1', 'c']);
    expect(AppState.mergeYouTubePlaylist(['a', 'b'], ['n', 'a'], onAir: null), ['n', 'a']);
  });

  group('5 channels on Nightingale TV\'s client, no limit on an own one', () {
    setUp(() {
      GoogleClient.sharedOverride = shared;
      for (var c = 12; c < 52; c++) {
        google.channels['UCch$c'] = FakeChannel('UCch$c', 'Channel $c', videos: [FakeVideo('c${c}v0')]);
      }
    });
    tearDown(() => GoogleClient.sharedOverride = null);

    List<YouTubeSubscription> picks(int from, int to) => [for (var c = from; c < to; c++) sub(google, 'UCch$c')];

    test('the 5th pick on Nightingale TV\'s client is fine, the 6th refused', () async {
      final mom = await addYouTube(app, google, 'mom', client: shared);
      await app.setYouTubePicks(mom.key, picks(0, 5), refresh: false);
      expect(app.youTubeSharedCount(), 5);
      await expectLater(app.setYouTubePicks(mom.key, picks(0, 6), refresh: false), throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('Servers → YouTube → Google client'))));
      expect(app.youTubeChannels, hasLength(5));
    });

    test('an own client takes 40 picks, and its channels don\'t count toward the 5', () async {
      final mom = await addYouTube(app, google, 'mom');
      await app.setYouTubePicks(mom.key, picks(0, 40), refresh: false);
      expect(app.youTubeChannels, hasLength(40));
      expect(app.youTubeSharedCount(), 0);
      final sam = await addYouTube(app, google, 'sam', client: shared);
      await app.setYouTubePicks(sam.key, picks(40, 45), refresh: false);
      expect(app.youTubeSharedCount(), 5);
      await expectLater(app.setYouTubePicks(sam.key, picks(40, 46), refresh: false), throwsStateError);
      expect(app.youTubeChannels, hasLength(45));
    });

    test('two accounts on Nightingale TV\'s client share the 5', () async {
      final mom = await addYouTube(app, google, 'mom', client: shared);
      await app.setYouTubePicks(mom.key, picks(0, 3), refresh: false);
      final sam = await addYouTube(app, google, 'sam', client: shared);
      expect(app.youTubeSharedCount(except: sam.key), 3);
      await app.setYouTubePicks(sam.key, picks(0, 2), refresh: false);
      await expectLater(app.setYouTubePicks(sam.key, picks(0, 3), refresh: false), throwsStateError);
      // Unpicking makes room again.
      await app.setYouTubePicks(mom.key, picks(0, 2), refresh: false);
      await app.setYouTubePicks(sam.key, picks(0, 3), refresh: false);
      expect(app.youTubeChannels, hasLength(5));
    });

    test('a profile with 7 from before keeps them all, and can add only once below 5', () async {
      final mom = await addYouTube(app, google, 'mom');
      await app.setYouTubePicks(mom.key, picks(0, 7), refresh: false);
      // The server moves to Nightingale TV's client as an update finds it.
      final server = app.servers.byKey(mom.key)!;
      final s = server.session!;
      server.session = ServerSession(
          kind: s.kind, serverUrl: s.serverUrl, serverName: s.serverName, serverId: s.serverId,
          userId: s.userId, userName: s.userName, accessToken: s.accessToken, deviceId: s.deviceId);
      expect(app.youTubeSharedCount(), 7);
      // Done with the same picks keeps all 7.
      await app.setYouTubePicks(mom.key, picks(0, 7), refresh: false);
      expect(app.youTubeChannels, hasLength(7));
      // Swapping one for a new one is still a new pick above the limit.
      await expectLater(app.setYouTubePicks(mom.key, [...picks(0, 6), sub(google, 'UCch9')], refresh: false), throwsStateError);
      await app.setYouTubePicks(mom.key, picks(0, 4), refresh: false);
      await app.setYouTubePicks(mom.key, [...picks(0, 4), sub(google, 'UCch9')], refresh: false);
      expect(app.youTubeChannels, hasLength(5));
    });

    test('switching back fits only within the 5', () async {
      final mom = await addYouTube(app, google, 'mom');
      await app.setYouTubePicks(mom.key, picks(0, 8), refresh: false);
      expect(app.youTubeFitsSharedClient(mom.key), isFalse);
      await app.setYouTubePicks(mom.key, picks(0, 5), refresh: false);
      expect(app.youTubeFitsSharedClient(mom.key), isTrue);
      final sam = await addYouTube(app, google, 'sam', client: shared);
      await app.setYouTubePicks(sam.key, picks(10, 11), refresh: false);
      expect(app.youTubeFitsSharedClient(mom.key), isFalse, reason: '5 + 1 shared');
    });
  });

  test('the daily limit: no request until Pacific midnight, channels keep playing, Servers says so', () async {
    final yt = await momWithPicks(['UCch0']);
    final server = app.youtube.serverOf(yt.key)!;
    google.quotaExceeded = true;
    server.catalog.refreshedAt = DateTime.now().subtract(const Duration(hours: 7));
    await app.refreshLibrary(background: true);
    final until = server.quotaBlockedUntil;
    expect(until, isNotNull);
    expect(until, nextPacificMidnight(DateTime.now()));
    expect(app.youTubeChannels.single.playlist, hasLength(3), reason: 'it keeps what it has');
    final units = google.unitTotal;
    server.catalog.refreshedAt = DateTime.now().subtract(const Duration(hours: 7));
    await app.refreshLibrary(background: true);
    expect(google.unitTotal, units, reason: 'nothing is asked while blocked');
    await expectLater(server.subscriptions(), throwsA(isA<YouTubeQuotaException>()));
  });

  test('Pacific midnight in standard and daylight time', () {
    expect(nextPacificMidnight(DateTime.utc(2026, 11, 23, 12)), DateTime.utc(2026, 11, 24, 8));
    expect(nextPacificMidnight(DateTime.utc(2026, 11, 24, 7, 59)), DateTime.utc(2026, 11, 24, 8));
    expect(nextPacificMidnight(DateTime.utc(2026, 7, 4, 12)), DateTime.utc(2026, 7, 5, 7));
    // The night daylight time ends (1 Nov 2026).
    expect(nextPacificMidnight(DateTime.utc(2026, 11, 1, 12)), DateTime.utc(2026, 11, 2, 8));
  });

  test('a revoked sign-in: Needs sign-in, off the air, and the data goes after 7 days', () async {
    final yt = await momWithPicks(['UCch0']);
    final server = app.youtube.serverOf(yt.key)!;
    google.revokeAccount('mom');
    server.close();
    server.catalog.refreshedAt = DateTime.now().subtract(const Duration(hours: 7));
    await app.refreshLibrary(background: true);
    expect(yt.state, ServerState.needsSignIn);
    final lost = server.catalog.signInLostAt!;
    expect(server.catalog.purge(lost.add(const Duration(days: 6, hours: 23))), isFalse);
    expect(server.catalog.purge(lost.add(const Duration(days: 7))), isTrue);
    expect(server.catalog.channels, isEmpty);
    expect(app.youTubeChannels, hasLength(1), reason: 'channels and picks stay until removed');
  });

  test('Remove: revoked at Google, no token, catalog or channel left', () async {
    final yt = await momWithPicks(['UCch0', 'UCch1']);
    final ref = yt.session!.accessToken;
    expect(Directory('${dir.path}/youtube/${yt.key}').existsSync(), isTrue);
    await app.removeServer(yt.key);
    expect(google.revoked, hasLength(1));
    expect(await SecretStore(await AppStorage.at(dir)).values(ref), isNull);
    expect(Directory('${dir.path}/youtube/${yt.key}').existsSync(), isFalse);
    expect(app.youTubeChannels, isEmpty);
    expect(app.library.youtubeVideos, isEmpty);
  });

  test('profile deletion revokes every YouTube sign-in in the folder', () async {
    await momWithPicks(['UCch0']);
    await app.storage.flush();
    await revokeYouTubeSignIns(await AppStorage.at(dir));
    expect(google.revoked, hasLength(1));
  });

  test('YouTube channels stay out of the Live TV export, sharing and blocks', () async {
    await momWithPicks(['UCch0']);
    final ch = app.youTubeChannels.single;
    final lineup = LineupServer(
      profileId: 'p1',
      appFor: () => app,
      profileName: () => 'p1',
      export: const ProfileExport(exported: true, port: 1, deviceId: '7B8AF336', deviceAuth: 'x'),
    ).lineupOf(app);
    expect(lineup, isNotEmpty);
    expect(lineup.any((c) => c.isYouTube), isFalse);
    expect(app.shareProblem(ch), isNotNull);
    final block = app.newBlock()
      ..title = 'Mornings'
      ..channelId = ch.id;
    expect(app.blockProblem(block), isNotNull);
  });

  test('a refused video leaves at once, the next one starting now, and from the catalog at the refresh', () async {
    final yt = await momWithPicks(['UCch0']);
    final ch = app.youTubeChannels.single;
    final now = DateTime.now();
    await app.skipYouTubeVideo(ch, '${yt.key}~c0v1', refused: true, now: now);
    expect(ch.playlist, ['${yt.key}~c0v2', '${yt.key}~c0v0']);
    expect(app.scheduleFor(ch)!.programAt(now).item!.id, '${yt.key}~c0v2');
    final server = app.youtube.serverOf(yt.key)!;
    expect(server.catalog.refused, {'c0v1'});
    server.catalog.refreshedAt = DateTime.now().subtract(const Duration(hours: 7));
    await app.refreshLibrary(background: true);
    expect(app.library.youtubeVideos.map((v) => v.id), isNot(contains('${yt.key}~c0v1')));
  });

  test('backups: the channels, picks, numbers and colour, never a token, a secret or catalog data', () async {
    final yt = await momWithPicks(['UCch0', 'UCch1']);
    await app.setServerColor(yt.key, 'wine');
    await app.storage.flush();
    final root = dir.parent;
    // The backup reads a household folder: put this profile in one.
    final home = Directory.systemTemp.createTempSync('youtube_backup');
    try {
      final top = await AppStorage.at(home);
      await top.writeJson('profiles.json', [
        {'id': 'aabbccdd', 'name': 'Mom'}
      ]);
      await top.flush();
      final profile = Directory('${home.path}/profiles/aabbccdd')..createSync(recursive: true);
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        final rel = f.path.substring(dir.path.length + 1);
        File('${profile.path}/$rel')
          ..createSync(recursive: true)
          ..writeAsBytesSync(f.readAsBytesSync());
      }
      final built = await BackupArchive.build(home, reason: 'manual', device: 'test');
      final text = utf8.decode(gzip.decode(built.bytes));
      for (final token in google.refreshTokens.keys) {
        expect(text, isNot(contains(token)));
      }
      expect(text, isNot(contains(own.secret)));
      expect(text, isNot(contains('c0v0')), reason: 'no video ids: YouTube data');
      expect(text, isNot(contains('About c0v0')));
      final archive = BackupArchive.check(built.bytes);
      final p = archive.profiles['aabbccdd']!;
      final youTube = [for (final c in p.channels!) if ((c! as Map)['youtube'] != null) c as Map];
      expect([for (final c in youTube) c['name']], ['Channel 0', 'Channel 1']);
      expect([for (final c in youTube) c['playlist']], [isEmpty, isEmpty]);
      final hint = (p.servers!['servers'] as List).cast<Map>().single;
      expect(hint['kind'], 'youtube');
      expect(hint['ownClient'], isTrue);
      expect(ServerColor.byName((p.settings!['serverColors'] as Map)[yt.key] as String?)?.name, 'wine');
    } finally {
      home.deleteSync(recursive: true);
    }
    expect(root.existsSync(), isTrue);
  });

  test('error reports scrub Google tokens, client ids and secrets', () {
    final s = ReportScrubber(names: ['Mom Cooks', 'Channel 0', 'Video c0v0']);
    final out = s.scrub('token ya29.a0AfB_byC-123xyz refresh 1//0gAbC-DeF_123 client '
        '123456789012-abcdefghijk.apps.googleusercontent.com secret GOCSPX-AbCdEf_123-xyz '
        'account Mom Cooks channel Channel 0 video Video c0v0');
    expect(out, isNot(contains('ya29')));
    expect(out, isNot(contains('0gAbC')));
    expect(out, isNot(contains('googleusercontent')));
    expect(out, isNot(contains('GOCSPX')));
    expect(out, isNot(contains('Mom Cooks')));
    expect(out, isNot(contains('Channel 0')));
    expect(out, isNot(contains('c0v0')));
  });

  test('server colours: YouTube starts as wine', () {
    expect(ServerColor.defaultFor(ServerKind.youtube), 'wine');
  });

  test('the catalog of every refreshed server is saved and its 30-day deletion needs no request', () async {
    final yt = await momWithPicks(['UCch0']);
    final file = File('${dir.path}/${YouTubeCatalog.fileOf(yt.key)}');
    expect(file.existsSync(), isTrue);
    final catalog = YouTubeCatalog.fromJson(jsonDecode(file.readAsStringSync()));
    final units = google.unitTotal;
    expect(catalog.purge(DateTime.now().add(const Duration(days: 30))), isTrue);
    expect(catalog.entries(), isEmpty);
    expect(google.unitTotal, units);
  });

  test('a restart keeps the lineup when the clips change as it opens (an added server\'s analysis)', () async {
    await app.close();
    dir.deleteSync(recursive: true);
    dir = Directory.systemTemp.createTempSync('youtube_app');
    app = await signedInApp(dir,
        fakeLibrary(shows: {'Alpha': 30}, commercials: [for (var i = 0; i < 6; i++) const Duration(seconds: 30)]));
    await momWithPicks(['UCch0']);
    final before = app.channels.length;
    expect(app.youTubeChannels, hasLength(1));
    await app.storage.flush();
    await app.close();
    app = AppState(await AppStorage.at(dir));
    await app.start();
    await app.storage.flush();
    expect(app.channels.length, before);
    final saved = jsonDecode(File('${dir.path}/channels.json').readAsStringSync()) as List;
    expect(saved, isNotEmpty);
    expect(File('${dir.path}/analysis').existsSync() ? Directory('${dir.path}/analysis').listSync().where((f) => f.path.contains('yt')) : const [],
        isEmpty, reason: 'no analysis for YouTube');
  });

  test('YouTube videos are their own kind with their channel as the series', () async {
    await momWithPicks(['UCch0']);
    final v = app.library.youtubeVideos.first;
    expect(v.kind, MediaKind.youtubeVideo);
    expect(v.seriesKey, 'yt:UCch0');
    expect(v.subtitle, contains('Channel 0'));
    expect(ServerSet.rawId(v.id), 'c0v0');
  });
}
