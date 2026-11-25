import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../platform/platform_info.dart';
import 'session_record.dart';

/// Memory in the trail (crash-visibility D5): a sample every 30 s while the
/// app is in front, kept in the session record, with a `memory` crumb only
/// when the device turns low on memory (or stops being), or its free
/// memory falls under twice Android's low-memory threshold. Android's
/// memory-trim levels are crumbs as they come.
class MemoryWatch {
  MemoryWatch({required this.onSample, required this.onCrumb, Future<MemorySample?> Function()? sample, this.every = const Duration(seconds: 30)})
      : _sample = sample ?? takeSample;

  final void Function(MemorySample sample) onSample;
  final void Function(String message, Map<String, Object?> data) onCrumb;
  final Future<MemorySample?> Function() _sample;
  final Duration every;

  Timer? _timer;
  MemorySample? _last;

  /// Samples now and every [every] (the app is in front).
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(every, (_) => unawaited(sampleNow()));
    unawaited(sampleNow());
  }

  /// No samples in the background.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> sampleNow() async {
    final MemorySample? s;
    try {
      s = await _sample();
    } on Object catch (e) {
      debugPrint('Memory sample failed: $e');
      return;
    }
    if (s == null) return;
    onSample(s);
    final crumb = crumbFor(_last, s);
    _last = s;
    if (crumb != null) onCrumb(crumb, s.toContext());
  }

  /// The crumb [now] earns after [previous], or null on steady memory.
  static String? crumbFor(MemorySample? previous, MemorySample now) {
    final low = now.lowMemory ?? false;
    if (previous == null) {
      if (low) return 'Device low on memory: ${now.describe()}';
      if (now.nearLow) return 'Device memory near low: ${now.describe()}';
      return null;
    }
    final wasLow = previous.lowMemory ?? false;
    if (low != wasLow) return low ? 'Device low on memory: ${now.describe()}' : 'Device memory recovered: ${now.describe()}';
    if (now.nearLow && !previous.nearLow) return 'Device memory near low: ${now.describe()}';
    return null;
  }

  /// An Android memory-trim level, as the crumb says it.
  static String trimCrumb(String level) => 'Memory trim: $level';

  /// The device's sample: Android's MemoryInfo, Linux's /proc/meminfo;
  /// the app's own resident memory from Dart.
  static Future<MemorySample?> takeSample() async {
    final rss = ProcessInfo.currentRss;
    final now = DateTime.now();
    if (PlatformInfo.isAndroid) {
      final info = await PlatformInfo.memoryInfo();
      if (info == null) return MemorySample(at: now, rss: rss);
      int? n(String k) => (info[k] as num?)?.toInt();
      return MemorySample(
          at: now,
          available: n('availMem'),
          total: n('totalMem'),
          threshold: n('threshold'),
          lowMemory: info['lowMemory'] as bool?,
          rss: rss);
    }
    if (Platform.isLinux) {
      try {
        return linuxSample(await File('/proc/meminfo').readAsString(), rss: rss, at: now);
      } on FileSystemException {
        return MemorySample(at: now, rss: rss);
      }
    }
    return MemorySample(at: now, rss: rss);
  }

  /// A sample from /proc/meminfo's text: low below a twentieth of the
  /// total.
  @visibleForTesting
  static MemorySample linuxSample(String meminfo, {required int rss, required DateTime at}) {
    int? kb(String key) {
      final m = RegExp('^$key:\\s+(\\d+) kB', multiLine: true).firstMatch(meminfo);
      return m == null ? null : int.parse(m[1]!) * 1024;
    }

    final total = kb('MemTotal');
    final available = kb('MemAvailable');
    final threshold = total == null ? null : total ~/ 20;
    return MemorySample(
        at: at,
        available: available,
        total: total,
        threshold: threshold,
        lowMemory: available == null || threshold == null ? null : available < threshold,
        rss: rss);
  }
}
