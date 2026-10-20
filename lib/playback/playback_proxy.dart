import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'index_cache.dart';

/// What the proxy reports for the playback diagnostics: [kind] is
/// `upstream` (a request to the server: `warm`, `from`, `ms` to headers),
/// `cache` (`what`: hit, tee, saved), or `fill` (a background fill's
/// summary).
typedef ProxyEvent = ({String kind, Map<String, Object?> data});

/// mpv's way to Jellyfin (fast-tune spec, "Playback goes through a local
/// proxy with warm connections").
///
/// ffmpeg opens a fresh connection (TCP and TLS) for every request and seek,
/// and a fresh connection cost about 0.9 s more than a warm one on the
/// measured link. The proxy listens on the loopback address and keeps
/// keep-alive connections to the server, with [spares] idle ones kept warm
/// (`GET /System/Ping`), so each of mpv's requests starts on an open one.
///
/// Each open gets a one-time path (`/o/<random token>`) mapped to its real
/// URL and auth headers; nothing else is served, and mpv never sees the
/// access token. For the static stream it also answers the file's head and
/// index from the [IndexCache], so a direct-play join reads only from its
/// join point.
///
/// The server runs in a background isolate, like the analyzer's proxy.
/// With [inIsolate] false (tests) it runs in this one.
class PlaybackProxy {
  PlaybackProxy({this.cacheDir, this.inIsolate = true, this.spares = 2, this.maxCacheBytes = 256 * 1024 * 1024});

  /// Where the index cache lives (default: the app's cache folder).
  final Directory? cacheDir;
  final bool inIsolate;
  final int spares;
  final int maxCacheBytes;

  /// `NIGHTINGALE_TV_NO_PROXY=1` (environment or dart-define) opens real
  /// URLs directly, for comparisons.
  static bool get disabled =>
      const String.fromEnvironment('NIGHTINGALE_TV_NO_PROXY') == '1' ||
      Platform.environment['NIGHTINGALE_TV_NO_PROXY'] == '1';

  /// The app's index cache folder.
  static Future<Directory> defaultCacheDir() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/playback-index');

  final _events = StreamController<ProxyEvent>.broadcast();

  /// Upstream requests, cache use and fills, as they happen.
  Stream<ProxyEvent> get events => _events.stream;

  _ProxyCore? _local;
  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _eventPort;
  int? _port;
  Future<void>? _starting;

  bool get running => _port != null;

