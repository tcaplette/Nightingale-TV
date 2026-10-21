import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/channels/channel.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/commercials/commercial_pool.dart';
import 'package:nightingale_tv/export/broadcast_art.dart';
import 'package:nightingale_tv/export/channel_stream.dart';
import 'package:nightingale_tv/export/encode_args.dart';
import 'package:nightingale_tv/export/export_settings.dart';
import 'package:nightingale_tv/library/library_index.dart';

import 'fixtures.dart';

const _frame = 1001 / 30000;

/// A TS packet starting a PES on [pid] with [pts], its payload labelled.
Uint8List _pes(int pid, int pts, String label) {
  final b = Uint8List(188)..fillRange(0, 188, 0xFF);
  b.setAll(0, [0x47, 0x40 | (pid >> 8), pid & 0xFF, 0x10]);
  b.setAll(4, [0, 0, 1, pid == 0x100 ? 0xE0 : 0xC0, 0, 0, 0x80, 0x80, 5]);
  final v = pts % (1 << 33);
  b.setAll(13, [
    0x21 | (((v >> 30) & 7) << 1),
    (v >> 22) & 0xFF,
    (((v >> 15) & 0x7F) << 1) | 1,
    (v >> 7) & 0xFF,
    ((v & 0x7F) << 1) | 1,
  ]);
  b.setAll(18, ascii.encode(label));
  return b;
}

/// [frames] frames of [label], one write per frame, starting at an
/// encoder-like 1.4 s.
List<Uint8List> _frames(String label, int frames, {bool audio = true}) => [
      for (var i = 0; i < frames; i++)
        Uint8List.fromList([
          ..._pes(0x100, 126000 + i * 3003, label),
          if (audio) ..._pes(0x101, 126000 - 1920 + i * 3003, label),
        ]),
    ];

/// What the muxer received: each video frame's PTS and label.
class _Frame {
  _Frame(this.pts, this.label, this.at);
  final int pts;
  final String label;
  final Duration at;
}

class _Muxer implements StreamConsumer<List<int>> {
  _Muxer(this.elapsed);
  final Duration Function() elapsed;
  final frames = <_Frame>[];
  final audioPackets = <String>[];
  final _carry = BytesBuilder();
  Duration stallAt = const Duration(days: 1);
  Duration stallFor = Duration.zero;
  final out = StreamController<List<int>>();

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _carry.add(data);
      final all = _carry.takeBytes();
      final whole = all.length - all.length % 188;
      _carry.add(all.sublist(whole));
      var video = 0;
      for (var o = 0; o < whole; o += 188) {
        final pid = ((all[o + 1] & 0x1F) << 8) | all[o + 2];
        final b = all.sublist(o, o + 188);
        final pts = ((b[13] >> 1) & 7) << 30 | b[14] << 22 | (b[15] >> 1) << 15 | b[16] << 7 | b[17] >> 1;
        final label = ascii.decode(b.sublist(18).takeWhile((c) => c != 0xFF).toList());
        if (pid == 0x100) {
          frames.add(_Frame(pts, label, elapsed()));
          video++;
        } else {
          audioPackets.add(label);
        }
      }
      out.add(all.sublist(0, whole));
      // Paced like -re: each frame takes its time to go out.
      await Future<void>.delayed(Duration(microseconds: (video * _frame * 1e6).round()));
      if (elapsed() >= stallAt) {
        stallAt = const Duration(days: 1);
        await Future<void>.delayed(stallFor);
      }
    }
  }

  @override
  Future<void> close() async => out.close();
}

class _Process implements Process {
  _Process(this.arguments, {IOSink? stdin}) : stdin = stdin ?? IOSink(StreamController<List<int>>().sink);

  final List<String> arguments;
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  @override
  final IOSink stdin;
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;

  bool get exited => _exit.isCompleted;

