import 'dart:io';

/// The web admin's files (docker-web-admin design D3), served by the setup
/// server from [dir]: `NTV_WEB_DIR`, else `web/` next to the executable.
///
/// A path that isn't a file gets `index.html`, so links to any page and
/// reloads work. Without a bundle, pages say how to build one.
class WebFiles {
  WebFiles(this.dir);

  /// `NTV_WEB_DIR`, else the bundle's `web/`.
  factory WebFiles.fromEnvironment(Map<String, String> env) {
    final configured = env['NTV_WEB_DIR']?.trim();
    return WebFiles(Directory(configured != null && configured.isNotEmpty
        ? configured
        : '${File(Platform.resolvedExecutable).parent.path}/web'));
  }

  final Directory dir;

  static const missingText = "The web admin isn't in this build. Build it with tool/build_web_admin.sh.";

  /// Only the setup server's own origin; WebAssembly for CanvasKit; blob:
  /// to read files picked in the browser (uploads).
  static const contentSecurityPolicy = "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
      "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' blob:; frame-ancestors 'none'";

  /// Files a new build changes without changing their names.
  static const _noCache = {'index.html', 'flutter_bootstrap.js'};

  static const _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json',
    'wasm': 'application/wasm',
    'png': 'image/png',
    'ico': 'image/x-icon',
    'svg': 'image/svg+xml',
    'otf': 'font/otf',
    'ttf': 'font/ttf',
    'woff2': 'font/woff2',
    'css': 'text/css; charset=utf-8',
    'txt': 'text/plain; charset=utf-8',
  };

  /// Answers a GET or HEAD for page path [path].
  Future<void> serve(HttpRequest request, String path) async {
    final response = request.response;
    final headers = response.headers
      ..set('Content-Security-Policy', contentSecurityPolicy)
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
    final index = File('${dir.path}/index.html');
    if (!await index.exists()) {
      headers
        ..contentType = ContentType.html
        ..set('Cache-Control', 'no-cache');
      if (_isAsset(path)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      response.write('<!DOCTYPE html><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
          '<title>Nightingale TV</title><p style="font-family:sans-serif;margin:2em">$missingText</p>');
      return;
    }
    var file = _fileFor(path) ?? index;
    if (file.path != index.path && !await file.exists()) {
      // A missing file isn't a page: no index.html for a script or picture.
      if (_isAsset(path)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      file = index;
    }
    final name = file.uri.pathSegments.last;
    final stat = await file.stat();
    headers.set(HttpHeaders.contentTypeHeader, _types[_extension(name)] ?? 'application/octet-stream');
    if (_noCache.contains(name) && file.parent.path == dir.path) {
      headers.set('Cache-Control', 'no-cache');
    } else {
      final etag = '"${stat.size.toRadixString(16)}-${stat.modified.microsecondsSinceEpoch.toRadixString(16)}"';
      headers
        ..set('Cache-Control', 'no-cache')
        ..set(HttpHeaders.etagHeader, etag);
      if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
        response.statusCode = HttpStatus.notModified;
        return;
      }
    }
    headers.contentLength = stat.size;
    if (request.method == 'HEAD') return;
    await response.addStream(file.openRead());
  }

  /// The file [path] names inside [dir], or null for the root or a path
  /// that would leave it.
  File? _fileFor(String path) {
    final segments = Uri.parse(path).pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    if (segments.any((s) => s == '..' || s == '.' || s.contains('\\') || s.startsWith('.'))) return null;
    return File('${dir.path}/${segments.join('/')}');
  }

  /// Whether [path] names one of the bundle's files rather than a page (page
  /// paths can hold dots: `live:src1:2.1`).
  static bool _isAsset(String path) {
    final ext = _extension(path);
    return ext != null && ext != 'html' && (_types.containsKey(ext) || const {'bin', 'symbols', 'map', 'frag'}.contains(ext));
  }

  /// The extension of [path]'s last segment, if it has one.
  static String? _extension(String path) {
    final last = path.split('/').last;
    final dot = last.lastIndexOf('.');
    return dot <= 0 ? null : last.substring(dot + 1).toLowerCase();
  }
}
