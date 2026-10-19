import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';

import 'fixtures.dart';

void main() {
  test('fresh settings are off, at Original', () {
    final s = AppSettings.fresh();
    expect(s.playback.transcodeIfNeeded, isFalse);
    expect(s.playback.maxBitrateMbps, isNull);
    expect(s.playback.preset.label, 'Original (no limit)');
    expect(s.playback.capBitsPerSecond, isNull);
  });

  test('a settings file from before has transcoding off', () {
    final s = AppSettings.fromJson({'installId': 'nightingaletv-abc', 'commercialPlan': {'mode': 'off'}});
    expect(s.playback, PlaybackSettings.off);
    final legacy = AppSettings.fromJson({'installId': 'retrotv-abc', 'commercialsEnabled': false});
    expect(legacy.playback, PlaybackSettings.off);
  });

  test('round-trips through JSON', () {
    final s = AppSettings.fresh()..playback = const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8);
    final again = AppSettings.fromJson(s.toJson());
    expect(again.playback, const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8));
    expect(again.playback.capBitsPerSecond, 8000000);
    expect(again.playback.preset.label, '8 Mbps · 1080p');
  });

  test('the cap is remembered while the toggle is off, but not in effect', () {
    const s = PlaybackSettings(maxBitrateMbps: 8);
    expect(PlaybackSettings.fromJson(s.toJson()).maxBitrateMbps, 8);
    expect(s.capBitsPerSecond, isNull);
  });

  test('off-preset values snap to the nearest preset at or below, 2 Mbps at least', () {
    Object? cap(Object? v) =>
        PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'maxBitrateMbps': v}).maxBitrateMbps;
    expect(cap(10), 8);
    expect(cap(8), 8);
    expect(cap(39), 20);
    expect(cap(100), 40);
    expect(cap(3), 2);
    expect(cap(1), 2);
    expect(cap(0), 2);
    expect(cap(12.7), 12);
    expect(cap(null), isNull);
    expect(PlaybackSettings.fromJson('nonsense'), PlaybackSettings.off);
  });

  test('presets are in order, Original first', () {
    expect([for (final p in PlaybackSettings.presets) p.label], [
      'Original (no limit)',
      '40 Mbps · 4K',
      '20 Mbps · 1080p high',
      '12 Mbps · 1080p',
      '8 Mbps · 1080p',
      '4 Mbps · 720p',
      '2 Mbps · 480p',
    ]);
    expect([for (final p in PlaybackSettings.presets) p.mbps], [null, 40, 20, 12, 8, 4, 2]);
  });

  test('analyzer budget: each activity, with a cap', () {
    const capped = PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8);
    expect(analyzerBudget(PlaybackActivity.tuning, capped), const Budget.paused());
    expect(analyzerBudget(PlaybackActivity.playing, capped), const Budget.limited(250000), reason: '25% of 8 Mbps');
    expect(analyzerBudget(PlaybackActivity.none, capped), const Budget.unlimited());
  });

  group('in the app', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_playback'));
    tearDown(() => dir.delete(recursive: true));

    test('a change is saved and survives a restart', () async {
      final app = await signedInApp(dir, fakeLibrary());
      expect(app.settings.playback, PlaybackSettings.off);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8));
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.playback, const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8));
      await app.close();
      await again.close();
    });

    test('the analyzer reads the static stream, whatever the setting', () async {
      final app = await signedInApp(dir, fakeLibrary(), serverId: 'srv', runAnalysis: true);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxBitrateMbps: 8));
      final proxy = app.analyzerProxy!;
      final upstream = proxy.upstream('item1');
      expect(upstream, app.client!.streamUri('item1'));
      expect(upstream.queryParameters['static'], 'true');
      expect(upstream.path, '/Videos/item1/stream');
      await app.close();
    });
  });
}