  /// Starts it (once); later calls wait for the first.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    final dir = cacheDir ?? await defaultCacheDir();
    if (!inIsolate) {
      final core = _local = _ProxyCore(IndexCache(dir, maxBytes: maxCacheBytes), spares, _events.add);
      _port = await core.bind();
      return;
    }
    final ready = ReceivePort();
    final events = _eventPort = ReceivePort();
    events.listen((m) {
      if (m case [final String kind, final Map<String, Object?> data]) _events.add((kind: kind, data: data));
    });
    _isolate = await Isolate.spawn(_serve, (ready.sendPort, events.sendPort, dir.path, spares, maxCacheBytes),
        debugName: 'playback proxy');
    final (SendPort commands, int port) = await ready.first as (SendPort, int);
    _commands = commands;
    _port = port;
  }

  /// Registers an open of [url] (with [headers], which mpv never sees) and
  /// returns the loopback URL mpv opens instead. The opens before it stop
  /// being served, except [alongside]: the loopback URL of the item playing
  /// when this one is the next segment, preloaded (segment-handover spec).
  /// [cache]: the static stream's cache key (none for transcodes). [joins]:
  /// mpv will seek away from the file's start, so reads past a cached region
  /// wait a moment before going upstream.
  Future<Uri> open(Uri url, Map<String, String> headers,
      {IndexCacheKey? cache, bool joins = false, Uri? alongside}) async {
    final token = _token();
    final keep = alongside != null && alongside.pathSegments.length == 2 ? alongside.pathSegments[1] : null;
    await _send([
      'open',
      token,
      url.toString(),
      Map<String, String>.of(headers),
      cache?.source,
      cache?.etag,
      cache?.size,
      joins,
      keep,
    ]);
    return Uri(scheme: 'http', host: '127.0.0.1', port: _port, path: '/o/$token');
  }

  /// Keeps [spares] connections to the server warm with [ping] (its
  /// `/System/Ping`).
  Future<void> warm(Uri ping, Map<String, String> headers) =>
      _send(['warm', ping.toString(), Map<String, String>.of(headers)]);

  /// While a segment plays, the warm connections are kept so every 60 s.
  Future<void> setPlaying(bool playing) => _send(['playing', playing]);

  /// In the background (Android: the app out of sight), no pings at all.
  Future<void> setBackground(bool background) => _send(['background', background]);

  /// While a stream opens, background fills hold off.
  Future<void> setTuning(bool tuning) => _send(['tuning', tuning]);

  /// Reads the head and index of the static stream [url] into the cache, at
  /// [bytesPerSecond] (null: no limit). Returns a summary for the
  /// diagnostics ("cached" when there was nothing to do).
  Future<String> fill(IndexCacheKey key, Uri url, Map<String, String> headers, {int? bytesPerSecond}) async =>
      await _send(['fill', key.source, key.etag, key.size, url.toString(), Map<String, String>.of(headers), bytesPerSecond])
          as String;

  /// Whether [source]'s head and index are kept.
  Future<bool> cached(String source) async => await _send(['cached', source]) as bool;

  /// Connections opened to the server and requests sent there (tests).
  Future<({int connections, int requests})> upstreamStats() async {
    final [int c, int r] = (await _send(['stats']) as List).cast<int>();
    return (connections: c, requests: r);
  }

  static String _token() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Object?> _send(List<Object?> command) async {
    await start();
    final local = _local;
    if (local != null) return local.handle(command);
    final commands = _commands;
    if (commands == null) throw StateError('The playback proxy is not running.');
    final reply = ReceivePort();
    commands.send([...command, reply.sendPort]);
    final answer = await reply.first;
    if (answer case ['error', final String message]) throw StateError(message);
    return answer;
  }

  Future<void> close() async {
    final starting = _starting;
    if (starting == null) return;
    try {
      await starting;
    } on Object {
      return;
    }
    _port = null;
    final local = _local;
    _local = null;
    if (local != null) {
      await local.close();
    } else {
      final reply = ReceivePort();
      _commands?.send(['close', reply.sendPort]);
      await reply.first.timeout(const Duration(seconds: 5), onTimeout: () => null);
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _commands = null;
      _eventPort?.close();
    }
    await _events.close();
  }
}

/// The background isolate: binds, reports its port, then follows commands.
Future<void> _serve((SendPort, SendPort, String, int, int) args) async {
  final (ready, events, dir, spares, maxBytes) = args;
  final core = _ProxyCore(IndexCache(Directory(dir), maxBytes: maxBytes), spares,
      (e) => events.send([e.kind, e.data]));
  final port = await core.bind();
  final commands = ReceivePort();
  ready.send((commands.sendPort, port));
  await for (final message in commands) {
    final command = (message as List<Object?>).sublist(0, message.length - 1);
    final reply = message.last as SendPort;
    // Commands run concurrently (a fill takes a while).
    unawaited(() async {
      try {
        reply.send(await core.handle(command));
      } on Object catch (e) {
        reply.send(['error', '$e']);
      }
    }());
    if (command.first == 'close') {
      commands.close();
      break;
    }
  }
}

/// One registered open.
class _Open {
  _Open(this.url, this.headers, this.key, this.joins);
  final Uri url;
  final Map<String, String> headers;
  final IndexCacheKey? key;
  final bool joins;

  /// Requests mpv made for it (a seek is a new one).
  int requests = 0;
  _Tee? tee;

  /// Still served.
  bool live = true;
}

class _ProxyCore {
  _ProxyCore(this.cache, int spares, this.emit) : pool = _Pool(spares);

  final IndexCache cache;
  final _Pool pool;
  final void Function(ProxyEvent) emit;
  HttpServer? _server;

  /// The opens being served, by token: the latest, and the one playing
  /// while the latest is preloaded.
  final _opens = <String, _Open>{};

