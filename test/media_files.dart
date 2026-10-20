import 'dart:io';
import 'dart:typed_data';

/// Short test videos made with ffmpeg once, then kept in the system temp
/// folder: an MP4 with its index (`moov`) at the end, the same written for
/// streaming (index first), and a Matroska copy.
Future<({File mp4, File faststart, File mkv})> testVideos() async {
  final dir = Directory('${Directory.systemTemp.path}/nightingale_tv_index_media_v1');
  await dir.create(recursive: true);
  final mp4 = File('${dir.path}/index-at-end.mp4');
  final faststart = File('${dir.path}/faststart.mp4');
  final mkv = File('${dir.path}/movie.mkv');
  Future<void> ffmpeg(List<String> args, File out) async {
    if (out.existsSync()) return;
    final part = '${out.path}.part${out.path.substring(out.path.lastIndexOf('.'))}';
    final r = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args, part]);
    if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
    await File(part).rename(out.path);
  }

  await ffmpeg([
    '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24',
    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
    '-t', '60',
    '-c:v', 'libx264', '-preset', 'ultrafast', '-b:v', '400k', '-g', '48',
    '-c:a', 'aac', '-b:a', '64k',
  ], mp4);
  await ffmpeg(['-i', mp4.path, '-c', 'copy', '-movflags', '+faststart'], faststart);
  await ffmpeg(['-i', mp4.path, '-c', 'copy'], mkv);
  return (mp4: mp4, faststart: faststart, mkv: mkv);
}

/// A server like Jellyfin's static stream: serves [files] by name at
/// `/Videos/<name>/stream` with Range support, and `/System/Ping`. It counts
/// connections and requests.
class FakeStreamServer {
  FakeStreamServer._(this._server, this.files);

  final HttpServer _server;
  final Map<String, Uint8List> files;

  /// Each request: (path, Range header, the client's port).
  final requests = <({String path, String? range, int port})>[];

  /// Answers with this status instead (when set).
  int? failWith;

  /// Extra response headers for every file.
  final extraHeaders = <String, String>{};

  int get connections => {for (final r in requests) r.port}.length;
  List<({String path, String? range, int port})> get streamRequests =>
      requests.where((r) => r.path != '/System/Ping').toList();

  String get url => 'http://127.0.0.1:${_server.port}';
  Uri streamUri(String name) => Uri.parse('$url/Videos/$name/stream?static=true');

  static Future<FakeStreamServer> start(Map<String, Uint8List> files) async {
    final s = FakeStreamServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), files);
    s._server.listen(s._handle);
    return s;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    requests.add((path: request.uri.path, range: range, port: request.connectionInfo!.remotePort));
    try {
      if (request.uri.path == '/System/Ping') {
        response.write('Jellyfin Server');
        return;
      }
      final segments = request.uri.pathSegments;
      final data = segments.length == 3 ? files[segments[1]] : null;
      if (failWith case final status?) {
        response.statusCode = status;
        return;
      }
      if (data == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      var from = 0;
      var to = data.length - 1;
      final m = range == null ? null : RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (m != null) {
        from = int.parse(m.group(1)!);
        if (m.group(2)!.isNotEmpty) to = int.parse(m.group(2)!).clamp(0, data.length - 1);
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $from-$to/${data.length}');
      }
      response.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, segments[1].endsWith('.mkv') ? 'video/x-matroska' : 'video/mp4')
        ..contentLength = to - from + 1;
      extraHeaders.forEach(response.headers.set);
      for (var p = from; p <= to; p += 64 * 1024) {
        response.add(Uint8List.sublistView(data, p, (p + 64 * 1024).clamp(0, to + 1)));
        await response.flush();
      }
    } on Object {
      // The client left mid-response (a seek).
    } finally {
      try {
        await response.close();
      } on Object {
        // Gone.
      }
    }
  }

  Future<void> close() => _server.close(force: true);
}
