import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../library/library_index.dart';
import '../break_sources.dart';
import 'break_points.dart';
import 'detections.dart';
import 'reel_cutter.dart';

/// Bumped when analysis changes enough that old results should be redone.
const analysisVersion = 1;

/// A scan of part of a program, around an evenly spaced break point.
class ScanWindow {
  const ScanWindow({required this.range, required this.analyzedAt, required this.detections});

  final Span range;
  final DateTime analyzedAt;
  final Detections detections;

  Map<String, Object?> toJson() => {
        'range': range.toJson(),
        'at': analyzedAt.toUtc().toIso8601String(),
        ...detections.toJson(),
      };

  factory ScanWindow.fromJson(Map<String, Object?> j) => ScanWindow(
        range: Span.fromJson(j['range']),
        analyzedAt: DateTime.parse(j['at'] as String).toLocal(),
        detections: Detections.fromJson(j),
      );
}

/// What analysis found in one version of a file.
class AnalysisResult {
  const AnalysisResult({
    required this.analyzedAt,
    this.cutSource,
    this.cuts = const [],
    this.skips = const [],
    this.windows = const [],
  });

  final DateTime analyzedAt;

  /// Reels: where the cuts came from (null when none could be found, e.g.
  /// without ffmpeg), and each clip's range.
  final CutSource? cutSource;
  final List<Span> cuts;

  /// Programs: Commercial media segments, skipped during playback.
  final List<Span> skips;

  /// Programs: scans around evenly spaced break points.
  final List<ScanWindow> windows;

  AnalysisResult withWindow(ScanWindow w) => AnalysisResult(
        analyzedAt: analyzedAt,
        cutSource: cutSource,
        cuts: cuts,
        skips: skips,
        windows: [...windows, w],
      );

  Map<String, Object?> toJson() => {
        'at': analyzedAt.toUtc().toIso8601String(),
        if (cutSource != null) 'cutSource': cutSource!.name,
        if (cuts.isNotEmpty) 'cuts': [for (final c in cuts) c.toJson()],
        if (skips.isNotEmpty) 'skips': [for (final s in skips) s.toJson()],
        if (windows.isNotEmpty) 'windows': [for (final w in windows) w.toJson()],
      };

  factory AnalysisResult.fromJson(Map<String, Object?> j) => AnalysisResult(
        analyzedAt: DateTime.parse(j['at'] as String).toLocal(),
        cutSource: CutSource.values.asNameMap()[j['cutSource']],
        cuts: [for (final c in j['cuts'] as List? ?? const []) Span.fromJson(c)],
        skips: [for (final s in j['skips'] as List? ?? const []) Span.fromJson(s)],
        windows: [
          for (final w in (j['windows'] as List? ?? const []).cast<Map<String, Object?>>()) ScanWindow.fromJson(w)
        ],
      );
}

/// One item's analysis: the result for its current file, the result for the
/// file before (still used until the new one is analyzed), and failures.
class AnalysisEntry {
  AnalysisEntry({
    required this.etag,
    required this.version,
    this.current,
    this.previous,
    this.failures = 0,
    this.lastFailure,
    this.gaveUp = false,
  });

  /// The Etag and [analysisVersion] [current] (and the failures) are for.
  String etag;
  int version;
  AnalysisResult? current;
  AnalysisResult? previous;
  int failures;
  DateTime? lastFailure;

  /// Failed too often; not tried again until the file changes.
  bool gaveUp;

  /// Newest first.
  Iterable<AnalysisResult> get results => [?current, ?previous];

  Map<String, Object?> toJson() => {
        'etag': etag,
        'version': version,
        if (current != null) 'current': current!.toJson(),
        if (previous != null) 'previous': previous!.toJson(),
        if (failures > 0) 'failures': failures,
        if (lastFailure != null) 'failedAt': lastFailure!.toUtc().toIso8601String(),
        if (gaveUp) 'gaveUp': true,
      };

  factory AnalysisEntry.fromJson(Map<String, Object?> j) => AnalysisEntry(
        etag: j['etag'] as String? ?? '',
        version: j['version'] as int? ?? 0,
        current: switch (j['current']) { final Map<String, Object?> r => AnalysisResult.fromJson(r), _ => null },
        previous: switch (j['previous']) { final Map<String, Object?> r => AnalysisResult.fromJson(r), _ => null },
        failures: j['failures'] as int? ?? 0,
        lastFailure: switch (j['failedAt']) { final String t => DateTime.parse(t).toLocal(), _ => null },
        gaveUp: j['gaveUp'] as bool? ?? false,
      );
}