  Timer? _keepWarm;
  bool _tuning = false;

  /// How long a read past a cached region waits, on an open that joins
  /// mid-file, before going upstream: mpv's seek to the join point comes
  /// first, and makes it unnecessary.
  static const _joinGrace = Duration(milliseconds: 1500);

  Future<int> bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((r) => unawaited(_handle(r)));
    return server.port;
  }

  Future<Object?> handle(List<Object?> command) async {
    switch (command) {
      case [
          'open',
          final String token,
          final String url,
          final Map<String, String> headers,
          final String? source,
          final String? etag,
          final int? size,
          final bool joins,
          final String? keep,
        ]:
        // A preload that comes after a new open (a tune meanwhile) mustn't
        // stop it being served.
        if (keep != null && !_opens.containsKey(keep)) throw StateError('the open it was to go alongside has ended');
        for (final token in [..._opens.keys]) {
          if (token == keep) continue;
          // What an open before learned is saved meanwhile.
          final before = _opens.remove(token)!..live = false;
          unawaited(_finishTee(before));
        }
        _opens[token] = _Open(Uri.parse(url), headers, source == null ? null : (source: source, etag: etag, size: size), joins);
      case ['warm', final String ping, final Map<String, String> headers]:
        pool.pingTarget = (Uri.parse(ping), headers);
        await pool.ensureSpares();
      case ['background', final bool background]:
        pool.background = background;
      case ['playing', final bool playing]:
        _keepWarm?.cancel();
        _keepWarm = null;
        if (playing) {
          _keepWarm = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(pool.keepWarm()));
        }
      case ['tuning', final bool tuning]:
        _tuning = tuning;
      case [
          'fill',
          final String source,
          final String? etag,
          final int? size,
          final String url,
          final Map<String, String> headers,
          final int? rate,
        ]:
        return _fill((source: source, etag: etag, size: size), Uri.parse(url), headers, rate);
      case ['cached', final String source]:
        return cache.peek(source)?.complete ?? false;
      case ['stats']:
        return [pool.connectionsOpened, pool.requests];
      case ['close']:
        await close();
    }
    return null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final parts = request.uri.pathSegments;
      final open = parts.length == 2 && parts[0] == 'o' ? _opens[parts[1]] : null;
      if (open == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final serial = ++open.requests;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final range = _parseRange(rangeHeader);
      final key = open.key;
      final entry = key == null ? null : await cache.lookup(key);
      final from = range?.$1 ?? 0;
      if (entry != null && request.method == 'GET' && entry.regionAt(from) != null) {
        await _serveCached(response, open, serial, entry, from, range?.$2);
      } else {
        await _pipe(request, response, open, entry, rangeHeader, from);
      }
    } on Object catch (e) {
      // mpv closes connections when it seeks; that's not an error.
      if (e is! HttpException && e is! SocketException) debugPrint('Playback proxy: $e');
      try {
        response.statusCode = HttpStatus.badGateway;
      } on StateError {
        // Headers already sent.
      }
    } finally {
      try {
        await response.close();
      } on Object {
        // The reader is gone.
      }
    }
  }

  /// `bytes=a-` or `bytes=a-b`: (a, b), or null.
  static (int, int?)? _parseRange(String? header) {
    final m = header == null ? null : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(header.trim());
    if (m == null) return null;
    return (int.parse(m.group(1)!), m.group(2)!.isEmpty ? null : int.parse(m.group(2)!));
  }

  /// Answers from the cache, then from upstream past the cached region if
  /// mpv reads on.
  Future<void> _serveCached(
      HttpResponse response, _Open open, int serial, IndexCacheEntry entry, int from, int? last) async {
    final end = min(last == null ? entry.size : last + 1, entry.size);
    emit((kind: 'cache', data: {'what': 'hit', 'from': from}));
    unawaited(cache.touch(entry));
    response.statusCode = HttpStatus.partialContent;
    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentRangeHeader, 'bytes $from-${end - 1}/${entry.size}')
      ..contentLength = end - from;
    if (entry.contentType case final type?) response.headers.set(HttpHeaders.contentTypeHeader, type);
    var at = from;
    while (at < end) {
      final region = entry.regionAt(at);
      if (region == null) break;
      final to = min(region.$2, end);
      for (var p = at; p < to; p += 64 * 1024) {
        response.add(await cache.read(entry, p, min(p + 64 * 1024, to)));
      }
      await response.flush();
      at = to;
    }
    if (at >= end) return;
    // mpv reads past what's kept. On a join it's about to seek away (a new
    // request): going upstream now would only compete with that seek.
    if (open.joins) {
      final deadline = DateTime.now().add(_joinGrace);
      while (DateTime.now().isBefore(deadline) && open.requests == serial && open.live) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (open.requests != serial || !open.live) return;
    }
    final up = await pool.request('GET', open.url, {
      ...open.headers,
      HttpHeaders.rangeHeader: 'bytes=$at-${last ?? ''}',
    });
    _emitUpstream(up, at);
    final total = _totalSize(up.response);
    if (up.response.statusCode != HttpStatus.partialContent || total != entry.size) {
      // The file changed since it was cached.
      up.abort();
      await cache.drop(entry.source);
      emit((kind: 'cache', data: {'what': 'stale', 'source': entry.source}));
      throw const HttpException('cached file changed');
    }
    await _copy(up, response, from: at, open: open);
    await _settleTee(open);
  }

  Future<void> _pipe(
      HttpRequest request, HttpResponse response, _Open open, IndexCacheEntry? entry, String? range, int from) async {
    final up = await pool.request(request.method, open.url, {
      ...open.headers,
      HttpHeaders.rangeHeader: ?range,
    });
    _emitUpstream(up, from);
    final upstream = up.response;
    response.statusCode = upstream.statusCode;
    for (final name in const [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
    ]) {
      final value = upstream.headers.value(name);
      if (value != null) response.headers.set(name, value);
    }
    if (upstream.contentLength >= 0) response.headers.contentLength = upstream.contentLength;
    final key = open.key;
    final ok = upstream.statusCode == HttpStatus.ok || upstream.statusCode == HttpStatus.partialContent;
    final size = _totalSize(upstream);
    if (key != null && ok && size != null) {
      if (entry != null && entry.size != size) {
        await cache.drop(entry.source);
        entry = null;
      }
      // Learn the head and index from what mpv reads.
      if (entry == null || !entry.complete) {
        final tee = open.tee ??= _Tee((source: key.source, etag: key.etag, size: size), size,
            upstream.headers.value(HttpHeaders.contentTypeHeader));
        if (entry != null && !tee.seeded) {
          tee.seeded = true;
          final head = entry.regionAt(0);
          if (head != null) tee.add(0, await cache.read(entry, 0, head.$2));
        }
      }
    }
    if (request.method == 'HEAD') {
      up.abort();
      return;
    }
    // Where the index is, from what has passed so far, so that this
    // response's bytes are kept if they're it (an MP4's moov at the end is
    // read by the request after the first).
    final tee = open.tee;
    if (tee != null && !tee.saved) {
      // The file's last bytes (an MP4's trailing boxes) are kept as they pass.
      if (tee.size - from <= indexCacheTail) tee.keepFrom(from);
      await tee.locate();
    }
    await _copy(up, response, from: from, open: open);
    await _settleTee(open);
  }

  /// The whole file's size: Content-Range's total, or a 200's length.
  static int? _totalSize(HttpClientResponse r) {
    final range = r.headers.value(HttpHeaders.contentRangeHeader);
    final m = range == null ? null : RegExp(r'/(\d+)$').firstMatch(range);
    if (m != null) return int.parse(m.group(1)!);
    return r.statusCode == HttpStatus.ok && r.contentLength >= 0 ? r.contentLength : null;
  }

  void _emitUpstream(_Upstream up, int from) => emit((
        kind: 'upstream',
        data: {'warm': up.warm, 'from': from, 'ms': up.headersAfter.inMilliseconds, 'status': up.response.statusCode},
      ));

  /// Copies [up] to [response] as fast as mpv reads it (socket
  /// backpressure), teeing what passes into [tee].
  Future<void> _copy(_Upstream up, HttpResponse response, {required int from, _Open? open}) async {
    var ended = false;
    var at = from;
    final tee = open?.tee;
    final stream = up.response.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        if (tee != null) {
          final hadHead = tee.headComplete;
          tee.add(at, data);
          // As soon as the head is in: where the index is, so only what's
          // needed is kept from here on.
          if (!hadHead && tee.headComplete) unawaited(_settleTee(open!));
        }
        at += data.length;
        sink.add(data);
      },
      handleDone: (sink) {
        ended = true;
        sink.close();
      },
    ));
    try {
      await response.addStream(stream);
    } on Object {
      // mpv left (a seek): the rest of this response isn't wanted.
      up.abort();
      rethrow;
    } finally {
      pool.release(up, reusable: ended && up.response.persistentConnection);
    }
  }

  Future<void> _settleTee(_Open open) async {
    final tee = open.tee;
    if (tee == null || tee.saved) return;
    final result = await tee.locate();
    if (result == null) return;
    await _saveTee(tee, result);
  }

  /// [open] was replaced: what its tee learned is kept, even if only the
  /// head (a fill may finish it).
  Future<void> _finishTee(_Open open) async {
    final tee = open.tee;
    if (tee == null || tee.saved || tee.headBytes().$2.isEmpty) return;
    await _saveTee(tee, await tee.locate() ?? const IndexNeeds(0), last: true);
  }

  /// Saves what [tee] has once its index is in (with as much of the head
  /// as mpv read); with [last], the head alone if that's all there is. An
  /// entry without the whole head is finished by a later fill.
  Future<void> _saveTee(_Tee tee, IndexLookup result, {bool last = false}) async {
    final regions = [tee.headBytes(), ...tee.tailBytes()];
    var indexKept = result is IndexNone;
    if (result is IndexFound) {
      final (start, end) = keptSpan(result, tee.size);
      // The index, and as much of what follows it as passed.
      final index = tee.bytesOf(result.start, result.end) == null ? null : tee.bytesUpTo(start, end);
      if (index != null) {
        regions.add((start, index));
        indexKept = true;
      } else if (result.end - result.start > indexCacheMaxIndex) {
        indexKept = true;
      }
    }
    // Not all read yet: mpv may still read it during this open.
    if (!indexKept && !last) return;
    if (tee.saved) return;
    tee.saved = indexKept;
    final complete = indexKept && tee.headComplete;
    await cache.put(tee.key, size: tee.size, contentType: tee.contentType, regions: regions, complete: complete);
    emit((kind: 'cache', data: {'what': indexKept ? 'saved' : 'saved-head', 'source': tee.key.source}));
  }

  // ---- Background fills ------------------------------------------------------

  Future<String> _fill(IndexCacheKey key, Uri url, Map<String, String> headers, int? rate) async {
    final existing = await cache.lookup(key);
    if (existing != null && existing.complete) return 'cached';
    final clock = Stopwatch()..start();
    final reads = <int, Uint8List>{
      // What an open already kept isn't read again.
      if (existing != null)
        for (final (start, end) in existing.regions) start: await cache.read(existing, start, end),
    };
    var size = existing?.size ?? key.size;
    String? type;
    var bytes = 0;
    var requests = 0;

    Future<Uint8List> get(int from, int to) async {
      if (_tuning) throw const HttpException('a stream is opening');
      requests++;
      final up = await pool.request('GET', url, {...headers, HttpHeaders.rangeHeader: 'bytes=$from-${to - 1}'});
      final total = _totalSize(up.response);
      if (up.response.statusCode != HttpStatus.partialContent || total == null) {
        up.abort();
        throw HttpException('no range support (${up.response.statusCode})');
      }
      size = total;
      type ??= up.response.headers.value(HttpHeaders.contentTypeHeader);
      final out = BytesBuilder(copy: false);
      var ended = false;
      try {
        final pace = Stopwatch()..start();
        final want = to - from;
        await for (final chunk in up.response) {
          // A server that sends past the range's end is cut off there.
          if (out.length + chunk.length > want) {
            out.add(chunk.sublist(0, want - out.length));
            break;
          }
          out.add(chunk);
          if (_tuning) throw const HttpException('a stream is opening');
          if (rate != null && rate > 0) {
            final due = Duration(microseconds: (out.length / rate * 1e6).round());
            if (due > pace.elapsed) await Future<void>.delayed(due - pace.elapsed);
          }
        }
        // Read to its end, the connection stays open for the next.
        ended = out.length <= want && up.response.contentLength == out.length;
      } finally {
        if (!ended) up.abort();
        pool.release(up, reusable: ended && up.response.persistentConnection);
      }
      bytes += out.length;
      return out.takeBytes();
    }

    try {
      if (size == null) reads[0] = await get(0, indexCacheHead);
      final fileSize = size!;
      Future<Uint8List?> read(int offset, int length) async {
        final end = min(offset + length, fileSize);
        if (offset >= end) return Uint8List(0);
        final out = BytesBuilder(copy: false);
        var at = offset;
        while (at < end) {
          final hit = reads.entries.where((e) => at >= e.key && at < e.key + e.value.length).firstOrNull;
          if (hit != null) {
            final to = min(end, hit.key + hit.value.length);
            out.add(Uint8List.sublistView(hit.value, at - hit.key, to - hit.key));
            at = to;
            continue;
          }
          // Only what isn't read yet; box and element headers are small
          // reads, on a warm connection.
          final b = await get(at, min(fileSize, max(end, at + 4096)));
          if (b.isEmpty) return null;
          reads[at] = b;
        }
        return out.takeBytes();
      }

      final head = (await read(0, indexCacheHead))!;
      final result = await locateIndex(read, fileSize);
      final regions = [(0, head)];
      var complete = result is IndexNone;
      var what = result is IndexNone ? 'head only (no index)' : 'head';
      if (result is IndexFound && result.end - result.start <= indexCacheMaxIndex) {
        final (start, end) = keptSpan(result, fileSize);
        final index = await read(start, end - start);
        if (index != null && index.length == end - start) {
          regions.add((start, index));
          complete = true;
          what = '${result.kind} ${(index.length / 1024).round()} KB at ${(result.start / fileSize * 100).round()}%';
        }
      } else if (result is IndexFound) {
        complete = true;
        what = '${result.kind} too big (${result.end - result.start} B), head only';
      }
      if (result is IndexFound && result.kind == 'moov' && result.end < fileSize - indexCacheTail) {
        final tail = await read(fileSize - indexCacheTail, indexCacheTail);
        if (tail != null) regions.add((fileSize - indexCacheTail, tail));
      }
      await cache.put((source: key.source, etag: key.etag, size: fileSize),
          size: fileSize, contentType: type, regions: regions, complete: complete);
      final summary = '${key.source}: $what, ${(bytes / 1024).round()} KB in $requests requests, '
          '${clock.elapsed.inMilliseconds} ms';
      emit((kind: 'fill', data: {'summary': summary}));
      return summary;
    } on Object catch (e) {
      final summary = '${key.source}: stopped ($e) after ${(bytes / 1024).round()} KB';
      emit((kind: 'fill', data: {'summary': summary}));
      return summary;
    }
  }

  Future<void> close() async {
    _keepWarm?.cancel();
    _opens.clear();
    pool.close();
    await _server?.close(force: true);
    _server = null;
  }
}

