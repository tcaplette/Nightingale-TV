import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../library/library_index.dart';
import 'analysis_cache.dart';
import 'break_points.dart';
import 'detections.dart';
import 'ffmpeg_runner.dart';
import 'reel_cutter.dart';
import 'stream_proxy.dart';

/// A program that needs break points, and how many mid-rolls the plans it
/// airs under ask for.
class ProgramNeed {
  const ProgramNeed(this.item, this.midCounts, {this.soon = false});

  final MediaEntry item;
  final Set<int> midCounts;

  /// Airs within the next 24 hours.
  final bool soon;
}

/// What there is to analyze right now.
class AnalysisWork {
  const AnalysisWork({this.reels = const [], this.programs = const []});

  static const none = AnalysisWork();

  /// Pool videos too long to be one clip.
  final List<MediaEntry> reels;
  final List<ProgramNeed> programs;
}

/// How far analysis has got, for the Commercials screen.
@immutable
class AnalysisProgress {
  const AnalysisProgress({
    this.reelsDone = 0,
    this.reelsTotal = 0,
    this.programsDone = 0,
    this.programsTotal = 0,
    this.current,
    this.ffmpegMissing = false,
    this.reelsNeedingFfmpeg = 0,
    this.failed = 0,
  });

  final int reelsDone;
  final int reelsTotal;
  final int programsDone;
  final int programsTotal;

  /// What's being analyzed now, if anything.
  final String? current;
  final bool ffmpegMissing;

  /// Reels with no segments or chapters, which only ffmpeg can split.
  final int reelsNeedingFfmpeg;

  /// Items given up on after repeated failures.
  final int failed;

  bool get busy => current != null;
  bool get complete => reelsDone == reelsTotal && programsDone == programsTotal;

  @override
  bool operator ==(Object other) =>
      other is AnalysisProgress &&
      other.reelsDone == reelsDone &&
      other.reelsTotal == reelsTotal &&
      other.programsDone == programsDone &&
      other.programsTotal == programsTotal &&
      other.current == current &&
      other.ffmpegMissing == ffmpegMissing &&
      other.reelsNeedingFfmpeg == reelsNeedingFfmpeg &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(
      reelsDone, reelsTotal, programsDone, programsTotal, current, ffmpegMissing, reelsNeedingFfmpeg, failed);
}

/// What a [MediaAnalyzer] is doing.
enum AnalyzerState {
  /// Not looked at its work yet.
  starting,

  /// Running a job, or holding off in the middle of one.
  working,

  /// Nothing left to do: waiting for news or a retry.
  idle,
}

/// Reads the Commercial media segments of an item.
typedef SegmentReader = Future<List<Span>> Function(String itemId);

