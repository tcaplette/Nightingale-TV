import 'dart:io';
import 'dart:typed_data';

import '../playback/playback_diagnostics.dart';
import 'backup_archive.dart';

/// A backup kept in the store.
class StoredBackup {
  const StoredBackup({required this.file, required this.kind, required this.savedAt, required this.archive, required this.size});

  final File file;

  /// Why it's in the store ([BackupReason]): from its file name.
  final String kind;

  /// When it was saved here, from its file name.
  final DateTime savedAt;

  /// When it was made: [savedAt], or for a file opened or uploaded, when the
  /// backup inside it was made.
  DateTime get createdAt => archive.createdAt;

  /// Its header and content (read once, see [BackupStore.list]).
  final BackupArchive archive;
  final int size;

  String get name => file.uri.pathSegments.last;
  String get fingerprint => archive.fingerprint;
  BackupSummary get summary => archive.summary;

  bool get isSafety => BackupReason.isSafety(kind);

  /// "Automatic", "Before deleting Kids", "Made by you"…
  String get kindLabel => switch (kind) {
        BackupReason.daily => 'Automatic',
        BackupReason.beforeRestore => 'Before restore',
        BackupReason.beforeReset => 'Before reset',
        BackupReason.beforeDelete => archive.subject == null ? 'Before deleting a profile' : 'Before deleting ${archive.subject}',
        BackupReason.beforeUpgrade => 'Before update',
        BackupReason.beforeLineupCleanup => 'Before lineup cleanup',
        BackupReason.file => 'From a file',
        BackupReason.movingToOfficial => 'Moving to Nightingale TV',
        BackupReason.movingToOwnBuild => 'Moving to Nightingale TV (own build)',
        BackupReason.fromOfficial => 'From Nightingale TV',
        BackupReason.fromOwnBuild => 'From Nightingale TV (own build)',
        _ => 'Made by you',
      };
}

/// The `backups/` folder in the app's data folder (D10): backups named
/// `<UTC timestamp>_<reason>.ntvbackup`, written atomically, kept by kind,
/// and a copy of the newest in `cloud/` for Android's system backup.
class BackupStore {
  BackupStore(this.dir);

  final Directory dir;

  static const extension = '.ntvbackup';

  /// The 14 newest daily backups and the 10 newest safety backups are kept;
  /// backups made by the user, opened or uploaded are kept until deleted.
  static const keepDaily = 14;
  static const keepSafety = 10;

  /// Android's system backup copies only this folder (D13).
  Directory get cloudDir => Directory('${dir.path}/cloud');
  File get cloudCopy => File('${cloudDir.path}/latest$extension');

  static final _name = RegExp(r'^(\d{8}T\d{9})Z_([a-z-]+)\.ntvbackup$');

  /// Headers already read, by file name, size and time.
  final _cache = <String, StoredBackup>{};