/// Learns a file's head and index from the bytes mpv reads through the
/// proxy, during the open of a file the cache doesn't have yet.
class _Tee {
  _Tee(this.key, this.size, this.contentType);

  final IndexCacheKey key;
  final int size;
  final String? contentType;

  /// The head entry already cached was added.
  bool seeded = false;

  /// Saved with its index (nothing more to learn).
  bool saved = false;

  /// Contiguous runs of bytes kept, by start: the head, what follows it,
  /// and wherever the index turns out to be.
  late final _runs = <_Run>[
    _Run(0, min(indexCacheHead, size)),
    // Until the head says where the index is, what follows it is kept (an
    // MP4 written for streaming has its index there).
    _Run(min(indexCacheHead, size), min(indexCacheHead + indexCacheMaxIndex, size)),
  ];

  bool get headComplete => _runs.first.full;

  void add(int offset, List<int> data) {
    for (final r in _runs) {
      r.add(offset, data);
    }
  }

  (int, Uint8List) headBytes() => (0, _runs.first.bytes);

  /// Bytes [from] to [to] if they've passed through (across runs), else
  /// null.
  Uint8List? bytesOf(int from, int to) {
    to = min(to, size);
    if (from >= to) return Uint8List(0);
    final out = BytesBuilder(copy: false);
    var at = from;
    while (at < to) {
      final r = _runs.where((r) => at >= r.start && at < r.end).firstOrNull;
      if (r == null) return null;
      final end = min(to, r.end);
      out.add(Uint8List.sublistView(r.bytes, at - r.start, end - r.start));
      at = end;
    }
    return out.takeBytes();
  }

