import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../convert/conversion.dart';
import '../../convert/conversion_jobs.dart';
import 'smb_connection.dart';
import 'smb_share.dart';

/// What one file of a share is served as.
class GatewayFile {
  const GatewayFile({required this.path, required this.size, this.modified = 0});

  final String path;
  final int size;

  /// Milliseconds since the epoch.
  final int modified;

  String get etag => '"$size-$modified"';
}

/// How the gateway reaches one share of one profile.
class GatewayTarget {
  const GatewayTarget({required this.address, required this.credentials, this.smb1 = false, this.serverId = ''});

  final SmbAddress address;
  final SmbCredentials credentials;

  /// SMB1 last time.
  final bool smb1;

  /// The share's own id, which a paired Nightingale TV knows it by.
  final String serverId;
}

/// A paired Nightingale TV that converts: where it is, and this device's
/// key there.
typedef GatewayHelper = ({Uri base, String key});

/// The address an app-made URL of the gateway starts with.
typedef GatewayBase = ({int port, String secret});

/// Serves files of SMB shares over HTTP on the loopback address (design
/// D3), so the player, the analyzer, export and ffmpeg read them as they
/// read a media server's. It runs in its own isolate, and is started before
/// any share's client is made ([ensureStarted]).
///
/// URLs are `http://127.0.0.1:<port>/<secret>/<target>/<kind>/<id>`, with a
/// secret made each time the app starts. Ids are looked up in the share's
/// scan, never taken as paths:
/// - `f` a file, for playback, and `b` the same file for background work
///   (ffprobe, analysis), over connections of its own so it never holds up
///   the picture;
/// - `i` an image: a file of the share, or a cover inside a file;
/// - `s` a subtitle track, as a format and from a time;
/// - `c` a conversion ([ConversionSpec]);
/// - `p` opens the playback connection, for keeping it warm.
class SmbGateway {
  SmbGateway._(this.base, this._send, this._close);

  final GatewayBase base;
  final Future<Object?> Function(List<Object?> command) _send;
  final Future<void> Function() _close;

  static SmbGateway? _instance;
  static Future<SmbGateway>? _starting;

  /// The running gateway; [ensureStarted] comes first.
  static SmbGateway get instance => _instance!;
  static bool get running => _instance != null;

  /// Runs it in this isolate (tests).
  @visibleForTesting
  static bool inIsolate = true;

  static Future<SmbGateway> ensureStarted() => _starting ??= _start().then((g) => _instance = g).catchError((Object e) {
        _starting = null;
        throw e;
      });

  static Future<SmbGateway> _start() async {
    final secret = _newSecret();
    final programs = await FfmpegPrograms.find();
    if (!inIsolate) {
      final core = GatewayCore(secret, programs);
      final port = await core.bind();
      return SmbGateway._((port: port, secret: secret), core.handle, core.close);
    }
    final ready = ReceivePort();
    // An error nothing handled is logged, and the gateway keeps serving:
    // every share's playback goes through it.
    final errors = ReceivePort()..listen((e) => debugPrint('SMB gateway error: ${e is List ? e.first : e}'));
    final isolate = await Isolate.spawn(_serve, (ready.sendPort, secret, programs),
        debugName: 'smb gateway', errorsAreFatal: false, onError: errors.sendPort);
    final (SendPort commands, int port) = await ready.first as (SendPort, int);
    Future<Object?> send(List<Object?> command) async {
      final reply = ReceivePort();
      commands.send((command, reply.sendPort));
      final answer = await reply.first;
      if (answer case ('error', final String message)) throw StateError(message);
      return answer;
    }

    return SmbGateway._((port: port, secret: secret), send, () async {
      await send(['close']).timeout(const Duration(seconds: 3), onTimeout: () => null);
      isolate.kill(priority: Isolate.immediate);
      errors.close();
    });
  }

