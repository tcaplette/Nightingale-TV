import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../data/app_storage.dart';
import 'smb_library.dart';
import 'smb_share.dart';

/// One title's history on one device.
class HistoryEntry {
  const HistoryEntry({this.plays = 0, this.last = 0, this.resume = 0, this.resumeAt = 0});

  final int plays;

  /// When it was last played, in milliseconds since the epoch.
  final int last;

  /// Where it resumes, in milliseconds, and when that was saved.
  final int resume;
  final int resumeAt;

  List<int> toJson() => [plays, last, resume, resumeAt];

  static HistoryEntry? fromJson(Object? j) => switch (j) {
        [final int plays, final int last, final int resume, final int resumeAt] =>
          HistoryEntry(plays: plays, last: last, resume: resume, resumeAt: resumeAt),
        _ => null,
      };
}

/// Where a share's history is kept.
enum HistoryPlace {
  /// On the share, shared with every device using its history name.
  share,

  /// On this device, by choice.
  device,

  /// On this device: the share can't be written to.
  readOnly,
}

/// A share's watched history (smb-history, design D11). It is saved on the
/// device first, in `smb_history/<share>.json`; on a writable share each
/// device also keeps its own file in `.nightingale/history/<history id>/`,
/// and every device's files together are the history.
class SmbHistory {
  SmbHistory(this._storage, {required this.serverId, required this.deviceFileId});

  final AppStorage _storage;
  final String serverId;

  /// This profile's own file name on shares: random, never the device id.
  final String deviceFileId;

  /// A viewing is written to the share at most this often while it goes on.
  static const writeEvery = Duration(minutes: 1);

  String get _local => 'smb_history/${smbIdOf(serverId)}.json';

  /// This profile's own entries, by title key.
  final _mine = <String, HistoryEntry>{};

  /// Other devices' entries as last read, by title key.
  var _others = <String, HistoryEntry>{};

  /// What isn't on the share yet.
  bool _unsent = false;
  DateTime _sentAt = DateTime(0);
  bool _loaded = false;

  HistoryPlace place = HistoryPlace.share;

  /// Where the history last went; null before it was tried.
  final placeShown = ValueNotifier<HistoryPlace?>(null);

  static String historyId(String name) => sha256.convert(utf8.encode(name.trim().toLowerCase())).toString().substring(0, 16);

  static String folderFor(String historyName) => '.nightingale/history/${historyId(historyName)}';

