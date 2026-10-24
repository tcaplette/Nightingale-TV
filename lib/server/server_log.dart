import 'dart:io';

import 'package:flutter/foundation.dart';

import '../live/url_privacy.dart';

/// Server mode's log on standard output (server-mode "Logs on standard
/// output"). Every line, the app's own `debugPrint`s included, is scrubbed:
/// no access token, Plex token, password or live source credential gets
/// through.
abstract final class ServerLog {
  /// Where lines go (tests capture them).
  @visibleForTesting
  static void Function(String line) output = stdout.writeln;

  static final _secrets = <String>{};

  /// Token-like values: `api_key=…`, `X-Plex-Token: …`, `Token="…"`.
  static final _tokenPair = RegExp(
      r'''((?:access[_-]?token|api[_-]?key|x-plex-token|token|password|pw|auth)["']?\s*[=:]\s*["']?)([^\s"'&,;]+)''',
      caseSensitive: false);

  /// Sends every `debugPrint` here.
  static void install() {
    debugPrint = (message, {wrapWidth}) {
      if (message != null) info(message);
    };
  }

  /// A value that must never show in the log (a token, a password).
  static void secret(String? value) {
    if (value != null && value.length >= 4) _secrets.add(value);
  }

  static void info(String message) => output('${_time()} ${scrub(message)}');

  /// Written as it is: the first-run setup link, which has to carry its
  /// token.
  static void raw(String message) => output('${_time()} $message');

  @visibleForTesting
  static String scrub(String text) {
    var out = text;
    // Longest first, so a secret containing another goes whole.
    for (final s in _secrets.toList()..sort((a, b) => b.length - a.length)) {
      out = out.replaceAll(s, '••••');
    }
    out = scrubUrlsIn(out);
    return out.replaceAllMapped(_tokenPair, (m) => '${m[1]}••••');
  }

  @visibleForTesting
  static void reset() {
    _secrets.clear();
    output = stdout.writeln;
  }

  static String _time() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
