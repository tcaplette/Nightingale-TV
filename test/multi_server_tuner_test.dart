import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/server/server_set.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'multi_server_fakes.dart';

void main() {
  late Directory dir;
  late AppState app;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;
  late FakeServer home;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('multi_tuner');
    now = DateTime.now();
    player = FakePlayer([]);
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();

  /// The profile signed in to [main] with [added] added and scanned.
  Future<void> start(FakeItems main, FakeServer added) async {
    home = FakeServer('Home', items: main, serverId: 'home');
    app = await signedInApp(
        dir,
        LibraryIndex.fromJellyfinItems(
            seriesItems: main.series, episodeItems: main.episodes, movieItems: main.movies, fetchedAt: DateTime(2026)));
    app.client = home.client;
    app.session = home.session;
    await app.addServer(added.session, added.client, refresh: false);
    await app.refreshLibrary(background: true);
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      ..preload = false
      ..sampleEvery = const Duration(hours: 1);
  }

  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)! as ChannelSchedule;

  /// Tunes [ch] 10 s into a program part.
  Future<ScheduledProgram> tuneIntoPart(Channel ch) async {
    var seg = scheduleOf(ch).playbackAt(now);
    for (var i = 0; i < 50 && (seg.isBreak || seg.item == null || seg.duration < const Duration(minutes: 1)); i++) {
      seg = scheduleOf(ch).playbackAt(seg.end);
    }
    now = seg.start.add(const Duration(seconds: 10));
    await tuner.tune(ch);
    await settle();
    return seg;
  }

  /// The channel of genre [name], or of the show [name].
  Channel genre(String name) => app.channels.firstWhere(
      (c) => c.source.genres.contains(name) || c.source.seriesKeys.contains('${name.toLowerCase()}|2000'));

  final comedy = fakeItems(shows: const {'Alpha': 20, 'Beta': 20}, genres: const {
    'Alpha': ['Comedy'],
    'Beta': ['Comedy'],
  });
  final drama = fakeItems(shows: const {'Gamma': 20, 'Delta': 20}, genres: const {
    'Gamma': ['Drama'],
    'Delta': ['Drama'],
  });

  test("each item plays from its own server, which sees only its own ids", () async {
    final plex = FakeServer('Plex', items: renamed(drama, 'p'), url: 'https://plex.example', serverId: 'p');
    await start(comedy, plex);
    final part = await tuneIntoPart(genre('Drama'));
    expect(part.item!.id, startsWith('s2~'));
    final opened = player.opens.last.url;
    expect(opened.host == 'plex.example' || opened.host == '127.0.0.1', isTrue);
    expect(opened.toString(), isNot(contains('~')));
    expect(plex.client.reports.single.$2.itemId, part.item!.id.substring(3));
    expect(home.client.reports, isEmpty);

    await tuneIntoPart(genre('Comedy'));
    expect(player.opens.last.url.toString(), isNot(contains('plex.example')));
    expect(home.client.reports.where((r) => r.$1 == 'start'), hasLength(1));
    for (final r in [...plex.requests, ...home.requests]) {
      expect(r, isNot(contains('~')));
    }
  });

  test('a mirrored episode plays from the first server in Play from, and reports only there', () async {
    final mirror = FakeServer('Mirror', items: renamed(comedy, 'x'), url: 'https://mirror.example', serverId: 'm');
    await start(comedy, mirror);
    await app.moveServer('s2', -1);
    final part = await tuneIntoPart(app.channels.first);
    // The entry keeps the main server's id; the copy plays from the mirror.
    expect(part.item!.id, isNot(startsWith('s2~')));
    expect(tuner.debugPlayingKey, 's2');
    expect(mirror.client.reports.single.$2.itemId, 'x${part.item!.id}');
    expect(home.client.reports, isEmpty);
  });

  test('a server that goes down mid-program fails over to the next copy at the same position', () async {
    final mirror = FakeServer('Mirror', items: renamed(comedy, 'x'), url: 'https://mirror.example', serverId: 'm');
    await start(comedy, mirror);
    await app.moveServer('s2', -1);
    await tuneIntoPart(app.channels.first);
    expect(tuner.debugPlayingKey, 's2');
    final opensBefore = player.opens.length;

    mirror.down = true;
    now = now.add(const Duration(minutes: 1));
    player.failNow();
    for (var i = 0; i < 20 && player.opens.length == opensBefore; i++) {
      await settle();
    }
    expect(player.opens.length, opensBefore + 1);
    expect(tuner.debugPlayingKey, 'main');
    expect(app.servers.byKey('s2')!.state, ServerState.unreachable);
    final expected = tuner.segment!.positionAt(now);
    expect(player.opens.last.start, expected);
    expect(tuner.status, isNot(TunerStatus.error));

    // Back up: used again once a ping finds it.
    mirror.down = false;
    await app.pingUnreachable();
    expect(app.servers.byKey('s2')!.state, ServerState.ok);
    await tuner.tune(app.channels.first);
    await settle();
    expect(tuner.debugPlayingKey, 's2');
  });

  test("with the only copy's server down, the channel fails as it always has", () async {
    final plex = FakeServer('Plex', items: renamed(drama, 'p'), url: 'https://plex.example', serverId: 'p');
    await start(comedy, plex);
    plex.down = true;
    player.onOpen = (_) => OpenResult.errors;
    await tuneIntoPart(genre('Drama'));
    for (var i = 0; i < 20 && tuner.status != TunerStatus.error; i++) {
      await settle();
    }
    expect(tuner.status, TunerStatus.error);
  });

  test("a server's quality limit caps its streams; the profile's cap stays for the others", () async {
    final plex = FakeServer('Plex', items: renamed(drama, 'p'), url: 'https://plex.example', serverId: 'p');
    await start(comedy, plex);
    await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
    await app.setServerQualityLimit('s2', 2000);
    await tuneIntoPart(genre('Drama'));
    expect(plex.client.decisions.last.maxBitrate, 2000000);
    expect(plex.client.decisions.last.id, isNot(contains('~')));
    await tuneIntoPart(genre('Comedy'));
    expect(home.client.decisions.last.maxBitrate, 8000000);
  });
}