  void finish(int code) {
    if (_exit.isCompleted) return;
    unawaited(out.close());
    unawaited(err.close());
    _exit.complete(code);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    finish(-15);
    return true;
  }

  String arg(String flag) => arguments[arguments.indexOf(flag) + 1];

  /// The source id in the loopback URL (the one input that's a URL).
  String get source => Uri.parse([
        for (var i = 0; i + 1 < arguments.length; i++)
          if (arguments[i] == '-i' && arguments[i + 1].startsWith('http')) arguments[i + 1],
      ].first)
          .pathSegments
          .last;

  /// A song's Now Playing card is the picture.
  bool get songCard => arguments.contains('/cache/song.png');
  Duration get from => Duration(microseconds: (double.parse(arg('-ss')) * 1e6).round());
  /// The video filters, with or without a logo laid over.
  String get filters => arguments.contains('-vf') ? arg('-vf') : arg('-filter_complex');
  int get frames => int.parse(RegExp(r'trim=end_frame=(\d+)').firstMatch(filters)!.group(1)!);
  bool get silent => arguments.contains('anullsrc=r=48000:cl=stereo');

  /// Pads a short file with its last picture.
  bool get holds => filters.contains('tpad=stop=-1:stop_mode=clone');

  /// The channel logo is an input.
  bool get logo => arguments.contains('/cache/logo.png');
}

/// How a fake encoder behaves for a source.
class _Behavior {
  const _Behavior({this.delay = const Duration(seconds: 2), this.fail = false, this.shortBy = 0, this.audio = true});
  final Duration delay;
  final bool fail;
  final int shortBy;
  final bool audio;
}

class _Harness {
  _Harness(this.async, this.app, this.channel, {this.encoder = VideoEncoder.x264, this.logo = LogoMode.off});

  final FakeAsync async;
  final AppState app;
  final Channel channel;
  final VideoEncoder encoder;
  final LogoMode logo;
  final start = DateTime(2026, 10, 18, 20, 0, 7);
  late final muxer = _Muxer(() => async.elapsed);
  final encoders = <({_Process p, Duration startedAt})>[];
  final behaviors = <String, _Behavior>{};
  final cardsAsked = <String>[];
  final silent = <String>{};
  final startups = <Duration>[];
  late final ChannelStream stream;

  DateTime now() => start.add(async.elapsed);
  ChannelSchedule get schedule => app.scheduleFor(channel)!;

  Future<Process> startProcess(String exe, List<String> args) async {
    if (exe == 'ffmpeg') return _Process(args, stdin: IOSink(muxer));
    final p = _Process(args);
    encoders.add((p: p, startedAt: async.elapsed));
    final b = behaviors[p.source] ?? const _Behavior();
    Timer(b.delay, () {
      if (p.killed) return;
      if (b.fail) {
        p.err.add(utf8.encode('Server returned 404 Not Found\n'));
        p.finish(1);
        return;
      }
      // Held to the end (tpad clone), as ffmpeg does.
      final n = p.holds ? p.frames : p.frames - b.shortBy;
      for (final f in _frames('src:${p.source}', n, audio: b.audio && !p.silent)) {
        p.out.add(f);
      }
      p.err.add(utf8.encode('frame=$n\nprogress=end\n'));
      p.finish(0);
    });
    return p;
  }

  void run(Duration d) {
    stream = ChannelStream(StreamContext(
      channel: channel,
      // As the real session does: a channel out of the lineup has no schedule.
      schedule: () => app.channels.any((c) => c.id == channel.id) ? app.scheduleFor(channel) : null,
      card: (c) async {
        cardsAsked.add(c.key);
        return Uint8List.fromList([for (final f in _frames(_label(c), 30)) ...f]);
      },
      openSource: (id) async => Uri.parse('http://127.0.0.1:1/0123secret/$id'),
      closeSource: (_) {},
      quality: ExportQuality.p720,
      encoder: encoder,
      start: startProcess,
      clock: now,
      expectedStartup: () {
        if (startups.isEmpty) return const Duration(seconds: 3);
        final s = [...startups]..sort();
        return s[s.length ~/ 2];
      },
      recordStartup: startups.add,
      isSilent: silent.contains,
      markSilent: silent.add,
      logoMode: () => logo,
      logoPng: () async => '/cache/logo.png',
      songCard: (_) async => '/cache/song.png',
    ));
    unawaited(stream.start());
    async.elapse(d);
  }

