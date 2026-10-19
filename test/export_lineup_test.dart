import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/lineup_server.dart';
import 'package:nightingale_tv/export/m3u_writer.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/export/xmltv_writer.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/profiles/profile.dart';
import 'package:nightingale_tv/remote/remote_control.dart';

import 'fixtures.dart';

final _urls = ExportUrls(Uri.parse('http://192.168.1.20:5004'));

/// `<programme …>` blocks of [xml] on channel [number], in order.
List<String> _programmes(String xml, int number) => [
      for (final m in RegExp(r'<programme [^>]*channel="(\d+)">(.*?)</programme>', dotAll: true).allMatches(xml))
        if (m.group(1) == '$number') m.group(0)!,
    ];

String? _attr(String element, String name) => RegExp('$name="([^"]*)"').firstMatch(element)?.group(1);

/// Never touches the real network.
SsdpResponder _silentSsdp() => SsdpResponder()..sendOverride = (_, _, _) {};

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

void main() {
  group('writers', () {
    late Directory dir;
    late AppState app;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_export_writers');
      app = await signedInApp(
          dir, fakeLibrary(shows: {'Alpha': 10, 'Beta & <Co>': 4}, genres: {'Alpha': ['Comedy']}, movies: 3));
    });

    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    String guide() =>
        buildXmltv(channels: app.channels, scheduleFor: app.scheduleFor, library: app.library, urls: _urls, now: DateTime.now());

    test('the M3U lists visible channels in number order with their attributes', () async {
      final hidden = app.channels.last;
      await app.updateChannel(hidden, hidden: true);
      final m3u = buildM3u(channels: app.channels, urls: _urls, profileName: 'Mom');
      final lines = const LineSplitter().convert(m3u);
      expect(lines.first, '#EXTM3U url-tvg="http://192.168.1.20:5004/xmltv.xml" x-tvg-url="http://192.168.1.20:5004/xmltv.xml"');
      final entries = lines.skip(1).toList();
      expect(entries, hasLength(app.channels.length * 2));
      for (var i = 0; i < app.channels.length; i++) {
        final c = app.channels[i];
        expect(entries[i * 2], startsWith('#EXTINF:-1 tvg-id="${c.number}" tvg-chno="${c.number}" '));
        expect(entries[i * 2], contains('tvg-logo="http://192.168.1.20:5004/logos/${c.number}.png"'));
        expect(entries[i * 2], contains('group-title="Nightingale TV · Mom"'));
        expect(entries[i * 2], endsWith(',${c.name}'));
        expect(entries[i * 2 + 1], 'http://192.168.1.20:5004/stream/${c.number}.ts');
      }
      expect(m3u, isNot(contains('/stream/${hidden.number}.ts')));
      final numbers = [for (final c in app.channels) c.number];
      expect(numbers, [...numbers]..sort());
    });

    test('the guide has the same slots as the TV guide for 72 hours from the hour', () {
      final xml = guide();
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day, now.hour);
      for (final c in app.channels) {
        final slots = app.scheduleFor(c)!.programsBetween(from, from.add(const Duration(hours: 72)));
        final programmes = _programmes(xml, c.number);
        expect(programmes, hasLength(slots.length), reason: c.name);
        expect(_attr(programmes.first, 'start'), xmltvTime(slots.first.start));
        expect(_attr(programmes.last, 'stop'), xmltvTime(slots.last.end));
      }
      for (final c in app.channels) {
        expect(xml, contains('<channel id="${c.number}">'));
        expect(xml, contains('<icon src="http://192.168.1.20:5004/logos/${c.number}.png"/>'));
      }
    });

    test('episodes carry episode numbers, sub-title, genres and previously-shown', () {
      final xml = guide();
      final ep = RegExp(r'<programme [^>]*>\s*<title>Alpha</title>.*?</programme>', dotAll: true).firstMatch(xml)!.group(0)!;
      final entry = app.library.episodes.firstWhere((e) => ep.contains('<sub-title>${e.title}</sub-title>'));
      expect(ep, contains('<episode-num system="xmltv_ns">${entry.season! - 1}.${entry.episode! - 1}.</episode-num>'));
      expect(
          ep,
          contains('<episode-num system="onscreen">S${'${entry.season}'.padLeft(2, '0')}'
              'E${'${entry.episode}'.padLeft(2, '0')}</episode-num>'));
      expect(ep, contains('<category>Comedy</category>'));
      expect(ep, contains('<previously-shown/>'));
      expect(ep, contains('<icon src="http://192.168.1.20:5004/images/${entry.seriesId}.jpg"/>'));
    });

    test('special characters are escaped', () {
      final xml = guide();
      expect(xml, contains('Beta &amp; &lt;Co&gt;'));
      expect(xml, isNot(contains('Beta & <Co>')));
    });

    test('programmes in a block carry its title; Off Air names the next block', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, now.hour + 2);
      final channel = await app.createBlockChannel('Late Show');
      final block = app.newBlock()
        ..title = 'Night & Day'
        ..channelId = channel.id
        ..days = {1, 2, 3, 4, 5, 6, 7}
        ..startMinute = start.hour * 60
        ..endMinute = (start.hour * 60 + 120) % (24 * 60)
        ..source = const ChannelSource(seriesKeys: ['alpha|2000']);
      await app.saveBlock(block);
      final xml = guide();
      final programmes = _programmes(xml, channel.number);
      final inBlock = programmes.where((p) => p.contains('<category>Night &amp; Day</category>'));
      expect(inBlock, isNotEmpty);
      final offAir = programmes.firstWhere((p) => p.contains('<title>Off Air</title>'));
      expect(offAir, contains('Back on the air'));
      expect(offAir, contains('Night &amp; Day'));
    });
  });

  test('XMLTV times carry their own UTC offset', () {
    for (final t in [DateTime(2026, 1, 15, 20), DateTime(2026, 7, 15, 20)]) {
      final o = t.timeZoneOffset;
      final sign = o.isNegative ? '-' : '+';
      final hhmm = '${'${o.inHours.abs()}'.padLeft(2, '0')}${'${o.inMinutes.abs() % 60}'.padLeft(2, '0')}';
      expect(xmltvTime(t), '${t.year}${'${t.month}'.padLeft(2, '0')}15200000 $sign$hhmm');
    }
  });

  test('only home-network addresses are served', () {
    expect(RemoteControl.isPrivate(InternetAddress('8.8.8.8')), isFalse);
    expect(RemoteControl.isPrivate(InternetAddress('192.168.1.5')), isTrue);
    expect(RemoteControl.isPrivate(InternetAddress.loopbackIPv4), isTrue);
  });

  group('server', () {
    late Directory dir;
    late Household household;
    late ExportService service;
    late Profile mom;
    final imageRequests = <http.Request>[];
    final client = HttpClient();

    Future<void> seed(Profile p, LibraryIndex library) async {
      final app = await signedInApp((await household.storageFor(p)).root, library);
      await app.close();
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_export_server');
      household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      household.leave();
      mom = household.profiles.single..name = 'Mom';
      await seed(mom, fakeLibrary(movies: 2));
      imageRequests.clear();
      service = ExportService(household, ssdp: _silentSsdp, serverFor: (s, id, export) {
        final base = s.defaultServer(id, export);
        return LineupServer(
          profileId: id,
          appFor: base.appFor,
          profileName: base.profileName,
          export: export,
          httpClient: MockClient((r) async {
            imageRequests.add(r);
            return http.Response.bytes([1, 2, 3], 200, headers: {'content-type': 'image/jpeg'});
          }),
        );
      });
      await service.load();
    });

    tearDown(() async {
      await service.stop();
      household.leave();
      await household.setExportedProfiles({});
      await dir.delete(recursive: true);
    });

    Future<int> export(Profile p) async {
      await service.setProfileExported(p.id, true);
      final port = await _freePort();
      expect(await service.setPort(p.id, port), isNull);
      await service.setEnabled(true);
      final app = household.appFor(p.id)!;
      for (var i = 0; i < 100 && app.phase != AppPhase.ready && app.phase != AppPhase.signedOut; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return service.serverOf(p.id)!.port!;
    }

    Future<(int, String, HttpHeaders)> get(int port, String path) async {
      final response = await (await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'))).close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      return (response.statusCode, utf8.decode(bytes, allowMalformed: true), response.headers);
    }

    test('nothing is served until export is on', () async {
      await service.setProfileExported(mom.id, true);
      expect(service.serverOf(mom.id), isNull);
      expect(household.appFor(mom.id), isNull);
    });

    test('an exported profile serves its playlist and guide', () async {
      final port = await export(mom);
      final (status, m3u, headers) = await get(port, '/lineup.m3u');
      expect(status, 200);
      expect(headers.contentType?.mimeType, 'audio/x-mpegurl');
      final app = household.appFor(mom.id)!;
      expect(m3u, contains('http://127.0.0.1:$port/stream/${app.channels.first.number}.ts'));
      expect((await get(port, '/playlist.m3u')).$1, 200);
      final (gs, xml, gh) = await get(port, '/guide.xml');
      expect(gs, 200);
      expect(gh.contentType?.mimeType, 'application/xml');
      expect(xml, contains('<channel id="${app.channels.first.number}">'));
      expect((await get(port, '/nope')).$1, 404);
    });

    test('the guide is cached until the profile changes something', () async {
      final port = await export(mom);
      await get(port, '/xmltv.xml');
      final server = service.serverOf(mom.id)!;
      expect(server.hasCachedGuide, isTrue);
      final app = household.appFor(mom.id)!;
      await app.updateChannel(app.channels.first, name: 'Renamed');
      expect(server.hasCachedGuide, isFalse);
      expect((await get(port, '/xmltv.xml')).$2, contains('Renamed'));
    });

    test('posters only for items in the lineup, fetched with the sign-in', () async {
      final port = await export(mom);
      final app = household.appFor(mom.id)!;
      expect((await get(port, '/images/somebody-else.jpg')).$1, 404);
      expect(imageRequests, isEmpty);
      final series = app.library.series.first.id;
      final (status, _, headers) = await get(port, '/images/$series.jpg');
      expect(status, 200);
      expect(headers.value('cache-control'), 'max-age=86400');
      expect(imageRequests.single.url.path, '/Items/$series/Images/Primary');
      expect(imageRequests.single.url.queryParameters['format'], 'Jpg');
      expect(imageRequests.single.headers['Authorization'], contains('Token="none"'));
      await get(port, '/images/$series.jpg');
      expect(imageRequests, hasLength(1), reason: 'cached');
    });

    test('a signed-out profile serves an empty lineup and says why', () async {
      final dad = household.newProfile()..name = 'Dad';
      await household.saveProfile(dad);
      final port = await export(dad);
      expect(service.problemOf(dad.id), ExportProblem.signedOut);
      expect(service.problemText(dad.id), 'Sign in to this profile on the TV to export its channels.');
      final (_, m3u, _) = await get(port, '/lineup.m3u');
      expect(m3u.trim().split('\n'), hasLength(1));
      expect((await get(port, '/stream/2.ts')).$1, 404);
      expect((await get(port, '/xmltv.xml')).$2, isNot(contains('<channel')));
    });

    test('a port in use is reported, and no other port is tried', () async {
      final taken = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(taken.close);
      await service.setProfileExported(mom.id, true);
      await service.setPort(mom.id, taken.port);
      await service.setEnabled(true);
      expect(service.problemOf(mom.id), ExportProblem.portInUse);
      expect(service.problemText(mom.id), startsWith('Port ${taken.port} is in use by another program.'));
      expect(service.serverOf(mom.id), isNull);
    });

    test("a kid's guide has nothing above the kid's limit", () async {
      mom.setPin('1234');
      await household.saveProfile(mom);
      final kid = household.newProfile()
        ..name = 'Kid'
        ..kind = ProfileKind.kid
        ..rating = KidRating.young;
      await household.saveProfile(kid);
      final base = fakeLibrary(shows: {'Bluey': 4, 'Sopranos': 4});
      await seed(
        kid,
        LibraryIndex(
          series: [
            for (final s in base.series)
              SeriesEntry(
                  key: s.key, id: s.id, name: s.name, year: s.year, officialRating: s.name == 'Bluey' ? 'TV-Y' : 'TV-MA'),
          ],
          episodes: base.episodes,
          movies: const [],
          fetchedAt: DateTime.now(),
        ),
      );
      final port = await export(kid);
      final (_, xml, _) = await get(port, '/xmltv.xml');
      expect(xml, contains('Bluey'));
      expect(xml, isNot(contains('Sopranos')));
    });

    test('settings persist across a restart', () async {
      final port = await export(mom);
      await service.stop();
      final again = ExportService(household, ssdp: _silentSsdp);
      await again.load();
      addTearDown(again.stop);
      expect(again.settings, service.settings);
      expect(again.serverOf(mom.id)?.port, port);
    });

    test('a deleted profile is forgotten', () async {
      final dad = household.newProfile()..name = 'Dad';
      await household.saveProfile(dad);
      await export(dad);
      await household.deleteProfile(dad);
      for (var i = 0; i < 100 && service.serverOf(dad.id) != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(service.settings.profiles.containsKey(dad.id), isFalse);
      expect(service.serverOf(dad.id), isNull);
    });
  });
}