  /// Bytes from [from] up to [to], or as far as they've passed
  /// contiguously.
  Uint8List bytesUpTo(int from, int to) {
    var end = from;
    while (end < to) {
      final r = _runs.where((r) => end >= r.start && end < r.end).firstOrNull;
      if (r == null) break;
      end = min(to, r.end);
    }
    return bytesOf(from, end)!;
  }

  /// Keeps what passes from [offset] to the end of the file.
  void keepFrom(int offset) {
    if (!_covers(offset, size)) _runs.add(_Run(offset, size));
  }

  /// The file's last bytes, if they passed: (start, bytes).
  List<(int, Uint8List)> tailBytes() => [
        for (final r in _runs)
          if (r.start >= size - indexCacheTail && r.full && r.end > r.start) (r.start, r.bytes),
      ];

  /// Whether the runs (with what they may still take) cover [from] to [to].
  bool _covers(int from, int to) {
    var at = from;
    while (at < to) {
      final r = _runs.where((r) => at >= r.start && at <= r.end && r.limit > at).firstOrNull;
      if (r == null) return false;
      at = r.limit;
    }
    return true;
  }

  /// Where the index is, as far as what passed shows; null until the head
  /// has passed. Bytes still needed start being kept.
  Future<IndexLookup?> locate() async {
    final result = await locateIndex((offset, length) => bytesOf(offset, offset + length), size);
    final want = switch (result) {
      IndexFound() => keptSpan(result, size),
      IndexNeeds(:final offset) => (offset, min(offset + indexCacheMaxIndex, size)),
      IndexNone() => null,
    };
    // What follows the head is kept only as far as the index needs it.
    final after = _runs[1];
    if (want == null || want.$2 <= after.start || want.$1 >= after.limit) {
      after.stop();
    } else if (result is IndexFound) {
      after.limit = max(after.end, min(after.limit, want.$2));
    }
    if (want != null && !_covers(want.$1, want.$2)) _runs.add(_Run(want.$1, want.$2));
    return result;
  }
}