  static String _stamp(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}${u.millisecond.toString().padLeft(3, '0')}Z';
  }

  static DateTime? _parseStamp(String s) {
    if (s.length != 18) return null;
    int at(int from, int to) => int.parse(s.substring(from, to));
    return DateTime.utc(at(0, 4), at(4, 6), at(6, 8), at(9, 11), at(11, 13), at(13, 15), at(15, 18));
  }

  /// Saves [bytes] (a backup file) as [kind], and returns it as listed.
  /// Older backups of its kind are pruned, and the cloud copy follows.
  Future<StoredBackup> save(Uint8List bytes, {required String kind, DateTime? at}) async {
    assert(BackupReason.all.contains(kind));
    final archive = BackupArchive.decode(bytes);
    await dir.create(recursive: true);
    var time = (at ?? DateTime.now()).toUtc();
    var file = File('${dir.path}/${_stamp(time)}_$kind$extension');
    while (await file.exists()) {
      time = time.add(const Duration(milliseconds: 1));
      file = File('${dir.path}/${_stamp(time)}_$kind$extension');
    }
    await _writeAtomically(file, bytes);
    final stored = StoredBackup(file: file, kind: kind, savedAt: time, archive: archive, size: bytes.length);
    _cache[_key(file.uri.pathSegments.last, bytes.length)] = stored;
    await prune();
    await _syncCloudCopy();
    return stored;
  }

  /// A temp file that isn't a `.ntvbackup`, then a rename: a crash mid-write
  /// never leaves a partial backup.
  static Future<void> _writeAtomically(File file, List<int> bytes) async {
    final tmp = File('${file.parent.path}/.${file.uri.pathSegments.last}.$pid.partial');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } on Object {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }

  static String _key(String name, int size) => '$name:$size';

  /// Every backup, newest first. A cloud copy that Android brought back
  /// (a reinstall or a new device) is added to the store first.
  Future<List<StoredBackup>> list() async {
    if (!await dir.exists()) return [];
    final found = <StoredBackup>[];
    final seen = <String>{};
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = f.uri.pathSegments.last;
      final m = _name.firstMatch(name);
      if (m == null) continue;
      final kind = m.group(2)!;
      final savedAt = _parseStamp(m.group(1)!);
      if (savedAt == null || !BackupReason.all.contains(kind)) continue;
      final size = await f.length();
      final key = _key(name, size);
      seen.add(key);
      var stored = _cache[key];
      if (stored == null) {
        try {
          final archive = BackupArchive.decode(await f.readAsBytes());
          stored = _cache[key] = StoredBackup(file: f, kind: kind, savedAt: savedAt, archive: archive, size: size);
        } on BackupException {
          continue; // Damaged: left alone, not listed.
        }
      }
      found.add(stored);
    }
    _cache.removeWhere((k, _) => !seen.contains(k));
    if (await _adoptCloudCopy(found) case final adopted?) found.add(adopted);
    return found..sort(_newestFirst);
  }

  /// By when each backup was made, as the list shows it.
  static int _newestFirst(StoredBackup a, StoredBackup b) {
    final made = b.createdAt.compareTo(a.createdAt);
    return made != 0 ? made : b.savedAt.compareTo(a.savedAt);
  }

  /// The newest backup of this device's own setup: not a file opened,
  /// uploaded or handed over, which may not be what's here.
  static StoredBackup? newestOwn(List<StoredBackup> list) =>
      list.where((b) => !BackupReason.isReceived(b.kind)).firstOrNull;

  /// The cloud copy, saved as a backup of its own when no backup in the
  /// store is the same one (Android restored only the copy).
  Future<StoredBackup?> _adoptCloudCopy(List<StoredBackup> listed) async {
    final copy = cloudCopy;
    if (!await copy.exists()) return null;
    try {
      final bytes = await copy.readAsBytes();
      final archive = BackupArchive.decode(bytes);
      final same = listed.any((b) => b.fingerprint == archive.fingerprint && b.createdAt == archive.createdAt);
      if (same) return null;
      final kind = BackupReason.all.contains(archive.reason) ? archive.reason : BackupReason.manual;
      final file = File('${dir.path}/${_stamp(archive.createdAt)}_$kind$extension');
      if (await file.exists()) return null;
      await _writeAtomically(file, bytes);
      PlaybackDiagnostics.note('BACKUP', 'adopted the cloud copy as ${file.uri.pathSegments.last}');
      return _cache[_key(file.uri.pathSegments.last, bytes.length)] =
          StoredBackup(file: file, kind: kind, savedAt: archive.createdAt.toUtc(), archive: archive, size: bytes.length);
    } on Object catch (e) {
      PlaybackDiagnostics.note('BACKUP', 'cloud copy unreadable: $e');
      return null;
    }
  }

  /// The newest backup, if there is one.
  Future<StoredBackup?> newest() async => (await list()).firstOrNull;

  /// [newestOwn] of the whole store.
  Future<StoredBackup?> newestOfThisSetup() async => newestOwn(await list());

  Future<Uint8List> read(StoredBackup b) => b.file.readAsBytes();

  Future<void> delete(StoredBackup b) async {
    if (await b.file.exists()) await b.file.delete();
    _cache.remove(_key(b.name, b.size));
    await _syncCloudCopy();
  }

  /// Keeps the newest [keepDaily] daily and [keepSafety] safety backups.
  Future<void> prune() async {
    final all = await list();
    final daily = all.where((b) => b.kind == BackupReason.daily).skip(keepDaily);
    final safety = all.where((b) => b.isSafety).skip(keepSafety);
    for (final b in [...daily, ...safety]) {
      PlaybackDiagnostics.note('BACKUP', 'pruned ${b.name}');
      await b.file.delete();
      _cache.remove(_key(b.name, b.size));
    }
  }

  /// `cloud/latest.ntvbackup` is a copy of the newest backup of this setup
  /// (none when there is none), rewritten atomically.
  Future<void> _syncCloudCopy() async {
    final newest = await _listOnly();
    final copy = cloudCopy;
    if (newest == null) {
      if (await copy.exists()) await copy.delete();
      return;
    }
    if (await copy.exists() && await copy.length() == newest.size) {
      final current = await copy.readAsBytes();
      final wanted = await newest.file.readAsBytes();
      if (_same(current, wanted)) return;
    }
    await cloudDir.create(recursive: true);
    await _writeAtomically(copy, await newest.file.readAsBytes());
  }

  /// The newest backup of this setup ([newestOwn]) without adopting the
  /// cloud copy (which is being rewritten).
  Future<StoredBackup?> _listOnly() async {
    if (!await dir.exists()) return null;
    StoredBackup? best;
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final m = _name.firstMatch(f.uri.pathSegments.last);
      final savedAt = m == null ? null : _parseStamp(m.group(1)!);
      if (savedAt == null || !BackupReason.all.contains(m!.group(2)) || BackupReason.isReceived(m.group(2)!)) continue;
      final size = await f.length();
      var stored = _cache[_key(f.uri.pathSegments.last, size)];
      if (stored == null) {
        try {
          final archive = BackupArchive.decode(await f.readAsBytes());
          stored = _cache[_key(f.uri.pathSegments.last, size)] =
              StoredBackup(file: f, kind: m.group(2)!, savedAt: savedAt, archive: archive, size: size);
        } on BackupException {
          continue;
        }
      }
      if (best == null || _newestFirst(stored, best) < 0) best = stored;
    }
    return best;
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
