import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/app_storage.dart';

/// One launch's record on the device (crash-visibility D2): whether the app
/// is in front, whether it exited cleanly, how far start-up got, the last
/// memory sample and the trail. The next launch reads it to report a death
/// in the foreground ("Unexpected exit") or a start that never got going
/// ("Slow start"). Kept in the app's data folder beside the report switch,
/// never in profiles or backups.
class SessionRecord extends ChangeNotifier {
  SessionRecord({
    required this.id,
    required this.version,
    required this.platform,
    required this.started,
    this.recording = true,
    this.foreground = true,
    this.cleanExit = false,
    this.stage,
    this.library,
    this.slowStartSent = false,
    List<StartupStep>? steps,
    List<TrailEntry>? trail,
    this.memory,
    List<RecentReport>? reports,
    DateTime Function()? now,
  })  : steps = steps ?? [],
        trail = trail ?? [],
        reports = reports ?? [],
        _now = now ?? DateTime.now;

  /// A new launch's record, keeping [previous]'s recent reports.
  factory SessionRecord.start(
      {required String version,
      required String platform,
      required bool recording,
      DateTime? started,
      SessionRecord? previous,
      DateTime Function()? now}) {
    final clock = now ?? DateTime.now;
    return SessionRecord(
      id: newId(),
      version: version,
      platform: platform,
      started: started ?? clock(),
      recording: recording,
      reports: [...?previous?.reports],
      now: clock,
    );
  }

  /// Beside the report switch, in a folder of its own.
  static const file = 'reports/session.json';

  /// Android's own clean-exit mark (MainActivity.onDestroy when the
  /// activity is finishing): the session id it ended.
  static const cleanExitFile = 'reports/clean_exit';

  static const trailSize = 40;
  static const reportsKept = 5;

  /// Trail entries are written at most this often; lifecycle and stage
  /// changes go at once.
  static const throttle = Duration(seconds: 3);

  /// Random, per launch: tag `session` on every event.
  final String id;
  final String version;

  /// The reporting environment: `android-tv`, `android-phone`, `linux` or
  /// `server`.
  final String platform;
  final DateTime started;

  /// Reporting was on: only then is anything about this session reported
  /// later.
  bool recording;
  bool foreground;
  bool cleanExit;

  /// The furthest start-up step reached ([StartupTrail]).
  String? stage;

  /// Which library path the launch took: `saved`, `missing`,
  /// `unreadable (<type>)` or `no lineup`.
  String? library;

  /// This launch sent its own "Slow start".
  bool slowStartSent;

  final List<StartupStep> steps;
  final List<TrailEntry> trail;
  MemorySample? memory;

  /// The last [reportsKept] reports this device sent, oldest first.
  final List<RecentReport> reports;

  final DateTime Function() _now;

  AppStorage? _storage;
  Timer? _pending;

