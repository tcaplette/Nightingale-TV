import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../backup/backup_archive.dart';
import '../server/media_server.dart';
import '../server/plex/plex_account.dart';

/// Which failures are worth a report (error-reporting D5): outcomes the
/// user's network or server causes are expected and stay breadcrumbs.
abstract final class ReportPolicy {
  /// Unreachable servers, timeouts, refused or rejected sign-ins, wrong
  /// PINs, files that aren't backups.
  static bool isExpected(Object error) => switch (error) {
        SocketException() || TimeoutException() || TlsException() || HttpException() || http.ClientException() => true,
        PlexWrongPin() => true,
        // A file that isn't a backup, or one from a newer app: the user's.
        BackupException() => true,
        final ServerException e => e.unreachable || e.statusCode == 401 || e.statusCode == 403,
        _ => false,
      };

  /// What makes two reports "the same error": the exception type, the area
  /// and the top frame in the app's own code.
  static String fingerprint(SentryEvent event) {
    final area = event.tags?['area'] ?? 'uncaught';
    final exceptions = event.exceptions ?? const <SentryException>[];
    if (exceptions.isEmpty) return 'message|$area|${event.message?.template ?? event.message?.formatted ?? ''}';
    // The thrown exception is the last one; any before it are its causes.
    final thrown = exceptions.last;
    final withFrames = exceptions.lastWhere((e) => e.stackTrace?.frames.isNotEmpty ?? false, orElse: () => thrown);
    return '${thrown.type}|$area|${topAppFrame(withFrames.stackTrace)}';
  }

  /// The innermost frame in the app's own code: "function@file".
  static String topAppFrame(SentryStackTrace? trace) {
    final frames = trace?.frames ?? const <SentryStackFrame>[];
    // Frames run from the caller to the callee.
    for (final f in frames.reversed) {
      final own = f.package == 'nightingale_tv' ||
          (f.absPath?.contains('package:nightingale_tv/') ?? false) ||
          (f.module?.startsWith('com.coffeehauslabs.') ?? false);
      if (own) return '${f.function}@${f.fileName ?? f.absPath ?? f.module}';
    }
    return frames.isEmpty ? '' : '${frames.last.function}@${frames.last.fileName ?? frames.last.module}';
  }
}

/// The repeat limits (error-reporting D5): one event per error per
/// [window], and at most [perRun] events per app run.
class ReportLimiter {
  ReportLimiter({this.window = const Duration(minutes: 10), this.perRun = 30, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Duration window;
  final int perRun;
  final DateTime Function() _now;
  final _lastSent = <String, DateTime>{};
  int _sent = 0;

  int get sent => _sent;

  /// Null when the event may go (and it's counted), or why it's left out.
  /// [test] reports skip the per-error limit, not the per-run one.
  String? admit(String fingerprint, {bool test = false}) {
    if (_sent >= perRun) return 'over $perRun reports this run';
    final now = _now();
    if (!test) {
      final last = _lastSent[fingerprint];
      if (last != null && now.difference(last) < window) return 'sent within ${window.inMinutes} min';
      _lastSent[fingerprint] = now;
    }
    _sent++;
    return null;
  }
}
