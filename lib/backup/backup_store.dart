import 'dart:io';
import 'dart:typed_data';

import '../playback/playback_diagnostics.dart';
import 'backup_archive.dart';
import 'undo_label.dart' as undo_label;

/// One of the two backups the store keeps: the automatic backup or the
/// undo point.
class StoredBackup {
  const StoredBackup({required this.file, required this.archive, required this.size});

  final File file;

  /// Its header and content.
  final BackupArchive archive;
  final int size;

  /// When it was made.
  DateTime get createdAt => archive.createdAt;

  /// Why it was made ([BackupReason]), from its header.
  String get reason => archive.reason;

  String get fingerprint => archive.fingerprint;
  BackupSummary get summary => archive.summary;

  /// The undo point's button: "Undo lineup reset", "Undo deleting Kids"…
  String get undoLabel => undo_label.undoLabel(reason, archive.subject);
}

/// The `backups/` folder in the app's data folder (backup-simplify D1):
/// two fixed files, each written atomically.
/// - `cloud/latest.ntvbackup`, the automatic backup. It is the folder
///   Android's system backup copies, so it is also the cloud copy.
/// - `undo.ntvbackup`, the undo point, which Android never copies.
class BackupStore {
  BackupStore(this.dir);

  final Directory dir;

  static const extension = '.ntvbackup';

  /// Android's system backup copies only this folder.
  Directory get cloudDir => Directory('${dir.path}/cloud');
  File get latestFile => File('${cloudDir.path}/latest$extension');
  File get undoFile => File('${dir.path}/undo$extension');

  /// Headers already read, by path, size and time written.
  final _cache = <String, StoredBackup>{};

  /// The automatic backup, if there is one that reads.
  Future<StoredBackup?> latest() => _load(latestFile);

  /// The undo point, if there is one that reads.
  Future<StoredBackup?> undo() => _load(undoFile);

  Future<StoredBackup?> _load(File f) async {
    final FileStat stat;
    try {
      stat = await f.stat();
    } on FileSystemException {
      return null;
    }
    if (stat.type != FileSystemEntityType.file) return null;
    final key = '${f.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    if (_cache[key] case final cached?) return cached;
    try {
      final archive = BackupArchive.decode(await f.readAsBytes());
      _cache.removeWhere((k, _) => k.startsWith('${f.path}:'));
      return _cache[key] = StoredBackup(file: f, archive: archive, size: stat.size);
    } on BackupException {
      return null; // Damaged: as if there were none; the next write replaces it.
    } on FileSystemException {
      return null;
    }
  }

  /// Writes [bytes] as the automatic backup, replacing the one there.
  Future<StoredBackup> writeLatest(Uint8List bytes) => _write(latestFile, bytes);

  /// Writes [bytes] as the undo point, replacing the one there.
  Future<StoredBackup> writeUndo(Uint8List bytes) => _write(undoFile, bytes);

  Future<StoredBackup> _write(File f, Uint8List bytes) async {
    final archive = BackupArchive.decode(bytes);
    await f.parent.create(recursive: true);
    await _writeAtomically(f, bytes);
    final stat = await f.stat();
    _cache.removeWhere((k, _) => k.startsWith('${f.path}:'));
    return _cache['${f.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}'] =
        StoredBackup(file: f, archive: archive, size: bytes.length);
  }

  Future<Uint8List> read(StoredBackup b) => b.file.readAsBytes();

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

  // ---- Clearing out older versions' backups (D10) -----------------------------

  /// The names older versions gave their backups: `<UTC stamp>_<reason>`.
  static final _oldName = RegExp(r'^(\d{8}T\d{9})Z_([a-z-]+)\.ntvbackup$');

  /// An old safety backup becomes the undo point only this recent.
  static const undoFrom = Duration(days: 7);

  /// Clears out the dated backups older versions kept, once: the newest of
  /// this device's own becomes the automatic backup when it's newer (or
  /// there's none), the newest safety backup of the last [undoFrom] becomes
  /// the undo point, and every other old file and leftover temp file goes.
  /// Does nothing when there's nothing old.
  Future<void> clearOldBackups({DateTime? now}) async {
    if (!await dir.exists()) return;
    final old = <({File file, String reason, DateTime savedAt})>[];
    final partial = <File>[];
    for (final d in [dir, cloudDir]) {
      if (!await d.exists()) continue;
      await for (final f in d.list()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.last;
        if (name.startsWith('.') && name.endsWith('.partial')) {
          // One of ours being written by another process would have this
          // pid; anything else is left over from a crash.
          if (!name.endsWith('.$pid.partial')) partial.add(f);
          continue;
        }
        if (d.path != dir.path) continue;
        final m = _oldName.firstMatch(name);
        final savedAt = m == null ? null : _parseStamp(m.group(1)!);
        if (savedAt != null) old.add((file: f, reason: m!.group(2)!, savedAt: savedAt));
      }
    }
    if (old.isEmpty && partial.isEmpty) return;
    old.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final kept = <String>[];
    // This device's own setup: not opened from a file or handed over.
    final own = old.where((b) => b.reason != 'file' && !b.reason.startsWith('from-'));
    final current = await latest();
    for (final b in own) {
      final archive = _decodeOr(await b.file.readAsBytes());
      if (archive == null) continue;
      if (current == null || archive.createdAt.isAfter(current.createdAt)) {
        await writeLatest(await b.file.readAsBytes());
        kept.add('latest');
      }
      break;
    }
    final since = (now ?? DateTime.now()).toUtc().subtract(undoFrom);
    for (final b in old.where((b) => BackupReason.isSafety(b.reason))) {
      if (b.savedAt.isBefore(since)) break;
      final bytes = await b.file.readAsBytes();
      if (_decodeOr(bytes) == null) continue;
      await writeUndo(bytes);
      kept.add('undo');
      break;
    }
    for (final f in [...old.map((b) => b.file), ...partial]) {
      try {
        await f.delete();
      } on FileSystemException {
        // Gone already.
      }
    }
    PlaybackDiagnostics.note('BACKUP',
        'migrated: kept ${kept.isEmpty ? 'nothing' : kept.join(', ')}, removed ${old.length + partial.length - kept.length}');
  }

  static BackupArchive? _decodeOr(Uint8List bytes) {
    try {
      return BackupArchive.decode(bytes);
    } on BackupException {
      return null;
    }
  }

  static DateTime? _parseStamp(String s) {
    if (s.length != 18) return null;
    int at(int from, int to) => int.parse(s.substring(from, to));
    return DateTime.utc(at(0, 4), at(4, 6), at(6, 8), at(9, 11), at(11, 13), at(13, 15), at(15, 18));
  }
}
