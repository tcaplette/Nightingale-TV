import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';

/// A channel as saved before custom channels.
Map<String, Object?> _oldChannel() => {
      'id': 'auto:all-shows',
      'number': 2,
      'name': 'All Shows',
      'icon': {'kind': 'builtin', 'value': 'tv', 'color': 0xFFFFD23F},
      'source': {'episodes': true, 'movies': false},
      'order': 'random',
      'playlist': ['a', 'b'],
      'anchor': '2026-10-01T04:00:00.000Z',
      'hidden': false,
      'favorite': false,
      'auto': true,
    };

void main() {
  const root = PoolRoot(itemId: 'box80s', libraryId: 'tv', label: '80s Sitcoms');

  test('an old channel loads unchanged and saves exactly as before', () {
    final old = _oldChannel();
    final ch = Channel.fromJson(old);
    expect(ch.source.roots, isEmpty);
    expect(ch.slotRule, isNull);
    expect(ch.generation, 0);
    expect(jsonEncode(ch.toJson()), jsonEncode(old));
  });

  test('a custom channel round-trips with its roots, order, slot rule and generation', () {
    final ch = Channel.fromJson(_oldChannel())
      ..source = const ChannelSource(roots: [root], seriesKeys: ['cheers|1982'], includeMovies: true)
      ..order = PlaybackOrder.weighted
      ..slotRule = const SlotRule(
          length: Duration(minutes: 30), tail: TailMode.offline, poolId: 'p1', offlineImage: 'offline-0123456789abcdef.png')
      ..generation = 3;
    final back = Channel.fromJson(jsonDecode(jsonEncode(ch.toJson())) as Map<String, Object?>);
    expect(back.source.roots, [root]);
    expect(back.source.seriesKeys, ['cheers|1982']);
    expect(back.source.includeMovies, isTrue);
    expect(back.order, PlaybackOrder.weighted);
    expect(back.slotRule, ch.slotRule);
    expect(back.generation, 3);
    expect(back.seed, isNot(Channel.fromJson(_oldChannel()).seed), reason: 'Reshuffle seeds with the generation');
  });

  test('roots and slot rules are written only when set', () {
    final json = Channel.fromJson(_oldChannel()).toJson();
    expect((json['source'] as Map).containsKey('roots'), isFalse);
    expect(json.containsKey('slot'), isFalse);
    expect(json.containsKey('generation'), isFalse);
  });

  test('an order this version does not know reads as Shuffled', () {
    expect(Channel.fromJson({..._oldChannel(), 'order': 'someday'}).order, PlaybackOrder.random);
    final block = ProgramBlock.fromJson({
      'id': 'b',
      'title': 'Block',
      'channelId': 'c',
      'days': [6],
      'start': 420,
      'end': 720,
      'source': {'episodes': true},
      'order': 'someday',
      'playlist': <String>[],
      'anchor': '2026-10-01T00:00:00.000',
    });
    expect(block.order, PlaybackOrder.random);
  });

  test('a slot length the app does not offer is ignored', () {
    expect(SlotRule.fromJson({'minutes': 45, 'tail': 'filler'}), isNull);
    expect(SlotRule.fromJson({'minutes': 90, 'tail': 'what'})?.tail, TailMode.filler);
  });

  test('which channels are custom and which can have a slot length', () {
    final custom = Channel.fromJson({..._oldChannel(), 'auto': false})
      ..source = const ChannelSource(roots: [root]);
    expect(custom.isCustom, isTrue);
    expect(custom.playsPrograms, isTrue);
    final generated = Channel.fromJson(_oldChannel());
    expect(generated.isCustom, isFalse);
    expect(generated.playsPrograms, isTrue);
    final music = Channel.fromJson({..._oldChannel(), 'auto': false, 'source': {'episodes': false, 'songs': true}})
      ..slotRule = const SlotRule(length: Duration(minutes: 30));
    expect(music.isCustom, isFalse);
    expect(music.effectiveSlotRule, isNull, reason: 'music channels have no slots');
  });

  test('what counts as something picked', () {
    expect(const ChannelSource().hasPicks, isFalse);
    expect(const ChannelSource(roots: [root]).hasPicks, isTrue);
    expect(const ChannelSource(seriesKeys: ['x']).hasPicks, isTrue);
    expect(const ChannelSource(genres: ['Comedy']).hasPicks, isTrue);
    expect(const ChannelSource(includeEpisodes: false, includeMovies: true).hasPicks, isTrue);
  });
}