  /// A title's key: the same title in another file is the same history.
  static String keyOf(SmbItem item, {String? showName}) => switch (item.type) {
        SmbFolderType.tvShows when showName != null && item.season != null && item.episode != null =>
          'e|${showName.toLowerCase()}|${item.season}|${item.episode}',
        SmbFolderType.movies => 'm|${item.title.toLowerCase()}|${item.year ?? ''}',
        _ => item.id,
      };

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final json = await _storage.readJson(_local);
    if (json is Map<String, Object?>) {
      for (final e in (json['mine'] as Map? ?? const {}).cast<String, Object?>().entries) {
        if (HistoryEntry.fromJson(e.value) case final h?) _mine[e.key] = h;
      }
      for (final e in (json['others'] as Map? ?? const {}).cast<String, Object?>().entries) {
        if (HistoryEntry.fromJson(e.value) case final h?) _others[e.key] = h;
      }
      _unsent = json['unsent'] == true;
    }
  }

  Future<void> _saveLocal() => _storage.writeJson(_local, {
        'mine': {for (final e in _mine.entries) e.key: e.value.toJson()},
        'others': {for (final e in _others.entries) e.key: e.value.toJson()},
        if (_unsent) 'unsent': true,
      });

  /// Every device's plays added together.
  int playsOf(String key) => (_mine[key]?.plays ?? 0) + (_others[key]?.plays ?? 0);

  /// The newest resume point of any device.
  Duration resumeOf(String key) {
    final a = _mine[key], b = _others[key];
    final newest = a == null ? b : b == null || a.resumeAt >= b.resumeAt ? a : b;
    return Duration(milliseconds: newest?.resume ?? 0);
  }

  /// A viewing ended at [position] of [runtime] (as the tuner reports it:
  /// the end when watched, else the resume point to keep).
  Future<void> record(String key, Duration position, Duration runtime, {DateTime? now}) async {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final before = _mine[key] ?? const HistoryEntry();
    final watched = position.inMilliseconds >= runtime.inMilliseconds * 0.9;
    _mine[key] = HistoryEntry(
      plays: before.plays + (watched ? 1 : 0),
      last: watched ? at : before.last,
      resume: watched ? 0 : position.inMilliseconds,
      resumeAt: at,
    );
    _unsent = true;
    await _saveLocal();
  }

  /// Whether the share should be written now: something is new, and
  /// (unless [now]) the last write was over a minute ago.
  bool due({bool now = false}) => _unsent && (now || DateTime.now().difference(_sentAt) >= writeEvery);

  /// Writes this profile's file to the share (temporary name, then a
  /// rename), and reads the other devices' files. A read-only share, or
  /// [keepLocal], keeps it on the device.
  Future<void> sync(SmbShare share, {required String historyName, required bool keepLocal}) async {
    if (keepLocal) {
      _place(HistoryPlace.device);
      return;
    }
    final folder = folderFor(historyName);
    if (_unsent) {
      final data = Uint8List.fromList(utf8.encode(jsonEncode({
        'version': 1,
        'entries': {for (final e in _mine.entries) e.key: e.value.toJson()},
      })));
      final tmp = '$folder/$deviceFileId.${Random().nextInt(1 << 30).toRadixString(36)}.tmp';
      try {
        await share.makeFolder(folder);
        await share.write(tmp, data);
        await share.rename(tmp, '$folder/$deviceFileId.json');
        _unsent = false;
        _sentAt = DateTime.now();
        _place(HistoryPlace.share);
      } on SmbException catch (e) {
        if (e.kind == SmbErrorKind.noAccess || e.kind == SmbErrorKind.other) {
          _place(HistoryPlace.readOnly);
          // Nothing will change by trying again on a read-only share.
          _unsent = false;
        } else {
          rethrow;
        }
      }
    }
    await _readOthers(share, folder);
    await _saveLocal();
  }

  void _place(HistoryPlace p) {
    place = p;
    placeShown.value = p;
  }

  Future<void> _readOthers(SmbShare share, String folder) async {
    final List<SmbEntry> files;
    try {
      files = await share.list(folder);
    } on SmbException catch (e) {
      if (e.kind == SmbErrorKind.gone) {
        _others = {};
        return;
      }
      rethrow;
    }
    final merged = <String, HistoryEntry>{};
    for (final f in files) {
      if (f.isFolder || !f.name.endsWith('.json') || f.name == '$deviceFileId.json' || f.size > 8 << 20) continue;
      try {
        final json = jsonDecode(utf8.decode(await share.readAll('$folder/${f.name}')));
        for (final e in ((json as Map)['entries'] as Map).cast<String, Object?>().entries) {
          final h = HistoryEntry.fromJson(e.value);
          if (h == null) continue;
          final known = merged[e.key];
          merged[e.key] = known == null
              ? h
              : HistoryEntry(
                  plays: known.plays + h.plays,
                  last: max(known.last, h.last),
                  resume: h.resumeAt > known.resumeAt ? h.resume : known.resume,
                  resumeAt: max(known.resumeAt, h.resumeAt));
        }
      } on Object {
        // One device's unreadable file doesn't stop the rest.
      }
    }
    _others = merged;
  }

  /// What a backup keeps of it: this profile's own entries.
  Map<String, Object?> backupJson() => {for (final e in _mine.entries) e.key: e.value.toJson()};

  Future<void> restore(Map<String, Object?> json) async {
    for (final e in json.entries) {
      if (HistoryEntry.fromJson(e.value) case final h?) _mine[e.key] = h;
    }
    _unsent = _mine.isNotEmpty;
    await _saveLocal();
  }

  Future<void> deleteLocal() => _storage.delete(_local);
}
