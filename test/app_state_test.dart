import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';

import 'fixtures.dart';

/// Custom channels in the app state (custom-channels).
void main() {
  late Directory dir;
  late AppState app;
  const shows = {'Cheers': 20, 'Taxi': 10, 'Alpha': 10};
  const box = PoolRoot(itemId: 'box80s', libraryId: 'tv', label: '80s Sitcoms');

  /// How many library scans the [server] saw (its show listings).
  var scans = 0;

  /// A server with [shows] and 6 movies in "TV Shows", plus [added] (movies
  /// added since the app's last scan), and the collection `box80s` holding
  /// [boxed] (item ids).
  JellyfinClient server(List<String> boxed, {List<Map<String, Object?>> added = const []}) {
    scans = 0;
    final fake = fakeItems(shows: shows, movies: 6);
    final items = (series: fake.series, episodes: fake.episodes, movies: [...fake.movies, ...added]);
    final byId = {for (final i in [...items.episodes, ...items.movies]) i['Id']: i};
    return JellyfinClient(
      serverUrl: 'https://jf.example',
      deviceId: 'd',
      deviceName: 'pc',
      accessToken: 't',
      userId: 'u',
      httpClient: MockClient((r) async {
        if (r.url.path == '/UserViews') {
          return http.Response(
              jsonEncode({
                'Items': [
                  {'Id': 'tv', 'Name': 'TV Shows', 'CollectionType': 'tvshows'},
                ]
              }),
              200);
        }
        final q = r.url.queryParameters;
        if (q['ParentId'] == 'tv' && q['IncludeItemTypes'] == 'Series') scans++;
        final all = switch ((q['ParentId'], q['IncludeItemTypes'])) {
          ('tv', 'Series') => items.series,
          ('tv', 'Episode') => items.episodes,
          ('tv', 'Movie') => items.movies,
          ('box80s', _) => [for (final id in boxed) byId[id] ?? {'Id': id, 'Type': 'Movie'}],
          _ => const <Map<String, Object?>>[],
        };
        return http.Response(jsonEncode({'Items': all, 'TotalRecordCount': all.length}), 200);
      }),
    );
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_custom');
    app = await signedInApp(dir, fakeLibrary(shows: shows, movies: 6, songs: fakeMusic(40)));
  });

  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  /// What plays on [ch] at [t]: the item and the position in it.
  (String?, Duration) onAir(Channel ch, DateTime t) {
    final p = app.scheduleFor(ch)!.playbackAt(t);
    return (p.item?.id, p.positionAt(t));
  }

  test('a channel from a collection: next number, live_tv icon, shuffled, fetched at once', () async {
    final highest = app.allChannels.map((c) => c.number).reduce((a, b) => a > b ? a : b);
    app.client = server(['Cheers-e1', 'Cheers-e2', 'Taxi-e1', 'movie-1']);
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(roots: [box]));
    expect(ch.number, highest + 1);
    expect(ch.name, '80s TV');
    expect(ch.icon.value, 'live_tv');
    expect(ch.order, PlaybackOrder.random);
    expect(ch.isCustom, isTrue);
    expect(ch.playlist.toSet(), {'Cheers-e1', 'Cheers-e2', 'Taxi-e1', 'movie-1'});
    expect(app.library.roots, contains('box80s'), reason: 'the root was fetched without a full scan');
    expect(app.scheduleFor(ch)!.playbackAt(DateTime.now()).item, isNotNull);

    final reloaded = AppState(app.storage);
    await reloaded.start();
    expect(reloaded.channelById(ch.id)!.source.roots, [box]);
    expect(reloaded.library.itemsByRoot['box80s'], hasLength(4), reason: 'saved with the library');
    await reloaded.close();
  });

  group('roots holding what the library lacks (jellyfin-folder-browse D5)', () {
    Map<String, Object?> newMovie(int i) => {
          'Id': 'new-$i',
          'Name': 'New Pick $i',
          'Type': 'Movie',
          'ProductionYear': 2026,
          'RunTimeTicks': const Duration(minutes: 100).inMicroseconds * 10,
          'LocationType': 'FileSystem',
        };

    test('movies added since the last scan: one scan, then they play', () async {
      app.client = server([for (var i = 1; i <= 5; i++) 'new-$i'], added: [for (var i = 1; i <= 5; i++) newMovie(i)]);
      expect(app.library['new-1'], isNull);
      final ch = await app.createCustomChannel('New Picks', const ChannelSource(roots: [box]));
      expect(scans, 1);
      expect(ch.playlist.toSet(), {for (var i = 1; i <= 5; i++) 'new-$i'});
      expect(app.library.itemsByRoot['box80s'], hasLength(5));
      expect(app.scheduleFor(ch)!.playbackAt(DateTime.now()).item, isNotNull);
    });

    test('a root whose items stay unknown is scanned for once, not again and again', () async {
      // `ghost` is listed under the root but in none of the server's
      // library listings.
      app.client = server(['Cheers-e1', 'ghost']);
      final ch = await app.createCustomChannel('80s TV', const ChannelSource(roots: [box]));
      expect(scans, 1);
      expect(ch.playlist, ['Cheers-e1']);
      await app.setChannelSource(ch, const ChannelSource(roots: [box]));
      expect(scans, 1, reason: 'the root is resolved now');
    });

    test('pool clips under a root are known: no scan', () async {
      final poolDir = await Directory.systemTemp.createTemp('nightingale_tv_custom_pool');
      final withAds =
          await signedInApp(poolDir, fakeLibrary(shows: shows, movies: 6, commercials: [const Duration(seconds: 30)]));
      addTearDown(() async {
        await withAds.close();
        await poolDir.delete(recursive: true);
      });
      // A trailer the server types as a movie, in a pool's folder.
      withAds.client = server(['Cheers-e1', 'ad-1']);
      final ch = await withAds.createCustomChannel('80s TV', const ChannelSource(roots: [box]));
      expect(scans, 0);
      expect(ch.playlist, ['Cheers-e1'], reason: 'pool items never play as programs');
    });

    test('roots holding only what the library has: no scan', () async {
      app.client = server(['Cheers-e1', 'movie-1']);
      final ch = await app.createCustomChannel('80s TV', const ChannelSource(roots: [box]));
      expect(scans, 0);
      expect(ch.playlist.toSet(), {'Cheers-e1', 'movie-1'});
    });
  });

  test('nothing picked, or nothing matching, adds no channel', () async {
    final count = app.allChannels.length;
    app.client = server(const []);
    await expectLater(app.createCustomChannel('', const ChannelSource()), throwsStateError);
    await expectLater(
        app.createCustomChannel('', const ChannelSource(roots: [box])),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Nothing in the library matches that.')));
    expect(app.allChannels, hasLength(count));
    final named = await app.createCustomChannel('  ', const ChannelSource(seriesKeys: ['taxi|2000']));
    expect(named.name, 'My Channel');
  });

  test('adding a show while one is on keeps it on at the same point; the new show follows', () async {
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(seriesKeys: ['cheers|2000']));
    final now = DateTime.now();
    final before = onAir(ch, now);
    await app.setChannelSource(ch, const ChannelSource(seriesKeys: ['cheers|2000', 'taxi|2000']), now: now);
    expect(onAir(ch, now), before);
    expect(ch.playlist.where((id) => id.startsWith('Taxi')), hasLength(10));
  });

  test('a source without the program on the air starts its playlist now', () async {
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(seriesKeys: ['cheers|2000']));
    final now = DateTime.now();
    await app.setChannelSource(ch, const ChannelSource(seriesKeys: ['taxi|2000']), now: now);
    expect(ch.anchor, now);
    final p = app.scheduleFor(ch)!.playbackAt(now);
    expect(p.item!.id, ch.playlist.first);
    expect(p.positionAt(now), Duration.zero);
  });

  test('reshuffle keeps the program on the air and changes what follows', () async {
    final ch = await app.createCustomChannel('Mix', const ChannelSource(seriesKeys: ['cheers|2000', 'taxi|2000']),
        order: PlaybackOrder.weighted);
    final now = DateTime.now();
    final before = onAir(ch, now);
    final order = [...ch.playlist];
    await app.reshuffleChannel(ch, now: now);
    expect(ch.generation, 1);
    expect(onAir(ch, now), before);
    expect(ch.playlist, isNot(order));
    expect(ch.playlist.toSet(), order.toSet());
  });

  test('reset keeps custom and music channels with their settings', () async {
    final a = await app.createCustomChannel('80s TV', const ChannelSource(seriesKeys: ['cheers|2000']));
    final b = await app.createCustomChannel('Taxi Stand', const ChannelSource(seriesKeys: ['taxi|2000']));
    await app.setSlotRule(b, const SlotRule(length: Duration(minutes: 30)));
    final radio = await app.createMusicChannel('Rock', const ChannelSource(includeEpisodes: false, includeSongs: true));
    await app.resetChannels();
    for (final ch in [a, b, radio]) {
      final kept = app.channelById(ch.id)!;
      expect(kept.number, ch.number);
      expect(kept.source.toJson(), ch.source.toJson());
    }
    expect(app.channelById(b.id)!.slotRule?.length, const Duration(minutes: 30));
    expect(app.allChannels.where((c) => c.auto), isNotEmpty, reason: 'the generated lineup is back');
  });

  test("a generated channel's source can't be changed", () async {
    final generated = app.allChannels.firstWhere((c) => c.auto);
    await expectLater(
        app.setChannelSource(generated, const ChannelSource(seriesKeys: ['taxi|2000'])),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'Only channels you added can change what they play.')));
  });

  test('a refresh puts a new collection item on next, without moving what is on', () async {
    app.client = server(['Cheers-e1', 'Cheers-e2', 'Cheers-e3']);
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(roots: [box]), order: PlaybackOrder.cyclic);
    final playlist = [...ch.playlist];
    final now = DateTime.now();
    final before = onAir(ch, now);
    app.client = server(['Cheers-e1', 'Cheers-e2', 'Cheers-e3', 'Taxi-e4']);
    await app.refreshLibrary(background: true);
    expect(ch.playlist.toSet(), {...playlist, 'Taxi-e4'});
    expect(onAir(ch, now), before);
    final at = ch.playlist.indexOf(before.$1!);
    expect(ch.playlist[(at + 1) % ch.playlist.length], 'Taxi-e4', reason: 'the new episode airs next');
  });

  test('refreshes asked for during a scan wait for it', () async {
    final first = app.refreshLibrary(background: true);
    final second = app.refreshLibrary(background: true);
    expect(app.refreshing, isTrue);
    await second;
    expect(app.refreshing, isFalse, reason: 'the second waited for the scan to finish');
    await first;
  });

  test('a deleted collection leaves the channel in the lineup with nothing to play', () async {
    app.client = server(['Cheers-e1', 'Cheers-e2']);
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(roots: [box]));
    app.client = server(const []);
    await app.refreshLibrary(background: true);
    expect(app.channelById(ch.id), isNotNull);
    expect(ch.playlist, isEmpty);
    expect(app.scheduleFor(ch), isNull);
    expect(app.rootMissing(box), isTrue);
  });

  test('a slot length keeps the program on and puts the anchor on the clock', () async {
    final ch = await app.createCustomChannel('80s TV', const ChannelSource(seriesKeys: ['cheers|2000']));
    final now = DateTime.now();
    final before = onAir(ch, now);
    await app.setSlotRule(ch, const SlotRule(length: Duration(minutes: 30)), now: now);
    expect(onAir(ch, now), before, reason: 'the program keeps its position, whatever the time of day');
    expect(ch.anchor.minute % 30, 0);
    expect(ch.anchor.second, 0);
    // After the program on the air finishes, every slot starts on the half hour.
    final programs = app.scheduleFor(ch)!.programsBetween(now, now.add(const Duration(hours: 4)));
    expect(programs.first.end.minute % 30, 0);
    expect(programs.first.end.second, 0);
    for (final p in programs.skip(1)) {
      expect(p.start.minute % 30, 0, reason: '${p.start}');
      expect(p.end.difference(p.start), const Duration(minutes: 30));
    }
    await expectLater(
        app.setSlotRule(app.allChannels.firstWhere((c) => c.isMusic), const SlotRule(length: Duration(minutes: 30))),
        throwsStateError);
  });

  test('a slot length keeps the position at every point of the program, on every tail', () async {
    for (final tail in TailMode.values) {
      for (var minute = 0; minute < 44; minute += 3) {
        final ch = await app.createCustomChannel('Sweep', const ChannelSource(seriesKeys: ['cheers|2000']));
        final at = ch.anchor.add(Duration(hours: 10, minutes: minute, seconds: 7));
        final before = onAir(ch, at);
        await app.setSlotRule(ch, SlotRule(length: const Duration(minutes: 30), tail: tail), now: at);
        expect(onAir(ch, at), before, reason: '$tail at +$minute min');
        final s = app.scheduleFor(ch)!;
        final slot = s.programAt(at);
        expect(slot.end.minute % 30, 0, reason: '$tail at +$minute min');
        // The next slot, and the ones after it, are whole slots on the clock.
        final next = s.next(slot);
        expect(next.start, slot.end);
        expect(next.end.difference(next.start), const Duration(minutes: 30));
        await app.deleteUserChannel(ch);
      }
    }
  });
}
