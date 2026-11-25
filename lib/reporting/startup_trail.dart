import 'dart:async';

import 'package:flutter/foundation.dart';

import 'session_record.dart';

/// Why a launch was slow (crash-visibility D4).
enum SlowStartReason {
  /// No usable screen 60 s after launch.
  noScreen('no usable screen in 60 s'),

  /// The launch's library download has run for 3 minutes.
  libraryDownload('library download over 3 min'),

  /// The previous launch never reached a usable screen (sent by this one).
  previousLaunch('previous launch never reached a usable screen');

  const SlowStartReason(this.text);

  final String text;
}

/// The launch's start-up steps (crash-visibility D4): `startup` crumbs, the
/// session record's stage, and the slow-start watchdog. The steps are the
/// ones [PlaybackDiagnostics.mark] times, plus `first picture`. Steps are
/// only taken until the launch reaches the TV or sign-in; after that only
/// its first picture is.
class StartupTrail {
  StartupTrail(this.record,
      {required this.launchedAt,
      required this.onSlowStart,
      this.onCrumb,
      this.noScreenAfter = const Duration(seconds: 60),
      this.downloadAfter = const Duration(minutes: 3)});

  /// The one for this launch; null in tests and server mode.
  static StartupTrail? current;

  /// A start-up step of this launch (nothing without a [current] trail).
  static void step(String name, {String? detail}) => current?.add(name, detail: detail);

  /// The steps and their rank: the stage is the furthest one reached.
  static const ranks = {
    'storage open': 1,
    'reporting started': 2,
    'household started': 3,
    'profile open': 4,
    'settings read': 5,
    'channels read': 6,
    'library read': 7,
    'syncing': 8,
    'signed out': 8,
    'profiles shown': 8,
    'ready': 9,
    'first picture': 10,
  };

  /// Screens the viewer can use: the TV, sign-in, the library download
  /// screen, and "Who's watching?".
  static const usable = {'ready', 'signed out', 'syncing', 'profiles shown', 'first picture'};

  /// The launch is done once one of these is reached.
  static const _closing = {'ready', 'signed out'};

  static bool reachedUsable(SessionRecord r) => r.steps.any((s) => usable.contains(s.name));

  final SessionRecord record;
  final DateTime launchedAt;
  final void Function(SlowStartReason reason) onSlowStart;

  /// Each step, for the SDK's breadcrumbs (and the record's trail).
  final void Function(String message, Map<String, Object?> data)? onCrumb;
  final Duration noScreenAfter;
  final Duration downloadAfter;

  Timer? _noScreen;
  Timer? _download;
  bool _closed = false;
  bool _pictured = false;
  bool _fired = false;

  /// Starts the watchdog; its 60 s run from [launchedAt].
  void start() {
    final left = noScreenAfter - record.now().difference(launchedAt);
    _noScreen = Timer(left.isNegative ? Duration.zero : left, () {
      if (!reachedUsable(record)) _fire(SlowStartReason.noScreen);
    });
  }

  void add(String name, {String? detail}) {
    if (name == 'first picture') {
      if (_pictured) return;
      _pictured = true;
    } else if (_closed) {
      return;
    }
    final rank = ranks[name] ?? 0;
    final stage = record.stage;
    final furthest = stage == null || rank >= (ranks[stage] ?? 0) ? name : stage;
    if (name == 'library read') record.library = detail;
    // The crumb first: the step's save (at once) then carries it.
    onCrumb?.call(detail == null ? name : '$name: $detail', {'stage': name});
    record.addStep(StartupStep(name, record.now(), detail: detail), stage: furthest);
    if (name == 'syncing') {
      _download ??= Timer(downloadAfter, () => _fire(SlowStartReason.libraryDownload));
    } else if (name == 'ready' || name == 'signed out') {
      _download?.cancel();
    }
    if (_closing.contains(name)) _closed = true;
  }

  void _fire(SlowStartReason reason) {
    if (_fired || record.slowStartSent) return;
    _fired = true;
    _noScreen?.cancel();
    _download?.cancel();
    onSlowStart(reason);
  }

  /// The steps, timed from launch.
  static List<String> describeSteps(SessionRecord r) => [for (final s in r.steps) s.describe(r.started)];

  @visibleForTesting
  bool get closed => _closed;

  void dispose() {
    _noScreen?.cancel();
    _download?.cancel();
    if (identical(current, this)) current = null;
  }
}