  static String _label(BroadcastCard c) => switch (c) {
        TuningCardSpec() => 'tuning',
        BlackCard() => 'black',
        OffAirCard() => 'offair',
        StandByCard(:final text) => 'standby:$text',
      };

  /// The labels in order, each with how many frames it ran.
  List<(String, int)> get runs {
    final out = <(String, int)>[];
    for (final f in muxer.frames) {
      if (out.isNotEmpty && out.last.$1 == f.label) {
        out.last = (f.label, out.last.$2 + 1);
      } else {
        out.add((f.label, 1));
      }
    }
    return out;
  }

  void expectContinuous() {
    final pts = [for (final f in muxer.frames) f.pts];
    for (var i = 1; i < pts.length; i++) {
      expect(pts[i] - pts[i - 1], 3003, reason: 'frame $i (${muxer.frames[i].label})');
    }
  }
}

void main() {
  late Directory dir;
  late AppState app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_channel_stream');
  });

  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });

  Future<AppState> make({Map<String, Object?>? settings, Duration episode = const Duration(minutes: 1)}) async =>
      app = await signedInApp(
        dir,
        fakeLibrary(
          shows: {'Alpha': 6, 'Beta': 6},
          episodeLength: episode,
          commercials: settings == null ? const [] : const [Duration(seconds: 15), Duration(seconds: 20)],
        ),
        settings: settings,
      );

  test('starts with the tuning card, then joins where the schedule is', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.behaviors.clear();
      h.run(const Duration(seconds: 20));
      final runs = h.runs;
      expect(runs.first.$1, 'tuning');
      // The encoder (2 s to start) was aimed 3 s ahead: tuning fills those 3 s.
      expect(runs.first.$2, 90);
      final first = h.encoders.first.p;
      final t1 = h.start.add(const Duration(seconds: 3));
      expect(first.from, h.schedule.playbackAt(t1).positionAt(t1));
      expect(runs[1].$1, 'src:${first.source}');
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  for (final mode in LogoMode.values) {
    test('the channel logo (${mode.name}) is laid over program parts as on the TV', () async {
      await make(settings: (AppSettings.fresh()
            ..commercialPlan = BreakPlan.automatic
            ..commercialPools = [
              CommercialPool(id: fakePoolId, name: 'Commercials', roots: const [
                PoolRoot(itemId: 'ads', libraryId: 'ads', label: 'Commercials'),
              ]),
            ])
          .toJson());
      final channel = app.channels.first;
      fakeAsync((async) {
        final h = _Harness(async, app, channel, logo: mode);
        h.run(const Duration(minutes: 4));
        expect(h.encoders.where((e) => app.library[e.p.source]?.kind == MediaKind.commercial), isNotEmpty);
        expect(h.encoders.where((e) => app.library[e.p.source]?.kind == MediaKind.episode), isNotEmpty);
        for (final e in h.encoders) {
          final commercial = app.library[e.p.source]?.kind == MediaKind.commercial;
          if (commercial || mode == LogoMode.off) {
            expect(e.p.logo, isFalse, reason: '${e.p.source}: no logo input');
          }
        }
        if (mode == LogoMode.always) {
          expect(h.encoders.where((e) => app.library[e.p.source]?.kind == MediaKind.episode).every((e) => e.p.logo), isTrue);
          expect(h.encoders.any((e) => e.p.filters.contains('fade')), isFalse);
        }
        if (mode == LogoMode.nowAndThen) {
          // Parts joined at their start show it from their first frame.
          expect(h.encoders.any((e) => e.p.logo && e.p.filters.contains('fade=t=in:st=0.000')), isTrue);
        }
        unawaited(h.stream.stop());
        async.flushTimers();
      });
    });
  }

  test('a radio channel streams each song with its Now Playing card and no logo', () async {
    app = await signedInApp(dir, fakeLibrary(shows: const {'Alpha': 6}, songs: fakeMusic(160)));
    final radio = app.channels.firstWhere((c) => c.name == 'Music Radio');
    fakeAsync((async) {
      final h = _Harness(async, app, radio, logo: LogoMode.always);
      h.run(const Duration(minutes: 8));
      expect(h.encoders.length, greaterThan(1));
      for (final e in h.encoders) {
        expect(e.p.songCard, isTrue, reason: e.p.source);
        expect(e.p.logo, isFalse, reason: 'songs carry no logo');
        expect(e.p.arguments.join(' '), contains('-map 0:v:0 -map 1:a:0?'));
        expect(app.library[e.p.source]!.kind, MediaKind.song);
      }
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('segments follow the schedule, started ahead, with no gaps', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.run(const Duration(minutes: 4));
      final schedule = h.schedule;
      // Every program frame shows what the schedule had on air then (to a
      // frame or two either side of a boundary).
      var mismatched = 0;
      for (final f in h.muxer.frames.skip(90)) {
        final at = h.start.add(Duration(microseconds: ((f.pts) * 100 ~/ 9)));
        final on = schedule.playbackAt(at).item?.sourceId;
        if (f.label != 'src:$on') mismatched++;
      }
      expect(mismatched, lessThan(h.runs.length * 3), reason: '${h.runs}');
      expect(h.runs.where((r) => r.$1 == 'black'), isEmpty, reason: 'encoders started ahead');
      // Each later encoder started before the one before it finished.
      for (var i = 1; i < h.encoders.length; i++) {
        final starts = h.encoders[i].startedAt;
        final previousEnded =
            h.muxer.frames.lastWhere((f) => f.label == 'src:${h.encoders[i - 1].p.source}', orElse: () => h.muxer.frames.last).at;
        expect(starts, lessThan(previousEnded), reason: 'encoder $i');
      }
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a source that is slow to open shows black, then the stream catches up', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      final second = h.schedule.next(h.schedule.programAt(h.start.add(const Duration(seconds: 3)))).item!.sourceId;
      h.behaviors[second] = const _Behavior(delay: Duration(seconds: 30));
      h.run(const Duration(minutes: 3));
      final labels = [for (final r in h.runs) r.$1];
      final i = labels.indexOf('src:$second');
      expect(labels[i - 1], 'black');
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a file that ends early is filled with PLEASE STAND BY until the next program', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      final first = h.schedule.playbackAt(h.start.add(const Duration(seconds: 3))).item!.sourceId;
      h.behaviors[first] = const _Behavior(shortBy: 150);
      h.run(const Duration(seconds: 90));
      final runs = h.runs;
      final i = runs.indexWhere((r) => r.$1 == 'src:$first');
      expect(runs[i + 1].$1, startsWith('standby:Up next at '));
      expect(runs[i + 1].$2, closeTo(150, 30));
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a failed segment shows "We\'ll be right back", and a failed hardware encoder falls back', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel, encoder: VideoEncoder.vaapi);
      final first = h.schedule.playbackAt(h.start.add(const Duration(seconds: 3))).item!.sourceId;
      h.behaviors[first] = const _Behavior(fail: true);
      h.run(const Duration(seconds: 100));
      final labels = [for (final r in h.runs) r.$1];
      expect(labels, contains("standby:We'll be right back"));
      expect(h.encoders.first.p.arg('-c:v'), 'h264_vaapi');
      expect(h.encoders.last.p.arg('-c:v'), 'libx264');
      expect(h.stream.ctx.encoder, VideoEncoder.x264);
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a stall rejoins the schedule at now', () async {
    await make(episode: const Duration(minutes: 2));
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.muxer
        ..stallAt = const Duration(seconds: 30)
        ..stallFor = const Duration(seconds: 10);
      h.run(const Duration(minutes: 5));
      // After the stall, each new program is joined where the schedule is
      // at the moment it's planned: within a second or two of the clock.
      final late = h.encoders.where((e) => e.startedAt > const Duration(seconds: 45)).toList();
      expect(late, isNotEmpty);
      for (final e in late) {
        final at = h.start.add(e.startedAt);
        final scheduled = h.schedule.playbackAt(at);
        // Started ahead by at most 20 s, so the join is near its slot start.
        expect(e.p.from >= scheduled.itemFrom - const Duration(seconds: 25), isTrue);
      }
      h.expectContinuous();
      final behind = h.muxer.frames.last.at - Duration(microseconds: h.muxer.frames.last.pts * 100 ~/ 9);
      expect(behind.inSeconds.abs(), lessThan(15));
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a block-only channel off the air plays OFF THE AIR in pieces of a minute', () async {
    await make();
    final ch = await app.createBlockChannel('Late Show');
    final block = app.newBlock()
      ..title = 'Night'
      ..channelId = ch.id
      ..days = {DateTime.saturday}
      ..startMinute = 23 * 60
      ..endMinute = 23 * 60 + 30
      ..source = const ChannelSource(seriesKeys: ['alpha|2000']);
    await app.saveBlock(block);
    final channel = app.channelById(ch.id)!;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.run(const Duration(minutes: 3));
      final runs = h.runs;
      expect(runs.first.$1, 'offair');
      expect(runs.every((r) => r.$1 == 'offair'), isTrue);
      expect(h.encoders, isEmpty);
      expect(h.cardsAsked.where((k) => k.startsWith('offair|Back on the air')), isNotEmpty);
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  Future<void> makeWithBreaks() async {
    final settings = (AppSettings.fresh()
          ..commercialPools = [
            CommercialPool(id: fakePoolId, name: 'Commercials', roots: const [
              PoolRoot(itemId: 'ads', libraryId: 'ads', label: 'Commercials'),
            ]),
          ]
          ..commercialPlan = BreakPlan.automatic)
        .toJson();
    await make(settings: settings, episode: const Duration(minutes: 8));
  }

  test('breaks play the same clips as the TV, and go straight back to the show', () async {
    await makeWithBreaks();
    final channel = app.channels.first;
    expect(app.breaksFor(channel), isTrue);
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.run(const Duration(minutes: 20));
      final schedule = h.schedule;
      final commercials = {for (final c in app.library.commercials) c.sourceId};
      final played = [for (final e in h.encoders) e.p.source];
      expect(played.where(commercials.contains), isNotEmpty, reason: 'commercials are encoded');
      // The clips match what the TV's schedule has on at those moments.
      for (final e in h.encoders.where((e) => commercials.contains(e.p.source))) {
        final f = h.muxer.frames.firstWhere((f) => f.label == 'src:${e.p.source}');
        final at = h.start.add(Duration(microseconds: f.pts * 100 ~/ 9));
        expect(schedule.playbackAt(at.add(const Duration(milliseconds: 200))).item?.sourceId, e.p.source);
      }
      // Only video between the breaks and the show: no card of any kind.
      expect(h.runs.where((r) => r.$1.startsWith('standby') || r.$1 == 'offair'), isEmpty);
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a commercial shorter than its listed length holds its last picture, with no card', () async {
    await makeWithBreaks();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      final commercials = {for (final c in app.library.commercials) c.sourceId};
      for (final id in commercials) {
        h.behaviors[id] = const _Behavior(shortBy: 60);
      }
      h.run(const Duration(minutes: 20));
      final ads = h.encoders.where((e) => commercials.contains(e.p.source)).toList();
      expect(ads, isNotEmpty);
      expect(ads.every((e) => e.p.holds), isTrue, reason: 'commercials are padded with their last picture');
      expect(h.encoders.where((e) => !commercials.contains(e.p.source)).any((e) => e.p.holds), isFalse,
          reason: 'program parts are not');
      expect(h.runs.where((r) => r.$1.startsWith('standby')), isEmpty);
      h.expectContinuous();
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('an item without audio gets silence from then on', () async {
    await make(episode: const Duration(seconds: 40));
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      for (final e in app.library.episodes) {
        h.behaviors[e.sourceId] = const _Behavior(audio: false);
      }
      h.run(const Duration(minutes: 12));
      expect(h.silent, isNotEmpty);
      final repeat = h.encoders.where((e) => h.silent.contains(e.p.source) && e.p.silent);
      expect(repeat, isNotEmpty, reason: 'a second airing gets anullsrc');
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  test('a hidden channel ends its stream; stop kills every process', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.run(const Duration(seconds: 30));
      expect(h.stream.running, isTrue);
      unawaited(app.updateChannel(channel, hidden: true));
      async.elapse(const Duration(minutes: 2));
      expect(h.stream.running, isFalse);
      async.flushTimers();
      expect(h.encoders.every((e) => e.p.exited), isTrue);
    });
  });

  test('encoder command lines never carry the token or the Jellyfin address', () async {
    await make();
    final channel = app.channels.first;
    fakeAsync((async) {
      final h = _Harness(async, app, channel);
      h.run(const Duration(minutes: 2));
      expect(h.encoders, isNotEmpty);
      for (final e in h.encoders) {
        final line = e.p.arguments.join(' ');
        expect(line, isNot(contains('Token')));
        expect(line, isNot(contains(app.session!.accessToken)));
        expect(line, isNot(contains(app.session!.serverUrl)));
        expect(e.p.arguments.take(3), ['-n', '10', 'ffmpeg']);
      }
      unawaited(h.stream.stop());
      async.flushTimers();
    });
  });

  group('encoder arguments', () {
    final url = Uri.parse('http://127.0.0.1:1/s/item');
    for (final e in VideoEncoder.values) {
      for (final q in ExportQuality.values) {
        test('${e.codec} at ${q.label}', () {
          final args = EncodeArgs.segment(input: url, from: const Duration(seconds: 12), frames: 300, quality: q, encoder: e);
          final line = args.join(' ');
          expect(line, contains('-c:v ${e.codec}'));
          expect(line, contains('scale=${q.width}:${q.height}'));
          expect(line, contains('trim=end_frame=300'));
          expect(line, contains('-b:v ${q.mbps}M'));
          expect(line, contains('-bf 0'));
          expect(line, contains('-g 60'));
          expect(line, contains('-ss 12.000'));
          expect(line, contains('-ac 2 -ar 48000'));
          expect(line.contains('-vaapi_device'), e == VideoEncoder.vaapi);
          expect(line.contains('hwupload'), e == VideoEncoder.vaapi);
          expect(args, isNot(contains('-frames:v')));
          expect(line, isNot(contains('tpad')));
          final held = EncodeArgs.segment(
              input: url, from: Duration.zero, frames: 300, quality: q, encoder: e, hold: true).join(' ');
          expect(held, contains('fps=30000/1001:start_time=0,tpad=stop=-1:stop_mode=clone,trim=end_frame=300'));
        });
      }
    }

    test('frames and lengths', () {
      expect(EncodeArgs.framesIn(const Duration(seconds: 1)), 30);
      expect(EncodeArgs.framesIn(const Duration(minutes: 22)), 39560);
      expect(EncodeArgs.framesLength(30).inMicroseconds, 1001000);
    });
  });
}
