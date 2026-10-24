import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/premiere_settings.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/live/live_source.dart';
import 'package:nightingale_tv/profiles/profile.dart';

/// The models the web admin and the server share, through JSON the way the
/// API sends it (docker-web-admin 6.16). Run on the VM and with
/// `flutter test --platform chrome`, where ints are JS numbers and dates
/// are parsed by the browser.
void main() {
  /// [json] sent as text and read back with [fromJson], written again.
  Object? roundTrip(Object? json, Object? Function(Map<String, Object?>) fromJson) =>
      jsonDecode(jsonEncode((fromJson((jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>()) as dynamic).toJson()));

  void same(Object? json, Object? Function(Map<String, Object?>) fromJson) =>
      expect(roundTrip(json, fromJson), jsonDecode(jsonEncode(json)));

  const roles = CustomRoles(
    preRoll: Duration(seconds: 15),
    midInterval: Duration(minutes: 10),
    midLength: Duration(seconds: 90),
    postRoll: Duration(minutes: 1),
    tailGrid: Duration(minutes: 30),
    midPool: 'pool-a',
    tailPool: 'pool-b',
  );

  test('Channel, with a badge icon in a 32-bit colour, its own plan and a UTC anchor', () {
    final c = Channel(
      id: 'user:abc',
      number: 107,
      name: 'Sitcoms & More',
      icon: const ChannelIcon(kind: ChannelIconKind.badge, value: 'WNTV', color: 0xFFE63946, shape: BadgeShape.shield),
      source: const ChannelSource(genres: ['comedy'], seriesKeys: ['alpha'], includeMovies: true, decades: [1980]),
      order: PlaybackOrder.random,
      playlist: const ['a', 'b'],
      anchor: DateTime.utc(2026, 3, 8, 9, 30, 0, 123),
      hidden: true,
      favorite: true,
      auto: false,
      commercialPlan: const BreakPlan(mode: BreakMode.custom, roles: roles),
      logoMode: LogoMode.always,
      premieres: false,
    );
    same(c.toJson(), Channel.fromJson);
    final back = Channel.fromJson((jsonDecode(jsonEncode(c.toJson())) as Map).cast<String, Object?>());
    expect(back.icon.color, 0xFFE63946);
    expect(back.anchor.toUtc(), DateTime.utc(2026, 3, 8, 9, 30, 0, 123));
    expect(back.commercialPlan, c.commercialPlan);
  });

  test('ProgramBlock with a lineup and a season across the year end', () {
    final b = ProgramBlock(
      id: 'block:x',
      title: 'Holiday',
      channelId: 'c1',
      days: {6, 7},
      startMinute: 22 * 60,
      endMinute: 2 * 60,
      seasonStart: const MonthDay(12, 1),
      seasonEnd: const MonthDay(1, 6),
      source: const ChannelSource(seriesKeys: ['beta']),
      order: PlaybackOrder.cyclic,
      lineup: [LineupSlot(seriesKey: 'alpha', count: 2), LineupSlot(seriesKey: 'beta')],
      playlist: const ['e1'],
      anchor: DateTime(2026, 12, 1),
      enabled: false,
    );
    same(b.toJson(), ProgramBlock.fromJson);
  });

  test('BreakPlan in every mode', () {
    for (final plan in const [BreakPlan.off, BreakPlan.automatic, BreakPlan(mode: BreakMode.custom, roles: roles)]) {
      same(plan.toJson(), BreakPlan.fromJson);
    }
  });

  test('CommercialPool with folders', () {
    final pool = CommercialPool(id: 'pool-a', name: 'Retro ads', roots: const [
      PoolRoot(itemId: 'f1', libraryId: 'lib', label: 'Commercials › 80s'),
      PoolRoot(itemId: 'lib', libraryId: 'lib', label: 'Commercials'),
    ]);
    same(pool.toJson(), CommercialPool.fromJson);
  });

  test('ChannelGroup', () {
    same(ChannelGroup(id: 'group:1', name: 'Kids', channelIds: ['c1', 'live:src:2.1']).toJson(), ChannelGroup.fromJson);
  });

  test('ExportSettings with profiles and ports', () {
    final s = ExportSettings.off
        .copyWith(enabled: true, quality: ExportQuality.p720, streamLimit: () => 3, encoder: ExportEncoderChoice.processorOnly)
        .withExported('p1', true, portFree: (p) => p == 5004);
    expect(ExportSettings.fromJson(jsonDecode(jsonEncode(s.toJson()))).toJson(), jsonDecode(jsonEncode(s.toJson())));
  });

  test('Profile: a kid with a rating and a PIN', () {
    final p = Profile(id: 'p1', name: 'Ava', kind: ProfileKind.kid, rating: KidRating.older, color: 4)..setPin('1234');
    same(p.toJson(), Profile.fromJson);
    expect(Profile.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>()).checkPin('1234'), isTrue);
  });

  test('PremiereSettings and LiveSource', () {
    final premieres = const PremiereSettings(enabled: false, startMinute: 21 * 60 + 15, days: {1, 3, 5});
    expect(PremiereSettings.fromJson(jsonDecode(jsonEncode(premieres.toJson()))), premieres);
    final source = LiveSource(
      id: 'src1',
      kind: LiveSourceKind.m3u,
      name: 'IPTV',
      playlistUrl: 'http://example/playlist.m3u',
      guideFromPlaylist: true,
      chosen: {'news': LiveChannelSettings(number: 101, name: 'News', logoMode: null, favorite: true)},
    );
    same(source.toJson(), LiveSource.fromJson);
  });
}
