import 'package:sentry_flutter/sentry_flutter.dart';

/// Takes personal data out of error reports before they leave the device
/// (error-reporting design D4): server addresses, tokens and keys, the
/// household's names and the user's file paths.
///
/// Every string of an event goes through [scrub]: the message, exception
/// values, stack frame paths, breadcrumbs, tags and contexts.
class ReportScrubber {
  ReportScrubber({Iterable<String?> names = const [], Iterable<String?> folders = const []}) {
    setNames(names);
    setFolders(folders);
  }

  List<String> _names = const [];
  RegExp? _namePattern;
  List<String> _folders = const [];

  /// The names currently known to the household: server names and
  /// addresses, usernames, profile names and the device name. Each is
  /// replaced with `<name>` wherever it shows as a whole word.
  void setNames(Iterable<String?> names) {
    final kept = {
      for (final n in names)
        if (n != null && n.trim().length >= 2) n.trim(),
    }.toList()
      // Longest first, so "Mom's TV" goes before "Mom".
      ..sort((a, b) => b.length.compareTo(a.length));
    _names = kept;
    _namePattern = kept.isEmpty
        ? null
        : RegExp('(?<![\\p{L}\\p{N}_])(?:${kept.map(RegExp.escape).join('|')})(?![\\p{L}\\p{N}_])',
            caseSensitive: false, unicode: true);
  }

  List<String> get names => List.unmodifiable(_names);