/// The background analysis job: splits reels into clips and finds scene
/// breaks near programs' evenly spaced break points.
///
/// One job at a time, in priority order (reels, then programs airing within
/// 24 hours, then the rest). It holds off while [busy] is true (the TV is
/// tuning), freezing a running ffmpeg. A failed item is retried after 1
/// minute, 10 minutes and 1 hour, then given up on until its file changes.
class MediaAnalyzer {
  MediaAnalyzer({
    required this.cache,
    required this.scanner,
    required this.proxy,
    required this.segments,
    required this.work,
    this.busy,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AnalysisStore cache;
  final SceneScanner scanner;
  final LoopbackStreamProxy proxy;
  final SegmentReader segments;

  /// Asked for the current work before each job.
  final AnalysisWork Function() work;
  final ValueListenable<bool>? busy;
  final DateTime Function() _clock;

  /// Waits before retrying an item that failed once, twice, three times.
  static const backoff = [Duration(minutes: 1), Duration(minutes: 10), Duration(hours: 1)];

  /// Tries, including the first, before giving up.
  static int get maxFailures => backoff.length + 1;

  final _progress = ValueNotifier(const AnalysisProgress());
  ValueListenable<AnalysisProgress> get progress => _progress;

  bool _running = false;
  bool get running => _running;

  /// Whether it has looked at its work yet, is working (or holding off in
  /// the middle of a job), or has nothing left to do.
  ValueListenable<AnalyzerState> get state => _state;
  final _state = ValueNotifier(AnalyzerState.starting);
  Future<void>? _loop;
  Completer<void>? _wake;
  Timer? _retryTimer;
  bool _ffmpeg = false;

  void start() {
    if (_running) return;
    _running = true;
    busy?.addListener(_onBusy);
    _loop = _run();
  }

  /// Something changed (library, plans, pools): look at the work again.
  void poke() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Stops after cancelling any running scan. Finished results are kept.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    busy?.removeListener(_onBusy);
    _retryTimer?.cancel();
    scanner.resume();
    scanner.cancel();
    poke();
    await _loop;
    _loop = null;
    await proxy.close();
    await cache.flush();
    _state.value = AnalyzerState.starting;
    _progress.value = AnalysisProgress(
      reelsDone: _progress.value.reelsDone,
      reelsTotal: _progress.value.reelsTotal,
      programsDone: _progress.value.programsDone,
      programsTotal: _progress.value.programsTotal,
      ffmpegMissing: _progress.value.ffmpegMissing,
      reelsNeedingFfmpeg: _progress.value.reelsNeedingFfmpeg,
      failed: _progress.value.failed,
    );
  }

  void _onBusy() {
    if (busy!.value) {
      scanner.pause();
    } else {
      scanner.resume();
      poke();
    }
  }

  Future<void> _run() async {
    _ffmpeg = await scanner.available();
    while (_running) {
      if (busy?.value ?? false) {
        await _sleep(null);
        continue;
      }
      final plan = _plan(work());
      _progress.value = plan.progress;
      final job = plan.next;
      if (job == null) {
        // Nothing to do: free the port, and wait for news or a retry.
        if (proxy.running) await proxy.close();
        _state.value = AnalyzerState.idle;
        await _sleep(plan.retryAt);
        continue;
      }
      _state.value = AnalyzerState.working;
      _progress.value = plan.progressWith(job.item.title);
      try {
        await job.run();
      } on Object catch (e) {
        if (!_running) break;
        debugPrint('Analysis of ${job.item.title} failed: $e');
        cache.recordFailure(job.item, at: _clock(), maxFailures: maxFailures);
      } finally {
        if (proxy.running) await proxy.disallow(job.item.sourceId);
      }
    }
  }

  /// Waits for [poke], or until [until].
  Future<void> _sleep(DateTime? until) async {
    if (!_running) return;
    final wake = _wake = Completer<void>();
    _retryTimer?.cancel();
    if (until != null) {
      final wait = until.difference(_clock());
      _retryTimer = Timer(wait.isNegative ? Duration.zero : wait, poke);
    }
    await wake.future;
    _retryTimer?.cancel();
  }

  _Plan _plan(AnalysisWork w) {
    final now = _clock();
    DateTime? retryAt;
    var failed = 0;

    /// Whether [item] may be tried now (not given up on, not backing off).
    bool ready(MediaEntry item) {
      if (cache.gaveUpOn(item)) {
        failed++;
        return false;
      }
      final (failures, last) = cache.failuresOf(item);
      if (failures == 0 || last == null) return true;
      final at = last.add(backoff[(failures - 1).clamp(0, backoff.length - 1)]);
      if (!at.isAfter(now)) return true;
      if (retryAt == null || at.isBefore(retryAt!)) retryAt = at;
      return false;
    }

    final jobs = <_Job>[];
    var reelsDone = 0, reelsNeedingFfmpeg = 0;
    for (final reel in w.reels) {
      if (cache.isAnalyzed(reel)) {
        reelsDone++;
        continue;
      }
      if (!_ffmpeg && _needsFfmpeg.contains(_key(reel))) {
        // No segments or chapters to cut at; only ffmpeg can split it.
        reelsNeedingFfmpeg++;
        continue;
      }
      if (ready(reel)) jobs.add(_Job(reel, () => _analyzeReel(reel)));
    }

    var programsDone = 0;
    final soon = <_Job>[], later = <_Job>[];
    for (final need in w.programs) {
      final item = need.item;
      final segmentsRead = cache.isAnalyzed(item);
      final windows = segmentsRead && _ffmpeg ? _windowsFor(need) : const <Span>[];
      if (segmentsRead && windows.isEmpty) {
        programsDone++;
        continue;
      }
      if (!ready(item)) continue;
      (need.soon ? soon : later).add(_Job(item, () => _analyzeProgram(need)));
    }
    jobs
      ..addAll(soon)
      ..addAll(later);
    final total = w.programs.length;
    return _Plan(
      next: jobs.firstOrNull,
      retryAt: retryAt,
      progress: AnalysisProgress(
        reelsDone: reelsDone,
        reelsTotal: w.reels.length,
        programsDone: programsDone,
        programsTotal: total,
        ffmpegMissing: !_ffmpeg,
        reelsNeedingFfmpeg: reelsNeedingFfmpeg,
        failed: failed,
      ),
    );
  }

  /// The windows still to scan for [need]'s break counts.
  List<Span> _windowsFor(ProgramNeed need) {
    final item = need.item;
    final info = cache.pointsFor(item, _farFuture);
    final windows = <Span>[];
    for (final count in need.midCounts) {
      for (final w in BreakPointFinder.windowsNeeded(item.runtime, count, info)) {
        if (!windows.any((x) => x.start <= w.start && x.end >= w.end)) windows.add(w);
      }
    }
    return windows..sort();
  }

  static final _farFuture = DateTime(9999);

  /// Reels (id + Etag) found to need detection while ffmpeg is missing.
  final _needsFfmpeg = <String>{};

  static String _key(MediaEntry item) => '${item.sourceId}|${item.etag}';

  Future<void> _analyzeReel(MediaEntry reel) async {
    final found = await segments(reel.sourceId);
    var cuts = ReelCutter.fromMetadata(reel.runtime, segments: found, chapters: reel.chapters);
    if (cuts == null) {
      if (!_ffmpeg) {
        // Nothing recorded, so it's split once ffmpeg is installed.
        _needsFfmpeg.add(_key(reel));
        return;
      }
      final d = await _scan(reel);
      if (!_running) return;
      cuts = ReelCutter.fromDetections(reel.runtime, d);
    }
    if (!_running) return;
    cache.recordReel(reel, cuts, at: _clock());
  }

  Future<void> _analyzeProgram(ProgramNeed need) async {
    final item = need.item;
    if (!cache.isAnalyzed(item)) {
      final found = await segments(item.sourceId);
      if (!_running) return;
      cache.recordSegments(item, found, at: _clock());
    }
    if (!_ffmpeg) return;
    for (final w in _windowsFor(need)) {
      if (!_running) return;
      while (busy?.value ?? false) {
        await _sleep(null);
        if (!_running) return;
      }
      final d = await _scan(item, from: w.start, length: w.length);
      if (!_running) return;
      cache.recordWindow(item, ScanWindow(range: w, analyzedAt: _clock(), detections: d));
    }
  }

  Future<Detections> _scan(MediaEntry item, {Duration? from, Duration? length}) async {
    await proxy.start();
    await proxy.allow(item.sourceId);
    return scanner.scan(proxy.urlFor(item.sourceId), from: from, length: length, runtime: item.runtime);
  }
}

class _Job {
  _Job(this.item, this.run);

  final MediaEntry item;
  final Future<void> Function() run;
}

class _Plan {
  _Plan({required this.next, required this.retryAt, required this.progress});

  final _Job? next;
  final DateTime? retryAt;
  final AnalysisProgress progress;

  AnalysisProgress progressWith(String current) => AnalysisProgress(
        reelsDone: progress.reelsDone,
        reelsTotal: progress.reelsTotal,
        programsDone: progress.programsDone,
        programsTotal: progress.programsTotal,
        current: current,
        ffmpegMissing: progress.ffmpegMissing,
        reelsNeedingFfmpeg: progress.reelsNeedingFfmpeg,
        failed: progress.failed,
      );
}