  static String _newSecret() {
    final rng = Random.secure();
    return List.generate(20, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static int _targets = 0;

  /// A name for a target, never used before in this launch.
  static String newTarget() => 't${++_targets}';

  Uri uri(String target, String kind, [String? id, Map<String, String>? query]) => Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: base.port,
      pathSegments: [base.secret, target, kind, ?id],
      queryParameters: query);

  /// Serves [target] from now on.
  Future<void> register(String target, GatewayTarget share) => _send(['register', target, share]);

  Future<void> unregister(String target) => _send(['unregister', target]);

  /// Replaces [target]'s files by id. Sent in chunks, so a large share never
  /// holds the sending isolate up.
  Future<void> setFiles(String target, Map<String, GatewayFile> files) async {
    const chunk = 1000;
    final entries = files.entries.toList();
    await _send(['files-begin', target]);
    for (var i = 0; i < entries.length; i += chunk) {
      await _send(['files', target, Map.fromEntries(entries.sublist(i, min(i + chunk, entries.length)))]);
    }
    await _send(['files-end', target]);
  }

  /// The paired Nightingale TVs, by id.
  Future<void> setHelpers(Map<String, GatewayHelper> helpers) => _send(['helpers', helpers]);

  /// Stops conversion [job] (a play session's).
  Future<void> stopJob(String job) => _send(['stop-job', job]);

  /// Conversions running now (tests and the idle check).
  Future<int> runningJobs() async => await _send(['jobs']) as int;

  /// Shares connected now.
  Future<int> connections() async => await _send(['connections']) as int;

  /// Stops it and everything it runs (the app exits; tests).
  static Future<void> stop() async {
    final g = _instance;
    _instance = null;
    _starting = null;
    await g?._close();
  }
}

Future<void> _serve((SendPort, String, FfmpegPrograms?) args) async {
  final (ready, secret, programs) = args;
  final core = GatewayCore(secret, programs);
  final port = await core.bind();
  final commands = ReceivePort();
  ready.send((commands.sendPort, port));
  await for (final message in commands) {
    final (List<Object?> command, SendPort reply) = message as (List<Object?>, SendPort);
    unawaited(() async {
      try {
        reply.send(await core.handle(command));
      } on Object catch (e) {
        reply.send(('error', '$e'));
      }
    }());
  }
}

class _Target {
  _Target(GatewayTarget share)
      : serverId = share.serverId,
        playback = _connection(share),
        background = _connection(share);

  static SmbConnection _connection(GatewayTarget share) =>
      SmbConnection(share.address, () async => share.credentials, knownSmb1: share.smb1, open: GatewayCore.openForTests);

  final String serverId;

  final SmbConnection playback;
  final SmbConnection background;
  Map<String, GatewayFile> files = {};
  Map<String, GatewayFile> loading = {};

  Future<void> close() => Future.wait([playback.close(), background.close()]);
}

/// What runs in the gateway's isolate.
@visibleForTesting
class GatewayCore {
  GatewayCore(this._secret, FfmpegPrograms? programs) : _programs = programs;

  final String _secret;
  final FfmpegPrograms? _programs;
  final _targets = <String, _Target>{};
  Map<String, GatewayHelper> _helpers = {};
  late final _jobs = ConversionJobs(_programs, input: (target, id) => _uri(target, 'f', id).toString())
    ..helpers = (helper, target, id) {
      final h = _helpers[helper];
      final t = _targets[target];
      final file = t?.files[id];
      if (h == null || t == null || file == null) return null;
      return HelperRoute(base: h.base, key: h.key, item: {
        'share': t.serverId,
        'item': id,
        'size': '${file.size}',
        'modified': '${file.modified}',
      });
    };
  HttpServer? _server;

  Uri _uri(String target, String kind, String id) => Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server!.port,
      pathSegments: [_secret, target, kind, id]);