  /// 12 hex characters: unique enough per device, and short of the 20 the
  /// scrubber takes for a token, so the `session` and `previous_session`
  /// tags arrive as they are.
  static String newId() {
    final r = Random.secure();
    return [for (var i = 0; i < 6; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }

  /// Reads the record a launch left, or null when there's none (or it can't
  /// be read).
  static Future<SessionRecord?> read(AppStorage storage) async {
    try {
      return fromJson(await storage.readJson(file));
    } on Object catch (e) {
      debugPrint('Session record unreadable: $e');
      return null;
    }
  }

  static SessionRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final started = DateTime.tryParse('${json['started']}');
    if (id is! String || started == null) return null;
    List<T> list<T>(String key, T? Function(Map<String, Object?>) read) => [
          for (final e in (json[key] as List?) ?? const [])
            if (e is Map<String, Object?>) ?read(e),
        ];
    return SessionRecord(
      id: id,
      version: '${json['version'] ?? ''}',
      platform: '${json['platform'] ?? ''}',
      started: started,
      recording: json['recording'] != false,
      foreground: json['foreground'] == true,
      cleanExit: json['cleanExit'] == true,
      stage: json['stage'] as String?,
      library: json['library'] as String?,
      slowStartSent: json['slowStartSent'] == true,
      steps: list('steps', StartupStep.fromJson),
      trail: list('trail', TrailEntry.fromJson),
      memory: json['memory'] is Map<String, Object?> ? MemorySample.fromJson(json['memory']! as Map<String, Object?>) : null,
      reports: list('reports', RecentReport.fromJson),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'platform': platform,
        'started': started.toUtc().toIso8601String(),
        'recording': recording,
        'foreground': foreground,
        'cleanExit': cleanExit,
        'stage': stage,
        'library': library,
        'slowStartSent': slowStartSent,
        'steps': [for (final s in steps) s.toJson()],
        'trail': [for (final t in trail) t.toJson()],
        'memory': memory?.toJson(),
        'reports': [for (final r in reports) r.toJson()],
      };

  /// From now on the record is saved to [storage]; it's written at once.
  Future<void> attach(AppStorage storage) {
    _storage = storage;
    return saveNow();
  }

  /// Writes the record now (atomically, through [AppStorage]).
  Future<void> saveNow() async {
    _pending?.cancel();
    _pending = null;
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.writeJson(file, toJson());
    } on Object catch (e) {
      debugPrint('Session record not saved: $e');
    }
  }

  /// Writes the record within [throttle].
  void saveSoon() {
    if (_storage == null || _pending != null) return;
    _pending = Timer(throttle, () => unawaited(saveNow()));
  }

  /// A scrubbed trail entry; the oldest goes past [trailSize].
  void addCrumb(TrailEntry entry) {
    if (!recording) return;
    trail.add(entry);
    if (trail.length > trailSize) trail.removeRange(0, trail.length - trailSize);
    saveSoon();
  }

  void setForeground(bool front) {
    if (front == foreground) return;
    foreground = front;
    unawaited(saveNow());
  }

  /// The app is closing on purpose (window closed, quit, server stopped).
  Future<void> markClean() {
    cleanExit = true;
    foreground = false;
    return saveNow();
  }

  void addStep(StartupStep step, {required String? stage}) {
    steps.add(step);
    this.stage = stage;
    if (recording) unawaited(saveNow());
  }

  void setMemory(MemorySample sample) {
    memory = sample;
    if (recording) saveSoon();
  }

  /// A report this device sent, for the Error reports screen.
  void addReport(RecentReport report) {
    reports.add(report);
    if (reports.length > reportsKept) reports.removeRange(0, reports.length - reportsKept);
    notifyListeners();
    unawaited(saveNow());
  }

  /// Reporting turned off: nothing more is kept about this session, and
  /// it won't be reported later.
  void stopRecording() {
    recording = false;
    trail.clear();
    steps.clear();
    memory = null;
    unawaited(saveNow());
  }

  /// Reporting turned on during this launch.
  void startRecording() {
    if (recording) return;
    recording = true;
    unawaited(saveNow());
  }

  DateTime now() => _now();

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }
}

/// A start-up step and when it was reached.
@immutable
class StartupStep {
  const StartupStep(this.name, this.at, {this.detail});

  final String name;
  final DateTime at;

  /// The `library read` step's path.
  final String? detail;

  static StartupStep? fromJson(Map<String, Object?> json) {
    final at = DateTime.tryParse('${json['at']}');
    final name = json['name'];
    if (at == null || name is! String) return null;
    return StartupStep(name, at, detail: json['detail'] as String?);
  }

  Map<String, Object?> toJson() =>
      {'name': name, 'at': at.toUtc().toIso8601String(), if (detail != null) 'detail': detail};

  /// "12.3 s library read: missing", timed from [launch].
  String describe(DateTime launch) {
    final s = (at.difference(launch).inMilliseconds / 1000).toStringAsFixed(1);
    return '$s s $name${detail == null ? '' : ': $detail'}';
  }
}

/// One scrubbed breadcrumb, as the SDK got it.
@immutable
class TrailEntry {
  const TrailEntry({required this.at, required this.category, this.message, this.data});

