import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/server_set.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  final households = <Household>[];
  final mom = momAndKids().first;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('youtube_backup');
    final src = Directory('${dir.path}/src')..createSync();
    await writeHousehold(src, [mom], fakeLibrary());
    final profile = AppStorage.existing(Directory('${src.path}/profiles/${mom.id}'));
    final channels = [...(await profile.readRaw('channels.json') as List)];
    // 12 YouTube channels, numbered out of order.
    for (var i = 0; i < 12; i++) {
      channels.add(Channel.youTube(
        ref: YouTubeRef(serverKey: 's2', channelId: 'UCch$i'),
        number: 500 - i,
        name: 'Channel $i',
        icon: const ChannelIcon(kind: ChannelIconKind.remote, value: 'https://yt3.ggpht.com/x'),
        playlist: ['s2~video$i'],
        anchor: DateTime(2026, 11, 23),
      ).toJson());
    }
    await profile.writeJson('channels.json', channels);
    await profile.writeJson(ServerSet.file, {
      'servers': [
        {
          'key': 's2',
          'session': {
            'kind': 'youtube',
            'serverUrl': 'https://www.youtube.com',
            'serverName': 'YouTube',
            'serverId': 'yt:mom',
            'userId': 'mom',
            'userName': 'Mom Cooks',
            'accessToken': 'yt-0011223344556677',
            'deviceId': 'd',
            'clientId': 'own-client',
          }
        }
      ],
      'order': ['main', 's2'],
      'nextKey': 3,
    });
    await profile.flush();
  });

  tearDown(() async {
    for (final h in households) {
      h.leave();
      h.backups?.dispose();
    }
    households.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  Future<Household> open(Directory root, {bool serverMode = false}) async {
    final h = Household(await AppStorage.at(root), runAnalysis: false, serverMode: serverMode);
    h.backups = BackupScheduler(h, BackupStore(Directory('${root.path}/backups')));
    await h.start();
    households.add(h);
    return h;
  }

  Future<List<int>> backup() async => (await BackupArchive.build(Directory('${dir.path}/src'), reason: 'manual', device: 'test')).bytes;

  List<Map> youTubeChannelsIn(Directory root) {
    final list = AppStorage.existing(Directory('${root.path}/profiles/${mom.id}'));
    final channels = File('${list.root.path}/channels.json').existsSync()
        ? (File('${list.root.path}/channels.json').readAsStringSync())
        : '[]';
    return [
      for (final c in (_decode(channels) as List).cast<Map>())
        if (c['youtube'] != null) c
    ];
  }

  test('a restore keeps every YouTube channel of an own-client server, without their videos; it needs sign-in',
      () async {
    final bytes = await backup();
    final root = Directory('${dir.path}/new')..createSync();
    final h = await open(root);
    await BackupRestorer(h, signOut: (_) async {}).restore(bytes);
    final kept = youTubeChannelsIn(root);
    expect(kept, hasLength(12));
    expect([for (final c in kept) c['playlist']], everyElement(isEmpty));
    final servers = _decode(File('${root.path}/profiles/${mom.id}/servers.json').readAsStringSync()) as Map;
    final s2 = (servers['servers'] as List).cast<Map>().single;
    expect(s2['session'], isNull);
    expect(s2['hint'], containsPair('kind', 'youtube'));
    expect(s2['hint'], containsPair('ownClient', true));
    expect(s2['hint'].toString(), isNot(contains('yt-0011223344556677')));
    final app = h.appFor(mom.id);
    if (app != null) expect(app.servers.byKey('s2')?.state, ServerState.needsSignIn);
  });

  test('a restore of 8 channels on Nightingale TV\'s client keeps the first 5 by number', () async {
    final profile = AppStorage.existing(Directory('${dir.path}/src/profiles/${mom.id}'));
    final servers = await profile.readRaw(ServerSet.file) as Map<String, Object?>;
    final entry = (servers['servers'] as List).cast<Map<String, Object?>>().single;
    (entry['session'] as Map<String, Object?>).remove('clientId');
    await profile.writeJson(ServerSet.file, servers, private: true);
    // 8 of the 12 (numbers 493 to 500).
    final channels = [
      for (final c in (await profile.readRaw('channels.json') as List).cast<Map<String, Object?>>())
        if (c['youtube'] == null || (c['number'] as num) > 492) c
    ];
    await profile.writeJson('channels.json', channels);
    await profile.flush();
    final bytes = await backup();
    final root = Directory('${dir.path}/shared')..createSync();
    final h = await open(root);
    await BackupRestorer(h, signOut: (_) async {}).restore(bytes);
    final kept = youTubeChannelsIn(root);
    expect([for (final c in kept) c['number']]..sort(), [493, 494, 495, 496, 497]);
  });

  test('the Docker server keeps all 12 YouTube channels with their numbers; YouTube needs sign-in', () async {
    final bytes = await backup();
    final root = Directory('${dir.path}/docker')..createSync();
    final h = await open(root, serverMode: true);
    await BackupRestorer(h, signOut: (_) async {}).restore(bytes);
    final kept = youTubeChannelsIn(root);
    expect(kept, hasLength(12));
    expect([for (final c in kept) c['number']]..sort(), [for (var i = 489; i <= 500; i++) i]);
    expect(h.notice.value, isNot(contains('YouTube')));
    final servers = _decode(File('${root.path}/profiles/${mom.id}/servers.json').readAsStringSync()) as Map;
    final s2 = (servers['servers'] as List).cast<Map>().single;
    expect(s2['session'], isNull);
    expect(s2['hint'], containsPair('kind', 'youtube'));
    expect(s2['hint'].toString(), isNot(contains('yt-0011223344556677')));
    final app = h.appFor(mom.id);
    if (app != null) expect(app.servers.byKey('s2')?.state, ServerState.needsSignIn);
  });

  test("the Docker server keeps a backup's channels on Nightingale TV's client too, all 8, needing sign-in", () async {
    final profile = AppStorage.existing(Directory('${dir.path}/src/profiles/${mom.id}'));
    final servers = await profile.readRaw(ServerSet.file) as Map<String, Object?>;
    final entry = (servers['servers'] as List).cast<Map<String, Object?>>().single;
    (entry['session'] as Map<String, Object?>).remove('clientId');
    await profile.writeJson(ServerSet.file, servers, private: true);
    final channels = [
      for (final c in (await profile.readRaw('channels.json') as List).cast<Map<String, Object?>>())
        if (c['youtube'] == null || (c['number'] as num) > 492) c
    ];
    await profile.writeJson('channels.json', channels);
    await profile.flush();
    final bytes = await backup();
    final root = Directory('${dir.path}/docker-shared')..createSync();
    final h = await open(root, serverMode: true);
    await BackupRestorer(h, signOut: (_) async {}).restore(bytes);
    expect([for (final c in youTubeChannelsIn(root)) c['number']]..sort(), [493, 494, 495, 496, 497, 498, 499, 500]);
    final restored = _decode(File('${root.path}/profiles/${mom.id}/servers.json').readAsStringSync()) as Map;
    final s2 = (restored['servers'] as List).cast<Map>().single;
    expect(s2['hint'], containsPair('kind', 'youtube'));
    expect(s2['hint']['ownClient'], isNot(true));
  });
}

Object? _decode(String s) => jsonDecode(s);