/// Bytes from [start], kept as they pass in order, up to [limit].
class _Run {
  _Run(this.start, this.limit);

  final int start;
  int limit;
  final _builder = BytesBuilder();
  Uint8List? _bytes;

  int get end => start + _builder.length;
  bool get full => end >= limit;

  Uint8List get bytes => _bytes ??= _builder.toBytes();

  void stop() => limit = end;

  void add(int offset, List<int> data) {
    final dataEnd = offset + data.length;
    if (full || offset > end || dataEnd <= end) return;
    _builder.add(data.sublist(end - offset, min(data.length, limit - offset)));
    _bytes = null;
  }
}

/// One upstream request in flight on [conn].
class _Upstream {
  _Upstream(this.conn, this.request, this.response, this.warm, this.headersAfter);
  final _Conn conn;
  final HttpClientRequest request;
  final HttpClientResponse response;

  /// It went out on a connection that was already open.
  final bool warm;
  final Duration headersAfter;

  void abort() => request.abort();
}

/// One connection to the server: an [HttpClient] allowed a single
/// connection, so which one is warm is known exactly.
class _Conn {
  _Conn()
      : http = HttpClient()
          ..maxConnectionsPerHost = 1
          ..idleTimeout = idleTimeout
          ..autoUncompress = false;

