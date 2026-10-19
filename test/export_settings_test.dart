import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/export/export_settings.dart';

void main() {
  bool allFree(int _) => true;

  test('fresh and missing settings are off', () {
    for (final s in [ExportSettings.off, ExportSettings.fromJson(null), ExportSettings.fromJson('nonsense')]) {
      expect(s.enabled, isFalse);
      expect(s.quality, ExportQuality.p1080);
      expect(s.streamLimit, isNull);
      expect(s.encoder, ExportEncoderChoice.automatic);
      expect(s.discovery, isTrue);
      expect(s.profiles, isEmpty);
      expect(s.exportedProfileIds, isEmpty);
    }
  });

  test('round-trips through JSON', () {
    final s = const ExportSettings(
      enabled: true,
      quality: ExportQuality.p720,
      streamLimit: 3,
      encoder: ExportEncoderChoice.processorOnly,
      discovery: false,
    ).withExported('a', true, portFree: allFree, random: Random(1));
    final again = ExportSettings.fromJson(s.toJson());
    expect(again, s);
    expect(again.exportedProfileIds, ['a']);
  });

  test('unusable values fall back to defaults', () {
    final s = ExportSettings.fromJson({
      'enabled': true,
      'quality': '4K',
      'streamLimit': 9,
      'encoder': 'quantum',
      'profiles': {
        'bad-port': {'exported': true, 'port': 0, 'deviceId': '7B8AF336', 'deviceAuth': 'x'},
        'bad-id': {'exported': true, 'port': 5004, 'deviceId': '12345678', 'deviceAuth': 'x'},
        'ok': {'exported': true, 'port': 5005, 'deviceId': '7B8AF336', 'deviceAuth': 'x'},
      },
    });
    expect(s.quality, ExportQuality.p1080);
    expect(s.streamLimit, isNull);
    expect(s.encoder, ExportEncoderChoice.automatic);
    expect(s.profiles.keys, ['ok']);
  });

  test('the first profile gets 5004, later ones the lowest free port above', () {
    var s = ExportSettings.off.withExported('a', true, portFree: allFree);
    expect(s.profiles['a']!.port, 5004);
    // 5005 is in use by another program right now.
    s = s.withExported('b', true, portFree: (p) => p != 5005);
    expect(s.profiles['b']!.port, 5006);
    s = s.withExported('c', true, portFree: allFree);
    expect(s.profiles['c']!.port, 5005);
  });

  test('turning export off and on keeps the port and DeviceID', () {
    final on = ExportSettings.off.withExported('a', true, portFree: allFree);
    final off = on.withExported('a', false, portFree: allFree);
    expect(off.isExported('a'), isFalse);
    final again = off.withExported('a', true, portFree: (_) => false);
    expect(again.profiles['a'], on.profiles['a']);
  });

  test('turning off a profile that was never exported changes nothing', () {
    expect(ExportSettings.off.withExported('a', false, portFree: allFree), ExportSettings.off);
  });

  test('a deleted profile is forgotten', () {
    final s = ExportSettings.off
        .withExported('a', true, portFree: allFree)
        .withExported('b', true, portFree: allFree)
        .without('a');
    expect(s.profiles.keys, ['b']);
  });

  test('exported profiles are only served with export on', () {
    final s = ExportSettings.off.withExported('a', true, portFree: allFree);
    expect(s.exportedProfileIds, isEmpty);
    expect(s.copyWith(enabled: true).exportedProfileIds, ['a']);
  });

  test('the Automatic stream limit follows the encoder', () {
    expect(ExportSettings.off.effectiveStreamLimit(hardware: true), 2);
    expect(ExportSettings.off.effectiveStreamLimit(hardware: false), 1);
    expect(const ExportSettings(streamLimit: 4).effectiveStreamLimit(hardware: false), 4);
  });

  test('DeviceAuth is 24 characters', () {
    final s = ExportSettings.off.withExported('a', true, portFree: allFree);
    expect(s.profiles['a']!.deviceAuth, matches(RegExp(r'^[a-z0-9]{24}$')));
  });

  group('HDHomeRun DeviceID', () {
    test('agrees with libhdhomerun on known ids', () {
      // Checked against hdhomerun_discover_validate_device_id (libhdhomerun4 20210624).
      for (final id in ['7B8AF336', '979E1D93', '608CD15A', '3DE6B219', '739A1B9C', 'FFFFFFFF']) {
        expect(HdHomeRunId.isValid(id), isTrue, reason: id);
      }
      for (final id in ['12345678', '00000001', '7B8AF337', '7B8AF3', 'ZZZZZZZZ']) {
        expect(HdHomeRunId.isValid(id), isFalse, reason: id);
      }
    });

    test('every generated id is valid', () {
      final rng = Random(42);
      for (var i = 0; i < 10000; i++) {
        final id = HdHomeRunId.generate(rng);
        expect(id, matches(RegExp(r'^[0-9A-F]{8}$')));
        expect(HdHomeRunId.isValid(id), isTrue, reason: id);
      }
    });
  });
}