  /// The user's home and the app's data folder: shortened to `~` in paths.
  void setFolders(Iterable<String?> folders) {
    _folders = {
      for (final f in folders)
        if (f != null && f.length > 1) f.endsWith('/') ? f.substring(0, f.length - 1) : f,
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  // `file://` URLs are paths, not servers.
  static final _url = RegExp(r'''(?<![A-Za-z0-9+.\-])(?!file:)[A-Za-z][A-Za-z0-9+.\-]*://[^\s/?#'"<>\\]*''');
  static final _serverQuery = RegExp(r'''(<server>[^\s?#'"<>]*)\?[^\s#'"<>]*''');
  static final _ipv4 = RegExp(r'(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?(?![\d.])');
  static final _ipv6 = RegExp(r'\[[0-9A-Fa-f:]{2,}\](?::\d{1,5})?');
  static final _authorization =
      RegExp(r'''((?:X-Emby-|X-MediaBrowser-)?Authorization["']?\s*[=:]\s*)[^\n]*''', caseSensitive: false);
  static final _secret = RegExp(
      r'''((?:X-Plex-Token|X-Emby-Token|X-MediaBrowser-Token|api[_-]?key|access[_-]?token|accesstoken|token|password|passwd|pw)["']?\s*[=:]\s*["']?)([^\s"'&,;<>]+)''',
      caseSensitive: false);
  static final _hex = RegExp(r'(?<![A-Za-z0-9])[0-9A-Fa-f]{20,}(?![A-Za-z0-9])');
  // Base64- or token-like: 20+ characters with letters and digits.
  static final _tokenLike =
      RegExp(r'(?<![A-Za-z0-9_+=\-])(?=[A-Za-z0-9_+=\-]*\d)(?=[A-Za-z0-9_+=\-]*[A-Za-z])[A-Za-z0-9_+=\-]{20,}');
  static final _homePath = RegExp(r'(?<![\w.~])/(?:home/[^/\s]+|root)(?=/|\b)');
  static final _androidData =
      RegExp(r'(?<![\w.~])/(?:data/user/\d+/[^/\s]+|data/data/[^/\s]+|storage/emulated/\d+|sdcard)(?=/|\b)');

  /// [text] with the personal data taken out.
  String scrub(String text) {
    var s = text;
    // 5. Paths first, so a file:// URL keeps its (shortened) path.
    for (final f in _folders) {
      s = s.replaceAll(f, '~');
    }
    s = s.replaceAll(_homePath, '~').replaceAll(_androidData, '~');
    // 1. Query strings go, server addresses become <server>.
    s = s.replaceAll(_url, '<server>').replaceAll(_ipv6, '<server>').replaceAll(_ipv4, '<server>');
    // Punctuation after a URL belongs to the sentence.
    s = s.replaceAllMapped(_serverQuery, (m) => m[1]! + (RegExp(r'[.,;:!)\]]+$').firstMatch(m[0]!)?[0] ?? ''));
    // 2. Known secrets (headers, JSON, relative URLs).
    s = s.replaceAllMapped(_authorization, (m) => '${m[1]}<redacted>');
    s = s.replaceAllMapped(_secret, (m) => '${m[1]}<redacted>');
    // 3. Token-like runs.
    s = s.replaceAll(_hex, '<redacted>').replaceAll(_tokenLike, '<redacted>');
    // 4. The household's names.
    final names = _namePattern;
    if (names != null) s = s.replaceAll(names, '<name>');
    return s;
  }

  String? scrubOrNull(String? text) => text == null ? null : scrub(text);

  /// Every string in [value] (maps and lists walked through) scrubbed.
  Object? scrubValue(Object? value) => switch (value) {
        final String s => scrub(s),
        final Map<dynamic, dynamic> m => {for (final e in m.entries) e.key: scrubValue(e.value)},
        final List<dynamic> l => [for (final v in l) scrubValue(v)],
        _ => value,
      };

  /// [event] with every string scrubbed, and no user, request or device
  /// name.
  SentryEvent scrubEvent(SentryEvent event) {
    event
      ..user = null
      ..request = null
      ..serverName = null
      ..transaction = scrubOrNull(event.transaction)
      ..culprit = scrubOrNull(event.culprit);
    final message = event.message;
    if (message != null) {
      event.message = SentryMessage(scrub(message.formatted),
          template: scrubOrNull(message.template), params: message.params?.map(scrubValue).toList());
    }
    for (final e in event.exceptions ?? const <SentryException>[]) {
      e
        ..value = scrubOrNull(e.value)
        ..type = scrubOrNull(e.type);
      _scrubFrames(e.stackTrace);
    }
    for (final t in event.threads ?? const <SentryThread>[]) {
      t.name = scrubOrNull(t.name);
      _scrubFrames(t.stacktrace);
    }
    for (final b in event.breadcrumbs ?? const <Breadcrumb>[]) {
      scrubBreadcrumb(b);
    }
    final tags = event.tags;
    if (tags != null) event.tags = {for (final e in tags.entries) e.key: scrub(e.value)};
    // ignore: deprecated_member_use
    final extra = event.extra;
    // ignore: deprecated_member_use
    if (extra != null) event.extra = {for (final e in extra.entries) e.key: scrubValue(e.value)};
    _scrubContexts(event.contexts);
    return event;
  }

  /// [b] with its message and data scrubbed.
  Breadcrumb scrubBreadcrumb(Breadcrumb b) {
    b.message = scrubOrNull(b.message);
    final data = b.data;
    if (data != null) b.data = {for (final e in data.entries) e.key: scrubValue(e.value)};
    return b;
  }

  void _scrubFrames(SentryStackTrace? trace) {
    for (final f in trace?.frames ?? const <SentryStackFrame>[]) {
      f
        ..absPath = scrubOrNull(f.absPath)
        ..fileName = scrubOrNull(f.fileName)
        ..contextLine = scrubOrNull(f.contextLine)
        ..package = scrubOrNull(f.package);
    }
  }

  void _scrubContexts(Contexts contexts) {
    final device = contexts.device;
    if (device != null) {
      device
        ..name = null
        ..deviceUniqueIdentifier = null;
    }
    final app = contexts.app;
    if (app != null) app.deviceAppHash = null;
    for (final key in contexts.keys.toList()) {
      final value = contexts[key];
      if (value is Map || value is List || value is String) contexts[key] = scrubValue(value);
    }
  }
}
