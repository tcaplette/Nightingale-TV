// SMB shares on Android (smb-sources 1.2, 1.3, 1.4, 2.4, 3.5): the Samba
// test shares (tool/test_servers, `up samba`) from an emulator, through the
// host's 10.0.2.2. SMB 2/3 and SMB1, guest and password, signing, lists,
// positional reads, writes and renames, share lists and throughput; the
// app's FFmpeg from nativeLibraryDir (MediaCodec from a process, then
// libx264), converting from the gateway to a pipe; a share read and probed
// as a server; passwords kept with the Keystore; and discovery of a host
// announced on the device, with the multicast lock held.
//
//   flutter test integration_test/smb_android_live_test.dart -d emulator-5554 \
//     --dart-define=SMB_PASSWORD=… --dart-define=HEAT_SHA1=… --dart-define=API=34
// HEAT_SHA1: sha1sum of Names/Movies/Heat (1995) {tmdb-949}/Heat.mkv in the
// archive share's folder (make_smb_media.sh's ~/.cache/nightingale-test-smb-media).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/convert/conversion.dart';
import 'package:nightingale_tv/convert/convert_helpers.dart';
import 'package:nightingale_tv/convert/convert_helper.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/library/index_builder.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/platform/smb_platform.dart';
import 'package:nightingale_tv/playback/android_device_profile.dart';
import 'package:nightingale_tv/server/media_server.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/smb/smb_discovery.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_open.dart';
import 'package:nightingale_tv/server/smb/smb_profile.dart';
import 'package:nightingale_tv/server/smb/smb_server.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

import '../test/smb/mdns_responder.dart';

const _password = String.fromEnvironment('SMB_PASSWORD');
const _heatSha1 = String.fromEnvironment('HEAT_SHA1');
// The emulator's API level, for the log.
const _api = String.fromEnvironment('API');
const _heat = 'Names/Movies/Heat (1995) {tmdb-949}/Heat.mkv';
const _user = SmbCredentials(user: 'smbtest', password: _password);
const _guest = SmbCredentials.guest();
SmbAddress _at(String s) => SmbAddress.parse('smb://10.0.2.2:$s')!;

// ignore: avoid_print
void _say(String s) => print('SMB-ANDROID $s');