  static const idleTimeout = Duration(seconds: 120);

  final HttpClient http;

  /// The local port of its open connection (null when there's none).
  int? port;
  bool busy = false;
  DateTime idleSince = DateTime.now();

  bool get warm =>
      !busy && port != null && DateTime.now().difference(idleSince) < idleTimeout - const Duration(seconds: 5);
}

/// The proxy's connections to the server.
class _Pool {
  _Pool(this.spares);

  final int spares;
  final _conns = <_Conn>[];

  /// Where warm-up pings go, and their headers.
  (Uri, Map<String, String>)? pingTarget;

  /// In the background no pings go out.
  bool background = false;
  int _warming = 0;

  int connectionsOpened = 0;
  int requests = 0;

  /// Sends a request on a warm connection if there is one.
  Future<_Upstream> request(String method, Uri url, Map<String, String> headers, {bool ping = false}) async {
    final idle = _conns.where((c) => !c.busy).toList()
      ..sort((a, b) => (b.warm ? 1 : 0) - (a.warm ? 1 : 0));
    final conn = idle.firstOrNull ?? _Conn();
    if (!_conns.contains(conn)) _conns.add(conn);
    conn.busy = true;
    try {
      return await _send(conn, method, url, headers);
    } on Object {
      // A connection the server had closed while idle: once more, fresh.
      if (conn.port == null) {
        conn.busy = false;
        rethrow;
      }
      conn.port = null;
      try {
        return await _send(conn, method, url, headers);
      } on Object {
        conn.busy = false;
        rethrow;
      }
    } finally {
      // Don't let warming wait for this one; keep spares for the next.
      if (!ping) unawaited(ensureSpares());
    }
  }

