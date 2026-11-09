import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'url_privacy.dart';
import '../l10n/tr.dart';

/// A playlist or guide that couldn't be fetched; [message] is shown on the
/// source's row as it is.
class LiveSourceException implements Exception {
  const LiveSourceException(this.message, {this.detail});

  final String message;

  /// Why, for logs (URLs scrubbed).
  final String? detail;

  @override
  String toString() => message;
}

/// Downloads for Live TV sources (live-tv-sources "Refreshing and caching"):
/// they time out after [idleTimeout] without data and refuse anything over
/// their cap. Never through the diagnostics client: URLs carry credentials,
/// so only scrubbed ones are ever logged.
class LiveDownloader {
  LiveDownloader({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static Duration idleTimeout = const Duration(seconds: 60);

  /// Playlists over this are refused.
  static const maxPlaylistBytes = 50 << 20;

  /// Guides are refused past this much, compressed (the parser caps the
  /// uncompressed size).
  static const maxGuideBytes = 1 << 30;

  /// The text at [url] (UTF-8, malformed bytes replaced), up to
  /// [maxPlaylistBytes]. [what] names it in errors ("playlist").
  Future<String> text(Uri url, {String what = 'playlist', Map<String, String> headers = const {}}) async {
    final bytes = BytesBuilder(copy: false);
    await _fetch(url, what, maxPlaylistBytes, headers, bytes.add);
    return const Utf8Decoder(allowMalformed: true).convert(bytes.takeBytes());
  }

  /// Saves what's at [url] to [file], up to [maxBytes].
  Future<void> toFile(Uri url, File file,
      {String what = 'guide', int maxBytes = maxGuideBytes, Map<String, String> headers = const {}}) async {
    final sink = file.openWrite();
    try {
      await _fetch(url, what, maxBytes, headers, sink.add);
    } finally {
      await sink.close();
    }
  }

  Future<void> _fetch(Uri url, String what, int maxBytes, Map<String, String> headers, void Function(List<int>) add) async {
    if (url.scheme != 'http' && url.scheme != 'https') throw LiveSourceException(tr.theSAddress(what));
    final request = http.Request('GET', url)..headers.addAll(headers);
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(idleTimeout);
    } on TimeoutException {
      throw LiveSourceException(tr.couldntReachThe(what), detail: 'no answer');
    } on Exception catch (e) {
      throw LiveSourceException(tr.couldntReachThe(what), detail: scrubUrlsIn('$e'));
    }
    if (response.statusCode >= 400) {
      await response.stream.drain<void>().catchError((Object _) {});
      throw LiveSourceException(tr.couldntReachThe(what), detail: 'HTTP ${response.statusCode}');
    }
    if ((response.contentLength ?? 0) > maxBytes) {
      throw LiveSourceException(tr.theIsToo(what));
    }
    var size = 0;
    try {
      await for (final chunk in response.stream.timeout(idleTimeout)) {
        size += chunk.length;
        if (size > maxBytes) throw LiveSourceException(tr.theIsToo(what));
        add(chunk);
      }
    } on TimeoutException {
      throw LiveSourceException(tr.couldntReachThe(what), detail: 'it stopped sending');
    } on http.ClientException catch (e) {
      throw LiveSourceException(tr.couldntReachThe(what), detail: scrubUrlsIn(e.message));
    }
  }

  void close() => _http.close();
}