Matcher _fails(SmbErrorKind kind) =>
    throwsA(isA<SmbException>().having((e) => e.kind, 'kind', kind).having((e) => '$e', 'text', isNot(contains(_password))));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, who, smb1, writable) in [
    ('1445/archive', _user, false, true),
    ('1445/guest', _guest, false, true),
    ('1445/readonly', _user, false, false),
    ('1446/signed', _user, false, true),
    ('1447/old', _user, true, true),
    ('1447/oldguest', _guest, true, true),
  ]) {
    testWidgets('$name connects, lists, reads and writes', (_) async {
      final share = await openSmbShare(_at(name), who);
      addTearDown(share.close);
      expect(share.smb1, smb1);
      final root = {for (final e in await share.list('')) e.name: e};
      expect(root, isNotEmpty);
      // The largest file a level down: stat, then reads at offsets.
      (String, int)? big;
      for (final folder in root.values.where((e) => e.isFolder && !e.name.startsWith('.'))) {
        for (final e in await share.list(folder.name)) {
          if (!e.isFolder && (big == null || e.size > big.$2)) big = ('${folder.name}/${e.name}', e.size);
        }
      }
      final (path, size) = big!;
      final stat = await share.stat(path);
      expect((stat.size, stat.isFolder), (size, false));
      expect(stat.fileId, isNot(0), reason: 'files keep an id across renames');
      final reader = await share.open(path);
      final whole = BytesBuilder(copy: false);
      final clock = Stopwatch()..start();
      while (whole.length < reader.size && whole.length < 60 << 20) {
        whole.add(await reader.read(whole.length, 1 << 20));
      }
      _say('$name: $size bytes, ${(whole.length / 1e6 / (clock.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
      final bytes = whole.takeBytes();
      for (final (offset, length) in [(0, 100), (12345, 300000), (bytes.length - 70000, 50000)]) {
        expect(await reader.read(offset, length), bytes.sublist(offset, offset + length), reason: '$offset+$length');
      }
      expect(await reader.read(reader.size, 10), isEmpty);
      await reader.close();
      await expectLater(share.stat('nope/nothing.mkv'), _fails(SmbErrorKind.gone));

      if (!writable) {
        await expectLater(share.write('nightingale-write-check.tmp', Uint8List(1)), _fails(SmbErrorKind.noAccess));
        return;
      }
      final folder = '.nightingale/android-${DateTime.now().microsecondsSinceEpoch}';
      await share.makeFolder(folder);
      for (final size in [5, 200000]) {
        final data = Uint8List.fromList([for (var i = 0; i < size; i++) i * 7 & 0xFF]);
        await share.write('$folder/a.tmp', data);
        final id = (await share.stat('$folder/a.tmp')).fileId;
        expect(id, isNot(0), reason: 'every file has an id');
        await share.rename('$folder/a.tmp', '$folder/a.json');
        expect(await share.readAll('$folder/a.json'), data);
        expect((await share.stat('$folder/a.json')).fileId, id, reason: 'a renamed file keeps its id');
        expect([for (final e in await share.list(folder)) e.fileId], [id], reason: 'listed with the same id');
      }
      expect([for (final e in await share.list(folder)) e.name], ['a.json']);
      await share.delete('$folder/a.json');
      // The empty folder is taken away on the host after the run.
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  testWidgets('the whole of a file reads as it is on the host', (_) async {
    final share = await openSmbShare(_at('1445/archive'), _user);
    addTearDown(share.close);
    expect(sha1.convert(await share.readAll(_heat)).toString(), _heatSha1);
  });

  testWidgets('share lists, and failures say what went wrong', (_) async {
    expect([for (final s in (await listSmbShares(_at('1445'), _user)).shares) s.name], ['media', 'archive', 'guest', 'readonly', 'private']);
    final old = await listSmbShares(_at('1447'), _user);
    expect(old.smb1, isTrue);
    expect([for (final s in old.shares) s.name], ['old', 'oldguest']);
    const wrong = SmbCredentials(user: 'smbtest', password: 'not-the-password');
    await expectLater(openSmbShare(_at('1445/media'), wrong), _fails(SmbErrorKind.wrongSignIn));
    await expectLater(openSmbShare(_at('1447/old'), wrong), _fails(SmbErrorKind.wrongSignIn));
    await expectLater(openSmbShare(_at('1446/signed'), _guest), _fails(SmbErrorKind.guestsRefused));
    await expectLater(openSmbShare(_at('1445/private'), _user), _fails(SmbErrorKind.noAccess));
    await expectLater(openSmbShare(_at('1445/nothere'), _user), _fails(SmbErrorKind.gone));
    await expectLater(openSmbShare(_at('1999/media'), _user), _fails(SmbErrorKind.unreachable));
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('the share passwords are kept with the Keystore', (_) async {
    final dir = await Directory.systemTemp.createTemp('smb_keystore');
    addTearDown(() => dir.delete(recursive: true));
    final storage = await AppStorage.at(Directory('${dir.path}/p'), logosDir: Directory('${dir.path}/logos'));
    final secrets = SecretStore(storage);
    final ref = await secrets.put(_user);
    expect((await secrets.get(ref))?.password, _password);
    await storage.flush();
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      expect(utf8.decode(f.readAsBytesSync(), allowMalformed: true), isNot(contains(_password)), reason: f.path);
    }
    expect(File('${dir.path}/${SecretStore.keyFile}').existsSync(), isFalse, reason: 'the Keystore holds the key, not a file');
    // Encrypted by the Keystore's own key, not one in the app's files.
    final sealed = await SmbPlatform.encrypt(Uint8List.fromList(utf8.encode('x')));
    expect(utf8.decode(await SmbPlatform.decrypt(sealed)), 'x');
  });

  testWidgets('a host announced on the network is found, with the multicast lock held', (_) async {
    final nas = MdnsResponder(instance: 'Emulator NAS', host: 'emunas', address: InternetAddress('10.0.2.2'), port: 1445);
    await nas.start();
    addTearDown(nas.stop);
    final d = SmbDiscovery(duration: const Duration(seconds: 6));
    addTearDown(d.dispose);
    await d.start();
    await Future<void>.delayed(const Duration(seconds: 7));
    _say('found ${[for (final h in d.current) '${h.address}:${h.port} ${h.label}']}');
    final found = d.current.where((h) => h.name == 'Emulator NAS').single;
    expect((found.address, found.port), ('10.0.2.2', 1445));
    expect(d.running, isFalse);
  }, timeout: const Timeout(Duration(seconds: 40)));

  group('the app\'s FFmpeg and a share as a server', () {
    late Directory dir;
    late AppStorage storage;
    late SmbProfile profile;
    late SmbServer server;
    late LibraryIndex index;
    // The files-ready calls: the last one comes after Can't play is worked out.
    final ready = <bool>[];

    setUpAll(() async {
      IndexBuilder.useIsolate = false;
      dir = await Directory.systemTemp.createTemp('smb_server');
      storage = await AppStorage.at(Directory('${dir.path}/profile'),
          logosDir: Directory('${dir.path}/logos'), analysisDir: Directory('${dir.path}/analysis'));
      profile = SmbProfile(storage,
          profileName: () => 'Mom', hold: ValueNotifier(false), onFilesReady: (s, {required last}) => ready.add(last), onChanged: () {});
      final ref = await profile.secrets.put(_user);
      const id = 'android-archive';
      profile.configOf(id)
        ..mappings = const [
          SmbMapping('Names/Movies', SmbFolderType.movies),
          SmbMapping('Formats', SmbFolderType.movies),
          SmbMapping('Commercials', SmbFolderType.commercials),
        ]
        ..keepLocal = true;
      await profile.saveConfig(id);
      await SmbGateway.ensureStarted();
      server = profile.client(ServerSession(
        kind: ServerKind.smb,
        serverUrl: 'smb://10.0.2.2:1445/archive',
        serverName: 'archive on 10.0.2.2',
        serverId: id,
        userId: 'smbtest',
        userName: 'smbtest',
        accessToken: ref,
        deviceId: 'emulator',
      ));
    });

    tearDownAll(() async {
      server.close();
      await storage.flush();
      await SmbGateway.stop();
      await dir.delete(recursive: true);
    });

    testWidgets('libffmpeg.so and libffprobe.so run from nativeLibraryDir', (_) async {
      final programs = (await FfmpegPrograms.find())!;
      final folder = (await SmbPlatform.nativeLibraryDir())!;
      expect((programs.android, programs.ffmpeg, programs.ffprobe), (true, '$folder/libffmpeg.so', '$folder/libffprobe.so'));
      for (final p in [programs.ffmpeg, programs.ffprobe]) {
        final r = await Process.run(p, ['-version'], environment: programs.environment);
        expect(r.exitCode, 0, reason: '$p: ${r.stderr}');
        _say('API $_api ${p.split('/').last}: ${'${r.stdout}'.split('\n').first}');
      }
    });

    testWidgets('a scan reads lengths with the app\'s ffprobe; Can\'t play lists what nothing plays', (_) async {
      final pool = CommercialPool(id: 'pool', name: 'Commercials', roots: [
        PoolRoot(itemId: smbIdOf('Commercials/'), libraryId: smbIdOf('Commercials/'), label: 'Commercials'),
      ]);
      index = await server.fetchLibraryIndex(pools: [pool]);
      while (!ready.contains(true)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      server.rebuildNext();
      index = await server.fetchLibraryIndex(pools: [pool]);
      final movies = {for (final m in index.movies) m.title: m};
      expect(movies['Heat']!.runtime.inMilliseconds, closeTo(60000, 100));
      expect(movies.keys, containsAll(['Windows Media', 'DivX Movie', 'Old Disc', 'High Range HDR10']));
      expect(index.commercials.firstWhere((c) => c.title == 'Soda Spot 1').runtime.inMilliseconds, closeTo(20000, 100));
      final cant = {for (final e in server.cantPlay.entries) e.key.title: e.value};
      expect(cant['Cut Off'], CantPlayReason.damaged);
      expect(cant['Sound Only'], CantPlayReason.noVideo);
    }, timeout: const Timeout(Duration(minutes: 5)));

    // What came out of a conversion, read by the app's own ffprobe.
    Future<Map<String, Object?>> probe(File f) async {
      final programs = (await FfmpegPrograms.find())!;
      final r = await Process.run(programs.ffprobe,
          ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height,color_transfer', '-of', 'json', f.path],
          environment: programs.environment);
      return ((jsonDecode('${r.stdout}') as Map)['streams'] as List).first as Map<String, Object?>;
    }

    testWidgets('MediaCodec from a process, then libx264: a file converts from the gateway to a pipe', (_) async {
      final programs = (await FfmpegPrograms.find())!;
      final wmv = index.movies.firstWhere((m) => m.title == 'Windows Media');
      final d = await server.playbackDecision(wmv.id, profile: androidDeviceProfile(DeviceCapabilities.fallback));
      expect((d.transcode, d.directStream), (true, false));
      final spec = ConversionSpec.fromQuery(d.transcodeTemplate!.queryParameters);
      final source = server.streamUri(wmv.id).toString();
      Future<(int, String)> run(ConversionEncoder encoder) async {
        final p = await Process.start(programs.ffmpeg, spec.arguments(source, encoder: encoder), environment: programs.environment);
        final err = StringBuffer();
        p.stderr.transform(utf8.decoder).listen(err.write);
        final out = BytesBuilder(copy: false);
        final got = Completer<void>();
        p.stdout.listen((c) {
          out.add(c);
          if (out.length > 300000 && !got.isCompleted) got.complete();
        }, onDone: () => got.isCompleted ? null : got.complete());
        await got.future.timeout(const Duration(seconds: 20), onTimeout: () {});
        p.kill(ProcessSignal.sigkill);
        await p.exitCode;
        final bytes = out.takeBytes();
        return (bytes.isEmpty ? -1 : bytes.length >= 300000 && bytes[0] == 0x47 ? bytes.length : 0, '$err');
      }

      final codec = await run(ConversionEncoder.mediacodec);
      _say('API $_api h264_mediacodec from a process: ${codec.$1 > 0 ? 'gave MPEG-TS' : 'gave nothing'}'
          '${codec.$1 > 0 ? '' : ' (${codec.$2.trim().split('\n').last})'}');
      final x264 = await run(ConversionEncoder.x264);
      expect(x264.$1, greaterThan(0), reason: x264.$2);

      // Through the gateway as the tuner asks: the encoders in order.
      final url = await server.transcodeUri(d.transcodeTemplate!, playSessionId: 'a1', startAt: const Duration(seconds: 10));
      final client = HttpClient();
      addTearDown(client.close);
      final answer = await (await client.getUrl(url)).close();
      expect((answer.statusCode, answer.headers.contentType?.mimeType), (200, 'video/mp2t'));
      final out = File('${dir.path}/wmv.ts');
      final sink = out.openWrite();
      var n = 0;
      await for (final c in answer) {
        sink.add(c);
        n += c.length;
        if (n > 1000000) break;
      }
      await sink.close();
      await server.stopTranscode('a1');
      expect((await probe(out))['codec_name'], 'h264');
      expect(await SmbGateway.instance.runningJobs(), 0);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('HDR is tone-mapped at 720p on the device', (_) async {
      final hdr = index.movies.firstWhere((m) => m.title == 'High Range HDR10');
      final d = await server.playbackDecision(hdr.id, profile: androidDeviceProfile(DeviceCapabilities.fallback));
      expect((d.transcodeTemplate!.queryParameters['hdr'], d.transcodeTemplate!.queryParameters['h']), ('1', '720'));
      final url = await server.transcodeUri(d.transcodeTemplate!, playSessionId: 'a2', startAt: const Duration(seconds: 2));
      final client = HttpClient();
      addTearDown(client.close);
      final answer = await (await client.getUrl(url)).close();
      final out = File('${dir.path}/hdr.ts');
      final sink = out.openWrite();
      var n = 0;
      final clock = Stopwatch()..start();
      await for (final c in answer) {
        sink.add(c);
        n += c.length;
        if (n > 1000000) break;
      }
      await sink.close();
      await server.stopTranscode('a2');
      _say('API $_api HDR 720p: 1 MB in ${clock.elapsedMilliseconds} ms');
      final v = await probe(out);
      expect((v['codec_name'], v['width'], v['height']), ('h264', 1280, 720));
      expect(v['color_transfer'], isNot('smpte2084'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  // Converting on another Nightingale TV, with this device too slow for the
  // file (smb-conversion). The helper runs in this app on the device, as the
  // Linux app and the server run it: an emulator is never run beside the
  // Linux app.
  group('a paired helper converts for a device that is too slow', () {
    late Directory dir;
    late ConvertHelper helper;
    late ConvertHelpers tv;
    late SmbProfile profile;
    late SmbServer server;
    const shareId = 'smb-helper-android';
    const port = 18487;

    setUpAll(() async {
      IndexBuilder.useIsolate = false;
      dir = await Directory.systemTemp.createTemp('helper');
      // The helper's household: one profile with the share, Formats mapped.
      final root = await AppStorage.at(Directory('${dir.path}/helper'));
      final p1 = await AppStorage.at(Directory('${dir.path}/helper/profiles/p1'), logosDir: root.logosDir);
      final ref = await SecretStore(p1).put(_user);
      await p1.writeJson('session.json', {
        'kind': 'smb', 'serverUrl': 'smb://10.0.2.2:1445/archive', 'serverName': 'archive', 'serverId': shareId, //
        'userId': 'smbtest', 'userName': 'smbtest', 'accessToken': ref, 'deviceId': 'd',
      });
      await p1.writeJson('smb_shares.json', {
        'shares': {
          shareId: {
            'folders': [
              {'path': 'Formats', 'type': 'movies'}
            ]
          }
        }
      });
      final share = await openSmbShare(_at('1445/archive'), _user);
      final scan = await SmbScanner(share, const [SmbMapping('Formats', SmbFolderType.movies)]).scan();
      await share.close();
      await p1.writeJson('smb_scan/${smbIdOf(shareId)}.json', scan.toJson());
      await p1.flush();
      await SmbGateway.ensureStarted();
      helper = ConvertHelper(root, deviceName: 'Test PC', port: port);
      await helper.load();
      await helper.setOn(true);

      // The TV: the same share, too slow for Windows Media's picture.
      tv = ConvertHelpers(await AppStorage.at(Directory('${dir.path}/tv')), deviceName: 'Living room TV');
      final storage = await AppStorage.at(Directory('${dir.path}/tv/profiles/p1'), logosDir: Directory('${dir.path}/tv/logos'));
      profile = SmbProfile(storage, profileName: () => 'Mom', hold: ValueNotifier(false), onFilesReady: (s, {required last}) {}, onChanged: () {})
        ..helpers = tv.helperFor
        ..helperKnown = tv.knownFor;
      final tvRef = await profile.secrets.put(_user);
      profile.configOf(shareId)
        ..mappings = const [SmbMapping('Formats', SmbFolderType.movies)]
        ..keepLocal = true;
      await profile.saveConfig(shareId);
      server = profile.client(ServerSession(
        kind: ServerKind.smb,
        serverUrl: 'smb://10.0.2.2:1445/archive',
        serverName: 'archive on 10.0.2.2',
        serverId: shareId,
        userId: 'smbtest',
        userName: 'smbtest',
        accessToken: tvRef,
        deviceId: 'emulator',
      ));
    });

    tearDownAll(() async {
      server.close();
      await profile.settled();
      await helper.stop();
      await SmbGateway.stop();
      await dir.delete(recursive: true);
    });

    testWidgets('found on the network, paired by its code', (_) async {
      final found = await tv.find();
      _say('helpers found: ${[for (final f in found) f.name]}');
      expect(found.map((f) => f.name), contains('Test PC'));
      final url = ConvertHelpers.parseAddress('127.0.0.1:$port')!;
      expect(await tv.pair(url, helper.code == '000000' ? '111111' : '000000'), isFalse);
      expect(await tv.pair(url, helper.code!), isTrue);
      expect(helper.pairings.single.name, 'Living room TV');
      expect(await tv.helperFor(shareId), tv.helpers.single.id);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('a file this device is too slow for converts on the helper', (_) async {
      final index = await server.fetchLibraryIndex();
      final wmv = index.movies.firstWhere((m) => m.title == 'Windows Media');
      final probe = await server.playbackDecision(wmv.id, profile: androidDeviceProfile(DeviceCapabilities.fallback));
      expect(probe.transcode, isTrue);
      // This device converts this kind of picture at a third of its speed.
      final spec = ConversionSpec.fromQuery(probe.transcodeTemplate!.queryParameters);
      expect(spec.helper, isNull, reason: 'fast enough as far as it knows: converted here');
      final kinds = (await server.debugVideoKind(wmv.id))!;
      await profile.speeds.record(kinds, 0.33);
      final d = await server.playbackDecision(wmv.id, profile: androidDeviceProfile(DeviceCapabilities.fallback));
      expect(ConversionSpec.fromQuery(d.transcodeTemplate!.queryParameters).helper, tv.helpers.single.id);
      final url = await server.transcodeUri(d.transcodeTemplate!, playSessionId: 'h1', startAt: const Duration(seconds: 20));
      final client = HttpClient();
      addTearDown(client.close);
      final answer = await (await client.getUrl(url)).close();
      expect((answer.statusCode, answer.headers.contentType?.mimeType), (200, 'video/mp2t'));
      var n = 0, first = -1;
      await for (final c in answer) {
        if (first < 0 && c.isNotEmpty) first = c[0];
        n += c.length;
        if (n > 600000) break;
      }
      expect(first, 0x47);
      expect(helper.running, greaterThanOrEqualTo(1), reason: 'the helper did the converting');
      await server.stopTranscode('h1');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(helper.running, 0, reason: 'the TV left, and the conversion ended');
      _say('converted on the paired helper: $n bytes');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