  Future<_Upstream> _send(_Conn conn, String method, Uri url, Map<String, String> headers) async {
    final clock = Stopwatch()..start();
    final request = await conn.http.openUrl(method, url);
    request.headers.removeAll(HttpHeaders.acceptEncodingHeader);
    headers.forEach(request.headers.set);
    final response = await request.close();
    requests++;
    final port = response.connectionInfo?.localPort;
    // The same local port: the connection already open was used.
    final warm = port != null && port == conn.port;
    if (!warm) connectionsOpened++;
    conn.port = port;
    return _Upstream(conn, request, response, warm, clock.elapsed);
  }

  void release(_Upstream up, {required bool reusable}) {
    final conn = up.conn;
    conn.busy = false;
    conn.idleSince = DateTime.now();
    if (!reusable) conn.port = null;
  }

  /// Opens connections until [spares] idle ones are warm. Pings go only to
  /// connections that aren't warm, so the warm ones stay free for mpv.
  Future<void> ensureSpares() async {
    final target = pingTarget;
    if (target == null || background) return;
    final warm = _conns.where((c) => c.warm).length;
    final needed = spares - warm - _warming;
    if (needed <= 0) return;
    await Future.wait([for (var i = 0; i < needed; i++) _ping(target, cold: true)]);
  }

  /// Every 60 s while a segment plays: pings the warm connections so the
  /// server keeps them, and tops the spares up.
  Future<void> keepWarm() async {
    final target = pingTarget;
    if (target == null || background) return;
    final warm = _conns.where((c) => c.warm).toList();
    await Future.wait([for (final c in warm) _ping(target, on: c)]);
    await ensureSpares();
  }

  Future<void> _ping((Uri, Map<String, String>) target, {_Conn? on, bool cold = false}) async {
    _warming++;
    final conn = on ?? _conns.where((c) => !c.busy && !c.warm).firstOrNull ?? _Conn();
    if (!_conns.contains(conn)) _conns.add(conn);
    if (conn.busy) {
      _warming--;
      return;
    }
    conn.busy = true;
    _Upstream? up;
    try {
      up = await _send(conn, 'GET', target.$1, target.$2);
      await up.response.drain<void>();
      release(up, reusable: up.response.persistentConnection);
    } on Object {
      conn.busy = false;
      conn.port = null;
    } finally {
      _warming--;
    }
  }

  void close() {
    for (final c in _conns) {
      c.http.close(force: true);
    }
    _conns.clear();
  }
}
