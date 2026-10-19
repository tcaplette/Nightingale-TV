import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/hdhomerun.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';

import 'fixtures.dart';

typedef _Sent = ({String text, InternetAddress to, int port});

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

String _search(String st, {String man = '"ssdp:discover"'}) =>
    'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: $man\r\nMX: 1\r\nST: $st\r\n\r\n';

void main() {
  group('tuner endpoints', () {
    late Directory dir;
    late Household household;
    late ExportService service;
    late Profile mom;
    late int port;
    final sent = <_Sent>[];
    final client = HttpClient();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_hdhr');
      household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      household.leave();
      mom = household.profiles.single..name = 'Mom';
      final seeded = await signedInApp((await household.storageFor(mom)).root, fakeLibrary());
      await seeded.close();
      sent.clear();
      service = ExportService(household, ssdp: () => SsdpResponder()
        ..sendOverride = (data, to, p) => sent.add((text: utf8.decode(data), to: to, port: p)));
      await service.load();
      await service.setProfileExported(mom.id, true);
      await service.setPort(mom.id, await _freePort());
      await service.setEnabled(true);
      final app = household.appFor(mom.id)!;
      for (var i = 0; i < 100 && app.phase != AppPhase.ready; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      port = service.serverOf(mom.id)!.port!;
    });

    tearDown(() async {
      await service.stop();
      await household.setExportedProfiles({});
      await dir.delete(recursive: true);
    });

    Future<(int, String)> fetch(String path, {String method = 'GET'}) async {
      final request = await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
      final response = await request.close();
      return (response.statusCode, await utf8.decodeStream(response));
    }

    test('discover.json describes the device', () async {
      final (status, body) = await fetch('/discover.json');
      expect(status, 200);
      final d = jsonDecode(body) as Map<String, Object?>;
      final export = service.settings.profiles[mom.id]!;
      expect(d['FriendlyName'], 'Nightingale TV (Mom)');
      expect(d['DeviceID'], export.deviceId);
      expect(d['DeviceAuth'], export.deviceAuth);
      expect(d['BaseURL'], 'http://127.0.0.1:$port');
      expect(d['LineupURL'], 'http://127.0.0.1:$port/lineup.json');
      expect(d['Manufacturer'], tunerIdentity.manufacturer);
      expect(d['TunerCount'], 2);
      await service.setStreamLimit(3);
      expect((jsonDecode((await fetch('/discover.json')).$2) as Map)['TunerCount'], 3);
    });

    test('the lineup matches the playlist and guide ids', () async {
      final lineup = (jsonDecode((await fetch('/lineup.json')).$2) as List).cast<Map<String, Object?>>();
      final app = household.appFor(mom.id)!;
      expect([for (final c in lineup) c['GuideNumber']], [for (final c in app.channels) '${c.number}']);
      expect(lineup.first['GuideName'], app.channels.first.name);
      expect(lineup.first['URL'], 'http://127.0.0.1:$port/stream/${app.channels.first.number}.ts');
      expect(lineup.first['HD'], 1);
      final m3u = (await fetch('/lineup.m3u')).$2;
      final xml = (await fetch('/xmltv.xml')).$2;
      for (final c in lineup) {
        expect(m3u, contains('tvg-id="${c['GuideNumber']}"'));
        expect(xml, contains('<channel id="${c['GuideNumber']}">'));
      }
    });

    test('lineup status and scans', () async {
      final status = jsonDecode((await fetch('/lineup_status.json')).$2);
      expect(status, {'ScanInProgress': 0, 'ScanPossible': 1, 'Source': 'Cable', 'SourceList': ['Cable']});
      expect((await fetch('/lineup.post?scan=start', method: 'POST')).$1, 200);
      expect((await fetch('/lineup.post?scan=abort', method: 'POST')).$1, 200);
    });

    test('device.xml carries the same name and a stable UDN', () async {
      final (status, xml) = await fetch('/device.xml');
      expect(status, 200);
      expect(xml, contains('<friendlyName>Nightingale TV (Mom)</friendlyName>'));
      final id = service.settings.profiles[mom.id]!.deviceId;
      expect(xml, contains('<UDN>uuid:${deviceUuid(id)}</UDN>'));
      expect(xml, contains('<URLBase>http://127.0.0.1:$port</URLBase>'));
      expect(deviceUuid(id), deviceUuid(id));
    });

    test('exporting announces the device; discovery off says goodbye and goes quiet', () async {
      final alive = sent.where((s) => s.text.contains('NTS: ssdp:alive')).toList();
      expect(alive, hasLength(3));
      expect(alive.first.to, SsdpResponder.group);
      expect(alive.first.text, contains('/device.xml'));
      sent.clear();
      await service.setDiscovery(false);
      expect(sent.where((s) => s.text.contains('NTS: ssdp:byebye')), hasLength(3));
      sent.clear();
      await service.setQuality(service.settings.quality);
      expect(sent, isEmpty);
      // Added by address, the device keeps working.
      expect((await fetch('/discover.json')).$1, 200);
    });
  });

  group('SSDP', () {
    late SsdpResponder ssdp;
    final sent = <_Sent>[];
    final device = (deviceId: '7B8AF336', location: Uri.parse('http://192.168.1.20:5004/device.xml'));
    final phone = InternetAddress('192.168.1.50');

    setUp(() {
      sent.clear();
      ssdp = SsdpResponder()..sendOverride = (data, to, p) => sent.add((text: utf8.decode(data), to: to, port: p));
      ssdp.setDevices([device]);
    });

    Future<List<_Sent>> answers(String request, {InternetAddress? from}) async {
      sent.clear();
      ssdp.handle(utf8.encode(request), from ?? phone, 40000, delay: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return [...sent];
    }

    test('answers searches for its targets, unicast to the asker', () async {
      final all = await answers(_search('ssdp:all'));
      expect(all, hasLength(3));
      expect(all.every((s) => s.to == phone && s.port == 40000), isTrue);
      expect(all.first.text, startsWith('HTTP/1.1 200 OK\r\n'));
      expect(all.first.text, contains('LOCATION: http://192.168.1.20:5004/device.xml\r\n'));
      expect(all.first.text, contains('CACHE-CONTROL: max-age=1800\r\n'));

      final server = await answers(_search(SsdpResponder.deviceType));
      expect(server, hasLength(1));
      expect(server.single.text, contains('ST: ${SsdpResponder.deviceType}\r\n'));
      expect(server.single.text, contains('USN: uuid:${deviceUuid(device.deviceId)}::${SsdpResponder.deviceType}\r\n'));

      expect(await answers(_search('upnp:rootdevice')), hasLength(1));
      expect(await answers(_search('uuid:${deviceUuid(device.deviceId)}')), hasLength(1));
      expect(await answers(_search('urn:schemas-upnp-org:device:Printer:1')), isEmpty);
    });

    test('ignores public senders, non-searches and bad MAN headers', () async {
      expect(await answers(_search('ssdp:all'), from: InternetAddress('8.8.8.8')), isEmpty);
      expect(await answers('NOTIFY * HTTP/1.1\r\nNT: upnp:rootdevice\r\n\r\n'), isEmpty);
      expect(await answers(_search('ssdp:all', man: 'nope')), isEmpty);
      expect(await answers('\xff\xfe garbage'), isEmpty);
    });

    test('alive on start, byebye on stop and for removed devices', () async {
      await ssdp.start();
      expect(sent.where((s) => s.text.startsWith('NOTIFY * HTTP/1.1') && s.text.contains('NTS: ssdp:alive')), hasLength(3));
      expect(sent.first.text, contains('HOST: 239.255.255.250:1900\r\n'));
      sent.clear();
      ssdp.setDevices([]);
      expect(sent.where((s) => s.text.contains('NTS: ssdp:byebye')), hasLength(3));
      expect(sent.first.text, isNot(contains('LOCATION')));
      sent.clear();
      await ssdp.stop();
      expect(sent, isEmpty, reason: 'nothing left to say goodbye for');
    });

    test('a stopped responder sends nothing', () {
      ssdp.setDevices([device, (deviceId: '979E1D93', location: device.location)]);
      expect(sent, isEmpty);
    });
  });
}