  final DateTime at;
  final String category;
  final String? message;
  final Map<String, Object?>? data;

  factory TrailEntry.of(Breadcrumb b) => TrailEntry(
      at: b.timestamp, category: b.category ?? '', message: b.message, data: _plain(b.data));

  static TrailEntry? fromJson(Map<String, Object?> json) {
    final at = DateTime.tryParse('${json['at']}');
    final category = json['category'];
    if (at == null || category is! String) return null;
    return TrailEntry(
        at: at,
        category: category,
        message: json['message'] as String?,
        data: (json['data'] as Map?)?.cast<String, Object?>());
  }

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'category': category,
        if (message != null) 'message': message,
        if (data != null && data!.isNotEmpty) 'data': data,
      };

  Breadcrumb toBreadcrumb() => Breadcrumb(timestamp: at, category: category, message: message, data: data);

  /// JSON-safe values only.
  static Map<String, Object?>? _plain(Map<String, dynamic>? data) => data == null
      ? null
      : {
          for (final e in data.entries)
            e.key: switch (e.value) {
              null || num() || bool() || String() => e.value,
              _ => '${e.value}',
            },
        };
}

/// The device's free memory and the app's own, at one moment
/// (crash-visibility D5). Bytes.
@immutable
class MemorySample {
  const MemorySample(
      {required this.at, this.available, this.total, this.threshold, this.lowMemory, required this.rss});

  final DateTime at;
  final int? available;
  final int? total;

  /// Below this, Android counts the device as low on memory (Linux: a
  /// twentieth of the total).
  final int? threshold;
  final bool? lowMemory;

  /// The app's resident memory.
  final int rss;

  /// Available memory is under twice the threshold.
  bool get nearLow => available != null && threshold != null && available! < 2 * threshold!;

  static MemorySample? fromJson(Map<String, Object?> json) {
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;
    int? n(String k) => (json[k] as num?)?.toInt();
    return MemorySample(
        at: at,
        available: n('available'),
        total: n('total'),
        threshold: n('threshold'),
        lowMemory: json['lowMemory'] as bool?,
        rss: n('rss') ?? 0);
  }

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'available': available,
        'total': total,
        'threshold': threshold,
        'lowMemory': lowMemory,
        'rss': rss,
      };

  static String mb(int? bytes) => bytes == null ? '?' : '${(bytes / (1024 * 1024)).round()} MB';

  /// "free 312 MB of 1987 MB (low at 216 MB), app 402 MB".
  String describe() =>
      'free ${mb(available)} of ${mb(total)}${threshold == null ? '' : ' (low at ${mb(threshold)})'}'
      '${lowMemory == true ? ', LOW' : ''}, app ${mb(rss)}';

  Map<String, Object?> toContext() => {
        'available_mb': available == null ? null : available! ~/ (1024 * 1024),
        'total_mb': total == null ? null : total! ~/ (1024 * 1024),
        'threshold_mb': threshold == null ? null : threshold! ~/ (1024 * 1024),
        'low_memory': lowMemory,
        'app_rss_mb': rss ~/ (1024 * 1024),
        'sampled': at.toUtc().toIso8601String(),
      };
}

/// A report this device sent (crash-visibility D6).
@immutable
class RecentReport {
  const RecentReport({required this.kind, required this.at, required this.id});

  /// `test`, `video`, `error`, `exit` (unexpected exit) or `slowStart`.
  final String kind;
  final DateTime at;

  /// The event ID, without dashes.
  final String id;

  static RecentReport? fromJson(Map<String, Object?> json) {
    final at = DateTime.tryParse('${json['at']}');
    final kind = json['kind'];
    final id = json['id'];
    if (at == null || kind is! String || id is! String) return null;
    return RecentReport(kind: kind, at: at, id: id);
  }

  Map<String, Object?> toJson() => {'kind': kind, 'at': at.toUtc().toIso8601String(), 'id': id};
}
