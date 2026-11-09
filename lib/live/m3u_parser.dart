import 'dart:isolate';

import 'live_data.dart';
import '../l10n/tr.dart';

/// Why a playlist couldn't be read.
class M3uException implements Exception {
  const M3uException._(this._message);

  final String Function() _message;

  /// Shown to the user as it is, in the current language.
  String get message => _message();

  static const notM3u = M3uException._(_notM3uMessage);
  static const empty = M3uException._(_emptyMessage);

  static String _notM3uMessage() => tr.thatIsntAn;
  static String _emptyMessage() => tr.thePlaylistHas;

  @override
  String toString() => message;
}

class M3uPlaylist {
  const M3uPlaylist({required this.channels, this.guideUrls = const []});

  /// In playlist order, with unique keys.
  final List<LiveChannelInfo> channels;

  /// From the header's `url-tvg` / `x-tvg-url`, in order.
  final List<String> guideUrls;
}

/// Reads [text] off the UI isolate (see [parseM3u]).
Future<M3uPlaylist> parseM3uInBackground(String text) => Isolate.run(() => parseM3u(text));

/// Stream schemes a channel may use; other entries are skipped.
const m3uSchemes = {'http', 'https', 'rtsp', 'rtmp', 'udp'};

/// Reads an extended M3U playlist as IPTV players do (live-tv-sources
/// "M3U conventions read"). Throws [M3uException] when [text] isn't a
/// playlist or has no channels.
M3uPlaylist parseM3u(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final lines = text.split(RegExp(r'\r\n|\r|\n'));
  final guideUrls = <String>[];
  final channels = <LiveChannelInfo>[];
  final keys = <String, int>{};
  var sawHeader = false;
  var sawEntry = false;

  // What's been read for the entry whose URL comes next.
  Map<String, String>? attrs;
  String? displayName;
  String? extGroup;
  final vlcHeaders = <String, String>{};

  void reset() {
    attrs = null;
    displayName = null;
    extGroup = null;
    vlcHeaders.clear();
  }

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final upper = line.length >= 8 ? line.substring(0, 8).toUpperCase() : line.toUpperCase();
    if (upper.startsWith('#EXTM3U')) {
      sawHeader = true;
      final header = _attributes(line.substring(7));
      for (final e in header.entries) {
        if (e.key != 'url-tvg' && e.key != 'x-tvg-url') continue;
        for (final url in e.value.split(',')) {
          final u = url.trim();
          if (u.isNotEmpty && !guideUrls.contains(u)) guideUrls.add(u);
        }
      }
      continue;
    }
    if (upper.startsWith('#EXTINF:')) {
      reset();
      sawEntry = true;
      final body = line.substring(8);
      final comma = _nameComma(body);
      attrs = _attributes(comma < 0 ? body : body.substring(0, comma));
      displayName = comma < 0 ? null : body.substring(comma + 1).trim();
      continue;
    }
    if (upper.startsWith('#EXTGRP:')) {
      extGroup = line.substring(8).trim();
      continue;
    }
    if (line.toUpperCase().startsWith('#EXTVLCOPT:')) {
      final opt = line.substring(11);
      final eq = opt.indexOf('=');
      if (eq > 0) {
        final name = opt.substring(0, eq).trim().toLowerCase();
        final value = opt.substring(eq + 1).trim();
        if (name == 'http-user-agent') vlcHeaders['User-Agent'] = value;
        if (name == 'http-referrer' || name == 'http-referer') vlcHeaders['Referer'] = value;
      }
      continue;
    }
    if (line.startsWith('#')) continue;

    // A stream URL ends the entry.
    final a = attrs ?? const <String, String>{};
    final (url, kodiHeaders) = _splitKodiHeaders(line);
    final name = displayName;
    final group = a['group-title'] ?? extGroup;
    final headers = {...vlcHeaders, ...kodiHeaders};
    reset();
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme == null || !m3uSchemes.contains(scheme)) continue;
    if (a['radio']?.toLowerCase() == 'true') continue;
    final tvgId = _nonEmpty(a['tvg-id'] ?? a['channel-id']);
    final tvgName = _nonEmpty(a['tvg-name']);
    final title = _nonEmpty(name) ?? tvgName ?? url;
    var key = tvgId ?? tvgName ?? _nonEmpty(name) ?? url;
    final seen = keys[key] = (keys[key] ?? 0) + 1;
    if (seen > 1) key = '$key#$seen';
    channels.add(LiveChannelInfo(
      key: key,
      name: title,
      number: _nonEmpty(a['tvg-chno'] ?? a['channel-number']),
      group: _nonEmpty(group),
      logo: _nonEmpty(a['tvg-logo']),
      guideId: tvgId,
      tvgName: tvgName,
      url: url,
      headers: headers,
    ));
  }
  if (!sawHeader && !sawEntry) throw M3uException.notM3u;
  if (channels.isEmpty) throw M3uException.empty;
  return M3uPlaylist(channels: channels, guideUrls: guideUrls);
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// Attributes `name="value"` (names case-insensitive, lower-cased).
Map<String, String> _attributes(String s) => {
      for (final m in RegExp(r'([A-Za-z0-9_\-]+)\s*=\s*"([^"]*)"').allMatches(s)) m[1]!.toLowerCase(): m[2]!,
    };

/// Where the display name starts in an `#EXTINF:` line's body: the first
/// comma outside quotes; -1 when there's none.
int _nameComma(String body) {
  var quoted = false;
  for (var i = 0; i < body.length; i++) {
    final c = body.codeUnitAt(i);
    if (c == 0x22) quoted = !quoted;
    if (c == 0x2C && !quoted) return i;
  }
  return -1;
}

/// Kodi's `url|User-Agent=…&Referer=…` suffix, as headers.
(String, Map<String, String>) _splitKodiHeaders(String line) {
  final bar = line.indexOf('|');
  if (bar < 0) return (line, const {});
  final headers = <String, String>{};
  for (final pair in line.substring(bar + 1).split('&')) {
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    final name = pair.substring(0, eq).trim();
    var value = pair.substring(eq + 1).trim();
    try {
      value = Uri.decodeComponent(value);
    } on ArgumentError {
      // Left as written.
    }
    headers[switch (name.toLowerCase()) {
      'user-agent' => 'User-Agent',
      'referer' || 'referrer' => 'Referer',
      _ => name,
    }] = value;
  }
  return (line.substring(0, bar).trim(), headers);
}
