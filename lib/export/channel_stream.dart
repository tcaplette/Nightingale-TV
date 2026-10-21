import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../channels/channel.dart';
import '../channels/logo_windows.dart';
import '../channels/schedule.dart';
import '../library/library_index.dart';
import 'broadcast_art.dart';
import 'encode_args.dart';
import 'export_settings.dart';
import 'ts_splicer.dart';

/// What a [ChannelStream] needs from the app (and fakes in tests).
class StreamContext {
  StreamContext({
    required this.channel,
    required this.schedule,
    required this.card,
    required this.openSource,
    required this.closeSource,
    required this.quality,
    required this.encoder,
    this.start = Process.start,
    this.clock = DateTime.now,
    Duration Function()? expectedStartup,
    void Function(Duration)? recordStartup,
    bool Function(String sourceId)? isSilent,
    void Function(String sourceId)? markSilent,
    LogoMode Function()? logoMode,
    Future<String?> Function()? logoPng,
    this.songCard,
    this.log,
  })  : expectedStartup = expectedStartup ?? (() => const Duration(seconds: 3)),
        recordStartup = recordStartup ?? ((_) {}),
        isSilent = isSilent ?? ((_) => false),
        markSilent = markSilent ?? ((_) {}),
        logoMode = logoMode ?? (() => LogoMode.off),
        logoPng = logoPng ?? (() async => null);

  final Channel channel;

  /// The channel's schedule right now; null once it's hidden or deleted.
  final ChannelSchedule? Function() schedule;

  /// [c]'s 1 s chunk, in this stream's format.
  final Future<Uint8List> Function(BroadcastCard c) card;

  /// Lets an encoder read [sourceId], returning the URL to read it at.
  final Future<Uri> Function(String sourceId) openSource;
  final void Function(String sourceId) closeSource;

  final ExportQuality quality;

  /// May change to `libx264` when a hardware encoder fails.
  VideoEncoder encoder;
  final Future<Process> Function(String executable, List<String> arguments) start;
  final DateTime Function() clock;

  /// How long sources take to give their first bytes (D4's E), and a new
  /// measurement of it.
  final Duration Function() expectedStartup;
  final void Function(Duration) recordStartup;

  /// Items found to have no audio track.
  final bool Function(String sourceId) isSilent;
  final void Function(String sourceId) markSilent;

  /// The channel's logo setting right now, and its logo's PNG file.
  final LogoMode Function() logoMode;
  final Future<String?> Function() logoPng;

  /// A song's Now Playing card (PNG file), its picture in the stream.
  final Future<String> Function(ScheduledProgram song)? songCard;

  /// Diagnostics: what the stream plans and how its encoders start.
  final void Function(String line)? log;
}

/// One exported channel as a never-ending MPEG-TS stream (design D3/D4):
/// segment encoders → [TsSplicer] → a copying, real-time muxer, whose
/// output is [output].
class ChannelStream {
  ChannelStream(this.ctx);

  final StreamContext ctx;

  /// Stream time 0 goes out at wall time [_anchor]; stream time S at
  /// `_anchor + S` (the muxer paces in real time).
  late DateTime _anchor;
  final _splicer = TsSplicer();

  Process? _muxer;
  final _encoders = <Process>{};
  bool _stopped = false;
  final _done = Completer<void>();

  /// The program planned to follow the one playing, started ahead.
  _ProgramPlan? _ahead;
  Timer? _aheadTimer;

  /// Slots that ran out early or failed, so the rest of them is a card.
  ({String sourceId, DateTime end})? _endedEarly;
  ({String sourceId, DateTime end, DateTime until})? _failed;

  /// After this much lag, the stream rejoins the schedule at now.
  static const reanchorAfter = Duration(seconds: 2);

  /// Remainders shorter than this are skipped.
  static const minSegment = Duration(milliseconds: 500);
  static const offAirPiece = Duration(seconds: 60);
  static const failurePiece = Duration(seconds: 30);

  /// What the muxer sends: the stream itself.
  Stream<List<int>> get output => _muxer!.stdout;

  /// Completes when the stream ends (stopped, or the channel went away).
  Future<void> get done => _done.future;

  bool get running => !_stopped;

  /// When stream time [s] goes out.
  DateTime _wallAt(Duration s) => _anchor.add(s);
  Duration get _streamTime => Duration(microseconds: _splicer.clock * 100 ~/ 9);

