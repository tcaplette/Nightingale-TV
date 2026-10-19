import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/analysis/stream_proxy.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/jellyfin/jellyfin_client.dart';
import 'package:nightingale_tv/playback/tuner.dart';
import 'package:nightingale_tv/playback/tuner_player.dart';

import 'fixtures.dart';

/// A Jellyfin that decides on bitrate the way the real one does, and logs
/// every call the tuner makes as it's made.
class FakeClient extends JellyfinClient {
  FakeClient(this.log) : super(serverUrl: 'https://jf.example', deviceId: 'dev', deviceName: 'pc', accessToken: 't');

  /// Shared with the player, so the order of calls and opens shows.
  final List<String> log;

  /// Source bitrates (bits per second); 25 Mbps unless set.
  final bitrates = <String, int>{};
  final decisions = <({String id, int? maxBitrate, bool force})>[];
  final stopped = <String>[];
  final reports = <(String kind, PlaybackReport report)>[];

  /// Answers [playbackInfo] only once this completes (when set).
  Completer<void>? holdDecisions;

  @override
  Future<PlaybackDecision> playbackInfo(String itemId,
      {int? maxBitrate, bool forceTranscode = false, Duration startAt = Duration.zero}) async {
    decisions.add((id: itemId, maxBitrate: maxBitrate, force: forceTranscode));
    log.add('decide:$itemId');
    await holdDecisions?.future;
    final over = maxBitrate != null && (bitrates[itemId] ?? 25000000) > maxBitrate;
    if (!forceTranscode && !over) return const PlaybackDecision.direct();
    return PlaybackDecision.transcode(transcodeTemplate('/videos/$itemId/stream.ts?DeviceId=dev&ApiKey=t&MediaSourceId=$itemId'));
  }

  @override
  Future<void> stopEncoding(String playSessionId) async {
    stopped.add(playSessionId);
    log.add('stop:$playSessionId');
  }

  @override
  Future<void> reportPlaybackStart(PlaybackReport report) async => reports.add(('start', report));
  @override
  Future<void> reportPlaybackProgress(PlaybackReport report) async => reports.add(('progress', report));
  @override
  Future<void> reportPlaybackStopped(PlaybackReport report) async => reports.add(('stopped', report));
}

/// What [FakePlayer.open] does with a URL.
enum OpenResult { plays, throws, errors, hangs }

class FakePlayer implements TunerPlayer {
  FakePlayer(this.log);

  final List<String> log;
  final opens = <({Uri url, Duration? start, Duration? end})>[];
  OpenResult Function(Uri url) onOpen = (_) => OpenResult.plays;

  final _playing = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  bool _isPlaying = false;

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<void> get tracksStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<String> get errorStream => _error.stream;
  @override
  Stream<String> get logStream => const Stream.empty();

  @override
  bool get playing => _isPlaying;
  @override
  bool get buffering => false;
  @override
  Duration position = Duration.zero;

  @override
  Future<void> open(Uri url, {required Map<String, String> headers, Duration? start, Duration? end}) async {
    opens.add((url: url, start: start, end: end));
    log.add('open:${url.path}');
    _isPlaying = false;
    position = Duration.zero;
    switch (onOpen(url)) {
      case OpenResult.plays:
        scheduleMicrotask(() {
          _isPlaying = true;
          _playing.add(true);
        });
      case OpenResult.throws:
        throw Exception('could not open');
      case OpenResult.errors:
        scheduleMicrotask(() => _error.add('could not open'));
      case OpenResult.hangs:
        break;
    }
  }

  /// A playback error some time after starting.
  void failNow() => _error.add('stream broke');

  @override
  Future<void> stop() async {
    _isPlaying = false;
    log.add('stop-player');
  }

  @override
  Future<void> showCaptions(bool on) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<String> debugProperty(String name) async => '';
}

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
    tuner = Tuner(app, player: player, clock: () => now);
  });

  tearDown(() async {
    tuner.dispose();
    await app.close();
    // Tuning saves the last channel in the background.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await dir.delete(recursive: true);
  });

  Future<void> settle() => pumpEventQueue();

  Future<void> setPlayback({bool on = true, int? mbps}) =>
      app.setPlayback(PlaybackSettings(transcodeIfNeeded: on, maxBitrateMbps: mbps));

  ChannelSchedule scheduleOf(Channel ch) => app.scheduleFor(ch)!;

  bool isPart(ScheduledProgram s) => !s.isBreak && s.item != null && !s.isCommercial;

  /// The next program part on [ch] from [from] (one a commercial break
  /// follows, when [ch] has breaks).
  ScheduledProgram partBeforeBreak(Channel ch, DateTime from) {
    final s = scheduleOf(ch);
    final breaks = app.breaksFor(ch);
    var seg = s.playbackAt(from);
    for (var i = 0; i < 200; i++) {
      final next = s.playbackAt(seg.end);
      if (isPart(seg) && (!breaks || next.isBreak && next.isCommercial) && seg.duration > const Duration(seconds: 30)) {
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

    test('without a cap, nothing is ever paused or limited', () async {
      for (final playback in const [PlaybackSettings.off, PlaybackSettings(transcodeIfNeeded: true)]) {
        for (final activity in PlaybackActivity.values) {
          expect(analyzerBudget(activity, playback), const Budget.unlimited());
        }
      }
      // Off with a remembered cap is still off.
      expect(analyzerBudget(PlaybackActivity.tuning, const PlaybackSettings(maxBitrateMbps: 8)), const Budget.unlimited());
    });
  });
}
