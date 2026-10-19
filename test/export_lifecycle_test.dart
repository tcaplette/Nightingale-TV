import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/export/export_service.dart';
import 'package:nightingale_tv/export/ssdp_responder.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';
import 'package:nightingale_tv/profiles/household.dart';

import 'fixtures.dart';

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// The Dart sources of Live TV export.
Iterable<(String, String)> _exportSources() sync* {
  for (final f in Directory('lib/export').listSync().whereType<File>()) {
    if (f.path.endsWith('.dart')) yield (f.path, f.readAsStringSync());
  }
}

void main() {
  group('turning things off', () {
    late Directory dir;
    late Household household;
    late ExportService service;
    final sent = <String>[];

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_export_life');
      household = Household(await AppStorage.at(dir), runAnalysis: false);
      await household.start();
      household.leave();
      for (final p in [household.profiles.single, household.newProfile()..name = 'Two']) {
        if (!household.isSaved(p)) await household.saveProfile(p);
        final app = await signedInApp((await household.storageFor(p)).root, fakeLibrary());
        await app.close();
      }
      sent.clear();
      service = ExportService(household, ssdp: () => SsdpResponder()..sendOverride = (d, _, _) => sent.add(utf8.decode(d)));
      await service.load();
      for (final p in household.profiles) {
        await service.setProfileExported(p.id, true);
        await service.setPort(p.id, await _freePort());
      }
      await service.setEnabled(true);
    });

    tearDown(() async {
      await service.stop();
      await household.setExportedProfiles({});
      await dir.delete(recursive: true);
    });

    test('export off stops every server, says goodbye and lets go of off-screen profiles', () async {
      final [a, b] = household.profiles;
      expect(service.serverOf(a.id), isNotNull);
      expect(service.serverOf(b.id), isNotNull);
      final port = service.serverOf(a.id)!.port!;
      sent.clear();
      await service.setEnabled(false);
      expect(service.serverOf(a.id), isNull);
      expect(service.serverOf(b.id), isNull);
      expect(sent.where((m) => m.contains('ssdp:byebye')), hasLength(6));
      expect(household.appFor(a.id), isNull);
      await expectLater(Socket.connect(InternetAddress.loopbackIPv4, port), throwsA(isA<SocketException>()));
    });

    test("one profile off stops only its server", () async {
      final [a, b] = household.profiles;
      await service.setProfileExported(a.id, false);
      expect(service.serverOf(a.id), isNull);
      expect(service.serverOf(b.id), isNotNull);
      expect(sent.where((m) => m.contains('ssdp:byebye')), hasLength(3));
    });
  });

  test("export never configures the TV's player", () {
    expect(identical(MediaKitTunerPlayer.configuration, const PlayerConfiguration(title: 'Nightingale TV')), isTrue);
    for (final (path, source) in _exportSources()) {
      expect(source, isNot(contains('media_kit')), reason: path);
      expect(source, isNot(contains('tuner_player')), reason: path);
      expect(source, isNot(contains("'../playback/tuner.dart'")), reason: path);
    }
  });

  test('export never reports playback to Jellyfin', () {
    for (final (path, source) in _exportSources()) {
      expect(source, isNot(contains('reportPlayback')), reason: path);
      expect(source, isNot(contains('PlaybackReport')), reason: path);
    }
  });
}
