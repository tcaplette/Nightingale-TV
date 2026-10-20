import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;

class CustomIconException implements Exception {
  CustomIconException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// User-uploaded channel logos, stored in the app's logos folder.
class CustomIconStore {
  CustomIconStore(this.dir);

  final Directory dir;

  static const maxSourceBytes = 20 * 1024 * 1024;
  static const _maxPixels = 512;
  static const _extensions = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'];

  File fileFor(String name) => File('${dir.path}/$name');

  Future<List<String>> list() async {
    if (!await dir.exists()) return [];
    final names = <(DateTime, String)>[];
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.png') || name.endsWith('.svg')) {
        names.add((await f.lastModified(), name));
      }
    }
    names.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final n in names) n.$2];
  }

  /// Opens the system file dialog. Returns the stored file name, or null if
  /// the user cancelled.
  Future<String?> pickAndImport() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Images', extensions: _extensions),
    ]);
    if (file == null) return null;
    return import(File(file.path));
  }

  /// Raster images are scaled to fit 512×512 and re-encoded as PNG, so the
  /// guide never decodes a huge photo. SVGs are kept as-is. Content-addressed
  /// names make re-uploading the same image a no-op.
  Future<String> import(File source) async => importBytes(await source.readAsBytes(), source.path);

  /// [import] for an image already read, named [fileName] (for its type).
  Future<String> importBytes(Uint8List bytes, String fileName) async {
    if (bytes.length > maxSourceBytes) {
      throw CustomIconException('That image is over 20 MB. Please pick a smaller one.');
    }
    final hash = sha1.convert(bytes).toString().substring(0, 16);
    final ext = fileName.split('.').last.toLowerCase();

    if (ext == 'svg') {
      final head = String.fromCharCodes(bytes.take(2048));
      if (!head.contains('<svg')) throw CustomIconException('That file is not a valid SVG.');
      final name = '$hash.svg';
      await fileFor(name).writeAsBytes(bytes, flush: true);
      return name;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw CustomIconException('Could not read that image. Try PNG, JPG, WebP or SVG.');
    }
    final frame = decoded.frames.first;
    final scaled = frame.width > _maxPixels || frame.height > _maxPixels
        ? img.copyResize(frame,
            width: frame.width >= frame.height ? _maxPixels : null,
            height: frame.height > frame.width ? _maxPixels : null,
            interpolation: img.Interpolation.average)
        : frame;
    final name = '$hash.png';
    await fileFor(name).writeAsBytes(img.encodePng(scaled), flush: true);
    return name;
  }

  Future<void> delete(String name) async {
    final f = fileFor(name);
    if (await f.exists()) await f.delete();
  }
}
