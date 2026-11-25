import 'dart:typed_data';

import 'package:nightingale_tv/server/smb/smb_share.dart';

/// A share in memory: files by path, with the folders their paths make.
class FakeShare implements SmbShare {
  FakeShare(Map<String, int> sizes, {this.writable = true, this.smb1 = false, DateTime? created})
      : files = {for (final e in sizes.entries) e.key: Uint8List(e.value)},
        _created = created ?? DateTime.utc(2020);

  final Map<String, Uint8List> files;
  final bool writable;
  @override
  final bool smb1;
  final DateTime _created;
  bool closed = false;
  final writes = <String>[];

  /// The share is gone from the network.
  bool down = false;

  void _check() {
    if (down) throw const SmbException(SmbErrorKind.unreachable, 'down');
  }

  Set<String> get _folders => _index().keys.where((k) => k.isNotEmpty).toSet();

  /// Each folder's entries; made again when the files change.
  Map<String, Map<String, SmbEntry>> _index() {
    if (_indexed != null && _indexedCount == files.length) return _indexed!;
    final out = <String, Map<String, SmbEntry>>{'': {}};
    for (final p in files.keys) {
      final parts = p.split('/');
      for (var i = 0; i < parts.length; i++) {
        final parent = parts.sublist(0, i).join('/');
        final last = i == parts.length - 1;
        out.putIfAbsent(parent, () => {})[parts[i]] = SmbEntry(
            name: parts[i],
            isFolder: !last,
            size: last ? files[p]!.length : 0,
            modified: DateTime.utc(2024),
            created: _created);
        if (!last) out.putIfAbsent(parts.sublist(0, i + 1).join('/'), () => {});
      }
    }
    _indexedCount = files.length;
    return _indexed = out;
  }

  Map<String, Map<String, SmbEntry>>? _indexed;
  int _indexedCount = -1;

  @override
  Future<List<SmbEntry>> list(String path) async {
    _check();
    final entries = _index()[path];
    if (entries == null) throw const SmbException(SmbErrorKind.gone, 'no folder');
    return entries.values.toList();
  }

  @override
  Future<SmbEntry> stat(String path) async {
    _check();
    if (path.isEmpty || _folders.contains(path)) {
      return SmbEntry(name: path, isFolder: true, created: _created);
    }
    final f = files[path];
    if (f == null) throw const SmbException(SmbErrorKind.gone, 'no file');
    return SmbEntry(name: path.split('/').last, isFolder: false, size: f.length, modified: DateTime.utc(2024));
  }

  @override
  Future<SmbReader> open(String path) async {
    _check();
    final f = files[path];
    if (f == null) throw const SmbException(SmbErrorKind.gone, 'no file');
    return _Reader(f);
  }

  @override
  Future<void> write(String path, Uint8List data) async {
    _check();
    if (!writable) throw const SmbException(SmbErrorKind.noAccess, 'read-only');
    files[path] = data;
    _indexed = null;
    writes.add(path);
  }

  @override
  Future<void> rename(String from, String to) async {
    _check();
    if (!writable) throw const SmbException(SmbErrorKind.noAccess, 'read-only');
    files[to] = files.remove(from)!;
    _indexed = null;
    writes.add(to);
  }

  @override
  Future<void> makeFolder(String path) async {
    _check();
    if (!writable) throw const SmbException(SmbErrorKind.noAccess, 'read-only');
  }

  @override
  Future<void> delete(String path) async {
    _check();
    files.remove(path);
    _indexed = null;
  }

  @override
  Future<void> close() async => closed = true;
}

class _Reader implements SmbReader {
  _Reader(this._data);

  final Uint8List _data;

  @override
  int get size => _data.length;

  @override
  Future<Uint8List> read(int offset, int length) async =>
      Uint8List.sublistView(_data, offset.clamp(0, _data.length), (offset + length).clamp(0, _data.length));

  @override
  Future<void> close() async {}
}
