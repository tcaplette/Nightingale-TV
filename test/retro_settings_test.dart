import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/playback/device_effects.dart';

Channel _channel({ChannelRetro retro = ChannelRetro.main}) => Channel(
      id: 'c',
      number: 3,
      name: 'Three',
      icon: const ChannelIcon.builtin('tv'),
      source: const ChannelSource(),
      order: PlaybackOrder.cyclic,
      playlist: const [],
      anchor: DateTime.utc(2026),
      retro: retro,
    );

void main() {
  group('model', () {
    test('the styles have the values in the spec', () {
      const custom = CrtValues();
      expect(CrtStyle.off.valuesWith(custom), const CrtValues());
      expect(
          CrtStyle.softTube.valuesWith(custom), const CrtValues(scanlines: CrtLevel.low, vignette: CrtLevel.low));
      expect(
          CrtStyle.livingRoom.valuesWith(custom),
          const CrtValues(
              scanlines: CrtLevel.medium,
              mask: CrtLevel.low,
              vignette: CrtLevel.medium,
              curvature: CrtLevel.low,
              glow: CrtLevel.low,
              color: CrtColor.warm));
      expect(
          CrtStyle.arcade.valuesWith(custom),
          const CrtValues(
              scanlines: CrtLevel.high,
              lines: 240,
              mask: CrtLevel.medium,
              vignette: CrtLevel.low,
              curvature: CrtLevel.medium,
              glow: CrtLevel.medium,
              color: CrtColor.vivid));
      expect(CrtStyle.studioMonitor.valuesWith(custom), const CrtValues(scanlines: CrtLevel.medium, mask: CrtLevel.low));
      const mine = CrtValues(glow: CrtLevel.high);
      expect(CrtStyle.custom.valuesWith(mine), mine);
    });

    test('Custom starts as Living room', () {
      expect(const RetroSettings().custom, CrtStyle.livingRoom.valuesWith(const CrtValues()));
    });

    test('unknown names read as following the main setting', () {
      final r = ChannelRetro.fromJson({'shape': 'wide', 'crt': 'plasma', 'overlay': 7, 'surround': 'blue'});
      expect(r.followsMain, isTrue);
      expect(ChannelRetro.fromJson('nonsense').followsMain, isTrue);
      expect(ChannelRetro.fromJson(null).followsMain, isTrue);
    });

    test('a channel following the main setting saves no retro field', () {
      expect(_channel().toJson().containsKey('retro'), isFalse);
    });

    test('a channel round-trips its own settings', () {
      const own = ChannelRetro(
          shape: PictureShape.fit43,
          surround: Surround.image,
          surroundImage: 'a.png',
          crt: CrtStyle.arcade,
          overlay: OverlayThemeName.vcr);
      final again = Channel.fromJson(jsonDecode(jsonEncode(_channel(retro: own).toJson())) as Map<String, Object?>);
      expect(again.retro, own);
    });

    test('main settings round-trip, and bad values read as defaults', () {
      const main = RetroSettings(
        shape: PictureShape.fill43,
        surround: Surround.charcoal,
        crt: CrtStyle.custom,
        overlay: OverlayThemeName.cableBox,
        custom: CrtValues(scanlines: CrtLevel.high, lines: 240),
        accents: {OverlayThemeName.cableBox: OverlayAccent.channel},
      );
      final again = RetroSettings.fromJson(jsonDecode(jsonEncode(main.toJson())));
      expect(again.toJson(), main.toJson());
      final bad = RetroSettings.fromJson({'shape': 'x', 'crt': 'x', 'accents': {'nope': 'theme', 'vcr': 'x'}});
      expect(bad.shape, PictureShape.original);
      expect(bad.crt, CrtStyle.off);
      expect(bad.accents, isEmpty);
    });

    test('settings are independent: own values over the main ones', () {
      const main = RetroSettings(shape: PictureShape.fit43);
      final r = ResolvedRetro.of(const ChannelRetro(crt: CrtStyle.softTube), main);
      expect(r.shape, PictureShape.fit43);
      expect(r.crt, CrtStyle.softTube);
      expect(r.values.scanlines, CrtLevel.low);
      expect(r.overlay, OverlayThemeName.standard);
    });

    test('Custom values reach every channel using Custom', () {
      const main = RetroSettings(custom: CrtValues(scanlines: CrtLevel.high));
      expect(ResolvedRetro.of(const ChannelRetro(crt: CrtStyle.custom), main).values.scanlines, CrtLevel.high);
    });

    test('the API check names what is wrong', () {
      expect(ChannelRetro.problemIn({'crt': 'arcade'}), isNull);
      expect(ChannelRetro.problemIn({'crt': 'plasma'}), isNotNull);
      expect(ChannelRetro.problemIn('x'), isNotNull);
      expect(RetroSettings.problemIn({'custom': {'lines': 300}}), isNotNull);
      expect(RetroSettings.problemIn({'accents': {'vcr': 'pink'}}), isNotNull);
      expect(RetroSettings.problemIn({'custom': {'glow': 'high'}, 'accents': {'vcr': 'channel'}}), isNull);
    });
  });

  group('live channels', () {
    test('start at Original and CRT Off, following main for the rest', () {
      final s = LiveChannelSettings(number: 1);
      expect(s.retro.shape, PictureShape.original);
      expect(s.retro.crt, CrtStyle.off);
      expect(s.retro.surround, isNull);
      expect(s.retro.overlay, isNull);
      final ch = Channel.live(
          ref: const LiveRef(sourceId: 's', key: 'k'), number: 1, name: 'L', icon: const ChannelIcon.builtin('tv'));
      expect(ResolvedRetro.of(ch.retro, const RetroSettings(shape: PictureShape.fill43, crt: CrtStyle.arcade)).crt,
          CrtStyle.off);
    });

    test('saved before this setting: same as a new one; saved choices come back', () {
      expect(LiveChannelSettings.fromJson({'number': 1, 'logoMode': 'off'}).retro, ChannelRetro.live);
      final s = LiveChannelSettings(number: 2, retro: const ChannelRetro(crt: CrtStyle.arcade));
      expect(LiveChannelSettings.fromJson(s.toJson()).retro, s.retro);
      final main = LiveChannelSettings(number: 2, retro: ChannelRetro.main);
      expect(LiveChannelSettings.fromJson(main.toJson()).retro, ChannelRetro.main);
    });
  });

  group('app state', () {
    late Directory dir;
    late AppState app;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('retro');
      app = AppState(await AppStorage.at(dir));
      await app.start();
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('a profile from before this change reads Original, Off, Standard', () {
      final s = AppSettings.fromJson({'installId': 'x', 'commercialsEnabled': false});
      expect(s.retro.shape, PictureShape.original);
      expect(s.retro.surround, Surround.black);
      expect(s.retro.crt, CrtStyle.off);
      expect(s.retro.overlay, OverlayThemeName.standard);
    });

    test('the main settings save and load', () async {
      await app.setMainRetro(const RetroSettings(crt: CrtStyle.arcade, overlay: OverlayThemeName.vcr));
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.retro.crt, CrtStyle.arcade);
      expect(again.settings.retro.overlay, OverlayThemeName.vcr);
    });
  });

  group('device switch', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('retro-device');
      DeviceEffects.instance.reset();
    });
    tearDown(() async {
      DeviceEffects.instance.reset();
      await dir.delete(recursive: true);
    });

    test('is on by default, and is saved beside the profiles', () async {
      final storage = await AppStorage.at(dir);
      await DeviceEffects.instance.load(storage);
      expect(DeviceEffects.instance.on, isTrue);
      await DeviceEffects.instance.setOn(false);
      DeviceEffects.instance.reset();
      await DeviceEffects.instance.load(storage);
      expect(DeviceEffects.instance.on, isFalse);
    });

    test('a fallback lasts until the app restarts and saves nothing', () async {
      final storage = await AppStorage.at(dir);
      await DeviceEffects.instance.load(storage);
      DeviceEffects.instance.turnOffShader();
      expect(DeviceEffects.instance.shaderTurnedOff, isTrue);
      expect(await storage.readJson('device_effects.json'), isNull);
    });
  });
}