/// Analysis results for every item on one Jellyfin server, kept in
/// `analysis/<serverId>.json` and shared by every profile on that server.
///
/// An item is analyzed again only when its Etag or [analysisVersion]
/// changes; until then its old result stays in use. Writes are batched
/// ([debounce]) and atomic.
/// What media analysis reads and records: one server's [AnalysisCache],
/// or several servers' at once (multi-server's `ServerAnalysis`).
abstract interface class AnalysisStore implements BreakPointSource, Listenable {
  bool isAnalyzed(MediaEntry item);
  bool gaveUpOn(MediaEntry item);
  (int, DateTime?) failuresOf(MediaEntry item);
  AnalysisResult? latest(MediaEntry item);
  void recordReel(MediaEntry reel, ReelCuts? cuts, {required DateTime at});
  void recordSegments(MediaEntry program, List<Span> skips, {required DateTime at});
  void recordWindow(MediaEntry program, ScanWindow window);
  void recordFailure(MediaEntry item, {required DateTime at, required int maxFailures});
  Future<void> flush();
}

class AnalysisCache extends ChangeNotifier implements AnalysisStore {
  AnalysisCache._(this.file, this._entries, this.debounce);

  /// Writes within this of each other are saved together.
  final Duration debounce;
  final File file;
  final Map<String, AnalysisEntry> _entries;
  Timer? _saveTimer;
  Future<void> _saving = Future.value();
  static var _tmpCounter = 0;

  /// Bumped on every change.
  int revision = 0;

  static const _formatVersion = 1;

  /// Open caches by file path, for [acquire].
  static final _shared = <String, ({Future<AnalysisCache> cache, int users})>{};

  /// The one cache for [serverId] in this process, shared by every profile
  /// signed in to that server, so they all see the same results and only
  /// one copy is ever written. Each [acquire] needs a [release].
  static Future<AnalysisCache> acquire(Directory dir, String serverId) {
    final path = _fileFor(dir, serverId).path;
    final entry = _shared[path];
    final cache = entry?.cache ?? open(dir, serverId);
    _shared[path] = (cache: cache, users: (entry?.users ?? 0) + 1);
    return cache;
  }

  /// Gives back an [acquire]d cache; the last user closes it.
  static Future<void> release(AnalysisCache cache) async {
    final entry = _shared[cache.file.path];
    if (entry == null) return cache.close();
    if (entry.users > 1) {
      _shared[cache.file.path] = (cache: entry.cache, users: entry.users - 1);
      return;
    }
    _shared.remove(cache.file.path);
    await cache.close();
  }

  static File _fileFor(Directory dir, String serverId) =>
      File('${dir.path}/${serverId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.json');

