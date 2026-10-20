import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../platform/platform_info.dart';

/// Reads and writes the app's JSON state files and custom logos under
/// `~/.local/share/<app id>/`.
class AppStorage {
  AppStorage._(this.root, [Directory? logosDir, Directory? analysisDir])
      : logosDir = logosDir ?? Directory('${root.path}/logos'),
        analysisDir = analysisDir ?? Directory('${root.path}/analysis');

  final Directory root;

  /// Custom channel icons; shared by every profile.
  final Directory logosDir;

  /// Media analysis results, one file per Jellyfin server; shared by every
  /// profile.
  final Directory analysisDir;

  /// The app's data folder before it was renamed from Retro TV.
  static const legacyAppId = 'com.coffeehauslabs.retro_tv';

  static Future<AppStorage> open() async {
    final dir = await getApplicationSupportDirectory();
    await adoptLegacyData(Directory('${dir.parent.path}/$legacyAppId'), dir);
    final storage = AppStorage._(dir);
    await storage.logosDir.create(recursive: true);
    return storage;
  }

  /// Moves [legacy] (the data folder from before the rename) to [current],
  /// unless [current] already holds data. A rename, so nothing is copied or
  /// lost, and it only ever happens once.
  static Future<void> adoptLegacyData(Directory legacy, Directory current) async {
    if (!await legacy.exists()) return;
    if (await current.exists()) {
      if (!await current.list().isEmpty) return;
      await current.delete();
    }
    await legacy.rename(current.path);
  }

  /// Storage rooted at [dir] (a profile's folder, or a temp folder in
  /// tests), optionally keeping logos and analysis results somewhere else.
  static Future<AppStorage> at(Directory dir, {Directory? logosDir, Directory? analysisDir}) async {
    final storage = AppStorage._(dir, logosDir, analysisDir);
    await dir.create(recursive: true);
    await storage.logosDir.create(recursive: true);
    return storage;
  }

  /// Moves a state file from [from]'s folder into this one, if it exists.
  Future<void> adopt(AppStorage from, String name) async {
    final file = from._file(name);
    if (await file.exists()) await file.rename(_file(name).path);
  }

  File _file(String name) => File('${root.path}/$name');

  Future<Object?> readJson(String name) async {
    final file = _file(name);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      // A corrupt file is treated as missing rather than crashing startup.
      return null;
    }
  }

  /// The last write queued for each file.
  final _writes = <String, Future<void>>{};
  static var _tmpCounter = 0;

  /// Writes atomically (temp file + rename) so a crash mid-write never leaves
  /// a truncated state file behind. Writes to the same file happen one after
  /// another, in the order they were asked for.
  Future<void> writeJson(String name, Object? data, {bool private = false}) {
    final text = jsonEncode(data);
    final previous = _writes[name] ?? Future<void>.value();
    final write = previous.catchError((Object _) {}).then((_) => _write(name, text, private));
    _writes[name] = write;
    write.whenComplete(() {
      if (identical(_writes[name], write)) _writes.remove(name);
    }).ignore();
    return write;
  }

  Future<void> _write(String name, String text, bool private) async {
    final file = _file(name);
    final tmp = File('${file.path}.${pid}_${_tmpCounter++}.tmp');
    try {
      await tmp.writeAsString(text, flush: true);
      // On Android the app's folder is already private to the app.
      if (private && !PlatformInfo.isAndroid) {
        await Process.run('chmod', ['600', tmp.path]);
      }
      await tmp.rename(file.path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }
}
