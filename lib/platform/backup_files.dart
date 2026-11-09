import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_info.dart';
import '../l10n/tr.dart';

/// Saving and opening backup files through the system's own dialogs
/// (backup-restore D12): the file dialog on Linux and Windows, the document
/// picker on Android phones and tablets. Most Android TVs have neither, and
/// there [available] is false.
abstract final class BackupFiles {
  static const _channel = MethodChannel('nightingale_tv/files');

  static List<XTypeGroup> get _types => [XTypeGroup(label: tr.nightingaleTvBackups, extensions: const ['ntvbackup'])];

  /// Pretends the device has (or hasn't) a file picker, in tests.
  @visibleForTesting
  static bool? debugAvailable;

  /// Whether Save to file and Open a backup file can be offered.
  static Future<bool> available() async {
    if (debugAvailable case final on?) return on;
    if (PlatformInfo.isDesktop) return true;
    if (!PlatformInfo.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canPickDocuments') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Saves [bytes] as [name] where the user picks. False if they cancelled.
  static Future<bool> save(String name, Uint8List bytes) async {
    if (PlatformInfo.isAndroid) {
      return await _channel.invokeMethod<bool>('saveDocument', {'name': name, 'bytes': bytes}) ?? false;
    }
    final location = await getSaveLocation(suggestedName: name, acceptedTypeGroups: _types);
    if (location == null) return false;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.ntvbackup')) path = '$path.ntvbackup';
    await File(path).writeAsBytes(bytes, flush: true);
    return true;
  }

  /// A backup file the user picks, at most [limit] bytes (more is returned
  /// as [limit] + 1 bytes, so the caller can say it's too big); null if
  /// they cancelled.
  static Future<Uint8List?> open({required int limit}) async {
    // Android's picker knows files by type, and .ntvbackup has none: any
    // file, checked once read.
    final file = await openFile(acceptedTypeGroups: PlatformInfo.isAndroid ? const [] : _types);
    if (file == null) return null;
    if (await file.length() > limit) return Uint8List(limit + 1);
    return file.readAsBytes();
  }
}
