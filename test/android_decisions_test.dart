// Android's playback decisions (android-playback, "Every segment's method
// comes from the capability decision on Android"), on Linux through
// PlatformInfo's override. The Linux rules are in tuner_test.dart.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/platform/platform_info.dart';
import 'package:nightingale_tv/playback/tuner.dart';

import 'fake_playback.dart';
import 'fixtures.dart';

bool isStatic(Uri u) => u.path.endsWith('/stream') && u.queryParameters['static'] == 'true';
bool isTranscode(Uri u) => u.path.endsWith('/stream.ts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakeClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;

  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  Tuner newTuner() => Tuner(app, player: player, clock: () => now)
    ..prefetch = false
    ..preload = false
    ..sampleEvery = const Duration(hours: 1);

  setUp(() async {
    PlatformInfo.debugOverride = TargetPlatform.android;
    dir = await Directory.systemTemp.createTemp('nightingale_tv_android_decisions');
    app = await signedInApp(dir, library);
    log = [];
    client = FakeClient(log);
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    tuner = newTuner();
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    // Tuning saves the last channel in the background.
    await app.storage.flush();
    await dir.delete(recursive: true);
    PlatformInfo.debugReset();
  });

  Future<void> settle() => pumpEventQueue();

  bool isPart(ScheduledProgram s) => !s.isBreak && s.item != null && !s.isCommercial;

  /// A program part on [ch] that a commercial break follows.
  ScheduledProgram partBeforeBreak(Channel ch, DateTime from) {
    final s = app.scheduleFor(ch)!;
    var seg = s.playbackAt(from);
    for (var i = 0; i < 200; i++) {
      final next = s.playbackAt(seg.end);
      if (isPart(seg) && next.isCommercial && seg.duration > const Duration(seconds: 30)) return seg;
      seg = next;
    }
    throw StateError('no part found');
  }

  Future<ScheduledProgram> tuneIntoPart(Channel ch) async {
    final part = partBeforeBreak(ch, now);
    now = part.start.add(const Duration(seconds: 10));
    await tuner.tune(ch);
    await settle();
    return part;
  }

  Future<ScheduledProgram> advance() async {
    final next = app.scheduleFor(tuner.channel!)!.playbackAt(tuner.segment!.end);
    now = next.start.add(const Duration(milliseconds: 500));
    await tuner.debugSegmentEnded();
    await settle();
    return tuner.segment!;
  }

  group('setting off', () {
    setUp(() => app.setGlobalPlan(BreakPlan.automatic));

    test('each item is asked once, with the device profile and no cap, and plays from the static stream', () async {
      expect(app.settings.playback, PlaybackSettings.off);
      for (var i = 0; i < 10; i++) {
        await tuner.channelUp();
        await settle();
      }
      expect(player.opens, isNotEmpty);
      expect(player.opens.every((o) => isStatic(o.url)), isTrue);
      final ids = [for (final d in client.decisions) d.id];
      expect(ids.toSet(), hasLength(ids.length), reason: 'at most one PlaybackInfo per item');
      expect(client.decisions.every((d) => d.maxBitrate == null && !d.force), isTrue);
      expect(client.decisions.every((d) => d.profile?['Name'] == 'Nightingale TV (Android)'), isTrue);
      expect(client.stopped, isEmpty, reason: 'no ActiveEncodings');
    });

    test('a commercial the device can\'t decode plays as a conversion, uncapped; the part after it as decided', () async {
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 8000));
      for (final c in library.commercials) {
        client.converts[c.sourceId] = false;
      }
      for (final e in library.episodes) {
        client.bitrates[e.id] = 5000000;
      }
      final part = await tuneIntoPart(app.channels.first);
      expect(isStatic(player.opens.single.url), isTrue, reason: 'under the cap, decodable');
      expect(client.decisions.single.maxBitrate, 8000000);
      final ad = await advance();
      expect(ad.isCommercial, isTrue);
      final open = player.opens.last;
      expect(isTranscode(open.url), isTrue);
      expect(client.decisions.last.id, ad.item!.sourceId);
      expect(client.decisions.last.maxBitrate, isNull, reason: 'the cap is never for commercials');
      // From the clip's start to its end, in the stream's own time.
      final joinedAt = ad.positionAt(now);
      expect(open.url.queryParameters['StartTimeTicks'], '${joinedAt.inMicroseconds * 10}');
      expect(open.end, ad.itemTo - joinedAt);
      expect(part.item!.sourceId, isNot(ad.item!.sourceId));
    });

    test('a re-encode with no cap asks for what the source needs; a direct stream and a set cap are not changed', () async {
      for (final e in library.episodes) {
        client.converts[e.id] = false;
        client.bitrates[e.id] = 2200000;
      }
      // Each tune below must be a program not decided yet this session.
      final decided = <String>{};
      void untilUndecided(Channel ch) {
        for (var i = 0; i < 500 && decided.contains(partBeforeBreak(ch, now).item!.sourceId); i++) {
          now = now.add(const Duration(minutes: 7));
        }
        decided.add(partBeforeBreak(ch, now).item!.sourceId);
      }

      untilUndecided(app.channels.first);
      await tuneIntoPart(app.channels.first);
      expect(player.opens.single.url.queryParameters['VideoBitrate'], '4400000', reason: 'twice a 2.2 Mbps HEVC source');

      await tuner.stop();
      for (final e in library.episodes) {
        client.converts[e.id] = true;
      }
      untilUndecided(app.channels[1]);
      await tuneIntoPart(app.channels[1]);
      expect(player.opens.last.url.queryParameters.containsKey('VideoBitrate'), isFalse, reason: 'direct stream');

      await tuner.stop();
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, maxKbps: 20000));
      for (final e in library.episodes) {
        client.converts[e.id] = false;
      }
      untilUndecided(app.channels[2]);
      await tuneIntoPart(app.channels[2]);
      expect(player.opens.last.url.queryParameters.containsKey('VideoBitrate'), isFalse, reason: 'the cap decides');
    });

    test('a fallback with no cap asks for what the source needs too', () async {
      for (final e in library.episodes) {
        client.bitrates[e.id] = 3000000;
      }
      player.onOpen = (url) => isStatic(url) ? OpenResult.errors : OpenResult.plays;
      await tuneIntoPart(app.channels.first);
      expect(player.opens.last.url.queryParameters['VideoBitrate'], '6000000');
    });

    test('a direct stream opens the conversion and is reported as DirectStream', () async {
      for (final e in library.episodes) {
        client.converts[e.id] = true;
      }
      await tuneIntoPart(app.channels.first);
      expect(isTranscode(player.opens.single.url), isTrue);
      final (kind, report) = client.reports.single;
      expect(kind, 'start');
      expect(report.playMethod, PlayMethod.directStream);
      expect(report.toJson()['PlayMethod'], 'DirectStream');
    });

    test('a part that fails to open is converted, whatever the setting', () async {
      player.onOpen = (url) => isStatic(url) ? OpenResult.errors : OpenResult.plays;
      final part = await tuneIntoPart(app.channels.first);
      final forced = client.decisions.where((d) => d.force).single;
      expect((forced.id, forced.maxBitrate), (part.item!.sourceId, null));
      expect(forced.profile, isNotNull);
      expect(isTranscode(player.opens.last.url), isTrue);
      expect(tuner.status, TunerStatus.playing);
    });

    test('the neighbours\' decisions are asked ahead, and tuning there asks nothing', () async {
      tuner.prefetch = true;
      final channels = app.channels;
      await tuneIntoPart(channels.first);
      player.buffered = 12.0;
      await tuner.debugSample();
      await settle();
      final neighbour = app.scheduleFor(channels[1])!.programAt(now).item!;
      expect([for (final d in client.decisions) d.id], contains(neighbour.sourceId));
      final asked = client.decisions.length;
      await tuner.channelUp();
      await settle();
      expect([for (final d in client.decisions.skip(asked)) d.id], isNot(contains(neighbour.sourceId)));
    });

    test('the launch channel\'s decision is asked during start-up, and the first tune awaits it', () async {
      final ch = app.channels[1];
      await app.setLastChannel(ch);
      tuner.dispose();
      await app.close();
      client.decisions.clear();
      client.holdDecisions = Completer();
      app = AppState(app.storage, sessionClient: (_) => client);
      await app.start();
      await settle();
      expect(client.decisions, hasLength(1), reason: 'asked as soon as the lineup is ready');
      expect(client.decisions.single.id, app.scheduleFor(ch)!.playbackAt(DateTime.now()).item!.sourceId);
      player = FakePlayer(log);
      now = DateTime.now();
      tuner = newTuner();
      unawaited(tuner.tune(ch));
      await settle();
      expect(player.opens, isEmpty, reason: 'the tune awaits the request in flight');
      client.holdDecisions!.complete();
      await settle();
      expect(player.opens, hasLength(1));
      expect(client.decisions, hasLength(1), reason: 'no second PlaybackInfo');
    });
  });

  group('volume leveling (volume-leveling)', () {
    const channel = MethodChannel('nightingale_tv/player');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      // A box that passes AC-3 and E-AC-3 through to HDMI but decodes
      // neither, asked at start-up.
      tuner.dispose();
      await app.close();
      messenger.setMockMethodCallHandler(channel, (call) async => switch (call.method) {
            'capabilities' => {
                'video': [
                  {'codec': 'h264', 'profiles': ['main', 'high'], 'maxWidth': 1920, 'maxHeight': 1080, 'maxFps': 60},
                ],
                'audio': ['aac', 'mp3'],
                'passthrough': ['ac3', 'eac3'],
                'maxChannels': 6,
              },
            _ => null,
          });
      app = await signedInApp(dir, library);
      app.client = client;
      await app.setGlobalPlan(BreakPlan.automatic);
      player = FakePlayer(log);
      tuner = newTuner();
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Set<String> audioCodecs(Map<String, Object?>? profile) => {
          for (final d in (profile!['DirectPlayProfiles'] as List).cast<Map<String, Object?>>())
            ...'${d['AudioCodec']}'.split(','),
        };

    test('turning it on clears the decisions, re-tunes once, and asks without passthrough', () async {
      final part = await tuneIntoPart(app.channels.first);
      final source = part.item!.sourceId;
      expect(player.opens, hasLength(1));
      expect(audioCodecs(client.decisions.last.profile), containsAll(['ac3', 'eac3']), reason: 'passthrough while off');
      expect(app.savedDecision(source, null), isNotNull);
      client.decisions.clear();

      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      await settle();
      expect(player.leveling, [false, true], reason: 'the player is rebuilt with it');
      expect(player.opens, hasLength(2), reason: 're-tuned once');
      expect(tuner.segment!.item!.sourceId, source, reason: 'the same channel and program');
      final asked = client.decisions.where((d) => d.id == source).toList();
      expect(asked, hasLength(1), reason: 'the cleared decision is asked again, once');
      expect(audioCodecs(asked.single.profile), {'aac', 'mp3'}, reason: 'Jellyfin converts AC-3');

      client.decisions.clear();
      await app.setPlayback(PlaybackSettings.off);
      await settle();
      expect(player.leveling, [false, true, false]);
      expect(player.opens, hasLength(3), reason: 're-tuned once more');
      expect(audioCodecs(client.decisions.where((d) => d.id == source).single.profile), containsAll(['ac3', 'eac3']),
          reason: 'passthrough is back');
    });

    test('other Playback changes don\'t touch it or re-tune', () async {
      await tuneIntoPart(app.channels.first);
      await app.setPlayback(const PlaybackSettings(maxKbps: 8000));
      await settle();
      expect(player.leveling, [false]);
      expect(player.opens, hasLength(1));
    });

    test('saved on, the first profile already leaves passthrough out', () async {
      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      tuner.dispose();
      player = FakePlayer(log);
      tuner = newTuner();
      expect(player.leveling, [true]);
      client.decisions.clear();
      await tuneIntoPart(app.channels.first);
      expect(player.opens, hasLength(1));
      expect(audioCodecs(client.decisions.first.profile), {'aac', 'mp3'});
    });
  });

  test('on Linux nothing of this happens: setting off asks nothing', () async {
    PlatformInfo.debugOverride = TargetPlatform.linux;
    for (var i = 0; i < 5; i++) {
      await tuner.channelUp();
      await settle();
    }
    expect(client.decisions, isEmpty);
  });

  test('on Linux a conversion is never rewritten', () async {
    PlatformInfo.debugOverride = TargetPlatform.linux;
    await app.setGlobalPlan(BreakPlan.automatic);
    await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true));
    player.onOpen = (url) => isStatic(url) ? OpenResult.errors : OpenResult.plays;
    await tuneIntoPart(app.channels.first);
    expect(isTranscode(player.opens.last.url), isTrue);
    expect(player.opens.last.url.queryParameters.containsKey('VideoBitrate'), isFalse);
  });

  group('preloading (segment-handover spec)', () {
    setUp(() async {
      await app.setGlobalPlan(BreakPlan.automatic);
      tuner.preload = true;
    });

    test('a commercial Jellyfin plays directly is asked ahead and preloaded', () async {
      final part = partBeforeBreak(app.channels.first, now);
      now = part.end.subtract(const Duration(seconds: 20));
      await tuner.tune(app.channels.first);
      await settle();
      final ad = app.scheduleFor(app.channels.first)!.playbackAt(part.end);
      expect(client.decisions.map((d) => d.id), contains(ad.item!.sourceId), reason: 'asked within 60 s of it');
      expect(player.enqueued.single.start, ad.itemFrom);
      expect(isStatic(player.enqueued.single.url), isTrue);
    });

    test('a commercial that converts isn\'t preloaded, and opens at the hand-over', () async {
      for (final c in library.commercials) {
        client.converts[c.sourceId] = false;
      }
      final part = partBeforeBreak(app.channels.first, now);
      now = part.end.subtract(const Duration(seconds: 20));
      await tuner.tune(app.channels.first);
      await settle();
      expect(player.enqueued, isEmpty);
      final ad = await advance();
      expect(ad.isCommercial, isTrue);
      expect(isTranscode(player.opens.last.url), isTrue);
    });
  });
}
