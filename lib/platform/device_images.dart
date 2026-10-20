import 'package:flutter/services.dart';

/// A picture on the device (from MediaStore).
class DeviceImage {
  const DeviceImage({required this.uri, required this.name, this.folder});

  final String uri;
  final String name;

  /// The folder it's in ("Download", "Pictures", a USB drive's folder…).
  final String? folder;
}

/// Thrown when Android won't let the app read pictures.
class DeviceImagesDenied implements Exception {}

/// The device's pictures, through MediaStore (android/…/DeviceImages.kt).
/// Android TVs have no document picker for the system file dialog, so a
/// custom channel icon is picked from these in the app instead.
abstract final class DeviceImages {
  static const _channel = MethodChannel('nightingale_tv/images');

  /// Whether Android has a real document picker (phones). TVs answer with a
  /// stub that closes at once.
  static Future<bool> hasDocumentPicker() async {
    try {
      return await _channel.invokeMethod<bool>('hasDocumentPicker') ?? false;
    } on MissingPluginException {
      return true; // Not the Android app (tests): the file dialog as elsewhere.
    }
  }

  /// Newest first. Asks for permission to read pictures the first time.
  static Future<List<DeviceImage>> list() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('list') ?? const [];
      return [
        for (final r in rows)
          DeviceImage(uri: r['uri']! as String, name: r['name'] as String? ?? '', folder: r['folder'] as String?),
      ];
    } on PlatformException catch (e) {
      if (e.code == 'denied') throw DeviceImagesDenied();
      rethrow;
    }
  }

  /// A small PNG of [image], for the grid.
  static Future<Uint8List?> thumbnail(DeviceImage image) =>
      _channel.invokeMethod<Uint8List>('thumbnail', {'uri': image.uri});

  /// [image]'s bytes, at most [limit] + 1 of them.
  static Future<Uint8List> read(DeviceImage image, {required int limit}) async =>
      await _channel.invokeMethod<Uint8List>('read', {'uri': image.uri, 'limit': limit}) ?? Uint8List(0);
}
