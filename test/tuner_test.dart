import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';

import 'fake_playback.dart';
import 'fixtures.dart';
import 'media_files.dart';
import 'package:nightingale_tv/server/media_server.dart';

bool isStatic(Uri u) => u.path.endsWith('/stream') && u.queryParameters['static'] == 'true';
bool isTranscode(Uri u) => u.path.endsWith('/stream.ts');

void main() {
  late Directory dir;
  late AppState app;
  late List<String> log;
  late FakeClient client;
  late FakePlayer player;
  late Tuner tuner;
  late DateTime now;

  // Five channels: everything, plus four genres.
  final library = fakeLibrary(
    shows: {'Alpha': 20, 'Beta': 20, 'Gamma': 20, 'Delta': 20, 'Echo': 20, 'Fox': 20, 'Golf': 20, 'Hotel': 20},
    genres: {
      'Alpha': ['Comedy'],
      'Beta': ['Comedy'],
      'Gamma': ['Drama'],
      'Delta': ['Drama'],
      'Echo': ['Kids'],
      'Fox': ['Kids'],
      'Golf': ['Mystery'],
      'Hotel': ['Mystery'],
    },
    commercials: const [Duration(seconds: 30), Duration(seconds: 15), Duration(seconds: 60)],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_tuner');
    app = await signedInApp(dir, library);
    log = [];
    client = FakeClient(log);
    app.client = client;
    player = FakePlayer(log);
    now = DateTime.now();
    // Asking ahead adds requests the counting tests don't expect; the
    // prefetch tests turn it back on.
    tuner = Tuner(app, player: player, clock: () => now)
      ..prefetch = false
      // Preloading adds playlist calls the counting tests don't expect; the
      // hand-over tests turn it back on.
      ..preload = false
      // Tests take the samples themselves (debugSample).
      ..sampleEvery = const Duration(hours: 1);
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    // Tuning saves the last channel in the background.
    await app.storage.flush();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();

  Future<void> setPlayback({bool on = true, int? mbps}) =>
      app.setPlayback(PlaybackSettings(transcodeIfNeeded: on, maxKbps: mbps == null ? null : mbps * 1000));

  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)! as ChannelSchedule;

  bool isPart(ScheduledProgram s) => !s.isBreak && s.item != null && !s.isCommercial;

  /// The next program part on [ch] from [from] (when [ch] has breaks, one a
  /// mid-program commercial break follows: the same program comes back
  /// after it, whatever the time of day the test runs).
  ScheduledProgram partBeforeBreak(Channel ch, DateTime from) {
    final s = scheduleOf(ch);
    final breaks = app.breaksFor(ch);

    /// The part after the break that starts at [t].
    ScheduledProgram partAfter(DateTime t) {
      var seg = s.playbackAt(t);
      for (var i = 0; i < 50 && seg.isBreak; i++) {
        seg = s.playbackAt(seg.end);
      }
      return seg;
    }

    var seg = s.playbackAt(from);
    for (var i = 0; i < 200; i++) {
      final next = s.playbackAt(seg.end);
      final midBreak = next.isBreak && next.isCommercial && partAfter(next.start).item?.id == seg.item?.id;
      if (isPart(seg) && (!breaks || midBreak) && seg.duration > const Duration(seconds: 30)) {
        return seg;
      }
      seg = next;
    }
    throw StateError('no part found');
  }

  /// Moves the clock into the segment after the one playing, and plays it
  /// as when the segment playing ends.
  Future<ScheduledProgram> advance() async {
    final next = scheduleOf(tuner.channel!).playbackAt(tuner.segment!.end);
    now = next.start.add(const Duration(milliseconds: 500));
    await tuner.debugSegmentEnded();
    await settle();
    return tuner.segment!;
  }

  /// Tunes to [ch] in the middle of a program part.
  Future<ScheduledProgram> tuneIntoPart(Channel ch) async {
    final part = partBeforeBreak(ch, now);
    now = part.start.add(const Duration(seconds: 10));
    await tuner.tune(ch);
    await settle();
    return part;
  }

  group('setting off (direct-play spec)', () {
    test('ten channel changes ask Jellyfin nothing new, and every open is the static stream', () async {
      for (var i = 0; i < 10; i++) {
        await tuner.channelUp();
        await settle();
      }
      expect(player.opens, isNotEmpty);
      expect(client.decisions, isEmpty, reason: 'no PlaybackInfo');
      expect(client.stopped, isEmpty, reason: 'no ActiveEncodings');
      expect(player.opens.every((o) => isStatic(o.url)), isTrue);
    });

    test('waiting for data asks nothing and transcodes nothing; only the buffer is read', () async {
      expect(app.settings.playback, PlaybackSettings.off);
      player.buffered = 1.0;
      await tuneIntoPart(app.channels.first);
      expect(tuner.debugSampling, isTrue, reason: 'sampled whenever the TV plays');
      for (var i = 0; i < 10; i++) {
        await tuner.debugSample();
      }
      expect(player.bufferedReads, 10);
      await settle();
      expect(client.decisions, isEmpty);
      expect(player.opens, hasLength(1), reason: 'nothing reopens what plays');
      expect(player.opens.every((o) => isStatic(o.url)), isTrue);
      await tuner.stop();
      expect(tuner.debugSampling, isFalse);
    });

    test('a failed open shows the error without a transcode retry', () async {
      player.onOpen = (_) => OpenResult.errors;
      await tuneIntoPart(app.channels.first);
      expect(tuner.status, TunerStatus.error);
      expect(client.decisions, isEmpty);
      expect(player.opens, hasLength(1));
    });

    test('direct play is reported as DirectPlay', () async {
      await tuneIntoPart(app.channels.first);
      final (kind, report) = client.reports.single;
      expect(kind, 'start');
      expect(report.playMethod, PlayMethod.directPlay);
      expect(report.toJson()['PlayMethod'], 'DirectPlay');
    });
  });

  test('the player is built the same whatever the setting (mpv config is fixed)', () async {
    // The only configuration the app ever gives mpv; TunerPlayer has no way
    // to change it, so the playback mode can't.
    expect(identical(MediaKitTunerPlayer.configuration, const PlayerConfiguration(title: 'Nightingale TV')), isTrue);
    await setPlayback(mbps: 8);
    expect(identical(MediaKitTunerPlayer.configuration, const PlayerConfiguration(title: 'Nightingale TV')), isTrue);
  });

  group('bitrate cap', () {
    setUp(() async {
      await app.setGlobalPlan(BreakPlan.automatic);
    });

    test('a program over the cap transcodes; the commercials in its breaks direct-play', () async {
      await setPlayback(mbps: 8);
      final part = await tuneIntoPart(app.channels.first);
      final open = player.opens.single;
      expect(isTranscode(open.url), isTrue);
      expect(open.url.host, 'jf.example');
      expect(open.url.queryParameters.keys.map((k) => k.toLowerCase()), isNot(contains('apikey')));
      expect(client.decisions.single.maxBitrate, 8000000);
      // Joined by Jellyfin at the scheduled position; mpv doesn't seek and
      // stops at the part's end, in the stream's own (0-based) time.
      final joinedAt = part.positionAt(part.start.add(const Duration(seconds: 10)));
      expect(open.url.queryParameters['StartTimeTicks'], '${joinedAt.inMicroseconds * 10}');
      expect(open.start, isNull);
      expect(open.end, part.itemTo - joinedAt);

      final ad = await advance();
      expect(ad.isCommercial, isTrue);
      expect(isStatic(player.opens.last.url), isTrue);
      expect(client.decisions, hasLength(1), reason: 'commercials skip the decision');
    });

    test('a transcode in the source\'s own times (Plex) starts at the join point and ends at the part\'s end', () async {
      client.sourceTime = true;
      await setPlayback(mbps: 8);
      final part = await tuneIntoPart(app.channels.first);
      final open = player.opens.single;
      expect(isTranscode(open.url), isTrue);
      final joinedAt = part.positionAt(part.start.add(const Duration(seconds: 10)));
      expect(open.start, joinedAt);
      expect(open.end, part.itemTo);
      expect(tuner.status, TunerStatus.playing);
    });

    test('a program under the cap direct-plays, with one decision across its parts', () async {
      await setPlayback(mbps: 8);
      for (final e in library.episodes) {
        client.bitrates[e.id] = 5000000;
      }
      await tuneIntoPart(app.channels.first);
      final program = tuner.segment!.item!.id;
      // Through the break and into the next part.
      while (true) {
        final s = await advance();
        if (isPart(s)) break;
      }
      expect(tuner.segment!.item!.id, program);
      expect(player.opens.every((o) => isStatic(o.url)), isTrue);
      expect([for (final d in client.decisions) d.id], [program]);
      expect(client.stopped, isEmpty);
    });

    test('a transcoded program\'s later parts transcode without asking again, each as a new job', () async {
      await setPlayback(mbps: 8);
      await tuneIntoPart(app.channels.first);
      final first = player.opens.single.url.queryParameters['PlaySessionId'];
      while (true) {
        final s = await advance();
        if (isPart(s)) break;
      }
      final second = player.opens.last;
      expect(isTranscode(second.url), isTrue);
      expect(client.decisions, hasLength(1));
      expect(second.url.queryParameters['PlaySessionId'], isNot(first));
      expect(second.url.queryParameters['StartTimeTicks'],
          '${tuner.segment!.positionAt(now).inMicroseconds * 10}');
    });

    test('entering a break stops the job before the first commercial opens', () async {
      await setPlayback(mbps: 8);
      await tuneIntoPart(app.channels.first);
      final job = player.opens.single.url.queryParameters['PlaySessionId']!;
      log.clear();
      await advance();
      expect(log.indexOf('stop:$job'), greaterThanOrEqualTo(0));
      expect(log.indexOf('stop:$job'), lessThan(log.indexWhere((l) => l.startsWith('open:'))));
    });

    test('stop() and quitting stop the job', () async {
      await setPlayback(mbps: 8);
      await tuneIntoPart(app.channels.first);
      final job = player.opens.single.url.queryParameters['PlaySessionId']!;
      await tuner.stop();
      expect(client.stopped, [job]);

      await tuneIntoPart(app.channels.first);
      final next = player.opens.last.url.queryParameters['PlaySessionId']!;
      await tuner.stopTranscodeForExit();
      expect(client.stopped, [job, next]);
    });

    test('reports during a transcoded part carry Transcode and the job\'s session', () async {
      await setPlayback(mbps: 8);
      await tuneIntoPart(app.channels.first);
      final job = player.opens.single.url.queryParameters['PlaySessionId'];
      final (kind, report) = client.reports.single;
      expect(kind, 'start');
      expect(report.playMethod, PlayMethod.transcode);
      expect(report.playSessionId, job);
      expect(report.toJson()['PlayMethod'], 'Transcode');
    });

    test('a transcoded episode watched to the end is reported as watched', () async {
      await setPlayback(mbps: 8);
      final ch = app.channels.first;
      // From the program's first part.
      final s = scheduleOf(ch);
      var seg = s.playbackAt(now);
      while (!(isPart(seg) && seg.itemFrom == Duration.zero)) {
        seg = s.playbackAt(seg.end);
      }
      now = seg.start.add(const Duration(milliseconds: 500));
      await tuner.tune(ch);
      await settle();
      final episode = tuner.segment!.item!;
      while (client.reports.where((r) => r.$1 == 'stopped').isEmpty) {
        await advance();
      }
      expect(player.opens.where((o) => o.url.path.contains(episode.id)).every((o) => isTranscode(o.url)), isTrue);
      final stopped = client.reports.firstWhere((r) => r.$1 == 'stopped').$2;
      expect(stopped.itemId, episode.id);
      expect(stopped.position, episode.runtime);
    });

    test('changing the setting applies from the next segment; the part playing plays on', () async {
      await setPlayback(mbps: 8);
      await tuneIntoPart(app.channels.first);
      expect(player.opens, hasLength(1));
      await setPlayback(on: false, mbps: 8);
      await settle();
      expect(player.opens, hasLength(1), reason: 'nothing reopened');
      expect(client.stopped, isEmpty);
      while (true) {
        final s = await advance();
        if (isPart(s)) break;
      }
      expect(isStatic(player.opens.last.url), isTrue);
    });
  });

  group('fallback when direct play fails', () {
    test('Original (no limit): no decision while tuning; a failed open retries once as a transcode', () async {
      await setPlayback();
      await tuneIntoPart(app.channels.first);
      expect(client.decisions, isEmpty);
      expect(isStatic(player.opens.single.url), isTrue);
      await tuner.stop();

      player.onOpen = (url) => isStatic(url) ? OpenResult.errors : OpenResult.plays;
      final part = await tuneIntoPart(app.channels[1]);
      final d = client.decisions.single;
      expect((d.id, d.force, d.maxBitrate), (part.item!.sourceId, true, null));
      expect(isTranscode(player.opens.last.url), isTrue);
      expect(player.opens.last.url.queryParameters['StartTimeTicks'], '${part.positionAt(now).inMicroseconds * 10}');
      expect(tuner.status, TunerStatus.playing);
    });

    test('an open that throws falls back too, under the cap', () async {
      await setPlayback(mbps: 20);
      for (final e in library.episodes) {
        client.bitrates[e.id] = 5000000;
      }
      player.onOpen = (url) => isStatic(url) ? OpenResult.throws : OpenResult.plays;
      await tuneIntoPart(app.channels.first);
      expect([for (final d in client.decisions) (d.force, d.maxBitrate)], [(false, 20000000), (true, 20000000)]);
      expect(tuner.status, TunerStatus.playing);
    });

    test('a fallback that plays settles the program as a transcode', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      await setPlayback();
      player.onOpen = (url) => isStatic(url) && !url.path.contains('ad-') ? OpenResult.errors : OpenResult.plays;
      await tuneIntoPart(app.channels.first);
      while (true) {
        final s = await advance();
        if (isPart(s)) break;
      }
      expect(isTranscode(player.opens.last.url), isTrue);
      expect(client.decisions, hasLength(1), reason: 'the later part didn\'t fail first');
    });

    test('a second failure shows the error state', () async {
      await setPlayback();
      player.onOpen = (_) => OpenResult.errors;
      await tuneIntoPart(app.channels.first);
      expect(tuner.status, TunerStatus.error);
      expect(player.opens, hasLength(2));
      expect(client.stopped, hasLength(1), reason: 'the failed job is stopped');
    });

    test('an error after playing started doesn\'t switch to a transcode', () async {
      await setPlayback();
      await tuneIntoPart(app.channels.first);
      expect(tuner.status, TunerStatus.playing);
      player.failNow();
      await settle();
      expect(tuner.status, TunerStatus.error);
      expect(client.decisions, isEmpty);
      expect(player.opens, hasLength(1));
    });
  });

  // No breaks, so every channel is in a program part whenever this runs.
