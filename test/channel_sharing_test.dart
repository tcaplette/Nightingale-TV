import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/channel_groups.dart';
import 'package:nightingale_tv/channels/channel_numbers.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/sharing/channel_recipe.dart';
import 'package:nightingale_tv/sharing/channel_shares.dart';
import 'package:nightingale_tv/sharing/recipe_cache.dart';
import 'package:nightingale_tv/sharing/share_client.dart';
import 'package:nightingale_tv/sharing/share_service.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';
import 'sharing_fakes.dart';

/// The sender's recipe: [shows]' episodes in airing order, show by show.
Map<String, Object?> senderRecipe(Map<String, int> shows, {String name = '90s Sitcoms', DateTime? anchor}) {
  final library = fakeLibrary(shows: shows);
  final ch = Channel(
    id: 'user:sender',
    number: 7,
    name: name,
    icon: const ChannelIcon.builtin('weekend'),
    source: const ChannelSource(includeEpisodes: false),
    order: PlaybackOrder.cyclic,
    playlist: [for (final e in library.episodes) e.id],
    anchor: anchor ?? DateTime(2026, 11, 1),
    auto: false,
  );
  return ChannelRecipe.fromChannel(ch, const [], library, station: 'Tyler TV').toJson();
}

void main() {
  late Directory dir;
  late Household h;
  late FakeShareBackend backend;
  late ShareService service;

  AppState app() => h.app!;
  ChannelShares channels() => service.channels;

  setUp(() async {
    ChannelShares.publishDelay = Duration.zero;
    backend = FakeShareBackend()
      ..profile = {
        'user_id': FakeShareBackend.userId,
        'display_name': 'Sam',
        'handle': 'sam',
        'avatar': 'fox',
        'avatar_color': 0,
        'station': 'Sam TV',
      }
      ..friends.add(const ShareProfile(userId: 'user-tyler', name: 'Tyler', handle: 'tyler'));
    dir = await Directory.systemTemp.createTemp('ntv_channel_sharing');
    await writeHousehold(dir, momAndKids(), fakeLibrary(shows: const {'Alpha': 10, 'Beta': 4}, movies: 2));
    h = await openHousehold(dir);
    await h.select(h.profiles.firstWhere((p) => p.name == 'Mom'));
    service = h.sharing = ShareService(h, h.root,
        url: 'https://share.test',
        key: 'sb_publishable_test',
        host: 'share.example',
        httpClient: backend.client,
        watchLifecycle: false);
    await service.load();
    final c = await service.setUp(h.current!);
    await c!.verifyCode('sam@example.com', FakeShareBackend.otp);
    await service.attachChannels();
    await channels().connect();
  });

  tearDown(() async {
    service.dispose();
    h.leave();
    h.backups?.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dir.delete(recursive: true);
  });

  Future<Channel> addShared(Map<String, Object?> recipe, {String id = 'sc-1'}) async {
    backend.shareIn(id, recipe);
    await channels().refreshIncoming();
    final s = channels().waiting.singleWhere((s) => s.sharedChannelId == id);
    return channels().add(await channels().preview(s));
  }

  group('Shared with you', () {
    test('a new share waits, is noticed once, and Add makes the next channel', () async {
      backend.shareIn('sc-1', senderRecipe(const {'Alpha': 10, 'Beta': 4}));
      final highest = ChannelNumbers.nextGenerated(app().channels);
      await channels().refreshIncoming();
      expect(channels().waiting.length, 1);
      expect(channels().notice.value,
          'Tyler shared 1 channel with you. Open Menu → Sharing to add that channel.');
      channels().notice.value = null;
      await channels().refreshIncoming();
      expect(channels().notice.value, isNull, reason: 'once per new set of shares');

      final preview = await channels().preview(channels().waiting.single);
      expect((preview.match!.matched, preview.match!.total), (14, 14));
      final ch = await channels().add(preview);
      expect(ch.number, highest);
      expect(ch.name, '90s Sitcoms');
      expect(ch.share!.ownerName, 'Tyler');
      expect(ch.share!.station, 'Tyler TV');
      expect((ch.share!.matched, ch.share!.total), (14, 14));
      expect(ch.playlist, [for (var i = 1; i <= 10; i++) 'Alpha-e$i', for (var i = 1; i <= 4; i++) 'Beta-e$i']);
      expect(channels().waiting, isEmpty);
      expect(backend.incoming.single['state'], 'added');
      // On the air at once, and under the Shared tab.
      expect(app().scheduleFor(ch)!.programAt(DateTime.now()).item, isNotNull);
      final auto = AutoGroups(app().library, app().blocks, kidProfile: false);
      expect([for (final c in app().channels) if (auto.contains(GuideTabs.shared, c)) c.id], [ch.id]);
    });

    test('nothing matching offers only Decline; Decline leaves the list', () async {
      backend.shareIn('sc-9', senderRecipe(const {'Zeta': 5}));
      await channels().refreshIncoming();
      final p = await channels().preview(channels().waiting.single);
      expect(p.match!.none, isTrue);
      expect(p.canAdd, isFalse);
      await channels().decline(p.share);
      expect(channels().waiting, isEmpty);
      expect(backend.incoming.single['state'], 'declined');
    });

    test('a recipe from a newer app asks for an update', () async {
      backend.shareIn('sc-2', {...senderRecipe(const {'Alpha': 3}), 'v': 2});
      await channels().refreshIncoming();
      final p = await channels().preview(channels().waiting.single);
      expect(p.tooNew, isTrue);
      expect(p.canAdd, isFalse);
    });
  });

  group('Shared copies', () {
    test('an update keeps the program on the air, and the receiver\'s name and number', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10}));
      await app().updateChannel(ch, name: 'My Sitcoms', number: 412);
      final before = DateTime.now();
      final playing = app().scheduleFor(ch)!.playbackAt(before);
      final item = playing.item!.id;
      final position = playing.positionAt(before);

      backend.publish('sc-1', senderRecipe(const {'Alpha': 10, 'Beta': 4}, name: 'Renamed by Tyler'));
      await channels().refreshIncoming();
      final after = DateTime.now();
      final copy = app().channelById(ch.id)!;
      expect(copy.share!.version, 2);
      expect(copy.playlist.length, 14);
      expect((copy.name, copy.number), ('My Sitcoms', 412));
      final now = app().scheduleFor(copy)!.playbackAt(after);
      expect(now.item!.id, item, reason: 'what was on the air didn\'t jump');
      expect((now.positionAt(after) - position - after.difference(before)).abs(), lessThan(const Duration(seconds: 2)));
    });

    test('Keep updated off: newer versions wait', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10}));
      await app().setKeepUpdated(ch, false);
      backend.publish('sc-1', senderRecipe(const {'Alpha': 10, 'Beta': 4}));
      await channels().refreshIncoming();
      expect(app().channelById(ch.id)!.playlist.length, 10);
    });

    test('an ended share marks the copy "No longer updated" and keeps it', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10}));
      backend.end('sc-1');
      await channels().refreshIncoming();
      final copy = app().channelById(ch.id)!;
      expect(copy.share!.ended, isTrue);
      expect(copy.share!.keepUpdated, isFalse);
      expect(app().channels, contains(copy));
    });

    test('content edits stop updates with the notice; name, icon, number, retro, logo and plan don\'t', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10}));
      await app().updateChannel(ch, name: 'Mine', icon: const ChannelIcon.builtin('tv'), number: 300);
      await app().setChannelRetro(ch, const ChannelRetro(crt: CrtStyle.off));
      await app().setChannelLogoMode(ch, LogoMode.off);
      await app().setChannelPlan(ch, BreakPlan.off);
      expect(ch.share!.keepUpdated, isTrue);
      expect(ch.share!.edited, isFalse);
      final notice = app().shareStopNotice(ch);
      expect(notice, "This channel won't follow Tyler's changes any more.");
      await app().setChannelSource(ch, ChannelSource(seriesKeys: [app().library.series.first.key]));
      expect(ch.share!.edited, isTrue);
      expect(ch.share!.keepUpdated, isFalse);
      expect(app().shareStopNotice(ch), isNull);
    });

    test('reordering a copy is a content edit and keeps its programs', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10}));
      await app().updateChannel(ch, order: PlaybackOrder.random);
      expect(ch.share!.edited, isTrue);
      expect(ch.playlist.toSet(), {for (var i = 1; i <= 10; i++) 'Alpha-e$i'});
    });

    test('a library scan re-matches copies and keeps them off the source rules', () async {
      final ch = await addShared(senderRecipe(const {'Alpha': 10, 'Gamma': 3}));
      expect((ch.share!.matched, ch.share!.total), (10, 13));
      final server = FakeServer('Home', items: fakeItems(shows: const {'Alpha': 10, 'Beta': 4, 'Gamma': 3}, movies: 2));
      app().client = server.client;
      await app().refreshLibrary(background: true);
      final copy = app().channelById(ch.id)!;
      expect((copy.share!.matched, copy.share!.total), (13, 13));
      expect(copy.playlist.length, 13);
      expect(copy.playlist.last, 'Gamma-e3', reason: 'in the recipe\'s order');
    });

    test('Channel.share round-trips; old channel files load unchanged', () {
      final link = ShareLink(
          id: 'sc-1', role: ShareRole.incoming, owner: 'u', ownerName: 'Tyler', ownerHandle: 'tyler', version: 3, matched: 4, total: 5);
      final ch = Channel(
          id: 'user:x',
          number: 1,
          name: 'x',
          icon: const ChannelIcon.builtin('tv'),
          source: const ChannelSource(),
          order: PlaybackOrder.cyclic,
          playlist: const [],
          anchor: DateTime(2026),
          share: link);
      final again = Channel.fromJson(jsonDecode(jsonEncode(ch.toJson())) as Map<String, Object?>);
      expect(again.share!.toJson(), link.toJson());
      final old = ch.toJson()..remove('share');
      expect(Channel.fromJson(old).share, isNull);
      expect(Channel.fromJson(old).toJson().containsKey('share'), isFalse);
      expect(jsonEncode(link.toJson()), isNot(contains('token')));
    });

    test('the recipe cache stays out of backups', () async {
      await addShared(senderRecipe(const {'Alpha': 10}));
      final cache = Directory(app().storage.pathOf(RecipeCache.folder));
      expect(cache.listSync(), hasLength(1));
      await h.flushAll();
      final built = await BackupArchive.build(dir, reason: BackupReason.manual, device: 'Test TV');
      final text = utf8.decode(gzip.decode(built.bytes));
      expect(text, isNot(contains('share_recipes')));
      expect(text, contains('"share"'), reason: 'the copy itself is backed up');
    });
  });

  group('Sending', () {
    test('send to a friend, republish on a change, Stop sharing', () async {
      final ch = app().channels.firstWhere((c) => !c.isLive && !c.isMusic);
      await channels().send([ch], to: backend.friends);
      expect(backend.lastShare!['to'], ['user-tyler']);
      final id = ch.share!.id;
      expect(ch.share!.role, ShareRole.out);
      expect(backend.sharedChannels[id]!['version'], 1);
      final recipe = jsonEncode(backend.sharedChannels[id]!['recipe']);
      expect(recipe, contains('"station":"Sam TV"'));
      for (final itemId in ch.playlist.take(5)) {
        expect(recipe, isNot(contains('"$itemId"')));
      }

      // A rename is republished within publishDelay (here at once).
      await app().updateChannel(ch, name: 'Renamed');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(backend.sharedChannels[id]!['version'], 2);
      expect(backend.lastShare!.containsKey('to'), isFalse, reason: 'a republish shares with nobody new');
      expect(ch.share!.version, 2);

      final out = await channels().outgoing();
      expect(out.single.receivers.single.name, 'Tyler');
      await channels().stop(id);
      expect(backend.sharedChannels[id]!['stopped'], isTrue);
      expect(app().channelById(ch.id)!.share, isNull);
    });

    test('Get a link gives a channels invite', () async {
      final ch = app().channels.firstWhere((c) => !c.isLive && !c.isMusic);
      final r = await channels().send([ch], link: true);
      expect(r.invite!.code, 'CH4NL5');
      expect(backend.lastShare!['link'], isTrue);
    });

    test('removing a shared channel stops sharing it', () async {
      final custom = await app().createCustomChannel('Mine', ChannelSource(seriesKeys: [app().library.series.first.key]));
      await channels().send([custom], to: backend.friends);
      final id = custom.share!.id;
      await app().deleteUserChannel(custom);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(backend.sharedChannels[id]!['stopped'], isTrue);
    });

    test('live and music channels can\'t be shared, with the reasons', () {
      final music = Channel(
          id: 'm',
          number: 1,
          name: 'm',
          icon: const ChannelIcon.builtin('tv'),
          source: const ChannelSource(includeSongs: true),
          order: PlaybackOrder.random,
          playlist: const [],
          anchor: DateTime(2026));
      expect(app().shareProblem(music), "Music channels can't be shared");
      final live = Channel.live(
          ref: const LiveRef(sourceId: 's', key: 'k'), number: 2, name: 'Live', icon: const ChannelIcon.builtin('tv'));
      expect(app().shareProblem(live), "Live channels play from your own tuner and can't be shared");
    });
  });

  test('a profile linked before channel sharing scans once for provider ids on connect', () async {
    final state = File(app().storage.pathOf('share_state.json'));
    await app().storage.flush();
    expect(state.readAsStringSync(), contains('"idsScanned":true'));
    // As if linked before this version: no record of the scan.
    state.deleteSync();
    final server = FakeServer('Home', items: fakeItems(shows: const {'Alpha': 10, 'Beta': 4}, movies: 2));
    app().client = server.client;
    final again = ChannelShares();
    await again.attach(service.active, app());
    await app().refreshLibrary(background: true);
    expect(
        server.requests.where((r) => r.contains('IncludeItemTypes=Episode')).any((r) => r.contains('ProviderIds')), isTrue);
    await app().storage.flush();
    expect(state.readAsStringSync(), contains('"idsScanned":true'));
    server.requests.clear();
    final third = ChannelShares();
    await third.attach(service.active, app());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.requests.where((r) => r.contains('IncludeItemTypes=Episode')), isEmpty, reason: 'only once');
    again.dispose();
    third.dispose();
  });

  group('Provider ids (4.1)', () {
    late Directory one;
    setUp(() async => one = await Directory.systemTemp.createTemp('ntv_share_ids'));
    tearDown(() async => one.delete(recursive: true));

    test('a linked one-server profile asks for them; an unlinked one sends the same requests as before', () async {
      final items = fakeItems(shows: const {'Alpha': 3}, movies: 1);
      final server = FakeServer('Home', items: items);
      final solo = await signedInApp(one, fakeLibrary(shows: const {'Alpha': 3}, movies: 1));
      solo.client = server.client;
      bool idsAsked(String type) =>
          server.requests.where((r) => r.contains('IncludeItemTypes=$type')).any((r) => r.contains('ProviderIds'));

      await solo.refreshLibrary(background: true);
      expect(idsAsked('Episode'), isFalse);
      expect(idsAsked('Movie'), isFalse);
      final unlinked = [...server.requests];

      server.requests.clear();
      await solo.refreshLibrary(background: true);
      expect(server.requests, unlinked, reason: 'unlinked: the same requests every time');

      server.requests.clear();
      solo.sharingLinked = () => true;
      await solo.refreshLibrary(background: true);
      expect(idsAsked('Episode'), isTrue);
      expect(idsAsked('Movie'), isTrue);
      await solo.close();
    });
  });

}
