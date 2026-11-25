import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What SMB shares need of Android (SmbPlatform.kt); never called elsewhere.
abstract final class SmbPlatform {
  static const _channel = MethodChannel('nightingale_tv/smb');

  /// Where the app's native libraries are, the only place Android runs
  /// programs from.
  static Future<String?> nativeLibraryDir() async {
    try {
      return await _channel.invokeMethod<String>('nativeLibraryDir');
    } on Object catch (e) {
      debugPrint('No native library folder: $e');
      return null;
    }
  }

  /// Encrypts with a key only the Android Keystore holds.
  static Future<Uint8List> encrypt(Uint8List data) async =>
      (await _channel.invokeMethod<Uint8List>('encrypt', data))!;

  static Future<Uint8List> decrypt(Uint8List data) async =>
      (await _channel.invokeMethod<Uint8List>('decrypt', data))!;

  /// Lets multicast answers through while looking for hosts.
  static Future<void> holdMulticast(bool hold) async {
    try {
      await _channel.invokeMethod<void>('holdMulticast', hold);
    } on Object catch (e) {
      debugPrint('Multicast lock: $e');
    }
  }

  /// The broadcast address of each network the device is on.
  static Future<List<String>> broadcastAddresses() async {
    try {
      return (await _channel.invokeListMethod<String>('broadcastAddresses')) ?? const [];
    } on Object catch (e) {
      debugPrint('Broadcast addresses: $e');
      return const [];
    }
  }
}