  static Future<AnalysisCache> open(Directory dir, String serverId,
      {Duration debounce = const Duration(seconds: 5)}) async {
    await dir.create(recursive: true);
    final file = _fileFor(dir, serverId);
    final entries = <String, AnalysisEntry>{};
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, Object?> && json['version'] == _formatVersion) {
          final items = (json['items'] as Map?)?.cast<String, Object?>() ?? const {};
          items.forEach((id, e) {
            if (e is Map<String, Object?>) entries[id] = AnalysisEntry.fromJson(e);
          });
        }
      }
    } on FormatException {
      // A damaged cache is rebuilt by analyzing again.
    }
    return AnalysisCache._(file, entries, debounce);
  }

  AnalysisEntry? operator [](String id) => _entries[id];

  Iterable<String> get ids => _entries.keys;

  static String _etag(MediaEntry item) => item.etag ?? '';

  /// Whether [item]'s current file has been analyzed (as far as [reel]
  /// analysis or the program's segments go).
  @override
  bool isAnalyzed(MediaEntry item) {
    final e = _entries[item.sourceId];
    return e != null && e.etag == _etag(item) && e.version == analysisVersion && e.current != null;
  }

  /// Gave up on [item]'s current file after too many failures.
  @override
  bool gaveUpOn(MediaEntry item) {
    final e = _entries[item.sourceId];
    return e != null && e.etag == _etag(item) && e.version == analysisVersion && e.gaveUp;
  }

  /// Failures so far on [item]'s current file, and when the last was.
  @override
  (int, DateTime?) failuresOf(MediaEntry item) {
    final e = _entries[item.sourceId];
    if (e == null || e.etag != _etag(item) || e.version != analysisVersion) return (0, null);
    return (e.failures, e.lastFailure);
  }

  /// The newest result for [item], even one for a file since replaced.
  @override
  AnalysisResult? latest(MediaEntry item) => _entries[item.sourceId]?.results.firstOrNull;

  /// The entry for [item]'s current file, moving a result for an older file
  /// (or analysis version) to `previous`.
  AnalysisEntry _entryFor(MediaEntry item) {
    final etag = _etag(item);
    final e = _entries[item.sourceId];
    if (e == null) return _entries[item.sourceId] = AnalysisEntry(etag: etag, version: analysisVersion);
    if (e.etag != etag || e.version != analysisVersion) {
      e
        ..previous = e.current ?? e.previous
        ..current = null
        ..etag = etag
        ..version = analysisVersion
        ..failures = 0
        ..lastFailure = null
        ..gaveUp = false;
    }
    return e;
  }

  @override
  void recordReel(MediaEntry reel, ReelCuts? cuts, {required DateTime at}) {
    _entryFor(reel)
      ..current = AnalysisResult(analyzedAt: at, cutSource: cuts?.source, cuts: cuts?.clips ?? const [])
      ..failures = 0
      ..lastFailure = null;
    _changed();
  }

  /// A program's Commercial segments were read (maybe none).
  @override
  void recordSegments(MediaEntry program, List<Span> skips, {required DateTime at}) {
    _entryFor(program)
      ..current = AnalysisResult(analyzedAt: at, skips: skips)
      ..failures = 0
      ..lastFailure = null;
    _changed();
  }

  /// A window of [program] was scanned. Its segments must have been read.
  @override
  void recordWindow(MediaEntry program, ScanWindow window) {
    final e = _entryFor(program);
    final current = e.current;
    if (current == null) throw StateError('Read ${program.id}\'s segments before scanning it.');
    e.current = current.withWindow(window);
    _changed();
  }

  /// Analysis of [item] failed; after [maxFailures] it is given up on until
  /// its file changes.
  @override
  void recordFailure(MediaEntry item, {required DateTime at, required int maxFailures}) {
    final e = _entryFor(item);
    e
      ..failures += 1
      ..lastFailure = at
      ..gaveUp = e.failures >= maxFailures;
    _changed();
  }

  /// Where [program] can break, as known at [asOf]: the newest result
  /// analyzed by then (so a slot already on air keeps its breaks when new
  /// results arrive), plus its chapters, which need no analysis.
  @override
  ProgramBreakInfo pointsFor(MediaEntry program, DateTime asOf) {
    final result = _entries[program.sourceId]?.results.where((r) => !r.analyzedAt.isAfter(asOf)).firstOrNull;
    final (source, candidates) =
        BreakPointFinder.candidatesFor(program.runtime, segments: result?.skips ?? const [], chapters: program.chapters);
    final windows = [for (final w in result?.windows ?? const <ScanWindow>[]) if (!w.analyzedAt.isAfter(asOf)) w];
    return ProgramBreakInfo(
      source: source,
      candidates: candidates,
      skips: result?.skips ?? const [],
      scenes: Detections(
        blacks: [for (final w in windows) ...w.detections.blacks]..sort(),
        silences: [for (final w in windows) ...w.detections.silences]..sort(),
      ),
      scanned: [for (final w in windows) w.range],
    );
  }

  void _changed() {
    revision++;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, () => unawaited(flush()));
  }

  /// Saves now (pending changes are otherwise saved after [debounce]).
  @override
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final json = jsonEncode({
      'version': _formatVersion,
      'items': {for (final e in _entries.entries) e.key: e.value.toJson()},
    });
    return _saving = _saving.catchError((Object _) {}).then((_) => _write(json));
  }

  /// Temp file + rename: a crash mid-write leaves the old cache in place,
  /// and the temp file is never read.
  Future<void> _write(String json) async {
    final tmp = File('${file.path}.${pid}_${_tmpCounter++}.tmp');
    try {
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(file.path);
    } on Object catch (e) {
      debugPrint('Could not save analysis results: $e');
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// Saves pending changes and stops the save timer.
  Future<void> close() async {
    if (_saveTimer != null) await flush();
    await _saving;
  }
}