  Future<int> bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((r) => unawaited(_handle(r)));
    return server.port;
  }

  Future<Object?> handle(List<Object?> command) async {
    switch (command) {
      case ['register', final String target, final GatewayTarget share]:
        final before = _targets[target];
        _targets[target] = _Target(share)..files = before?.files ?? {};
        unawaited(before?.close());
      case ['unregister', final String target]:
        await _targets.remove(target)?.close();
      case ['files-begin', final String target]:
        _targets[target]?.loading = {};
      case ['files', final String target, final Map<String, GatewayFile> files]:
        _targets[target]?.loading.addAll(files);
      case ['files-end', final String target]:
        if (_targets[target] case final t?) {
          t.files = t.loading;
          t.loading = {};
        }
      case ['helpers', final Map<String, GatewayHelper> helpers]:
        _helpers = helpers;
      case ['stop-job', final String job]:
        await _jobs.stop(job);
      case ['jobs']:
        return _jobs.running;
      case ['connections']:
        return _targets.values.fold<int>(0, (n, t) => n + (t.playback.isOpen ? 1 : 0) + (t.background.isOpen ? 1 : 0));
      case ['close']:
        await close();
    }
    return null;
  }

  Future<void> close() async {
    await _jobs.stopAll();
    final targets = [..._targets.values];
    _targets.clear();
    await Future.wait([for (final t in targets) t.close()]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
    await _server?.close(force: true);
  }

  static int _statusOf(SmbErrorKind kind) => switch (kind) {
        SmbErrorKind.unreachable => HttpStatus.serviceUnavailable,
        SmbErrorKind.wrongSignIn || SmbErrorKind.guestsRefused => HttpStatus.unauthorized,
        SmbErrorKind.noAccess => HttpStatus.forbidden,
        SmbErrorKind.gone => HttpStatus.notFound,
        SmbErrorKind.other => HttpStatus.badGateway,
      };

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.removeAll(HttpHeaders.contentTypeHeader);
    try {
      final parts = request.uri.pathSegments;
      final target = parts.length >= 3 && parts[0] == _secret ? _targets[parts[1]] : null;
      if (target == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (parts.length == 3 && parts[2] == 'p') {
        await target.playback.use((_) async {});
        response.statusCode = HttpStatus.noContent;
        return;
      }
      final id = parts.length == 4 ? parts[3] : '';
      final file = target.files[id];
      if (file == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      switch (parts[2]) {
        case 'f':
          await _serveFile(request, target.playback, file);
        case 'b':
          await _serveFile(request, target.background, file);
        case 'i':
          await _serveImage(request, target, parts[1], id, file);
        case 's':
          await _serveSubtitle(request, target, parts[1], id, file);
        case 'c':
          await _jobs.serve(request, parts[1], id);
        default:
          response.statusCode = HttpStatus.notFound;
      }
    } on SmbException catch (e) {
      _setStatus(response, _statusOf(e.kind));
    } on ConversionException {
      _setStatus(response, HttpStatus.badGateway);
    } on Object catch (e) {
      // Readers close connections when they seek; that's not an error.
      if (e is! HttpException && e is! SocketException) debugPrint('SMB gateway: ${e.runtimeType}');
      _setStatus(response, HttpStatus.badGateway);
    } finally {
      try {
        await response.close();
      } on Object {
        // The reader is gone.
      }
    }
  }

  static void _setStatus(HttpResponse response, int status) {
    try {
      response.statusCode = status;
      response.contentLength = 0;
    } on Object {
      // Headers already sent.
    }
  }

  /// `bytes=a-`, `bytes=a-b` or `bytes=-n` of [size] bytes as (start, end);
  /// null without one, and (size, size) when it asks past the end.
  static (int, int)? parseRange(String? header, int size) {
    final m = header == null ? null : RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (m == null || m[1]!.isEmpty && m[2]!.isEmpty) return null;
    if (m[1]!.isEmpty) return (max(0, size - int.parse(m[2]!)), size);
    final start = int.parse(m[1]!);
    if (start >= size) return (size, size);
    final end = m[2]!.isEmpty ? size : min(int.parse(m[2]!) + 1, size);
    return end <= start ? null : (start, end);
  }

  Future<void> _serveFile(HttpRequest request, SmbConnection connection, GatewayFile file) => connection.use((share) async {
        final response = request.response;
        final reader = await share.open(file.path);
        try {
          final size = reader.size;
          final range = parseRange(request.headers.value(HttpHeaders.rangeHeader), size);
          response.headers
            ..set(HttpHeaders.acceptRangesHeader, 'bytes')
            ..set(HttpHeaders.contentTypeHeader, contentTypeOf(file.path))
            ..set(HttpHeaders.etagHeader, size == file.size ? file.etag : '"$size"');
          if (range != null && range.$1 >= size) {
            response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
            response.contentLength = 0;
            return;
          }
          final (start, end) = range ?? (0, size);
          if (range != null) {
            response.statusCode = HttpStatus.partialContent;
            response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-${end - 1}/$size');
          }
          response.contentLength = end - start;
          if (request.method == 'HEAD' || end == start) return;
          // Each chunk goes out as it arrives, at the reader's pace.
          response.bufferOutput = false;
          // await for (not addStream): when the reader goes, the read-ahead
          // ends here, its last read's error included, before the file
          // closes; addStream would leave that error unhandled.
          await for (final chunk in readAhead(reader, start, end)) {
            response.add(chunk);
            await response.flush();
          }
        } finally {
          await reader.close();
        }
      });

  /// Tests, with the gateway in this isolate: how its shares are opened.
  @visibleForTesting
  static SmbOpener? openForTests;

  /// Windows of a file read ahead: 1 MiB each, 4 MiB once the reader has
  /// read on for a while, with two windows on their way.
  @visibleForTesting
  static Stream<Uint8List> readAhead(SmbReader reader, int start, int end,
      {int window = 1 << 20, int largest = 4 << 20, int ahead = 2}) async* {
    // The first bytes come at once: a header, or the join point.
    const first = 256 * 1024;
    var at = start;
    var asked = 0;
    final queue = <(Future<Uint8List>, int)>[];
    void ask() {
      while (at < end && queue.length <= ahead) {
        final size = asked == 0 ? first : (asked < 8 ? window : largest);
        final length = min(size, end - at);
        final read = reader.read(at, length);
        // An error is seen when its turn comes; meanwhile it's nobody's.
        read.ignore();
        queue.add((read, length));
        at += length;
        asked++;
      }
    }

    ask();
    while (queue.isNotEmpty) {
      final (read, length) = queue.removeAt(0);
      final data = await read;
      // Fewer bytes than promised: the file was cut short meanwhile.
      if (data.length < length) throw const SmbException(SmbErrorKind.gone, 'the file ended early');
      yield data;
      ask();
    }
  }

  /// `?cover=1`: the picture inside the file; otherwise the file itself.
  Future<void> _serveImage(HttpRequest request, _Target target, String name, String id, GatewayFile file) async {
    final response = request.response;
    if (request.uri.queryParameters['cover'] == '1') {
      final programs = _programs;
      final bytes = programs == null ? null : await programs.cover(_uri(name, 'b', id).toString());
      if (bytes == null || bytes.isEmpty) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      response.headers.set(HttpHeaders.contentTypeHeader, bytes[0] == 0x89 ? 'image/png' : 'image/jpeg');
      response.contentLength = bytes.length;
      if (request.method != 'HEAD') response.add(bytes);
      return;
    }
    await _serveFile(request, target.background, file);
  }

  /// `?format=` (srt, vtt, ass), `?start=` seconds, and `?track=` for a
  /// track inside the file. A subtitle file in the format asked, from the
  /// start, is served as it is.
  Future<void> _serveSubtitle(HttpRequest request, _Target target, String name, String id, GatewayFile file) async {
    final q = request.uri.queryParameters;
    final format = q['format'] ?? 'srt';
    final start = Duration(milliseconds: ((double.tryParse(q['start'] ?? '') ?? 0) * 1000).round());
    final track = int.tryParse(q['track'] ?? '');
    final own = file.path.split('.').last.toLowerCase();
    if (track == null && start == Duration.zero && (own == format || own == 'ssa' && format == 'ass')) {
      await _serveFile(request, target.background, file);
      return;
    }
    final text = await _programs?.subtitle(_uri(name, 'b', id).toString(), track: track, format: format, start: start);
    final response = request.response;
    if (text == null) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    response.headers.set(HttpHeaders.contentTypeHeader, format == 'vtt' ? 'text/vtt; charset=utf-8' : 'text/plain; charset=utf-8');
    response.contentLength = text.length;
    if (request.method != 'HEAD') response.add(text);
  }

  static String contentTypeOf(String path) => switch (path.split('.').last.toLowerCase()) {
        'mp4' || 'm4v' => 'video/mp4',
        'mov' => 'video/quicktime',
        'mkv' => 'video/x-matroska',
        'webm' => 'video/webm',
        'avi' => 'video/x-msvideo',
        'ts' || 'm2ts' || 'mts' => 'video/mp2t',
        'mpg' || 'mpeg' || 'vob' => 'video/mpeg',
        'wmv' || 'asf' => 'video/x-ms-asf',
        'flv' => 'video/x-flv',
        'ogv' => 'video/ogg',
        'mp3' => 'audio/mpeg',
        'm4a' || 'aac' => 'audio/mp4',
        'flac' => 'audio/flac',
        'ogg' || 'oga' || 'opus' => 'audio/ogg',
        'wav' => 'audio/wav',
        'wma' => 'audio/x-ms-wma',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'srt' => 'text/plain; charset=utf-8',
        'vtt' => 'text/vtt; charset=utf-8',
        _ => 'application/octet-stream',
      };
}
