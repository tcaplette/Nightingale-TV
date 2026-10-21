import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';

import 'fixtures.dart';

void main() {
  test('fresh settings are off, with Original chosen', () {
    final s = AppSettings.fresh();
    expect(s.playback, PlaybackSettings.off);
    expect(s.playback.transcodeIfNeeded, isFalse);
    expect(s.playback.preset.label, 'Original (no limit)');
    expect(s.playback.capKbps(), isNull, reason: 'off');
    // Turned on for the first time: Original, no cap.
    final on = s.playback.copyWith(transcodeIfNeeded: true);
    expect(on.preset.label, 'Original (no limit)');
    expect(on.capKbps(), isNull);
  });

  test('a settings file from before has transcoding off', () {
    final s = AppSettings.fromJson({'installId': 'nightingaletv-abc', 'commercialPlan': {'mode': 'off'}});
    expect(s.playback, PlaybackSettings.off);
    final legacy = AppSettings.fromJson({'installId': 'retrotv-abc', 'commercialsEnabled': false});
    expect(legacy.playback, PlaybackSettings.off);
  });

  test('a saved Auto loads as Original, the toggle as it was', () {
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 'auto'}),
        const PlaybackSettings(transcodeIfNeeded: true));
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 'auto'}).preset.label,
        'Original (no limit)');
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': false, 'bitrate': 'auto'}), PlaybackSettings.off);
  });

  test('a saved cap below 4 Mbps loads as 4 Mbps', () {
    PlaybackSettings load(Object? kbps) => PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': kbps});
    for (final kbps in [420, 720, 1500, 2000, 3999, 0]) {
      expect(load(kbps), const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 4000), reason: '$kbps kbps');
    }
    expect(load(420).preset.label, '4 Mbps · 720p');
  });

  test('other saved caps snap to the preset at or below', () {
    Object? cap(Object? v) => PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': v}).maxKbps;
    expect(cap(10000), 8000);
    expect(cap(8000), 8000);
    expect(cap(39000), 20000);
    expect(cap(100000), 40000);
    expect(cap(12700.5), 12000);
    expect(cap(4000), 4000);
    expect(cap(5000), 4000);
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': false, 'bitrate': 8000}).maxKbps, 8000);
  });

  test('settings saved before Auto (maxBitrateMbps) follow the same rules', () {
    PlaybackSettings load(Object? mbps) =>
        PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'maxBitrateMbps': mbps});
    expect(load(null), const PlaybackSettings(transcodeIfNeeded: true), reason: 'Original');
    expect(load(8), const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
    expect(load(8).preset.label, '8 Mbps · 1080p');
    expect(load(10).maxKbps, 8000);
    expect(load(12.7).maxKbps, 12000);
    expect(load(3).maxKbps, 4000);
    expect(load(1).maxKbps, 4000);
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': false, 'maxBitrateMbps': 8}).maxKbps, 8000);
  });

  test('unreadable settings are off with Original', () {
    expect(PlaybackSettings.fromJson('nonsense'), PlaybackSettings.off);
    expect(PlaybackSettings.fromJson(null), PlaybackSettings.off);
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 'what'}),
        const PlaybackSettings(transcodeIfNeeded: true));
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true}), const PlaybackSettings(transcodeIfNeeded: true));
  });

  test('round-trips through JSON', () {
    for (final playback in [
      for (final preset in PlaybackSettings.presets)
        for (final on in [true, false]) PlaybackSettings(transcodeIfNeeded: on).copyWith(bitrate: preset),
    ]) {
      final s = AppSettings.fresh()..playback = playback;
      expect(AppSettings.fromJson(s.toJson()).playback, playback);
    }
    const eight = PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000);
    expect(eight.toJson(), {'transcodeIfNeeded': true, 'bitrate': 8000, 'volumeLeveling': false});
    expect(eight.capKbps(), 8000);
    expect(PlaybackSettings.off.toJson(), {'transcodeIfNeeded': false, 'bitrate': 'original', 'volumeLeveling': false});
    expect(const PlaybackSettings(transcodeIfNeeded: true).toJson(),
        {'transcodeIfNeeded': true, 'bitrate': 'original', 'volumeLeveling': false});
  });

  test('volume leveling is off by default and round-trips through JSON', () {
    expect(AppSettings.fresh().playback.volumeLeveling, isFalse);
    for (final playback in const [
      PlaybackSettings(volumeLeveling: true),
      PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000, volumeLeveling: true),
      PlaybackSettings(maxKbps: 4000, volumeLeveling: true),
    ]) {
      final s = AppSettings.fresh()..playback = playback;
      expect(AppSettings.fromJson(s.toJson()).playback, playback);
    }
    const leveled = PlaybackSettings(volumeLeveling: true);
    expect(leveled.toJson()['volumeLeveling'], true);
    expect(leveled, isNot(PlaybackSettings.off));
    expect(leveled.hashCode, isNot(PlaybackSettings.off.hashCode));
    expect(PlaybackSettings.off.copyWith(volumeLeveling: true), leveled);
    expect(leveled.copyWith(transcodeIfNeeded: true).volumeLeveling, isTrue, reason: 'other changes keep it');
  });

  test('settings saved before volume leveling load with it off and the rest unchanged', () {
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 8000}),
        const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'maxBitrateMbps': 12}),
        const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 12000));
    expect(PlaybackSettings.fromJson({'transcodeIfNeeded': false, 'bitrate': 'original'}), PlaybackSettings.off);
  });

  test('an unreadable volume leveling value is off', () {
    for (final v in ['yes', 1, null, <String, Object?>{}]) {
      expect(PlaybackSettings.fromJson({'transcodeIfNeeded': true, 'bitrate': 8000, 'volumeLeveling': v}),
          const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000), reason: '$v');
    }
    expect(PlaybackSettings.fromJson({'volumeLeveling': true}).volumeLeveling, isTrue);
    expect(PlaybackSettings.fromJson({'bitrate': 4000, 'volumeLeveling': true}),
        const PlaybackSettings(maxKbps: 4000, volumeLeveling: true));
    expect(PlaybackSettings.fromJson({'maxBitrateMbps': 8, 'volumeLeveling': true}),
        const PlaybackSettings(maxKbps: 8000, volumeLeveling: true));
  });

  test('the cap is remembered while the toggle is off, but not in effect', () {
    const s = PlaybackSettings(maxKbps: 8000);
    expect(PlaybackSettings.fromJson(s.toJson()).maxKbps, 8000);
    expect(s.capKbps(), isNull);
  });

  test('the cap in effect is exactly the chosen cap', () {
    for (final preset in PlaybackSettings.presets) {
      expect(const PlaybackSettings(transcodeIfNeeded: true).copyWith(bitrate: preset).capKbps(), preset.kbps);
    }
  });

  test('choices are in order, Original first, 4 Mbps last; no Auto', () {
    expect([for (final p in PlaybackSettings.presets) p.label], [
      'Original (no limit)',
      '40 Mbps · 4K',
      '20 Mbps · 1080p high',
      '12 Mbps · 1080p',
      '8 Mbps · 1080p',
      '4 Mbps · 720p',
    ]);
    expect([for (final p in PlaybackSettings.presets) p.kbps], [null, 40000, 20000, 12000, 8000, 4000]);
  });

  test('analyzer budget: each activity, with a cap', () {
    const capped = PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000);
    expect(analyzerBudget(PlaybackActivity.tuning, capped), const Budget.paused());
    expect(analyzerBudget(PlaybackActivity.playing, capped), const Budget.limited(250000), reason: '25% of 8 Mbps');
    expect(analyzerBudget(PlaybackActivity.playing, capped, fileBitsPerSecond: 2000000), const Budget.limited(250000),
        reason: 'the cap, not the file');
    expect(analyzerBudget(PlaybackActivity.none, capped), const Budget.unlimited());
  });

  test('analyzer budget: with no cap, a quarter of the playing file\'s bitrate', () {
    for (final playback in const [
      PlaybackSettings.off,
      PlaybackSettings(transcodeIfNeeded: true),
      PlaybackSettings(maxKbps: 8000),
    ]) {
      expect(analyzerBudget(PlaybackActivity.playing, playback), const Budget.paused(),
          reason: '$playback: bitrate not known yet');
      expect(analyzerBudget(PlaybackActivity.playing, playback, fileBitsPerSecond: 8000000),
          const Budget.limited(250000), reason: '$playback: 2 Mbps');
      expect(analyzerBudget(PlaybackActivity.tuning, playback, fileBitsPerSecond: 8000000), const Budget.paused());
      expect(analyzerBudget(PlaybackActivity.none, playback), const Budget.unlimited());
    }
  });

  group('in the app', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('nightingale_tv_playback'));
    tearDown(() => dir.delete(recursive: true));

    test('a change is saved and survives a restart', () async {
      final app = await signedInApp(dir, fakeLibrary());
      expect(app.settings.playback, PlaybackSettings.off);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.playback, const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      await app.close();
      await again.close();
    });

    test('volume leveling is saved and survives a restart', () async {
      final app = await signedInApp(dir, fakeLibrary());
      expect(app.settings.playback.volumeLeveling, isFalse);
      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.playback, const PlaybackSettings(volumeLeveling: true));
      await app.close();
      await again.close();
    });

    test('an old playback_decisions.json is deleted at start-up', () async {
      final app = await signedInApp(dir, fakeLibrary());
      await app.close();
      await app.storage.writeJson(AppState.legacyDecisionsFile, {
        'measurement': {'bitsPerSecond': 300000, 'at': DateTime.now().toIso8601String()},
        'servers': <String, Object?>{},
      });
      final again = AppState(app.storage);
      await again.start();
      await pumpEventQueue();
      expect(await app.storage.readJson(AppState.legacyDecisionsFile), isNull);
      await again.close();
    });

    test('the analyzer\'s proxy gets the budget as soon as the playing file\'s bitrate is known', () async {
      final app = await signedInApp(dir, fakeLibrary(), serverId: 'srv', runAnalysis: true);
      final proxy = app.analyzerProxy!;
      app.playbackActivity.value = PlaybackActivity.playing;
      expect(proxy.budget, const Budget.paused(), reason: 'no cap, bitrate not known yet');
      app.playingBitrate.value = 8000000;
      expect(proxy.budget, const Budget.limited(250000), reason: '2 Mbps of an 8 Mbps file');
      app.playbackActivity.value = PlaybackActivity.none;
      expect(proxy.budget, const Budget.unlimited());
      await app.close();
    });

    test('the analyzer reads the static stream, whatever the setting', () async {
      final app = await signedInApp(dir, fakeLibrary(), serverId: 'srv', runAnalysis: true);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      final proxy = app.analyzerProxy!;
      final upstream = proxy.upstream('item1');
      expect(upstream, app.client!.streamUri('item1'));
      expect(upstream.queryParameters['static'], 'true');
      expect(upstream.path, '/Videos/item1/stream');
      await app.close();
    });
  });
}
