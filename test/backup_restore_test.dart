import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_restorer.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/premieres.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/device_effects.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/remote/firewall_check.dart';
import 'package:nightingale_tv/remote/remote_control.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';
import 'package:nightingale_tv/server/media_server.dart';

/// Settings without the nightly premiere slot, whose new episodes depend
/// on when each device first saw them.
Map<String, Object?> _noPremieres() =>
    (AppSettings.fresh()..premieres = const PremiereSettings(enabled: false)).toJson();

/// A Jellyfin server holding [fakeLibrary]'s shows.
JellyfinClient _server() {
  final items = fakeItems(shows: const {'Alpha': 10, 'Beta': 4});
  return JellyfinClient(
    serverUrl: 'http://127.0.0.1:9',
    deviceId: 'd',
    deviceName: 'pc',
    accessToken: 't',
    userId: 'u',
    httpClient: MockClient((r) async {
      if (r.url.path == '/UserViews') {
        return http.Response(
            jsonEncode({
              'Items': [
                {'Id': 'tv', 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
              ]
            }),
            200);
      }
      final q = r.url.queryParameters;
      final all = switch ((q['ParentId'], q['IncludeItemTypes'])) {
        ('tv', 'Series') => items.series,
        ('tv', 'Episode') => items.episodes,
        ('tv', 'Movie') => items.movies,
        _ => const <Map<String, Object?>>[],
      };
      final start = int.parse(q['StartIndex'] ?? '0'), limit = int.parse(q['Limit'] ?? '500');
      return http.Response(jsonEncode({'Items': all.skip(start).take(limit).toList(), 'TotalRecordCount': all.length}), 200);
    }),
  );
}

ServerSession _session(String serverId) => ServerSession(
      serverUrl: 'http://127.0.0.1:9',
      serverName: 'Home',
      userId: 'u-mom',
      userName: 'mom',
      accessToken: 'new-token',
      deviceId: 'd',
      serverId: serverId,
    );

void main() {
  late Directory dir;
  final households = <Household>[];

  setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_restore'));
  tearDown(() async {
    for (final h in households) {
      h.leave();
      h.backups?.dispose();
    }
    households.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  Future<Household> open(Directory root) async {
    final h = await openHousehold(root);
    households.add(h);
    return h;
  }

  final mom = momAndKids().first;

  AppStorage storageOf(Directory root, String id) => AppStorage.existing(Directory('${root.path}/profiles/$id'));

  Future<String?> installIdOf(Directory root, String id) async =>
      (await storageOf(root, id).readRaw('settings.json') as Map?)?['installId'] as String?;

  group('automatic and safety backups', () {
    late Household h;
    setUp(() async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      h = await open(dir);
    });

    Future<List<StoredBackup>> stored() => h.backups!.store.list();

    test('an unchanged household saves nothing; a renamed channel saves a daily', () async {
      expect(await h.backups!.dailyCheck(), isNotNull);
      expect(await h.backups!.dailyCheck(), isNull);
      expect(await stored(), hasLength(1));

      await h.select(mom);
      final ch = h.app!.allChannels.first;
      await h.app!.updateChannel(ch, name: 'Renamed');
      final daily = await h.backups!.dailyCheck();
      expect(daily!.kind, BackupReason.daily);
      final names = [for (final c in daily.archive.profiles[mom.id]!.channels!) (c as Map)['name']];
      expect(names, contains('Renamed'));
      expect(await stored(), hasLength(2));
    });

    test('reset, delete and a settings upgrade each save their kind first', () async {
      await h.select(mom);
      await h.app!.resetChannels();
      expect((await stored()).first.kind, BackupReason.beforeReset);

      // Delete needs a change since the last backup to save another.
      await h.app!.updateChannel(h.app!.allChannels.first, name: 'Changed');
      final kids = h.profiles.last;
      await h.deleteProfile(kids);
      final before = (await stored()).first;
      expect(before.kind, BackupReason.beforeDelete);
      expect(before.kindLabel, 'Before deleting Kids');
      expect(before.archive.summary.profiles, ['Mom', 'Kids']);

      // Settings saved before break plans: upgraded on loading.
      h.leave();
      await storageOf(dir, mom.id).writeJson('settings.json', {
        'installId': (await installIdOf(dir, mom.id))!,
        'commercialsEnabled': true,
        'commercialLibraryIds': ['ads'],
      });
      await storageOf(dir, mom.id).flush();
      await h.select(mom);
      // Settings this old also predate show identity: the lineup cleanup
      // saves its own backup after the upgrade's (lineup-dedup D7).
      final kinds = [for (final b in await stored()) b.kind];
      expect(kinds.take(2), [BackupReason.beforeLineupCleanup, BackupReason.beforeUpgrade]);
      final upgrade = (await stored()).firstWhere((b) => b.kind == BackupReason.beforeUpgrade);
      // It holds the settings as they were before the upgrade.
      expect(upgrade.archive.profiles[mom.id]!.settings!['commercialsEnabled'], isTrue);
      expect((await storageOf(dir, mom.id).readRaw('settings.json') as Map)['commercialPlan'], isNotNull);
    });

    test('a store that can\'t be written refuses the reset and the delete', () async {
      await h.select(mom);
      final channels = [for (final c in h.app!.allChannels) c.name];
      final backups = h.backups!.store.dir;
      if (await backups.exists()) await backups.delete(recursive: true);
      await File(backups.path).writeAsString('in the way');

      await expectLater(h.app!.resetChannels(),
          throwsA(isA<BackupException>().having((e) => e.message, 'message', startsWith('Couldn\'t save a backup first: '))));
      expect([for (final c in h.app!.allChannels) c.name], channels);

      await expectLater(h.deleteProfile(h.profiles.last), throwsA(isA<BackupException>()));
      expect(h.profiles, hasLength(2));
      expect(await Directory('${dir.path}/profiles/${h.profiles.last.id}').exists(), isTrue);
    });
  });

  group('the daily check\'s timing', () {
    late Household h;
    late _CountingScheduler scheduler;
    final launchIdle = AppState.launchIdleWait;

    setUp(() async {
      AppState.launchIdleWait = const Duration(days: 30);
      await writeHousehold(dir, [Profile(id: 'solo000000000001', name: 'Solo')], fakeLibrary());
      h = await open(dir);
      expect(h.app, isNotNull, reason: 'one profile with no PIN goes straight in');
      scheduler = _CountingScheduler(h);
    });
    tearDown(() {
      AppState.launchIdleWait = launchIdle;
      scheduler.dispose();
    });

    test('waits for the launch\'s picture, then repeats every 24 hours', () {
      fakeAsync((async) {
        scheduler.start();
        async.elapse(const Duration(minutes: 1));
        expect(scheduler.checks, 0, reason: 'nothing before the picture');
        h.app!.playbackActivity.value = PlaybackActivity.playing;
        async.elapse(BackupScheduler.firstCheck - const Duration(seconds: 1));
        expect(scheduler.checks, 0);
        async.elapse(const Duration(seconds: 1));
        expect(scheduler.checks, 1, reason: '15 s after the picture');
        async.elapse(const Duration(hours: 23));
        expect(scheduler.checks, 1);
        async.elapse(const Duration(hours: 1));
        expect(scheduler.checks, 2);
        async.elapse(const Duration(hours: 24));
        expect(scheduler.checks, 3);
      });
    });

    test('with nothing tuning, it still runs, after the fallback', () {
      fakeAsync((async) {
        scheduler.start();
        async.elapse(BackupScheduler.firstCheckFallback - const Duration(seconds: 1));
        expect(scheduler.checks, 0);
        async.elapse(const Duration(seconds: 1));
        expect(scheduler.checks, 1);
        async.elapse(const Duration(hours: 1));
        expect(scheduler.checks, 1);
      });
    });
  });

  group('restoring', () {
    test('a custom channel comes back with its sources, slot rule and offline image, the same program on the air', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      final h = await open(dir);
      await h.select(mom);
      final app = h.app!;
      final image = await app.icons.importOfflineBytes(fakeLogo(100), 'difficulties.png');
      expect(BackupArchive.logoName.hasMatch(image), isTrue);
      final ch = await app.createCustomChannel('80s TV', const ChannelSource(seriesKeys: ['alpha|2000']));
      await app.setSlotRule(ch, SlotRule(length: const Duration(minutes: 30), tail: TailMode.offline, offlineImage: image));
      final now = DateTime.now();
      final onAir = app.scheduleFor(ch)!.playbackAt(now);
      final backup = (await h.backups!.backUp(BackupReason.manual))!;

      await app.deleteUserChannel(ch);
      await File('${dir.path}/logos/$image').delete();
      final bytes = await h.backups!.store.read(backup);
      expect(BackupArchive.check(bytes).logos.keys, contains(image));
      await BackupRestorer(h).restore(bytes);
      await h.select(h.profiles.first);

      final back = h.app!.channelById(ch.id)!;
      expect(back.source.seriesKeys, ['alpha|2000']);
      expect(back.slotRule, ch.slotRule);
      expect(await File('${dir.path}/logos/$image').exists(), isTrue);
      expect(h.app!.scheduleFor(back)!.playbackAt(now).item?.id, onAir.item?.id);
    });

    test('pool types and plans\' bumper settings come back', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      final h = await open(dir);
      await h.select(mom);
      final app = h.app!;
      final pool = await app.createPool();
      await app.setPoolKind(pool, PoolKind.bumpers);
      final roles = const CustomRoles(midInterval: Duration(minutes: 10)).withBumpers(pool.id);
      await app.setGlobalPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
      final ch = app.allChannels.first;
      await app.setChannelPlan(ch, BreakPlan(mode: BreakMode.custom, roles: roles.withBumpers(null, none: true)));
      final backup = (await h.backups!.backUp(BackupReason.manual))!;

      await app.setPoolKind(pool, PoolKind.commercials);
      await app.setChannelPlan(ch, null);
      await BackupRestorer(h).restore(await h.backups!.store.read(backup));
      await h.select(h.profiles.first);

      expect(h.app!.poolById(pool.id)!.kind, PoolKind.bumpers);
      expect(h.app!.settings.commercialPlan.roles.bumperPool, pool.id);
      expect(h.app!.channelById(ch.id)!.commercialPlan!.roles.noBumpers, isTrue);
    });

    test('retro settings come back, and the device switch is neither saved nor changed', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      final h = await open(dir);
      await h.select(mom);
      final app = h.app!;
      const main = RetroSettings(
        shape: PictureShape.fill43,
        crt: CrtStyle.custom,
        overlay: OverlayThemeName.vcr,
        custom: CrtValues(scanlines: CrtLevel.high, lines: 240),
        accents: {OverlayThemeName.vcr: OverlayAccent.channel},
      );
      const own = ChannelRetro(shape: PictureShape.fit43, surround: Surround.charcoal, crt: CrtStyle.arcade);
      final ch = app.allChannels.first;
      await app.setMainRetro(main);
      await app.setChannelRetro(ch, own);
      DeviceEffects.instance.reset();
      await DeviceEffects.instance.load(h.root);
      await DeviceEffects.instance.setOn(false);
      await h.root.flush();
      final backup = (await h.backups!.backUp(BackupReason.manual))!;
      final bytes = await h.backups!.store.read(backup);
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('device_effects')));

      await app.setMainRetro(const RetroSettings());
      await app.setChannelRetro(ch, ChannelRetro.main);
      await DeviceEffects.instance.setOn(true);
      await BackupRestorer(h).restore(bytes);
      await h.select(h.profiles.first);

      expect(h.app!.settings.retro.toJson(), main.toJson());
      expect(h.app!.channelById(ch.id)!.retro, own);
      expect(DeviceEffects.instance.on, isTrue, reason: 'a restore leaves this device as it is');
      DeviceEffects.instance.reset();
    });

    test('the Guide range comes back', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 0);
      final h = await open(dir);
      await h.select(mom);
      await h.app!.setGuideRange(5);
      await h.root.flush();
      final backup = (await h.backups!.backUp(BackupReason.manual))!;
      final bytes = await h.backups!.store.read(backup);

      await h.app!.setGuideRange(3);
      await BackupRestorer(h).restore(bytes);
      await h.select(h.profiles.first);

      expect(h.app!.settings.guideRangeHours, 5);
    });

    test('on the same device: everyone stays signed in, the backup\'s channels are back', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary(), logos: 1);
      final h = await open(dir);
      final installIds = {for (final p in momAndKids()) p.id: await installIdOf(dir, p.id)};
      final backup = (await h.backups!.backUp(BackupReason.manual))!;

      await h.select(mom);
      final first = h.app!.allChannels.first;
      final name = first.name;
      await h.app!.updateChannel(first, name: 'Renamed');
      await File('${dir.path}/logos/${logoNameFor(9)}').writeAsBytes(fakeLogo(200));

      final restorer = BackupRestorer(h);
      final archive = BackupArchive.check(await h.backups!.store.read(backup));
      final plan = await restorer.plan(archive);
      expect(plan.needPassword, isEmpty);
      await restorer.restore(await h.backups!.store.read(backup));

      expect(h.notice.value, startsWith('Restored the backup from '));
      expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
      expect((await h.backups!.store.list()).map((b) => b.kind), contains(BackupReason.beforeRestore));
      for (final p in momAndKids()) {
        final session = await storageOf(dir, p.id).readRaw('session.json') as Map;
        expect(session['accessToken'], tokenFor(p.id));
        expect(await storageOf(dir, p.id).readRaw('library.json'), isNotNull);
        expect(await storageOf(dir, p.id).readRaw(AppState.signInHintFile), isNull);
        expect(await installIdOf(dir, p.id), installIds[p.id]);
      }
      // Logos already here are kept.
      expect(await File('${dir.path}/logos/${logoNameFor(9)}').exists(), isTrue);
      expect(await File('${dir.path}/logos/${logoNameFor(1)}').exists(), isTrue);
      expect(await Directory('${dir.path}/restore.tmp').exists(), isFalse);
      expect(await File('${dir.path}/restore.json').exists(), isFalse);
      expect(await Directory('${dir.path}/profiles.old').exists(), isFalse);

      await h.select(h.profiles.first);
      expect(h.app!.phase, AppPhase.ready);
      expect(h.app!.channelById(first.id)!.name, name);
    });

    test("a profile with Live TV sources: they come back, and after their refresh so do the channels as they were",
        () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final h = await open(dir);
      await h.select(mom);
      final app = h.app!;
      // A playlist and a guide picked from files (so the refresh needs no network).
      final picked = Directory('${dir.path}/picked')..createSync();
      final m3u = File('${picked.path}/list.m3u')
        ..writeAsStringSync('#EXTM3U\n${[
          for (final n in ['2.1', '4.1', '7.1']) '#EXTINF:-1 tvg-id="c$n" tvg-chno="$n",Channel $n\nhttp://p/$n.ts',
        ].join('\n')}\n');
      final now = DateTime.now().toUtc();
      String t(DateTime d) => '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}'
          '${'${d.hour}'.padLeft(2, '0')}0000 +0000';
      final start = DateTime.utc(now.year, now.month, now.day, now.hour);
      final guide = File('${picked.path}/guide.xml')
        ..writeAsStringSync('<tv><channel id="c4.1"><display-name>Channel 4.1</display-name></channel>'
            '<programme start="${t(start)}" stop="${t(start.add(const Duration(hours: 3)))}" channel="c4.1">'
            '<title>The News</title></programme></tv>');
      final source = await app.addM3uSource(
          name: 'Files',
          playlist: (name: 'list.m3u', path: m3u.path, bytes: null),
          guide: (name: 'guide.xml', path: guide.path, bytes: null));
      await app.chooseLiveChannels(source, {'c2.1', 'c4.1'});
      await app.refreshLiveSource(source, channels: false);
      // Choosing starts a refresh of its own; the one above returns at once
      // while it runs, and it writes the cache until it ends.
      while (app.live.isRefreshing(source)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final ch = app.allChannels.firstWhere((c) => c.live?.key == 'c4.1');
      await app.updateChannel(ch, favorite: true);
      final group = await app.createGroup('Locals');
      await app.setInGroup(group, ch, true);
      final numbers = {for (final c in app.allChannels) if (c.isLive) c.live!.key: c.number};
      await app.storage.flush();

      final backup = (await h.backups!.backUp(BackupReason.manual))!;
      final archive = BackupArchive.check(await h.backups!.store.read(backup));
      final part = archive.profiles[mom.id]!;
      expect((part.liveSources!['sources'] as List).single, containsPair('name', 'Files'));
      expect(part.liveFiles.keys, unorderedEquals([source.playlistFile, source.guideFile]));
      expect(archive.summary.channels, archive.profiles.values.fold(0, (n, p) => n + (p.channels?.length ?? 0)) + 2,
          reason: 'the chosen live channels count');
      final text = utf8.decode(BackupArchive.gunzip(await h.backups!.store.read(backup)));
      expect(text, isNot(contains('The News')), reason: 'no cached guide data');
      expect(text, isNot(contains('live_cache')));

      // Gone here: the sources, their files and cache.
      final profileDir = storageOf(dir, mom.id).root;
      await Directory('${profileDir.path}/live_files').delete(recursive: true);
      await Directory('${profileDir.path}/live_cache').delete(recursive: true);
      await File('${profileDir.path}/live_sources.json').delete();

      await BackupRestorer(h).restore(await h.backups!.store.read(backup));
      expect(await Directory('${profileDir.path}/live_cache').exists(), isFalse);
      await h.select(h.profiles.first);
      final again = h.app!;
      final restored = again.live.sources.single;
      expect(restored.name, 'Files');
      // As at a start: the refresh brings the channels back.
      await again.refreshLiveSource(restored);
      final live = [for (final c in again.allChannels) if (c.isLive) c];
      expect({for (final c in live) c.live!.key: c.number}, numbers);
      final news = live.firstWhere((c) => c.live!.key == 'c4.1');
      expect(news.favorite, isTrue);
      expect(again.settings.groups.single.channelIds, [news.id]);
      expect(again.scheduleFor(news)!.programAt(DateTime.now()).title, 'The News');
    });

    test('sign-ins the restore drops are signed out of Jellyfin; kept ones aren\'t', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final h = await open(dir);
      final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
      // Since the backup: a new profile, signed in, that the backup hasn't.
      final solo = Profile(id: 'solo000000000001', name: 'Solo');
      await writeProfile(dir, solo, fakeLibrary());
      await h.root.writeJson('profiles.json', [for (final p in [...momAndKids(), solo]) p.toJson()]);
      await h.root.flush();
      final signedOut = <String>[];
      await BackupRestorer(h, signOut: (s) async => signedOut.add(s.accessToken)).restore(bytes);
      await pumpEventQueue();
      expect(signedOut, [tokenFor(solo.id)]);
      expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
      // A failing server doesn't fail the restore.
      final again = (await h.backups!.build(BackupReason.manual)).bytes;
      await writeProfile(dir, solo, fakeLibrary());
      await BackupRestorer(h, signOut: (s) async => throw const SocketException('unreachable')).restore(again);
      await pumpEventQueue();
      expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
    });

    test('on the same device a Plex or Emby sign-in stays only on the same kind and server', () async {
      final [mom, kids] = momAndKids();
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      await writeProfile(dir, mom, fakeLibrary(), serverId: 'machine-1', kind: 'plex');
      await writeProfile(dir, kids, fakeLibrary(), serverId: 'emby-1', kind: 'emby');
      final h = await open(dir);
      final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
      expect((await BackupRestorer(h).plan(BackupArchive.check(bytes))).needPassword, isEmpty);
      // Kids is now on a Jellyfin server that happens to have the same id.
      await writeProfile(dir, kids, fakeLibrary(), serverId: 'emby-1');
      final plan = await BackupRestorer(h).plan(BackupArchive.check(bytes));
      expect(plan.needPassword, ['Kids']);
      await BackupRestorer(h, signOut: (s) async {}).restore(bytes);
      final kept = await storageOf(dir, mom.id).readRaw('session.json') as Map;
      expect((kept['kind'], kept['accountToken']), ('plex', accountTokenFor(mom.id)));
      final hint = await storageOf(dir, kids.id).readRaw(AppState.signInHintFile) as Map;
      expect((hint['kind'], hint['serverId']), ('emby', 'emby-1'));
    });

    test('a backup turned down changes nothing and saves no backup', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final h = await open(dir);
      final before = await File('${dir.path}/profiles.json').readAsString();
      await expectLater(BackupRestorer(h).restore(utf8.encode('nope')), throwsA(isA<BackupException>()));
      expect(await File('${dir.path}/profiles.json').readAsString(), before);
      expect(await h.backups!.store.list(), isEmpty);
    });

    group('on a new device', () {
      late Directory oldTv;
      late Directory newTv;
      late List<int> bytes;
      late Map<String, String?> oldInstallIds;

      setUp(() async {
        oldTv = await Directory('${dir.path}/old').create();
        newTv = await Directory('${dir.path}/new').create();
        await writeHousehold(oldTv, momAndKids(), fakeLibrary());
        // The old TV's own settings, without premieres (see _noPremieres).
        await writeProfile(oldTv, mom, fakeLibrary(), settings: _noPremieres()..['logoMode'] = 'always');
        oldInstallIds = {for (final p in momAndKids()) p.id: await installIdOf(oldTv, p.id)};
        final h = await open(oldTv);
        bytes = (await h.backups!.build(BackupReason.manual)).bytes;
      });

      test('paired phones stay on the device: never in a backup, kept by a restore', () async {
        final h = await open(newTv);
        final http = HttpClient();
        addTearDown(http.close);
        final remote = RemoteControl(h, firewallCheck: FirewallCheck(linux: false));
        addTearDown(remote.stop);
        await remote.setEnabled(true, port: 0);

        Future<HttpClientResponse> post(RemoteControl r, String path, Object body, {String? key}) async {
          final request = await http.postUrl(Uri.parse('http://127.0.0.1:${r.port}$path'));
          request.headers.contentType = ContentType.json;
          request.headers.set(RemoteControl.actionHeader, '1');
          if (key != null) request.headers.set(RemoteControl.keyHeader, key);
          request.write(jsonEncode(body));
          return request.close();
        }

        final keys = <String>[];
        for (final name in ['Kitchen Pixel · Chrome', 'Den iPhone · Safari']) {
          remote.openPairing();
          final response = await post(remote, '/api/pair', {'code': remote.pairingCode, 'name': name});
          keys.add((jsonDecode(await utf8.decodeStream(response)) as Map)['key'] as String);
        }
        remote.closePairing();
        await h.root.flush();
        final hashes = [for (final p in remote.pairings) p.keyHash];

        final backup = (await h.backups!.build(BackupReason.manual)).bytes;
        final text = utf8.decode(gzip.decode(backup), allowMalformed: true);
        for (final secret in [...hashes, ...keys, 'Kitchen Pixel', 'Den iPhone', RemoteControl.pairingsFile]) {
          expect(text, isNot(contains(secret)));
        }
        expect(BackupArchive.check(backup).remote, {'enabled': true}, reason: 'the on/off setting travels');

        // Another device's backup, restored here: this TV's phones still work.
        await BackupRestorer(h).restore(bytes);
        final after = RemoteControl(h, firewallCheck: FirewallCheck(linux: false), dispatch: (_, _) => true);
        addTearDown(after.stop);
        await after.load();
        expect(after.pairings.map((p) => p.name), containsAll(['Kitchen Pixel · Chrome', 'Den iPhone · Safari']));
        await after.setEnabled(true, port: 0);
        final pressed = await post(after, '/api/key', {'key': 'up'}, key: keys.first);
        await pressed.drain<void>();
        expect(pressed.statusCode, 200);
      });

      test('sign-ins are left out, hints written, and device ids are new', () async {
        final h = await open(newTv);
        expect(h.welcomeBack, isNull, reason: 'no backups here yet');
        expect(h.profiles, hasLength(1), reason: 'a first profile, as on any first run');
        final plan = await BackupRestorer(h).plan(BackupArchive.check(bytes));
        expect(plan.needPassword, ['Mom', 'Kids']);
        await BackupRestorer(h).restore(bytes);

        expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
        for (final p in momAndKids()) {
          expect(await storageOf(newTv, p.id).readRaw('session.json'), isNull);
          expect(await storageOf(newTv, p.id).readRaw('library.json'), isNull);
          final hint = await storageOf(newTv, p.id).readRaw(AppState.signInHintFile) as Map;
          expect(hint['userName'], p.name.toLowerCase());
          expect(hint['serverId'], 's1');
          final installId = await installIdOf(newTv, p.id);
          expect(installId, startsWith(AppSettings.deviceIdPrefix));
          expect(installId, isNot(oldInstallIds[p.id]));
        }
        await h.select(h.profileById(mom.id)!);
        expect(h.app!.phase, AppPhase.signedOut);
        expect(h.app!.signInHint!['serverUrl'], 'http://127.0.0.1:9');
      });

      test('signing in to the same server brings the same programs at the same times', () async {
        final old = await open(oldTv);
        await old.select(mom);
        final now = DateTime.now();
        final onOld = {
          for (final c in old.app!.allChannels)
            c.id: (c.name, old.app!.scheduleFor(c)?.programAt(now).title, old.app!.scheduleFor(c)?.programAt(now).start),
        };
        expect(onOld.values.where((v) => v.$2 != null), isNotEmpty);
        final blocksOnOld = [for (final b in old.app!.blocks) b.id];
        expect(blocksOnOld, isNotEmpty);
        old.leave();

        final h = await open(newTv);
        await BackupRestorer(h).restore(bytes);
        await h.select(h.profileById(mom.id)!);
        final app = h.app!;
        await app.completeSignIn(_session('s1'), _server());
        expect(app.phase, AppPhase.ready);
        // A sign-in that knows its server's id (every Plex one) opens that
        // server's analysis results without looking the id up.
        await pumpEventQueue();
        expect(app.analysisCache, isNotNull);
        final onNew = {
          for (final c in app.allChannels)
            c.id: (c.name, app.scheduleFor(c)?.programAt(now).title, app.scheduleFor(c)?.programAt(now).start),
        };
        expect(onNew, onOld);
        expect([for (final b in app.blocks) b.id], blocksOnOld);
        expect(app.settings.logoMode, LogoMode.always);
        expect(await storageOf(newTv, mom.id).readRaw(AppState.signInHintFile), isNull);
        expect(app.settings.installId, isNot(oldInstallIds[mom.id]));
      });

      test('signing in to a different server keeps the settings and starts a new lineup', () async {
        // Something only the backup's lineup has.
        final old = await open(oldTv);
        await old.select(mom);
        await old.app!.updateChannel(old.app!.allChannels.first, name: 'Only in the backup');
        bytes = (await old.backups!.build(BackupReason.manual)).bytes;
        old.leave();

        final h = await open(newTv);
        await BackupRestorer(h).restore(bytes);
        await h.select(h.profileById(mom.id)!);
        final app = h.app!;
        await app.completeSignIn(_session('another-server'), _server());
        expect(app.phase, AppPhase.ready);
        expect(app.allChannels, isNotEmpty);
        expect(app.allChannels.map((c) => c.name), isNot(contains('Only in the backup')));
        expect(app.blocks, isEmpty);
        expect(app.settings.logoMode, LogoMode.always);
        expect(await storageOf(newTv, mom.id).readRaw(AppState.signInHintFile), isNull);
      });

      test('Live TV export settings come back with their tuner ids and ports', () async {
        final export = ExportSettings.off
            .copyWith(enabled: true)
            .withExported(mom.id, true, portFree: (p) => p == 5010);
        final old = await AppStorage.at(oldTv);
        await old.writeJson('export.json', export.toJson());
        await old.flush();
        final h0 = await open(oldTv);
        bytes = (await h0.backups!.build(BackupReason.manual)).bytes;
        final archive = BackupArchive.check(bytes);
        expect(archive.exportOn, isTrue);

        final h = await open(newTv);
        expect((await BackupRestorer(h).plan(archive)).exportMoves, isTrue);
        // Android has no Live TV export: nothing moves there.
        PlatformInfo.debugOverride = TargetPlatform.android;
        try {
          expect((await BackupRestorer(h).plan(archive)).exportMoves, isFalse);
        } finally {
          PlatformInfo.debugReset();
        }
        await BackupRestorer(h).restore(bytes);
        final restored = ExportSettings.fromJson(await h.root.readJson('export.json'));
        expect(restored, export);
        expect(restored.profiles[mom.id]!.port, 5010);
        expect(restored.profiles[mom.id]!.deviceId, export.profiles[mom.id]!.deviceId);
      });
    });

    test('Live TV export stops for the restore and starts again with the backup\'s settings', () async {
      await writeHousehold(dir, momAndKids(), fakeLibrary());
      final h = await open(dir);
      final service = h.export = ExportService(h, ssdp: () => SsdpResponder()..sendOverride = (_, _, _) {});
      addTearDown(() async {
        await service.stop();
        await h.setExportedProfiles({});
      });
      await service.load();
      Future<int> freePort() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = s.port;
        await s.close();
        return port;
      }

      // Backed up exporting Mom on one port…
      await service.setProfileExported(mom.id, true);
      final backupPort = await freePort();
      await service.setPort(mom.id, backupPort);
      await service.setEnabled(true);
      final deviceId = service.settings.profiles[mom.id]!.deviceId;
      final backup = (await h.backups!.backUp(BackupReason.manual))!;
      // …then moved to another, and streaming there.
      final laterPort = await freePort();
      await service.setPort(mom.id, laterPort);
      expect(service.serverOf(mom.id)!.port, laterPort);

      await BackupRestorer(h).restore(await h.backups!.store.read(backup));
      expect(service.settings.profiles[mom.id]!.port, backupPort);
      expect(service.settings.profiles[mom.id]!.deviceId, deviceId);
      expect(service.serverOf(mom.id)!.port, backupPort);
      expect(h.appFor(mom.id), isNotNull, reason: 'kept loaded for export again');
      await expectLater(Socket.connect(InternetAddress.loopbackIPv4, laterPort), throwsA(isA<SocketException>()));
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, backupPort);
      socket.destroy();
    });

    group('after a crash', () {
      late List<int> bytes;
      late Household h;

      setUp(() async {
        await writeHousehold(dir, momAndKids(), fakeLibrary());
        h = await openHousehold(dir, start: false);
        bytes = (await h.backups!.build(BackupReason.manual)).bytes;
        // The setup changes after the backup: one profile only.
        final solo = Profile(id: 'solo000000000001', name: 'Solo');
        await writeProfile(dir, solo, fakeLibrary());
        await h.root.writeJson('profiles.json', [solo.toJson()]);
        await h.root.flush();
      });

      test('a journal in its swap phase is finished at start', () async {
        await BackupRestorer(h).stage(BackupArchive.check(bytes));
        // As if the power went just after the profiles were moved aside.
        await Directory('${dir.path}/profiles').rename('${dir.path}/profiles.old');
        final again = await open(dir);
        expect(again.profiles.map((p) => p.name), ['Mom', 'Kids']);
        expect(await Directory('${dir.path}/profiles/${mom.id}').exists(), isTrue);
        expect(await Directory('${dir.path}/profiles/solo000000000001').exists(), isFalse);
        expect(await Directory('${dir.path}/restore.tmp').exists(), isFalse);
        expect(await Directory('${dir.path}/profiles.old').exists(), isFalse);
        expect(await File('${dir.path}/restore.json').exists(), isFalse);
      });

      test('a staged restore with no journal is thrown away', () async {
        await BackupRestorer(h).stage(BackupArchive.check(bytes));
        await File('${dir.path}/restore.json').delete();
        final again = await open(dir);
        expect(again.profiles.map((p) => p.name), ['Solo']);
        expect(again.app, isNotNull);
        expect(await Directory('${dir.path}/restore.tmp').exists(), isFalse);
      });
    });
  });

  group('first run', () {
    late List<int> bytes;
    late Directory fresh;

    setUp(() async {
      final old = await Directory('${dir.path}/old').create();
      await writeHousehold(old, momAndKids(), fakeLibrary());
      final h = await openHousehold(old, start: false);
      bytes = (await h.backups!.build(BackupReason.daily)).bytes;
      fresh = await Directory('${dir.path}/fresh').create();
      // Android brought back only the cloud copy.
      final store = BackupStore(Directory('${fresh.path}/backups'));
      await store.cloudDir.create(recursive: true);
      await store.cloudCopy.writeAsBytes(bytes);
    });

    test('Welcome back offers the newest backup, and Restore it restores it', () async {
      final h = await open(fresh);
      expect(h.started, isTrue);
      expect(h.welcomeBack, isNotNull);
      expect(h.welcomeBack!.summary.profiles, ['Mom', 'Kids']);
      expect(h.profiles, isEmpty);
      expect(await File('${fresh.path}/profiles.json').exists(), isFalse);

      await BackupRestorer(h).restore(await h.backups!.store.read(h.welcomeBack!));
      expect(h.welcomeBack, isNull);
      expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
      // Nothing to keep from an empty first run.
      expect((await h.backups!.store.list()).map((b) => b.kind), isNot(contains(BackupReason.beforeRestore)));
    });

    test('Start fresh makes a first profile and keeps the backups', () async {
      final h = await open(fresh);
      await h.startFresh();
      expect(h.welcomeBack, isNull);
      expect(h.profiles, hasLength(1));
      expect(h.app, isNotNull);
      expect(await h.backups!.store.list(), hasLength(1));
    });

    test('a new install offers a restore at sign-in, and backs up nothing first', () async {
      final h = await open(await Directory('${dir.path}/new-install').create());
      expect(h.welcomeBack, isNull);
      expect(h.firstRun, isTrue);
      expect(await h.hasNothingToKeep(), isTrue);
      expect((await BackupRestorer(h).plan(BackupArchive.check(bytes))).backsUpFirst, isFalse);
      await BackupRestorer(h).restore(bytes);
      expect(h.profiles.map((p) => p.name), ['Mom', 'Kids']);
      expect(h.firstRun, isFalse);
      expect(await h.backups!.store.list(), isEmpty);
      // From now on a restore keeps what's here first.
      expect(await h.hasNothingToKeep(), isFalse);
      expect((await BackupRestorer(h).plan(BackupArchive.check(bytes))).backsUpFirst, isTrue);
    });

    test('a new install that hasn\'t signed in makes no backups', () async {
      final h = await open(await Directory('${dir.path}/empty-install').create());
      expect(await h.backups!.dailyCheck(), isNull);
      expect(await h.backups!.backUp(BackupReason.manual), isNull);
      expect(await h.backups!.store.list(), isEmpty);
    });

    test('an existing setup isn\'t a first run', () async {
      final existing = await Directory('${dir.path}/existing').create();
      await writeHousehold(existing, [Profile(id: 'solo000000000001', name: 'Solo')], fakeLibrary());
      final h = await open(existing);
      expect(h.firstRun, isFalse);
      expect(await h.hasNothingToKeep(), isFalse);
    });

    test('no Welcome back with no backups, or once there are profiles', () async {
      final empty = await open(await Directory('${dir.path}/empty').create());
      expect(empty.welcomeBack, isNull);
      expect(empty.profiles, hasLength(1));

      final h = await open(fresh);
      await h.startFresh();
      h.leave();
      final again = await open(fresh);
      expect(again.welcomeBack, isNull);
    });
  });
}

class _CountingScheduler extends BackupScheduler {
  _CountingScheduler(Household household) : super(household, BackupStore(Directory('${household.root.root.path}/backups')));

  int checks = 0;

  @override
  Future<StoredBackup?> dailyCheck() async {
    checks++;
    return null;
  }
}