  Future<void> start() async {
    _anchor = ctx.clock();
    final muxer = _muxer = await ctx.start('ffmpeg', EncodeArgs.muxer);
    unawaited(muxer.stderr.transform(const Utf8Decoder(allowMalformed: true)).forEach((e) {
      debugPrint('Live TV export muxer (channel ${ctx.channel.number}): ${e.trim()}');
    }));
    unawaited(muxer.exitCode.then((_) => stop()));
    unawaited(_run().catchError((Object e, StackTrace st) {
      if (!_stopped) debugPrint('Live TV export stream ${ctx.channel.number} failed: $e\n$st');
    }).whenComplete(stop));
  }

  /// Ends the stream and every process it started.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _aheadTimer?.cancel();
    final ahead = _ahead;
    _ahead = null;
    if (ahead != null) _release(ahead);
    for (final p in [..._encoders]) {
      _kill(p);
    }
    final muxer = _muxer;
    if (muxer != null) {
      try {
        await muxer.stdin.close();
      } on Object {
        // Already gone.
      }
      _kill(muxer);
    }
    if (!_done.isCompleted) _done.complete();
  }

  static void _kill(Process p) {
    p.kill(ProcessSignal.sigterm);
    Timer(const Duration(seconds: 2), () => p.kill(ProcessSignal.sigkill));
  }

  Future<void> _write(Uint8List bytes) async {
    if (bytes.isEmpty || _stopped) return;
    final stdin = _muxer!.stdin;
    stdin.add(bytes);
    await stdin.flush();
  }

  Future<void> _writeCard(BroadcastCard card, int chunks) async {
    final chunk = await ctx.card(card);
    for (var i = 0; i < chunks && !_stopped; i++) {
      await _write(_splicer.segment(chunk));
    }
  }

  // ---- The loop --------------------------------------------------------------

  Future<void> _run() async {
    // Tuning: the first program's encoder starts at once, aimed at where
    // the schedule will be when it's ready; the tuning card plays until
    // then.
    final t1 = ctx.clock().add(ctx.expectedStartup());
    var plan = _plan(t1, allowReanchor: false);
    if (plan is _ProgramPlan) {
      await _startEncoder(plan);
      final tuning = TuningCardSpec(ctx.channel);
      while (!_stopped && (!plan.ready || _wallAt(_streamTime).isBefore(plan.t.subtract(minSegment)))) {
        await _writeCard(tuning, 1);
      }
    }
    while (!_stopped && plan != null) {
      await _play(plan);
      if (_stopped) break;
      plan = _takeAhead() ?? _plan(_wallAt(_streamTime));
    }
  }

  /// What plays from schedule time [t] (see D4).
  _Plan? _plan(DateTime t, {bool allowReanchor = true}) {
    final now = ctx.clock();
    if (allowReanchor && now.difference(t) > reanchorAfter) {
      ctx.log?.call('rejoined the schedule ${now.difference(t).inMilliseconds} ms behind');
      _anchor = now.subtract(_streamTime);
      t = now;
    }
    final schedule = ctx.schedule();
    if (schedule == null) return null;
    var segment = schedule.playbackAt(t);
    for (var i = 0; i < 8 && segment.end.difference(t) < minSegment; i++) {
      t = segment.end;
      segment = schedule.playbackAt(t);
    }
    final remaining = segment.end.difference(t);
    final item = segment.item;
    if (item == null) {
      return _CardPlan(OffAirCard.at(schedule, t), remaining > offAirPiece ? offAirPiece : remaining);
    }
    final failed = _failed;
    if (failed != null && failed.sourceId == item.sourceId && failed.end == segment.end && now.isBefore(failed.until)) {
      final left = failed.until.difference(now);
      return _CardPlan(const StandByCard.rightBack(), remaining < left ? remaining : left);
    }
    final early = _endedEarly;
    if (early != null && early.sourceId == item.sourceId && early.end == segment.end) {
      return _CardPlan(StandByCard.upNext(segment.end), remaining);
    }
    return _ProgramPlan(segment, t, item.sourceId, segment.positionAt(t), EncodeArgs.framesIn(remaining));
  }

  /// The program started ahead, if it's still what plays now (within a
  /// second of where the schedule says it starts).
  _Plan? _takeAhead() {
    _aheadTimer?.cancel();
    final ahead = _ahead;
    _ahead = null;
    if (ahead == null) return null;
    final fresh = _plan(_wallAt(_streamTime));
    if (fresh is _ProgramPlan &&
        fresh.sourceId == ahead.sourceId &&
        fresh.segment.end == ahead.segment.end &&
        fresh.t.difference(ahead.t).abs() <= const Duration(seconds: 1)) {
      return ahead;
    }
    _release(ahead);
    return fresh;
  }

  /// Starts the next program's encoder [lead] before [end] (stream time).
  void _planAhead(Duration end) {
    final lead = ctx.expectedStartup() + const Duration(seconds: 3);
    final clamped = lead < const Duration(seconds: 3)
        ? const Duration(seconds: 3)
        : (lead > const Duration(seconds: 20) ? const Duration(seconds: 20) : lead);
    final at = _wallAt(end).subtract(clamped);
    var wait = at.difference(ctx.clock());
    if (wait.isNegative) wait = Duration.zero;
    _aheadTimer?.cancel();
    _aheadTimer = Timer(wait, () {
      if (_stopped || _ahead != null) return;
      final next = _plan(_wallAt(end), allowReanchor: false);
      if (next is _ProgramPlan) {
        _ahead = next;
        unawaited(_startEncoder(next));
      } else if (next is _CardPlan) {
        // Warm the card's chunk.
        unawaited(ctx.card(next.card).then((_) {}, onError: (Object _) {}));
      }
    });
  }

  Future<void> _play(_Plan plan) async {
    switch (plan) {
      case _CardPlan(:final card, :final length):
        final chunks = (length.inMilliseconds / 1000).round().clamp(1, 1 << 20);
        _planAhead(_streamTime + Duration(seconds: chunks));
        await _writeCard(card, chunks);
      case _ProgramPlan():
        if (plan.process == null) await _startEncoder(plan);
        _planAhead(_streamTime + EncodeArgs.framesLength(plan.frames));
        await _playProgram(plan);
    }
  }

  Future<void> _startEncoder(_ProgramPlan plan) async {
    final started = plan.started = ctx.clock();
    ctx.log?.call('encoder ${plan.sourceId} for ${plan.t.toIso8601String()} from ${plan.from} '
        '${plan.frames} frames${plan.segment.isCommercial ? ' (commercial, held)' : ''}, '
        '${plan.t.difference(started).inMilliseconds} ms ahead');
    try {
      final logo = await _logoFor(plan);
      final song = plan.segment.item?.kind == MediaKind.song ? ctx.songCard : null;
      final card = song == null ? null : await song(plan.segment);
      final url = await ctx.openSource(plan.sourceId);
      plan.opened = true;
      if (_stopped) return _release(plan);
      plan.logo = logo != null;
      final process = await ctx.start(
        'nice',
        card != null
            ? EncodeArgs.songSegment(
                input: url,
                card: card,
                from: plan.from,
                frames: plan.frames,
                quality: ctx.quality,
                encoder: plan.encoder = ctx.encoder,
              )
            : EncodeArgs.segment(
          input: url,
          from: plan.from,
          frames: plan.frames,
          quality: ctx.quality,
          encoder: plan.encoder = ctx.encoder,
          audio: !ctx.isSilent(plan.sourceId),
          hold: plan.segment.isCommercial,
          logo: logo,
        ),
      );
      plan.process = process;
      _encoders.add(process);
      plan.output = StreamIterator(process.stdout);
      plan.stderrDone = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.startsWith('frame=')) {
          plan.produced = int.tryParse(line.substring(6).trim()) ?? plan.produced;
        } else if (line.startsWith('speed=')) {
          plan.speed = line.substring(6).trim();
        } else if (!line.contains('=') && line.trim().isNotEmpty) {
          plan.errors.add(line.trim());
        }
      });
      plan.first = plan.output!.moveNext().then((has) {
        plan.ready = true;
        final took = ctx.clock().difference(started);
        if (has) ctx.recordStartup(took);
        ctx.log?.call('encoder ${plan.sourceId} first output after ${took.inMilliseconds} ms'
            '${has ? '' : ' (none)'}; due ${plan.t.difference(ctx.clock()).inMilliseconds} ms from now');
        return has;
      });
    } on Object catch (e) {
      plan.errors.add('$e');
      plan.ready = true;
      plan.first = Future.value(false);
    }
  }

  /// The logo [plan]'s segment carries: the TV's windows for it (channel-
  /// logo), relative to where the encoder starts; null when it never shows.
  Future<SegmentLogo?> _logoFor(_ProgramPlan plan) async {
    final mode = ctx.logoMode();
    final end = plan.t.add(EncodeArgs.framesLength(plan.frames));
    final windows = logoWindows(mode, [plan.segment], plan.t, end);
    if (windows.isEmpty) return null;
    final png = await ctx.logoPng();
    if (png == null) return null;
    final relative = [
      for (final w in windows) (start: w.start.difference(plan.t), end: w.end.difference(plan.t)),
    ];
    ctx.log?.call('logo ${mode.name} on ${plan.sourceId}: '
        '${[for (final w in relative) '${w.start.inMilliseconds / 1000}–${w.end.inMilliseconds / 1000} s'].join(', ')}');
    return SegmentLogo(png: png, windows: relative, always: mode == LogoMode.always);
  }

  Future<void> _playProgram(_ProgramPlan plan) async {
    // A source that isn't ready yet: black until it is.
    var black = 0;
    while (!_stopped && !plan.ready) {
      await _writeCard(const BlackCard(), 1);
      black++;
    }
    if (black > 0) ctx.log?.call('black ${black}s waiting for ${plan.sourceId}');
    final output = plan.output;
    final has = await plan.first!;
    if (has && output != null && !_stopped) {
      _splicer.begin();
      await _write(_splicer.add(output.current));
      while (!_stopped && await output.moveNext()) {
        await _write(_splicer.add(output.current));
      }
      await _write(_splicer.end());
    }
    final process = plan.process;
    final code = process == null ? -1 : await process.exitCode;
    await plan.stderrDone;
    if (process != null) _encoders.remove(process);
    _release(plan);
    if (_stopped) return;
    final item = plan.segment.item!;
    if (plan.produced == 0 || (code != 0 && !has)) {
      final why = plan.errors.isEmpty ? 'exit code $code' : plan.errors.join(' | ');
      debugPrint('Live TV export: channel ${ctx.channel.number} couldn\'t play ${item.id} '
          '(${plan.encoder?.codec}): $why');
      _failed = (sourceId: plan.sourceId, end: plan.segment.end, until: ctx.clock().add(failurePiece));
      if (plan.encoder?.hardware ?? false) {
        debugPrint('Live TV export: channel ${ctx.channel.number} switches to libx264.');
        ctx.encoder = VideoEncoder.x264;
      }
      return;
    }
    final took = ctx.clock().difference(plan.started).inMilliseconds;
    ctx.log?.call('encoder ${plan.sourceId} done: ${plan.produced}/${plan.frames} frames, exit $code, '
        'logo ${plan.logo ? 'on' : 'off'}, $took ms, speed ${plan.speed ?? '?'}');
    if (!_splicer.sawAudio && !ctx.isSilent(plan.sourceId)) ctx.markSilent(plan.sourceId);
    // Commercials are padded with their last picture, so only a program
    // part ends early.
    if (!plan.segment.isCommercial && plan.produced < plan.frames - 15) {
      _endedEarly = (sourceId: plan.sourceId, end: plan.segment.end);
    }
  }

  void _release(_ProgramPlan plan) {
    final p = plan.process;
    // An encoder that never got to play (started ahead for a plan that
    // changed, or at stop) is still running: stop it.
    if (p != null && !plan.finished) {
      plan.finished = true;
      if (_encoders.remove(p)) _kill(p);
    }
    if (plan.opened) {
      plan.opened = false;
      ctx.closeSource(plan.sourceId);
    }
  }
}

sealed class _Plan {}

class _CardPlan extends _Plan {
  _CardPlan(this.card, this.length);
  final BroadcastCard card;
  final Duration length;
}

class _ProgramPlan extends _Plan {
  _ProgramPlan(this.segment, this.t, this.sourceId, this.from, this.frames);

  final ScheduledProgram segment;

  /// Schedule time the segment is joined at.
  final DateTime t;
  final String sourceId;

  /// Position in the source file.
  final Duration from;
  final int frames;

  VideoEncoder? encoder;

  /// When its encoder started, and whether it lays the logo over.
  DateTime started = DateTime.now();
  bool logo = false;
  Process? process;
  StreamIterator<List<int>>? output;
  Future<bool>? first;
  Future<void>? stderrDone;
  bool ready = false;
  bool opened = false;
  bool finished = false;
  int produced = 0;

  /// ffmpeg's last reported encode speed ("1.8x").
  String? speed;
  final errors = <String>[];
}
