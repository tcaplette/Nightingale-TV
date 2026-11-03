import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:image/image.dart' as img;
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/export/m3u_writer.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/export/xmltv_writer.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/server/server_log.dart';
import 'package:nightingale_tv/setup/accounts.dart';
import 'package:nightingale_tv/setup/setup_server.dart';
import 'package:nightingale_tv/setup/web_files.dart';
import 'package:xml/xml.dart';

import '../integration_test/fake_jellyfin.dart';
import 'fixtures.dart';
import 'setup_client.dart';

/// The web admin's station endpoints (docker-web-admin 4.2, 4.5–4.14),
/// over a profile signed in to a fake Jellyfin through the API.
void main() {
  late Directory dir;
  late Household household;
  late Accounts accounts;
  late SetupServer setup;
  late Client admin;
  late FakeJellyfin jellyfin;
  late String id;
  AppState? signedIn;
  final bodies = <String>[];
  final iterations = Accounts.iterations;

  setUpAll(() => Accounts.iterations = 1000);
  tearDownAll(() => Accounts.iterations = iterations);

  setUp(() async {
    BackupArchive.useIsolate = false;
    bodies.clear();
    ServerLog.output = (_) {};
    dir = await Directory.systemTemp.createTemp('nightingale_tv_station');
    household = Household(await AppStorage.at(dir), runAnalysis: false, serverMode: true);
    household.backups = BackupScheduler(household, BackupStore(Directory('${dir.path}/backups')));
    accounts = await Accounts.load(dir);
    setup = SetupServer(household, accounts, port: 0, web: WebFiles(Directory('${dir.path}/no_web')));
    await setup.start();
    await household.start();
    admin = Client(setup.boundPort!);
    jellyfin = await FakeJellyfin.start(
        fakeItems(shows: const {'Alpha': 10, 'Beta': 4, 'Gamma': 6}, ratings: const {'Alpha': 'TV-MA', 'Beta': 'TV-G'}, movies: 3));
    final r = await admin.post('/api/v1/password', {'token': accounts.setupToken, 'name': 'sam', 'password': 'correct horse'});
    expect(r.status, 200);
    id = household.profiles.single.id;
  });

  tearDown(() async {
    // A scan started by a test finishes before its folder goes.
    for (var i = 0; i < 500 && (signedIn?.isRefreshingLibrary ?? false); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    signedIn = null;
    admin.close();
    await setup.stop();
    await household.export?.stop();
    await household.closeAll();
    accounts.close();
    await jellyfin.close();
    await dir.delete(recursive: true);
    BackupArchive.useIsolate = true;
    ServerLog.reset();
  });

  /// GET [path], keeping the body for the token search.
  Future<Object?> get(String path) async {
    final r = await admin.get(path);
    expect(r.status, 200, reason: '$path: ${r.json}');
    bodies.add(utf8.decode(r.bytes, allowMalformed: true));
    return r.json;
  }

  /// A PUT or DELETE with the current revision of [path] (or [of]).
  Future<Answer> edit(String method, String path, [Object? body, String? of]) =>
      admin.edit(method, path, body: body, revisionOf: of ?? path);

  /// Signs the profile in to the fake Jellyfin through the API and waits
  /// for its library.
  Future<AppState> signIn() async {
    final base = '/api/v1/profiles/$id/sign-in';
    await admin.post(base, {'action': 'start'});
    await admin.post(base, {'action': 'connect', 'address': jellyfin.url});
    await admin.post(base, {'action': 'choosePassword'});
    final step = (await admin.post(base, {'action': 'password', 'user': 'howard', 'password': FakeJellyfin.password}))
        .json! as Map;
    expect(step['finished'], isTrue, reason: '$step');
    final app = (await household.appForSetup(id))!;
    for (var i = 0; i < 300 && (app.phase != AppPhase.ready || app.channels.isEmpty); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(app.phase, AppPhase.ready);
    return signedIn = app;
  }

  group('profiles that aren\'t exported (4.2)', () {
    test('a signed-out profile is refused with 503 where the library is needed', () async {
      final r = await admin.get('/api/v1/profiles/$id/library/browse');
      expect(r.status, 503);
      expect(r.json, {'error': SetupServer.signedOutText});
      final refresh = await admin.post('/api/v1/profiles/$id/library/refresh');
      expect(refresh.status, 503);
      final summary = (await get('/api/v1/profiles/$id/library'))! as Map;
      expect(summary['signedIn'], isFalse);
    });

    test('renaming a channel on a signed-in profile that isn\'t exported is saved; 10 minutes later it is let go',
        () async {
      var now = DateTime.now();
      setup.clock = () => now;
      final app = await signIn();
      final ch = app.allChannels.first;
      final r = await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'name': 'Renamed'});
      expect(r.status, 200, reason: '${r.json}');
      final saved = jsonDecode(await File('${dir.path}/profiles/$id/channels.json').readAsString()) as List;
      expect(saved.any((c) => (c as Map)['id'] == ch.id && c['name'] == 'Renamed'), isTrue);
      expect(setup.isBorrowed(id), isTrue);
      now = now.add(const Duration(minutes: 11));
      await setup.releaseIdle();
      expect(setup.isBorrowed(id), isFalse);
    });
  });

  group('library (4.5)', () {
    test('summary, refresh with its progress, folder browsing', () async {
      await signIn();
      final summary = (await get('/api/v1/profiles/$id/library'))! as Map;
      expect((summary['signedIn'], summary['series'], summary['episodes'], summary['movies']), (true, 3, 20, 3));
      final refresh = await admin.post('/api/v1/profiles/$id/library/refresh');
      expect(refresh.status, 200);
      expect((refresh.json! as Map)['syncing'], isTrue);
      final app = household.appFor(id) ?? (await household.appForSetup(id))!;
      for (var i = 0; i < 300 && app.isRefreshingLibrary; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(((await get('/api/v1/profiles/$id/library'))! as Map)['syncing'], isFalse);
      final libraries = (await get('/api/v1/profiles/$id/library/browse'))! as List;
      expect(libraries.map((l) => (l as Map)['name']), containsAll(['Commercials', 'TV Shows']));
      final tree = (await get('/api/v1/profiles/$id/library/browse?library=${FakeJellyfin.tvLibrary}'))! as List;
      final root = tree.single as Map;
      expect(root['name'], 'tv');
      expect((root['children'] as List).map((c) => (c as Map)['name']), ['Alpha', 'Beta', 'Gamma']);
    });

    test("Jellyfin logo: the picture comes from the setup server, and no response holds the token", () async {
      final app = await signIn();
      final ch = app.allChannels.first;
      final show = app.library.series.first;
      final logo = ChannelIcon(kind: ChannelIconKind.jellyfin, value: show.id);
      expect((await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'icon': logo.toJson()})).status, 200);
      final picture = await admin.get('/api/v1/profiles/$id/channels/${ch.id}/logo');
      expect(picture.status, 200);
      expect(picture.headers.contentType?.mimeType, 'image/png');
      final art = await admin.get('/api/v1/profiles/$id/art/${show.id}?kind=primary');
      expect(art.status, 200);
      for (final path in [
        '/api/v1/status',
        '/api/v1/profiles',
        '/api/v1/profiles/$id',
        '/api/v1/profiles/$id/library',
        '/api/v1/profiles/$id/channels',
        '/api/v1/profiles/$id/channels/${ch.id}',
        '/api/v1/profiles/$id/guide?hours=24',
        '/api/v1/profiles/$id/blocks',
        '/api/v1/profiles/$id/groups',
        '/api/v1/profiles/$id/commercials',
        '/api/v1/profiles/$id/live-sources',
        '/api/v1/profiles/$id/icons',
        '/api/v1/profiles/$id/sign-in',
        '/api/v1/me',
        '/api/v1/users',
      ]) {
        await get(path);
      }
      final everything = bodies.join('\n');
      expect(everything, isNot(contains(FakeJellyfin.accessToken)));
      expect(everything, isNot(contains(FakeJellyfin.password)));
    });
  });

  group('channels (4.6)', () {
    test('renumbering: channel 2 set to 1 swaps with channel 1, as on the TV', () async {
      final app = await signIn();
      await admin.post('/api/v1/profiles/$id/channels', {'kind': 'block', 'name': 'Second'});
      final sorted = [...app.allChannels]..sort((a, b) => a.number.compareTo(b.number));
      final one = sorted[0], two = sorted[1];
      final (n1, n2) = (one.number, two.number);
      final r = await edit('PUT', '/api/v1/profiles/$id/channels/${two.id}', {'number': n1});
      expect(r.status, 200, reason: '${r.json}');
      expect((app.channelById(two.id)!.number, app.channelById(one.id)!.number), (n1, n2));
      final bad = await edit('PUT', '/api/v1/profiles/$id/channels/${two.id}', {'number': 0});
      expect(bad.status, 400);
    });

    test('the whole model sent back with "main setting" clears the channel\'s own logo mode and plan', () async {
      final app = await signIn();
      final ch = app.allChannels.first;
      await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'logoMode': 'always', 'commercialPlan': {'mode': 'off'}});
      expect((ch.logoMode, ch.commercialPlan?.mode.name), (LogoMode.always, 'off'));
      final model = ((await get('/api/v1/profiles/$id/channels/${ch.id}'))! as Map).cast<String, Object?>()
        ..remove('logoMode')
        ..remove('commercialPlan')
        ..remove('commercials');
      final r = await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', model);
      expect(r.status, 200, reason: '${r.json}');
      expect((ch.logoMode, ch.commercialPlan), (null, null));
    });

    test('retro: one setting edited, the rest follow main; the whole model without it follows main', () async {
      final app = await signIn();
      final ch = app.allChannels.first;
      final path = '/api/v1/profiles/$id/channels/${ch.id}';
      await app.setMainRetro(const RetroSettings(shape: PictureShape.fit43));
      final r = await edit('PUT', path, {'retro': {'crt': 'arcade'}});
      expect(r.status, 200, reason: '${r.json}');
      expect(ch.retro, const ChannelRetro(crt: CrtStyle.arcade));
      final view = (((await get(path))! as Map)['view'] as Map)['retro'] as Map;
      expect(view['crt'], 'arcade');
      expect(view['shape'], 'fit43', reason: 'the values in effect');
      final model = ((await get(path))! as Map).cast<String, Object?>()..remove('retro');
      expect((await edit('PUT', path, model)).status, 200);
      expect(ch.retro.followsMain, isTrue);
    });

    test('retro: an unknown value or a path is a 400 and changes nothing', () async {
      final app = await signIn();
      final ch = app.allChannels.first;
      final path = '/api/v1/profiles/$id/channels/${ch.id}';
      await app.setChannelRetro(ch, const ChannelRetro(crt: CrtStyle.softTube));
      for (final bad in [
        {'crt': 'plasma'},
        {'shape': 'wide'},
        {'surround': 'blue'},
        {'overlay': 'neon'},
        {'surround': 'image', 'surroundImage': '../../settings.json'},
        'arcade',
      ]) {
        expect((await edit('PUT', path, {'retro': bad})).status, 400, reason: '$bad');
        expect(ch.retro, const ChannelRetro(crt: CrtStyle.softTube));
      }
    });

    test('retro: the main settings and Custom style read and edit; the device switch is not there', () async {
      final app = await signIn();
      final path = '/api/v1/profiles/$id/retro';
      final r = await edit('PUT', path, {
        'crt': 'custom',
        'custom': {'scanlines': 'high', 'lines': 240},
        'accents': {'vcr': 'channel'},
      });
      expect(r.status, 200, reason: '${r.json}');
      final retro = app.settings.retro;
      expect(retro.crt, CrtStyle.custom);
      expect(retro.custom.scanlines, CrtLevel.high);
      expect(retro.custom.lines, 240);
      expect(retro.custom.glow, CrtLevel.low, reason: 'left out, stays');
      expect(retro.accentOf(OverlayThemeName.vcr), OverlayAccent.channel);
      expect((await edit('PUT', path, {'custom': {'lines': 300}})).status, 400);
      expect((await edit('PUT', path, {'crt': 'plasma'})).status, 400);
      expect(app.settings.retro.custom.lines, 240);
      final read = (await get(path))! as Map;
      expect((read['retro'] as Map)['crt'], 'custom');
      expect(read.toString(), isNot(contains('effects')));
    });

    test('a block channel is added and removed; a generated one can only be hidden', () async {
      final app = await signIn();
      final made = await admin.post('/api/v1/profiles/$id/channels', {'kind': 'block', 'name': 'Saturday'});
      expect(made.status, 200, reason: '${made.json}');
      final cid = (made.json! as Map)['id'] as String;
      expect(app.channelById(cid)!.blockOnly, isTrue);
      expect((await edit('DELETE', '/api/v1/profiles/$id/channels/$cid', null, '/api/v1/profiles/$id/channels')).status, 200);
      expect(app.channelById(cid), isNull);
      final generated = app.allChannels.first.id;
      final refused = await edit('DELETE', '/api/v1/profiles/$id/channels/$generated', null, '/api/v1/profiles/$id/channels');
      expect(refused.status, 400);
      expect(app.channelById(generated), isNotNull);
      final music = await admin.post('/api/v1/profiles/$id/channels', {'kind': 'music', 'source': {'songs': true}});
      expect(music.status, 400, reason: 'no songs in this library');
    });

    test('a custom channel: added from a collection, edited, reshuffled, slotted, removed', () async {
      final app = await signIn();
      jellyfin.collections['box80s'] = ['Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1'];
      final base = '/api/v1/profiles/$id/channels';
      const root = {'itemId': 'box80s', 'libraryId': 'tv', 'label': '80s Sitcoms (collection)'};
      final empty = await admin.post(base, {'kind': 'custom', 'name': 'Nothing', 'source': <String, Object?>{}});
      expect(empty.status, 400);
      final made = await admin.post(base, {
        'kind': 'custom',
        'name': '80s TV',
        'order': 'weighted',
        'source': {
          'roots': [root]
        },
      });
      expect(made.status, 200, reason: '${made.json}');
      final cid = (made.json! as Map)['id'] as String;
      final ch = app.channelById(cid)!;
      expect(ch.playlist.toSet(), {'Alpha-e1', 'Alpha-e2', 'Beta-e1', 'movie-1'});
      expect(ch.order, PlaybackOrder.weighted);
      final guide = (await get('/api/v1/profiles/$id/guide'))! as Map;
      final row = (guide['channels'] as List).cast<Map>().firstWhere((c) => c['id'] == cid);
      expect(row['airings'], isNotEmpty);

      final path = '$base/$cid';
      final patched = await edit('PATCH', path, {
        'source': {
          'seriesKeys': ['gamma|2000'],
          'roots': [root]
        }
      }, path);
      expect(patched.status, 200, reason: '${patched.json}');
      expect(ch.playlist.where((i) => i.startsWith('Gamma')), hasLength(6));

      final slotted = await edit('PUT', path, {
        'slot': {'minutes': 30, 'tail': 'offline'}
      });
      expect(slotted.status, 200, reason: '${slotted.json}');
      expect(ch.slotRule?.tail, TailMode.offline);
      expect((await edit('PUT', path, {'slot': {'minutes': 45}})).status, 400);
      expect((await edit('PUT', path, {'order': 'someday'})).status, 400);
      expect((await edit('PUT', path, {'slot': null})).status, 200);
      expect(ch.slotRule, isNull);

      final shuffled = await admin.post('$path/reshuffle');
      expect(shuffled.status, 200);
      expect(ch.generation, 1);

      expect((await edit('DELETE', path, null, base)).status, 200);
      expect(app.channelById(cid), isNull);
    });

    test("a generated channel's source is refused with the TV's message; its slot length isn't", () async {
      final app = await signIn();
      final ch = app.allChannels.firstWhere((c) => c.auto);
      final path = '/api/v1/profiles/$id/channels/${ch.id}';
      final r = await edit('PATCH', path, {
        'source': {
          'seriesKeys': ['gamma|2000']
        }
      });
      expect(r.status, 400);
      expect(r.json, {'error': 'Only channels you added can change what they play.'});
      final model = ((await get(path))! as Map).cast<String, Object?>();
      expect((await edit('PUT', path, model)).status, 200, reason: 'the whole model, source unchanged, is fine');
      expect((await edit('PUT', path, {'slot': {'minutes': 60, 'tail': 'truncate'}})).status, 200);
      expect(ch.slotRule?.length, const Duration(minutes: 60));
      expect((await admin.post('$path/reshuffle')).status, ch.order == PlaybackOrder.cyclic ? 400 : 200);
    });

    test('an offline image uploads beside the icons, but is not listed as one', () async {
      await signIn();
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));
      final r = await admin.call('POST', '/api/v1/profiles/$id/icons?name=card.png&kind=offline', bytes: png);
      expect(r.status, 200, reason: '${r.json}');
      final name = (r.json! as Map)['name'] as String;
      expect(name, startsWith('offline-'));
      expect((await admin.get('/api/v1/profiles/$id/icons/$name')).status, 200);
      expect(((await get('/api/v1/profiles/$id/icons'))! as Map)['icons'], isEmpty);
    });

    test('reset fails safely: when the safety backup can\'t be saved nothing is reset', () async {
      final app = await signIn();
      final ch = app.allChannels.first;
      await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'name': 'Mine'});
      // The backups folder can't be written.
      final blocked = File('${dir.path}/blocked')..writeAsStringSync('');
      household.backups = BackupScheduler(household, BackupStore(Directory(blocked.path)));
      final r = await admin.post('/api/v1/profiles/$id/channels/reset');
      expect(r.status, 409);
      expect((r.json! as Map)['error'], startsWith("Couldn't save a safety backup first, so nothing was reset"));
      expect(app.channelById(ch.id)!.name, 'Mine');
    });

    test('main logo mode and premieres', () async {
      final app = await signIn();
      expect((await edit('PUT', '/api/v1/profiles/$id/logo', {'logoMode': 'off'})).status, 200);
      expect(app.settings.logoMode, LogoMode.off);
      final premieres = {...app.settings.premieres.toJson(), 'enabled': !app.settings.premieres.enabled};
      expect((await edit('PUT', '/api/v1/profiles/$id/premieres', {'premieres': premieres})).status, 200);
      expect(app.settings.premieres.toJson(), premieres);
    });
  });

  group('guide (4.7)', () {
    test("the guide's airings are the export's XMLTV programmes for the same window", () async {
      final app = await signIn();
      // The profile's Guide range doesn't shorten it.
      await app.setGuideRange(3);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day, now.hour);
      final guide = (await get('/api/v1/profiles/$id/guide?from=${Uri.encodeQueryComponent(from.toIso8601String())}&hours=24'))!
          as Map;
      expect(DateTime.parse(guide['to'] as String).difference(DateTime.parse(guide['from'] as String)),
          const Duration(hours: 24));
      final xml = XmlDocument.parse(buildXmltv(
          channels: [for (final c in app.channels) if (!c.isLive) c],
          scheduleFor: app.scheduleFor,
          library: app.library,
          urls: ExportUrls(Uri.parse('http://127.0.0.1:5004')),
          now: now));
      final to = from.add(const Duration(hours: 24));
      String key(String channel, DateTime start, DateTime end) => '$channel ${xmltvTime(start)} ${xmltvTime(end)}';
      final fromXml = {
        for (final p in xml.findAllElements('programme'))
          if (DateTime.parse(_isoOf(p.getAttribute('start')!)).isBefore(to))
            '${p.getAttribute('channel')} ${p.getAttribute('start')} ${p.getAttribute('stop')} ${p.getElement('title')?.innerText}',
      };
      final fromGuide = {
        for (final c in (guide['channels'] as List).cast<Map<String, Object?>>())
          for (final a in (c['airings'] as List).cast<Map<String, Object?>>())
            '${key('${c['number']}', DateTime.parse(a['start'] as String).toLocal(), DateTime.parse(a['end'] as String).toLocal())} ${a['title']}',
      };
      expect(fromGuide, isNotEmpty);
      expect(fromGuide, fromXml);
      final capped = (await get('/api/v1/profiles/$id/guide?hours=100'))! as Map;
      expect(DateTime.parse(capped['to'] as String).difference(DateTime.parse(capped['from'] as String)),
          const Duration(hours: 24));
    });
  });

  group('custom icons (4.8)', () {
    test('a big icon: 413 and "That picture is too big (5 MB at most)."', () async {
      await signIn();
      final answer = await oversize(setup.boundPort!, 'POST', '/api/v1/profiles/$id/icons?name=huge.png', 12 << 20,
          cookie: admin.cookie);
      expect(answer, startsWith('HTTP/1.1 413'));
      expect(answer, contains('That picture is too big (5 MB at most).'));
    });

    test("an uploaded PNG becomes channel 7's icon and its logo serves it", () async {
      final app = await signIn();
      final png = img.encodePng(img.Image(width: 40, height: 20)..clear(img.ColorRgb8(200, 30, 30)));
      final up = await admin.call('POST', '/api/v1/profiles/$id/icons?name=logo.png', bytes: png);
      expect(up.status, 200, reason: '${up.json}');
      final name = (up.json! as Map)['name'] as String;
      final ch = app.allChannels.first;
      final icon = ChannelIcon(kind: ChannelIconKind.custom, value: name);
      expect((await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'icon': icon.toJson()})).status, 200);
      expect(app.channelById(ch.id)!.icon.value, name);
      expect(app.icons.fileFor(name).existsSync(), isTrue, reason: 'where the stream cards read it');
      final logo = await admin.get('/api/v1/profiles/$id/channels/${ch.id}/logo');
      expect(img.decodePng(Uint8List.fromList(logo.bytes))!.width, 40);
      expect(((await get('/api/v1/profiles/$id/icons'))! as Map)['icons'], [name]);
      final deleted = await edit('DELETE', '/api/v1/profiles/$id/icons/$name', null, '/api/v1/profiles/$id/icons');
      expect(deleted.status, 200);
      expect(app.channelById(ch.id)!.icon.kind, ChannelIconKind.builtin);
      expect((await admin.get('/api/v1/profiles/$id/icons/../../profiles.json')).status, 404);
    });
  });

  group('groups and tabs (4.9)', () {
    test('a group is made, filled, renamed, moved, hidden and deleted', () async {
      final app = await signIn();
      final chs = app.allChannels.take(2).map((c) => c.id).toList();
      final made = await admin.post('/api/v1/profiles/$id/groups', {'name': 'Kids', 'channelIds': chs});
      expect(made.status, 200, reason: '${made.json}');
      final gid = (made.json! as Map)['created'] as String;
      expect(app.settings.groups.single.channelIds, chs);
      final groups = '/api/v1/profiles/$id/groups';
      expect((await edit('PUT', '$groups/$gid/channels', {'channelIds': [chs.last]}, groups)).status, 200);
      expect(app.settings.groups.single.channelIds, [chs.last]);
      expect((await edit('PUT', '$groups/$gid', {'name': 'Family'}, groups)).status, 200);
      expect(app.settings.groups.single.name, 'Family');
      final order = [...app.allTabIds];
      final moved = [order.first, gid, ...order.skip(1).where((t) => t != gid)];
      final tabs = await edit('PUT', '/api/v1/profiles/$id/tabs', {'order': moved, 'hidden': [gid]});
      expect(tabs.status, 200, reason: '${tabs.json}');
      expect(app.allTabIds, moved);
      expect(app.settings.hiddenTabs, {gid});
      expect((await edit('DELETE', '$groups/$gid', null, groups)).status, 200);
      expect(app.settings.groups, isEmpty);
    });
  });

  group('blocks (4.10)', () {
    test('round trip: a block read and written back unchanged is saved identical', () async {
      final app = await signIn();
      final blocks = '/api/v1/profiles/$id/blocks';
      final draft = ((await get(blocks))! as Map)['newBlock'] as Map<String, Object?>;
      final show = app.library.series.first.key;
      final bad = await admin.post(blocks, {...draft, 'title': ''});
      expect(bad.status, 400);
      expect((bad.json! as Map)['error'], 'Give the block a title.');
      final made = await admin.post(blocks, {
        ...draft,
        'title': 'Cartoons',
        'source': {'episodes': true, 'movies': false, 'seriesKeys': [show]},
      });
      expect(made.status, 200, reason: '${made.json}');
      final bid = (made.json! as Map)['id'] as String;
      final before = jsonEncode(app.blocks.single.toJson());
      final read = (await get('$blocks/$bid'))! as Map;
      final again = await edit('PUT', '$blocks/$bid', read);
      expect(again.status, 200, reason: '${again.json}');
      expect(jsonEncode(app.blocks.single.toJson()), before);
      final playlist = (await get('$blocks/$bid/playlist'))! as Map;
      expect(playlist['total'], app.blockPlaylist(app.blocks.single).length);
      final clash = await admin.post(blocks, {...read, 'id': null, 'title': 'Overlap'});
      expect(clash.status, 400);
      expect((clash.json! as Map)['error'], startsWith('This overlaps "Cartoons"'));
      final onNew = await admin.post(blocks, {...read, 'title': 'Own channel', 'newChannel': true});
      expect(onNew.status, 200, reason: '${onNew.json}');
      expect(app.channelById((onNew.json! as Map)['channelId'] as String)!.blockOnly, isTrue);
      expect((await edit('DELETE', '$blocks/$bid', null, blocks)).status, 200);
      expect(app.blocks.map((b) => b.title), ['Own channel']);
    });
  });

  group('late-night blocks (late-night-drift 2.4)', () {
    test('a rated block reads and writes back identical; nothing qualifying is refused', () async {
      final app = await signIn();
      final blocks = '/api/v1/profiles/$id/blocks';
      final listed = (await get(blocks))! as Map;
      expect(listed['kidProfile'], isFalse);
      final draft = listed['newBlock'] as Map<String, Object?>;
      final none = await admin.post(blocks, {
        ...draft,
        'title': 'Late Night',
        'source': {'episodes': true, 'movies': false, 'seriesKeys': ['beta|2000'], 'ratingFloor': 'mature'},
      });
      expect(none.status, 400);
      expect((none.json! as Map)['error'],
          'Nothing in this mix is rated TV-MA or higher. Choose a lower rating or other shows.');
      final made = await admin.post(blocks, {
        ...draft,
        'title': 'Late Night',
        'source': {'episodes': true, 'movies': false, 'seriesKeys': ['alpha|2000', 'beta|2000'], 'ratingFloor': 'mature'},
      });
      expect(made.status, 200, reason: '${made.json}');
      expect(app.blocks.single.source.ratingFloor, RatingFloor.mature);
      expect(app.blocks.single.playlist, hasLength(10), reason: "only Alpha's episodes");
      final bid = (made.json! as Map)['id'] as String;
      final before = jsonEncode(app.blocks.single.toJson());
      final read = (await get('$blocks/$bid'))! as Map;
      expect((read['view'] as Map)['describe'], endsWith('TV-MA / R and up'));
      final again = await edit('PUT', '$blocks/$bid', read);
      expect(again.status, 200, reason: '${again.json}');
      expect(jsonEncode(app.blocks.single.toJson()), before);
    });
  });

  group('commercials (4.11)', () {
    test('pools with clip counts, folders, the main plan and a channel plan', () async {
      final app = await signIn();
      final base = '/api/v1/profiles/$id/commercials';
      final made = await admin.post('/api/v1/profiles/$id/pools', {'name': 'Retro ads'});
      expect(made.status, 200, reason: '${made.json}');
      final pid = (made.json! as Map)['created'] as String;
      final pool = ((made.json! as Map)['pools'] as List).cast<Map>().singleWhere((p) => p['id'] == pid);
      expect(pool['name'], 'Retro ads');
      expect((pool['view'] as Map)['clips'], 0);
      final roots = [
        {'itemId': FakeJellyfin.reelFolder, 'libraryId': FakeJellyfin.adsLibrary, 'label': 'Commercials / reels'},
      ];
      expect((await edit('PUT', '/api/v1/profiles/$id/pools/$pid/roots', {'roots': roots}, base)).status, 200);
      expect(app.poolById(pid)!.roots.single.itemId, FakeJellyfin.reelFolder);
      expect((await edit('PUT', '/api/v1/profiles/$id/pools/$pid', {'name': 'Ads'}, base)).status, 200);
      expect(app.poolById(pid)!.name, 'Ads');
      final marked = await edit('PUT', '/api/v1/profiles/$id/pools/$pid', {'kind': 'bumpers'}, base);
      expect(marked.status, 200);
      expect(app.poolById(pid)!.kind, PoolKind.bumpers);
      expect(app.poolById(pid)!.name, 'Ads', reason: 'a type alone keeps the name');
      final listed = ((marked.json! as Map)['pools'] as List).cast<Map>().singleWhere((p) => p['id'] == pid);
      expect(listed['kind'], 'bumpers');
      expect((await edit('PUT', '/api/v1/profiles/$id/pools/$pid', {'kind': 'idents'}, base)).status, 400);
      expect(app.poolById(pid)!.kind, PoolKind.bumpers, reason: 'refused: unchanged');
      expect(
          (await edit('PUT', '/api/v1/profiles/$id/pools/$pid', {'name': 'Back to ads', 'kind': 'commercials'}, base)).status,
          200);
      expect((app.poolById(pid)!.name, app.poolById(pid)!.kind), ('Back to ads', PoolKind.commercials));
      expect((await edit('PUT', '/api/v1/profiles/$id/pools/$pid', {'name': 'Ads'}, base)).status, 200);
      final plan = {'mode': 'automatic', 'roles': <String, Object?>{}};
      expect((await edit('PUT', '$base/plan', {'plan': plan}, base)).status, 200);
      expect(app.settings.commercialPlan.mode.name, 'automatic');
      final ch = app.allChannels.first;
      expect((await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}/plan', {'plan': {'mode': 'off'}}, base)).status, 200);
      expect(ch.commercialPlan?.isOff, isTrue);
      expect((await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}/plan', {'plan': null}, base)).status, 200);
      expect(ch.commercialPlan, isNull);
      expect((await edit('DELETE', '/api/v1/profiles/$id/pools/$pid', null, base)).status, 200);
      expect(app.poolById(pid), isNull);
    });
  });

  group('live sources (4.12)', () {
    test('an uploaded M3U adds its chosen channels to the guide', () async {
      await signIn();
      const m3u = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="news" tvg-chno="101",Town News\nhttp://127.0.0.1:9/news.ts\n'
          '#EXTINF:-1 tvg-id="weather" tvg-chno="102",Weather Now\nhttp://user:secret@127.0.0.1:9/weather.ts\n';
      final up = await admin.call('POST', '/api/v1/profiles/$id/live-sources/files?name=local.m3u', bytes: utf8.encode(m3u));
      expect(up.status, 200, reason: '${up.json}');
      final added = await admin.post('/api/v1/profiles/$id/live-sources', {'playlistUpload': (up.json! as Map)['upload']});
      expect(added.status, 200, reason: '${added.json}');
      final source = added.json! as Map;
      expect(source['name'], 'local');
      expect((source['view'] as Map)['chosen'], 2);
      final guide = (await get('/api/v1/profiles/$id/guide'))! as Map;
      final names = [for (final c in (guide['channels'] as List).cast<Map>()) c['name']];
      expect(names, containsAll(['Town News', 'Weather Now']));
      final sid = source['id'] as String;
      final channels = (await get('/api/v1/profiles/$id/live-sources/$sid/channels'))! as Map;
      expect(jsonEncode(channels), isNot(contains('secret')));
      final base = '/api/v1/profiles/$id/live-sources';
      final news = ((channels['channels'] as List).cast<Map>()).firstWhere((c) => c['name'] == 'Town News')['key'];
      expect((await edit('PUT', '$base/$sid/channels', {'keys': [news]}, base)).status, 200);
      final after = (await get('/api/v1/profiles/$id/guide'))! as Map;
      final left = [for (final c in (after['channels'] as List).cast<Map>()) c['name']];
      expect(left, contains('Town News'));
      expect(left, isNot(contains('Weather Now')));
      expect((await edit('DELETE', '$base/$sid', null, base)).status, 200);
      expect(((await get(base))! as Map)['sources'], isEmpty);
    });

    test('an upload over 32 MB is refused with 413', () async {
      final answer = await oversize(
          setup.boundPort!, 'POST', '/api/v1/profiles/$id/live-sources/files?name=big.xml', (32 << 20) + 1,
          cookie: admin.cookie);
      expect(answer, startsWith('HTTP/1.1 413'));
      expect(answer, contains('That file is too big (32 MB at most).'));
    });
  });

  group('export (4.13)', () {
    test('quality, stream limit, encoder and discovery through ExportService', () async {
      final export = household.export = ExportService(household,
          ssdp: () => SsdpResponder()..sendOverride = (d, _, _) {}, art: BroadcastArt(Directory('${dir.path}/cache')));
      await export.load();
      final before = (await get('/api/v1/export'))! as Map;
      expect(before['qualities'], ['1080p', '720p']);
      final r = await edit('PUT', '/api/v1/export',
          {'quality': '720p', 'streamLimit': 2, 'encoder': 'processorOnly', 'discovery': false});
      expect(r.status, 200, reason: '${r.json}');
      expect(export.settings.quality, ExportQuality.p720);
      expect(export.settings.streamLimit, 2);
      expect(export.settings.encoder, ExportEncoderChoice.processorOnly);
      expect(export.settings.discovery, isFalse);
      expect((await edit('PUT', '/api/v1/export', {'streamLimit': null})).status, 200);
      expect(export.settings.streamLimit, isNull);
      expect((await edit('PUT', '/api/v1/export', {'streamLimit': 99})).status, 400);
    });
  });

  group('saved backups (4.14)', () {
    test('list, download, restore and delete the server\'s saved backups', () async {
      final app = await signIn();
      final saved = await household.backups!.backUp(BackupReason.manual);
      final list = ((await get('/api/v1/backups'))! as Map)['backups'] as List;
      final entry = list.cast<Map>().singleWhere((b) => b['name'] == saved!.name);
      expect(entry['kind'], 'Made by you');
      final download = await admin.get('/api/v1/backups/${saved!.name}');
      expect(download.status, 200);
      expect(BackupArchive.check(Uint8List.fromList(download.bytes)).summary.profiles, isNotEmpty);
      final ch = app.allChannels.first;
      final name = ch.name;
      await edit('PUT', '/api/v1/profiles/$id/channels/${ch.id}', {'name': 'Changed after the backup'});
      final restored = await admin.post('/api/v1/backups/${saved.name}/restore');
      expect(restored.status, 200, reason: '${restored.json}');
      final after = (await household.appForSetup(id))!;
      expect(after.channelById(ch.id)!.name, name);
      final deleted = await admin.call('DELETE', '/api/v1/backups/${saved.name}');
      expect(deleted.status, 200);
      expect((await admin.get('/api/v1/backups/${saved.name}')).status, 404);
    });
  });
}

/// An XMLTV time ("20261024190000 -0700") as ISO 8601.
String _isoOf(String t) =>
    '${t.substring(0, 4)}-${t.substring(4, 6)}-${t.substring(6, 8)}T${t.substring(8, 10)}:${t.substring(10, 12)}:'
    '${t.substring(12, 14)}${t.substring(15, 18)}:${t.substring(18, 20)}';