test('rapid surfing over five transcoding channels leaves at most one job running', () async {
    await setPlayback(mbps: 8);
    client.holdDecisions = Completer<void>();
    final channels = app.channels.take(5).toList();
    expect(channels, hasLength(5));
    for (final ch in channels) {
      unawaited(tuner.tune(ch));
      await settle();
      // Let some decisions arrive between flips, others late.
      if (ch == channels[2]) {
        client.holdDecisions!.complete();
        await settle();
        client.holdDecisions = Completer<void>();
      }
    }
    client.holdDecisions!.complete();
    await settle();
    final started = {
      for (final o in player.opens)
        if (isTranscode(o.url)) o.url.queryParameters['PlaySessionId']!,
    };
    expect(started, isNotEmpty);
    expect(started.difference(client.stopped.toSet()).length, lessThanOrEqualTo(1));
    expect(client.stopped.toSet().difference(started), isEmpty, reason: 'only jobs that were started are stopped');
    await tuner.stop();
    expect(started.difference(client.stopped.toSet()), isEmpty, reason: 'starts and stops balance');
  });

  test('a transcode that hasn\'t started in time is stopped and fails', () async {
    await setPlayback(mbps: 8);
    tuner.transcodeStartup = const Duration(milliseconds: 50);
    player.onOpen = (_) => OpenResult.hangs;
    await tuneIntoPart(app.channels.first);
    expect(tuner.status, TunerStatus.tuning);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(tuner.status, TunerStatus.error);
    expect(client.stopped, hasLength(1));
  });

  group('analyzer budget follows the tuner', () {
    test('with a cap: paused while tuning, a quarter of the cap while playing, free otherwise', () async {
      await setPlayback(mbps: 8);
      expect(app.analyzerBudgetNow, const Budget.unlimited());
      client.holdDecisions = Completer<void>();
      final part = partBeforeBreak(app.channels.first, now);
      now = part.start.add(const Duration(seconds: 10));
      unawaited(tuner.tune(app.channels.first));
      await settle();
      expect(tuner.status, TunerStatus.tuning);
      expect(app.analyzerBudgetNow, const Budget.paused());
      client.holdDecisions!.complete();
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(app.analyzerBudgetNow, const Budget.limited(250000), reason: '2 Mbps');
      await tuner.stop();
      expect(app.analyzerBudgetNow, const Budget.unlimited());
    });

    test('every way out of tuning releases the pause', () async {
      await setPlayback(mbps: 8);
      Future<void> tuneAndCheck(OpenResult result, Future<void> Function() leave) async {
        player.onOpen = (_) => result;
        await tuneIntoPart(app.channels.first);
        await leave();
        expect(app.analyzerBudgetNow, isNot(const Budget.paused()), reason: '$result');
        await tuner.stop();
      }

      tuner.transcodeStartup = const Duration(milliseconds: 50);
      await tuneAndCheck(OpenResult.plays, () async {}); // playing
      await tuneAndCheck(OpenResult.errors, settle); // error (after the fallback fails too)
      await tuneAndCheck(OpenResult.hangs, () => Future<void>.delayed(const Duration(milliseconds: 120))); // timeout
      player.onOpen = (_) => OpenResult.hangs;
      await tuneIntoPart(app.channels.first);
      expect(app.analyzerBudgetNow, const Budget.paused());
      await tuner.stop(); // stop
      expect(app.analyzerBudgetNow, const Budget.unlimited());
    });

    test('with the setting off: paused while tuning and until the file\'s bitrate is known, then a quarter of it',
        () async {
      player.fileBitrate = 8000000;
      expect(app.analyzerBudgetNow, const Budget.unlimited());
      player.onOpen = (_) => OpenResult.noPicture;
      await tuneIntoPart(app.channels.first);
      expect(app.analyzerBudgetNow, const Budget.paused());
      player.showPicture(player.opens.last.start!);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(app.analyzerBudgetNow, const Budget.paused(), reason: 'the bitrate isn\'t read yet');
      await tuner.debugSample();
      expect(app.playingBitrate.value, 8000000);
      expect(app.analyzerBudgetNow, const Budget.limited(250000), reason: '2 Mbps of an 8 Mbps file');
      // The next open reads its own file's bitrate.
      player.onOpen = (_) => OpenResult.plays;
      player.fileBitrate = 4000000;
      await advance();
      expect(app.playingBitrate.value, isNull);
      await tuner.debugSample();
      expect(app.analyzerBudgetNow, const Budget.limited(125000));
      await tuner.stop();
      expect(app.analyzerBudgetNow, const Budget.unlimited());
    });

    test('Original with the toggle on uses the file\'s bitrate too; a cap ignores it', () async {
      player.fileBitrate = 8000000;
      await setPlayback();
      await tuneIntoPart(app.channels.first);
      await tuner.debugSample();
      expect(app.analyzerBudgetNow, const Budget.limited(250000));
      await setPlayback(mbps: 4);
      expect(app.analyzerBudgetNow, const Budget.limited(125000), reason: 'a quarter of 4 Mbps, at once');
    });

    test('a bitrate mpv can\'t tell comes from the library\'s size and runtime', () async {
      final items = fakeItems(shows: const {'Alpha': 20, 'Beta': 20});
      // 22 minutes at 2 Mbps.
      const size = 2000000 * 22 * 60 ~/ 8;
      for (final e in items.episodes) {
        e['MediaSources'] = [
          {'Size': size},
        ];
      }
      final sized = LibraryIndex.fromJellyfinItems(
        seriesItems: items.series,
        episodeItems: items.episodes,
        movieItems: items.movies,
        commercialItems: items.commercials,
        poolsByItem: const {},
        fetchedAt: DateTime(2026),
      );
      final dir2 = await Directory.systemTemp.createTemp('nightingale_tv_tuner_sized');
      final app2 = await signedInApp(dir2, sized);
      app2.client = client;
      final tuner2 = Tuner(app2, player: FakePlayer(log), clock: () => now)
        ..prefetch = false
        ..sampleEvery = const Duration(hours: 1);
      addTearDown(() async {
        tuner2.dispose();
        await app2.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await dir2.delete(recursive: true);
      });
      await tuner2.tune(app2.channels.first);
      await settle();
      expect(tuner2.status, TunerStatus.playing);
      await tuner2.debugSample();
      expect(app2.playingBitrate.value, 2000000);
      expect(app2.analyzerBudgetNow, const Budget.limited(62500));
    });
  });

  group('tuning ends at the first frame', () {
    test('mpv saying "playing" isn\'t tuned in; the picture moving is', () async {
      player.onOpen = (_) => OpenResult.noPicture;
      await tuneIntoPart(app.channels.first);
      expect(tuner.status, TunerStatus.tuning);
      expect(tuner.changingChannel, isTrue);
      expect(app.playbackBusy.value, isTrue, reason: 'analysis holds off until the picture comes');
      player.showPicture(player.opens.last.start!);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.changingChannel, isFalse);
    });

    test('the next segment on the same channel isn\'t a channel change', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      await tuneIntoPart(app.channels.first);
      player.onOpen = (_) => OpenResult.noPicture;
      await advance();
      expect(tuner.status, TunerStatus.tuning);
      expect(tuner.changingChannel, isFalse);
    });

    test('a transcode that shows no picture in time times out, though mpv says "playing"', () async {
      await setPlayback(mbps: 8);
      tuner.transcodeStartup = const Duration(milliseconds: 50);
      player.onOpen = (_) => OpenResult.noPicture;
      await tuneIntoPart(app.channels.first);
      expect(isTranscode(player.opens.single.url), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(tuner.status, TunerStatus.error);
      expect(client.stopped, hasLength(1), reason: 'the job is stopped');
    });
  });

  group('keyframe joins', () {
    /// A program part at least a minute long on [ch], from now on.
    ScheduledProgram longPart(Channel ch) {
      final s = scheduleOf(ch);
      var seg = s.playbackAt(now);
      for (var i = 0; i < 200; i++) {
        if (isPart(seg) && seg.duration > const Duration(minutes: 1)) return seg;
        seg = s.playbackAt(seg.end);
      }
      throw StateError('no long part');
    }

    test('joining mid-show opens at a keyframe; segments starting on schedule open exactly', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final part = longPart(ch);
      now = part.start.add(const Duration(seconds: 30));
      await tuner.tune(ch);
      await settle();
      expect(player.opens.last.exact, isFalse);
      await advance();
      expect(player.opens.last.exact, isTrue);
    });

    test('a join just after a part starts is exact, so the part before can\'t show', () async {
      final ch = app.channels.first;
      final part = longPart(ch);
      now = part.start.add(const Duration(seconds: 5));
      await tuner.tune(ch);
      await settle();
      expect(player.opens.last.exact, isTrue);
    });

    test('a keyframe join that starts early ends its part that much later', () async {
      final ch = app.channels.first;
      final part = longPart(ch);
      player.keyframeEarly = const Duration(seconds: 3);
      now = part.start.add(const Duration(seconds: 30));
      await tuner.tune(ch);
      await settle();
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.segmentEndsAt, part.end.add(const Duration(seconds: 3)));
    });
  });

  group('decisions asked ahead', () {
    test('with a cap, the neighbours\' programs are asked for once tuned in, and tuning there asks nothing', () async {
      tuner.prefetch = true;
      await setPlayback(mbps: 8);
      for (final e in library.episodes) {
        client.bitrates[e.id] = 5000000;
      }
      final channels = app.channels;
      await tuneIntoPart(channels.first);
      await settle();
      expect(client.decisions, hasLength(1), reason: 'nothing asked ahead at the picture itself');
      // mpv has 10 s buffered.
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

    test('with the setting off, nothing is asked ahead', () async {
      tuner.prefetch = true;
      for (var i = 0; i < 3; i++) {
        await tuner.channelUp();
        await settle();
      }
      expect(client.decisions, isEmpty);
    });
  });
  group('a fixed cap is the cap in effect; nothing lowers it', () {
    /// One second of playback with mpv waiting for data (or not).
    Future<void> tick({bool waiting = false, double buffered = 2}) async {
      now = now.add(const Duration(seconds: 1));
      player.buffered = waiting ? 0 : buffered;
      await tuner.debugSample();
      await settle();
    }

    test('a direct play waiting for data plays on, and the next part opens under the same cap', () async {
      await setPlayback(mbps: 8);
      for (final e in library.episodes) {
        client.bitrates[e.id] = 5000000;
      }
      await tuneIntoPart(app.channels.first);
      expect(isStatic(player.opens.single.url), isTrue, reason: '5 Mbps is under 8 Mbps');
      for (var i = 0; i < 30; i++) {
        await tick(waiting: i.isEven);
      }
      expect(player.opens, hasLength(1), reason: 'never reopened mid-part');
      expect(client.decisions.every((d) => d.maxBitrate == 8000000), isTrue);
      expect(app.capInEffect, 8000);
      final first = tuner.segment!.item!.id;
      while (tuner.segment!.item!.id == first) {
        await advance();
      }
      expect(client.decisions.last.maxBitrate, 8000000);
      expect(isStatic(player.opens.last.url), isTrue);
    });

    test('a program over the cap transcodes at the cap and stays there', () async {
      await setPlayback(mbps: 8);
      for (final e in library.episodes) {
        client.bitrates[e.id] = 25000000;
      }
      await tuneIntoPart(app.channels.first);
      expect(client.decisions.single.maxBitrate, 8000000);
      expect(isTranscode(player.opens.single.url), isTrue);
      for (var i = 0; i < 60; i++) {
        await tick(waiting: i % 3 == 0);
      }
      expect(player.opens, hasLength(1));
      expect(client.decisions, hasLength(1));
      expect(app.capInEffect, 8000);
    });

    test('Original asks nothing while tuning, whatever playback does', () async {
      await setPlayback();
      for (var i = 0; i < 3; i++) {
        await tuner.channelUp();
        await settle();
        for (var j = 0; j < 5; j++) {
          await tick(waiting: true);
        }
      }
      expect(client.decisions, isEmpty, reason: 'no PlaybackInfo');
      expect(player.opens.every((o) => isStatic(o.url)), isTrue);
    });

    test('decisions asked ahead use the chosen cap', () async {
      await setPlayback(mbps: 4);
      tuner.prefetch = true;
      await tuneIntoPart(app.channels.first);
      await tick(buffered: 12);
      final ahead = client.decisions.skip(1).toList();
      expect(ahead, isNotEmpty);
      expect(ahead.every((d) => d.maxBitrate == 4000000), isTrue);
      final asked = client.decisions.length;
      await tuner.channelUp();
      await settle();
      expect(client.decisions, hasLength(asked), reason: 'kept under 4 Mbps, found under 4 Mbps');
    });
  });

  group('the launch channel\'s decision', () {
    test('is asked during start-up, once, and the first tune uses it', () async {
      await setPlayback(mbps: 4);
      final ch = app.channels[1];
      await app.setLastChannel(ch);
      tuner.dispose();
      await app.close();
      client.decisions.clear();
      client.holdDecisions = Completer();
      app = AppState(app.storage, sessionClient: (_) => client);
      await app.start();
      expect(client.decisions, hasLength(1), reason: 'asked as soon as the lineup is ready');
      final launched = client.decisions.single.id;
      expect(launched, app.scheduleFor(ch)!.playbackAt(DateTime.now()).item!.sourceId);
      player = FakePlayer(log);
      now = DateTime.now();
      // Not preloading: within a minute of the hand-over, that asks the next
      // segment's decision.
      tuner = Tuner(app, player: player, clock: () => now)
        ..prefetch = false
        ..preload = false
        ..sampleEvery = const Duration(hours: 1);
      unawaited(tuner.tune(ch));
      await settle();
      expect(player.opens, isEmpty, reason: 'the tune awaits the request in flight');
      client.holdDecisions!.complete();
      await settle();
      expect(player.opens, hasLength(1));
      expect(client.decisions, hasLength(1), reason: 'no second PlaybackInfo');
    });

    test('isn\'t asked with the setting off, or on with Original', () async {
      for (final playback in const [PlaybackSettings.off, PlaybackSettings(transcodeIfNeeded: true)]) {
        await app.setPlayback(playback);
        tuner.dispose();
        await app.close();
        client.decisions.clear();
        app = AppState(app.storage, sessionClient: (_) => client);
        await app.start();
        await settle();
        expect(client.decisions, isEmpty, reason: '$playback');
        tuner = Tuner(app, player: player, clock: () => now)
          ..prefetch = false
          ..sampleEvery = const Duration(hours: 1);
      }
    });
  });

  group('decisions are kept for the session only', () {
    /// The app and tuner as after a restart, with the same server.
    Future<void> restart() async {
      tuner.dispose();
      await app.close();
      // The same server: the launch's early decision goes to it too.
      app = AppState(app.storage, sessionClient: (_) => client);
      await app.start();
      player = FakePlayer(log);
      tuner = Tuner(app, player: player, clock: () => now)
        ..prefetch = false
        ..sampleEvery = const Duration(hours: 1);
    }

    test('re-tuning the same program asks nothing new', () async {
      await setPlayback(mbps: 8);
      final part = await tuneIntoPart(app.channels.first);
      expect(client.decisions, hasLength(1));
      await tuner.channelUp();
      await settle();
      final asked = client.decisions.length;
      now = part.start.add(const Duration(seconds: 20));
      await tuner.tune(app.channels.first);
      await settle();
      expect(client.decisions, hasLength(asked));
      expect(isTranscode(player.opens.last.url), isTrue);
    });

    test('after a restart, the decision is asked again, and nothing is saved to disk', () async {
      await setPlayback(mbps: 8);
      final part = await tuneIntoPart(app.channels.first);
      expect(client.decisions, hasLength(1));
      client.decisions.clear();
      now = part.start.add(const Duration(seconds: 20));
      await restart();
      expect(await app.storage.readJson(AppState.legacyDecisionsFile), isNull);
      await tuner.tune(app.channels.first);
      await settle();
      expect(client.decisions.where((d) => d.id == part.item!.sourceId), isNotEmpty,
          reason: 'asked again (at launch or by the tune)');
      expect(isTranscode(player.opens.single.url), isTrue);
      expect(player.opens.single.url.queryParameters['StartTimeTicks'], '${part.positionAt(now).inMicroseconds * 10}');
    });

    test('changing the setting clears the session\'s decisions', () async {
      await setPlayback(mbps: 8);
      final part = await tuneIntoPart(app.channels.first);
      expect(app.savedDecision(part.item!.sourceId, 8000), isNotNull);
      await setPlayback(mbps: 4);
      await setPlayback(mbps: 8);
      expect(app.savedDecision(part.item!.sourceId, 8000), isNull);
      client.decisions.clear();
      now = part.start.add(const Duration(seconds: 20));
      await tuner.tune(app.channels.first);
      await settle();
      expect(client.decisions.where((d) => d.id == part.item!.sourceId), hasLength(1), reason: 'asked again, once');
    });
  });

  group('a schedule change while tuned in', () {
    /// A time when [ch] airs the same program with breaks off and on
    /// (same), or another one (!same), from parts of each, with the plan
    /// changed at [change]: a minute into the program on air (and never at
    /// the very end of a slot, after which the two loops never air the same
    /// program again). Changing the plan back doesn't always give the first
    /// schedule again (the program on air keeps its place, not always its
    /// position), so the channels' anchors are put back after the trial.
    Future<({DateTime change, DateTime at})> findTime(Channel ch, {required bool same}) async {
      final anchors = {for (final c in app.channels) c: c.anchor};
      final off = scheduleOf(ch);
      final change = off.programAt(now).start.add(const Duration(minutes: 1));
      await app.setGlobalPlan(BreakPlan.automatic, now: change);
      final on = scheduleOf(ch);
      await app.setGlobalPlan(BreakPlan.off, now: change);
      anchors.forEach((c, anchor) => c.anchor = anchor);
      expect(scheduleOf(ch).programAt(now).start, off.programAt(now).start, reason: 'back where it was');
      var t = change;
      for (var i = 0; i < 2000; i++, t = t.add(const Duration(minutes: 3))) {
        final a = off.playbackAt(t), b = on.playbackAt(t);
        if (!isPart(a) || !isPart(b) || a.end.difference(t) < const Duration(minutes: 1)) continue;
        if ((off.programAt(t).item?.id == on.programAt(t).item?.id) == same) return (change: change, at: t);
      }
      throw StateError('no such time');
    }

    test('the program on air plays on, and the new plan takes over when its segment ends', () async {
      final ch = app.channels.first;
      final found = await findTime(ch, same: true);
      now = found.at;
      await tuner.tune(ch);
      await settle();
      final playing = tuner.segment!;
      await app.setGlobalPlan(BreakPlan.automatic, now: found.change);
      await tuner.reschedule();
      await settle();
      expect(player.opens, hasLength(1), reason: 'not reopened');
      expect(tuner.segment, same(playing));
      expect(tuner.segmentEndsAt, playing.end);
    });

    test('another program on air now is tuned in, not the old one played on under the new guide', () async {
      final ch = app.channels.first;
      final found = await findTime(ch, same: false);
      now = found.at;
      await tuner.tune(ch);
      await settle();
      final before = tuner.program!.item!.id;
      await app.setGlobalPlan(BreakPlan.automatic, now: found.change);
      await tuner.reschedule();
      await settle();
      final onAir = scheduleOf(ch).programAt(now).item!.id;
      expect(onAir, isNot(before));
      expect(player.opens, hasLength(2));
      expect(tuner.program?.item?.id, onAir);
      expect(player.opens.last.url.path, contains(tuner.segment!.item!.sourceId));
    });
  });

  group('preloaded hand-overs (segment-handover spec)', () {
    setUp(() => tuner.preload = true);

    /// Tunes to [ch] [before] the end of a part (one a break follows, when
    /// the channel has breaks).
    Future<ScheduledProgram> tuneBeforeEnd(Channel ch, Duration before) async {
      final part = partBeforeBreak(ch, now);
      now = part.end.subtract(before);
      await tuner.tune(ch);
      await settle();
      return part;
    }

    /// The statuses the tuner goes through from now on.
    List<TunerStatus> watchStatus() {
      final seen = <TunerStatus>[];
      tuner.addListener(() => seen.add(tuner.status));
      return seen;
    }

    test('the next segment is added 30 s before the hand-over, with its clip start and end', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final part = await tuneBeforeEnd(ch, const Duration(seconds: 90));
      expect(tuner.status, TunerStatus.playing);
      expect(player.enqueued, isEmpty, reason: 'a minute and a half before');

      now = part.end.subtract(const Duration(seconds: 20));
      await tuner.retune();
      await settle();
      final ad = scheduleOf(ch).playbackAt(part.end);
      expect(ad.isCommercial, isTrue);
      final queued = player.enqueued.single;
      expect(isStatic(queued.url), isTrue);
      expect(queued.start, ad.itemFrom, reason: 'exactly from the clip\'s start');
      expect(queued.end, ad.itemTo);
      expect(tuner.preloadedSegment?.start, ad.start);
    });

    test('the player moves on by itself: no open, no tuning, no channel number, and the break is on', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final part = await tuneBeforeEnd(ch, const Duration(seconds: 20));
      final ad = tuner.preloadedSegment!;
      final seen = watchStatus();
      now = ad.start;
      player.reachEnd();
      await settle();
      expect(player.opens, hasLength(1));
      expect(tuner.segment?.start, ad.start);
      expect(tuner.inBreak, isTrue);
      expect(tuner.program?.item?.id, part.item!.id, reason: 'the break belongs to the program');
      expect(seen, isNot(contains(TunerStatus.tuning)));
      expect(tuner.status, TunerStatus.playing);
      expect(tuner.changingChannel, isFalse);
      // The schedule's hand-over came after: nothing more happens to it.
      expect(log.where((l) => l == 'advance'), isEmpty);
    });

    test('the tuner moves the player on at the scheduled time when it hasn\'t yet', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      await tuneBeforeEnd(app.channels.first, const Duration(seconds: 20));
      final ad = tuner.preloadedSegment!;
      final seen = watchStatus();
      now = ad.start;
      await tuner.debugSegmentEnded();
      await settle();
      expect(log.where((l) => l == 'advance'), hasLength(1));
      expect(player.opens, hasLength(1));
      expect(tuner.segment?.start, ad.start);
      expect(player.position, ad.itemFrom, reason: 'the next segment starts at its own start');
      expect(seen, isNot(contains(TunerStatus.tuning)));
      expect(tuner.status, TunerStatus.playing);
    });

    test('a part after a part preloads; a next program that converts doesn\'t, and opens at the hand-over', () async {
      // No breaks: one program follows another.
      final ch = app.channels.first;
      final part = await tuneBeforeEnd(ch, const Duration(seconds: 20));
      final next = scheduleOf(ch).playbackAt(part.end);
      expect(isPart(next), isTrue);
      expect(tuner.preloadedSegment?.start, next.start, reason: 'direct play, setting off');
      expect(player.enqueued.single.start, next.itemFrom);

      await tuner.stop();
      player.enqueued.clear();
      await setPlayback(mbps: 8);
      final part2 = await tuneBeforeEnd(ch, const Duration(seconds: 20));
      expect(isTranscode(player.opens.last.url), isTrue);
      expect(player.enqueued, isEmpty, reason: 'its decision is a conversion');
      final next2 = scheduleOf(ch).playbackAt(part2.end);
      now = next2.start.add(const Duration(milliseconds: 500));
      await tuner.debugSegmentEnded();
      await settle();
      expect(isTranscode(player.opens.last.url), isTrue);
      expect(tuner.segment?.start, next2.start);
    });

    /// An app whose only commercial is [clip] long, on Automatic, and its
    /// tuner.
    Future<(AppState, Tuner)> oneClipApp(Duration clip) async {
      final dir = await Directory.systemTemp.createTemp('nightingale_tv_one_clip');
      final oneApp = await signedInApp(
          dir,
          fakeLibrary(
              shows: {'Alpha': 20, 'Beta': 20},
              genres: {'Alpha': ['Comedy'], 'Beta': ['Comedy']},
              commercials: [clip]));
      oneApp.client = client;
      final oneTuner = Tuner(oneApp, player: player, clock: () => now)
        ..prefetch = false
        ..sampleEvery = const Duration(hours: 1);
      addTearDown(() async {
        oneTuner.dispose();
        await oneApp.close();
        // Tuning saves the last channel in the background.
        await oneApp.storage.flush();
        await dir.delete(recursive: true);
      });
      await oneApp.setGlobalPlan(BreakPlan.automatic);
      return (oneApp, oneTuner);
    }

    test('a slot\'s last clip is cut to end on time, and hands over to what follows', () async {
      // One 50 s clip: the post-roll repeats it and cuts the last one short.
      final (oneApp, oneTuner) = await oneClipApp(const Duration(seconds: 50));
      final ch = oneApp.channels.first;
      final s = oneApp.scheduleFor(ch)!;
      // The last clip of a slot, cut short.
      var seg = s.playbackAt(now);
      for (var i = 0; i < 3000 && !(seg.isCommercial && s.programAt(seg.start).end == seg.end); i++) {
        seg = s.playbackAt(seg.end);
      }
      expect(seg.isCommercial, isTrue);
      expect(seg.duration, lessThan(const Duration(seconds: 50)), reason: 'cut short');
      expect(s.programAt(seg.start).end, seg.end, reason: 'ends with its slot');
      final after = s.playbackAt(seg.end);
      expect(after.item, isNotNull);
      expect(after.isBreak, isFalse, reason: 'the next program, no card in between');
      now = seg.end.subtract(const Duration(seconds: 6));
      await oneTuner.tune(ch);
      await settle();
      expect(oneTuner.status, TunerStatus.playing);
      expect(oneTuner.preloadedSegment?.start, after.start);
      expect(player.enqueued.single.start, after.itemFrom);
      now = after.start;
      await oneTuner.debugSegmentEnded();
      await settle();
      expect(player.opens, hasLength(1), reason: 'no open');
      expect(oneTuner.segment?.start, after.start);
      expect(oneTuner.status, TunerStatus.playing);
    });

    test('a clip cut to under 4 s is skipped: what follows it is preloaded', () async {
      // 53 s clips: the post-roll's last one is cut to 3 s.
      final (oneApp, oneTuner) = await oneClipApp(const Duration(seconds: 53));
      final ch = oneApp.channels.first;
      final s = oneApp.scheduleFor(ch)!;
      // A clip that a clip of under 4 s follows, and then something to play.
      var seg = s.playbackAt(now);
      bool shortNext(ScheduledProgram p) {
        final next = s.playbackAt(p.end);
        return p.isCommercial &&
            next.isCommercial &&
            next.duration < const Duration(seconds: 4) &&
            s.playbackAt(next.end).item != null;
      }

      for (var i = 0; i < 3000 && !shortNext(seg); i++) {
        seg = s.playbackAt(seg.end);
      }
      expect(shortNext(seg), isTrue, reason: 'the schedule has one');
      final after = s.playbackAt(s.playbackAt(seg.end).end);
      now = seg.end.subtract(const Duration(seconds: 6));
      await oneTuner.tune(ch);
      await settle();
      expect(oneTuner.preloadedSegment?.start, after.start);
      expect(player.enqueued.single.start, after.itemFrom);
      now = seg.end;
      await oneTuner.debugSegmentEnded();
      await settle();
      expect(player.opens, hasLength(1), reason: 'no open');
      expect(oneTuner.segment?.start, after.start);
      expect(oneTuner.status, TunerStatus.playing);
    });

    test('a commercial that ends early holds its last picture; a program part shows stand-by', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final part = await tuneBeforeEnd(ch, const Duration(seconds: 90));
      // In the break, its first commercial's file ends 2 s early.
      now = part.end.add(const Duration(milliseconds: 500));
      await tuner.debugSegmentEnded();
      await settle();
      final ad = tuner.segment!;
      expect(ad.isCommercial, isTrue);
      now = ad.end.subtract(const Duration(seconds: 2));
      final seen = watchStatus();
      player.complete();
      await settle();
      expect(tuner.status, TunerStatus.playing, reason: 'the last picture stays up');
      expect(seen, isNot(contains(TunerStatus.standby)));
      // On to the next segment at the hand-over.
      final next = await advance();
      expect(next.start, ad.end);
      expect(tuner.status, TunerStatus.playing);

      // A program part whose file ends early still shows PLEASE STAND BY.
      final show = await tuneIntoPart(ch);
      expect(tuner.segment?.start, show.start);
      player.complete();
      await settle();
      expect(tuner.status, TunerStatus.standby);
    });

    test('a channel change drops the preloaded segment before the new channel opens', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      await tuneBeforeEnd(app.channels.first, const Duration(seconds: 20));
      expect(player.queued, isNotNull);
      log.clear();
      await tuner.channelUp();
      await settle();
      expect(log.indexOf('clear-queue'), greaterThanOrEqualTo(0));
      expect(log.indexOf('clear-queue'), lessThan(log.indexWhere((l) => l.startsWith('open:'))));
      expect(tuner.channel, app.channels[1]);
      // What's queued now, if anything, is the new channel's.
      final queued = tuner.preloadedSegment;
      if (queued != null) expect(scheduleOf(app.channels[1]).playbackAt(queued.start).start, queued.start);
      expect(player.opens, hasLength(2));
    });

    test('through a break and back, the program is one viewing', () async {
      await app.setGlobalPlan(BreakPlan.automatic);
      final ch = app.channels.first;
      final part = await tuneBeforeEnd(ch, const Duration(seconds: 20));
      final program = part.item!.id;
      var handedOver = 0;
      var preloaded = false;
      for (var i = 0; i < 50; i++) {
        final next = tuner.preloadedSegment;
        preloaded = next != null;
        if (next != null) {
          now = next.start;
          player.reachEnd();
          handedOver++;
        } else {
          now = scheduleOf(ch).playbackAt(tuner.segment!.end).start.add(const Duration(milliseconds: 500));
          await tuner.debugSegmentEnded();
        }
        await settle();
        if (isPart(tuner.segment!)) break;
      }
      expect(handedOver, greaterThan(0));
      final after = tuner.segment!;
      expect(after.item!.id, program, reason: 'back from the break');
      // Preloaded, or opened at the hand-over.
      final from = preloaded ? player.position : player.opens.last.start;
      expect(from, after.positionAt(now), reason: 'at its scheduled position');
      final reports = client.reports.where((r) => r.$2.itemId == program).toList();
      expect(reports.where((r) => r.$1 == 'start'), hasLength(1));
      expect(reports.where((r) => r.$1 == 'stopped'), isEmpty);
    });
  });

  group('volume leveling (volume-leveling spec)', () {
    test('the player gets the setting at start-up and at every change; Linux doesn\'t re-tune', () async {
      expect(player.leveling, [false]);
      await tuneIntoPart(app.channels.first);
      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      await settle();
      expect(player.leveling, [false, true]);
      await app.setPlayback(const PlaybackSettings(transcodeIfNeeded: true, volumeLeveling: true));
      await settle();
      expect(player.leveling, [false, true], reason: 'other settings don\'t touch it');
      await app.setPlayback(PlaybackSettings.off);
      await settle();
      expect(player.leveling, [false, true, false]);
      expect(player.opens, hasLength(1), reason: 'what plays is leveled in place');
    });

    test('saved on, the player starts with it on', () async {
      await app.setPlayback(const PlaybackSettings(volumeLeveling: true));
      final again = FakePlayer([]);
      final second = Tuner(app, player: again, clock: () => now);
      expect(again.leveling, [true]);
      second.dispose();
    });
  });

  group('volume leveling on mpv\'s decks', () {
    late File video;
    late bool ffmpeg;
    late MediaKitTunerPlayer mpv;
    late List<String> errors;

    setUpAll(() async {
      MediaKit.ensureInitialized();
      try {
        video = (await testVideos()).mkv;
        ffmpeg = true;
      } on Object {
        ffmpeg = false;
      }
    });

    setUp(() {
      mpv = MediaKitTunerPlayer(verboseLog: false, video: false);
      errors = [];
      mpv.errorStream.listen(errors.add);
    });

    tearDown(() => mpv.dispose());

    Future<String> prop(Player p, String name) => (p.platform as NativePlayer).getProperty(name);

    /// Silent decks that still decode video (no window in tests).
    Future<void> quiet() async {
      for (final p in mpv.debugDecks) {
        final native = p.platform as NativePlayer;
        await native.setProperty('ao', 'null');
        await native.setProperty('vo', 'null');
        await native.setProperty('vid', 'auto');
      }
    }

    /// Waits for [p]'s audio to be playing through its filters.
    Future<String> audioOut(Player p) async {
      for (var i = 0; i < 50; i++) {
        final format = await prop(p, 'audio-out-params/format');
        if (format.isNotEmpty) return format;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return '';
    }

    test('both decks, and a deck made later, get the chain; off clears it', () async {
      if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
      await mpv.setVolumeLeveling(true);
      final onAir = mpv.debugDecks.single;
      expect(await prop(onAir, 'af'), allOf(contains('acompressor='), contains('alimiter='), contains('level=disabled')));
      // The spare deck is made at the first enqueue, after the change.
      await quiet();
      await mpv.enqueue(Uri.file(video.path), headers: const {});
      final spare = mpv.debugDecks.last;
      expect(mpv.debugDecks, hasLength(2));
      expect(await prop(spare, 'af'), await prop(onAir, 'af'));
      await mpv.setVolumeLeveling(false);
      expect([await prop(onAir, 'af'), await prop(spare, 'af')], ['', '']);
      await mpv.setVolumeLeveling(true);
      expect(await prop(onAir, 'af'), contains('acompressor='));
      expect(await prop(spare, 'af'), contains('acompressor='));
    });

    test('mpv plays through the chain', () async {
      if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
      await quiet();
      await mpv.setVolumeLeveling(true);
      await mpv.open(Uri.file(video.path), headers: const {});
      final deck = mpv.debugDecks.single;
      expect(await audioOut(deck), isNotEmpty, reason: 'audio plays');
      expect(await prop(deck, 'af'), contains('acompressor='));
      expect(errors, isEmpty);
    });

    test('turned on and off while playing: the same file plays on, through the chain and then without', () async {
      if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
      await quiet();
      await mpv.open(Uri.file(video.path), headers: const {});
      final deck = mpv.debugDecks.single;
      expect(await audioOut(deck), isNotEmpty);
      Future<double> position() async => double.parse(await prop(deck, 'time-pos'));
      final before = await position();
      await mpv.setVolumeLeveling(true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(await prop(deck, 'af'), contains('acompressor='));
      expect(await audioOut(deck), isNotEmpty, reason: 'audio flows through the filters');
      final on = await position();
      expect(on, greaterThan(before), reason: 'no re-open: the position moves on');
      await mpv.setVolumeLeveling(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(await prop(deck, 'af'), '');
      expect(await audioOut(deck), isNotEmpty);
      expect(await position(), greaterThan(on));
      expect(errors, isEmpty);
    });

    test('a refused chain plays on unleveled, and isn\'t a playback error', () async {
      if (!ffmpeg) return markTestSkipped('ffmpeg is not installed');
      await quiet();
      mpv.levelingAf = 'lavfi=[nosuchfilter=1]';
      await mpv.setVolumeLeveling(true);
      await mpv.open(Uri.file(video.path), headers: const {});
      final deck = mpv.debugDecks.single;
      expect(await audioOut(deck), isNotEmpty, reason: 'the audio came back');
      expect(await prop(deck, 'af'), '');
      expect(await prop(deck, 'aid'), isNot('no'));
      expect(errors, isEmpty, reason: 'the tuner never hears of it');
      // Stays off for later decks until the setting changes again.
      await mpv.enqueue(Uri.file(video.path), headers: const {});
      expect(await prop(mpv.debugDecks.last, 'af'), '');
    });
  });
}
