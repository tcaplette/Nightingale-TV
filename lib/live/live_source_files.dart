import 'dart:io';

import '../data/app_storage.dart';
import 'live_source.dart';

// Live TV sources' storage, apart from the models so the web admin can use
// those (docker-web-admin design D2): only device and server code imports
// this.

/// A profile's Live TV sources, in `live_sources.json` under the profile's
/// folder; playlists and guides picked from files live in [filesDir].
class LiveSourceStore {
  LiveSourceStore(this.storage);

  final AppStorage storage;

  static const fileName = 'live_sources.json';

  /// Where picked playlist and guide files are copied (they're backed up).
  static const filesFolder = 'live_files';

  Directory get filesDir => Directory('${storage.root.path}/$filesFolder');

  File fileFor(String name) => File('${filesDir.path}/$name');

  Future<List<LiveSource>> load() async {
    final json = await storage.readJson(fileName);
    final list = json is Map<String, Object?> ? json['sources'] : null;
    if (list is! List) return [];
    final sources = <LiveSource>[];
    for (final s in list.whereType<Map<String, Object?>>()) {
      try {
        sources.add(LiveSource.fromJson(s));
      } on Object {
        // One unreadable source doesn't take the others with it.
      }
    }
    return sources;
  }

  Future<void> save(List<LiveSource> sources) =>
      storage.writeJson(fileName, {'sources': [for (final s in sources) s.toJson()]}, private: true);

  /// Copies a picked file into [filesDir] as [sourceId]'s [role] file
  /// (`playlist` or `guide`), keeping its extension; returns the name saved.
  Future<String> copyIn(File picked, String sourceId, String role) async {
    await filesDir.create(recursive: true);
    final ext = RegExp(r'\.[A-Za-z0-9]{1,5}(\.gz)?$').firstMatch(picked.path)?[0] ?? '';
    final name = '$sourceId-$role$ext';
    final tmp = fileFor('$name.tmp');
    await picked.copy(tmp.path);
    await tmp.rename(fileFor(name).path);
    return name;
  }

  /// Saves [bytes] (a file picked on the device) as [sourceId]'s [role]
  /// file with [extension] ("m3u", "xml.gz"); returns the name saved.
  Future<String> saveBytes(List<int> bytes, String sourceId, String role, String extension) async {
    await filesDir.create(recursive: true);
    final ext = extension.isEmpty ? '' : '.${extension.replaceFirst(RegExp(r'^\.'), '')}';
    final name = '$sourceId-$role$ext';
    final tmp = fileFor('$name.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(fileFor(name).path);
    return name;
  }

  /// Copies picked file [f] in as [sourceId]'s [role] file; returns the
  /// name saved.
  Future<String> savePicked(PickedLiveFile f, String sourceId, String role) async {
    final path = f.path;
    if (path != null && await File(path).exists()) {
      await filesDir.create(recursive: true);
      final ext = pickedExtension(f);
      final name = '$sourceId-$role${ext.isEmpty ? '' : '.$ext'}';
      final tmp = fileFor('$name.tmp');
      await File(path).copy(tmp.path);
      await tmp.rename(fileFor(name).path);
      return name;
    }
    return saveBytes(f.bytes ?? const [], sourceId, role, pickedExtension(f));
  }

  /// Deletes [source]'s copied files.
  Future<void> deleteFiles(LiveSource source) async {
    for (final name in [source.playlistFile, source.guideFile]) {
      if (name == null) continue;
      final f = fileFor(name);
      if (await f.exists()) await f.delete();
    }
  }
}

/// A playlist or guide the user picked from the device: its name, and the
/// file to copy ([path]) or, where there's no path, its [bytes].
typedef PickedLiveFile = ({String name, String? path, List<int>? bytes});

/// [f]'s extension, as copies keep it ("m3u", "xml.gz").
String pickedExtension(PickedLiveFile f) =>
    RegExp(r'\.([A-Za-z0-9]{1,5}(\.gz)?)$').firstMatch(f.name)?[1]?.toLowerCase() ?? '';
