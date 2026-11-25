import 'dart:async';
import 'dart:typed_data';

import 'smb1_client.dart';
import 'smb_share.dart';

/// A share over SMB1, for hosts that speak nothing newer. A dropped
/// connection is made again for the next request.
class Smb1Share implements SmbShare {
  Smb1Share._(this._address, this._credentials, this._client, this._tree);

  final SmbAddress _address;
  final SmbCredentials _credentials;
  Smb1Client _client;
  int _tree;
  Future<void>? _reconnecting;
  bool _closed = false;

  /// Connects; throws [SmbSpeaksNewer] when the host speaks SMB 2 or 3.
  static Future<Smb1Share> connect(SmbAddress address, SmbCredentials credentials) async {
    final (client, tree) = await _open(address, credentials);
    return Smb1Share._(address, credentials, client, tree);
  }

  static Future<Smb1Client> _signIn(SmbAddress address, SmbCredentials credentials) async {
    final found = await Smb1Client.negotiate(address);
    final client = found.client;
    if (client == null) throw const SmbSpeaksNewer();
    try {
      await client.signIn(credentials);
      return client;
    } on Object {
      await client.close();
      rethrow;
    }
  }

  static Future<(Smb1Client, int)> _open(SmbAddress address, SmbCredentials credentials) async {
    final client = await _signIn(address, credentials);
    try {
      return (client, await client.connectTree(address.share, guest: credentials.isGuest));
    } on Object {
      await client.close();
      rethrow;
    }
  }

  static Future<List<SmbShareInfo>> listShares(SmbAddress address, SmbCredentials credentials) async {
    final client = await _signIn(address, credentials);
    try {
      return await client.listShares(guest: credentials.isGuest);
    } finally {
      await client.close();
    }
  }

  @override
  bool get smb1 => true;

  /// Runs [task] on a live connection; [again] repeats it once on a new one
  /// when the connection drops (never a request that changes the share).
  Future<T> _on<T>(Future<T> Function(Smb1Client client, int tree) task, {bool again = true}) async {
    await _ensure();
    final client = _client;
    try {
      return await task(client, _tree);
    } on SmbException catch (e) {
      if (!again || e.kind != SmbErrorKind.unreachable || _closed) rethrow;
      await _ensure();
      return task(_client, _tree);
    }
  }

  Future<void> _ensure() {
    if (_closed) throw const SmbException(SmbErrorKind.unreachable, 'closed');
    if (_client.isOpen) return Future.value();
    return _reconnecting ??= _open(_address, _credentials).then((fresh) async {
      if (_closed) return fresh.$1.close();
      _client = fresh.$1;
      _tree = fresh.$2;
    }).whenComplete(() => _reconnecting = null);
  }

  @override
  Future<List<SmbEntry>> list(String path) => _on((c, t) => c.list(t, path));

  @override
  Future<SmbEntry> stat(String path) => _on((c, t) => c.stat(t, path));

  @override
  Future<SmbReader> open(String path) async {
    final reader = _Smb1Reader(this, path);
    await reader._reopen();
    return reader;
  }

  @override
  Future<void> write(String path, Uint8List data) => _on((c, t) async {
        // Overwrite or create.
        final file = await c.openFile(t, path, access: Smb1Client.writeAccess, disposition: 5);
        try {
          await c.write(t, file.fid, data);
        } finally {
          await c.closeFile(t, file.fid);
        }
      });

  @override
  Future<void> rename(String from, String to) => _on((c, t) async {
        // SMB1 renames never replace.
        try {
          await c.delete(t, to);
        } on SmbException catch (e) {
          if (e.kind != SmbErrorKind.gone) rethrow;
        }
        await c.rename(t, from, to);
      }, again: false);

  @override
  Future<void> makeFolder(String path) => _on((c, t) async {
        var at = '';
        for (final part in path.split('/')) {
          at = smbJoin(at, part);
          try {
            await c.makeFolder(t, at);
          } on SmbException {
            // A folder above may be there without being ours to make.
            if (at == path) rethrow;
          }
        }
      });

  @override
  Future<void> delete(String path) => _on((c, t) => c.delete(t, path), again: false);

  @override
  Future<void> close() async {
    _closed = true;
    await _client.close();
  }
}

/// The host speaks SMB 2 or 3 after all.
class SmbSpeaksNewer implements Exception {
  const SmbSpeaksNewer();
}

class _Smb1Reader implements SmbReader {
  _Smb1Reader(this._share, this._path);

  final Smb1Share _share;
  final String _path;
  late Smb1Client _client;
  late int _fid;
  @override
  late int size;

  Future<void> _reopen() => _share._on((c, t) async {
        final file = await c.openFile(t, _path);
        _client = c;
        _fid = file.fid;
        size = file.entry.size;
      });

  @override
  Future<Uint8List> read(int offset, int length) => _share._on((c, t) async {
        // A file handle belongs to its connection.
        if (!identical(c, _client)) {
          final file = await c.openFile(t, _path);
          _client = c;
          _fid = file.fid;
        }
        return c.read(t, _fid, offset, length);
      });

  @override
  Future<void> close() async {
    if (!_client.isOpen) return;
    try {
      await _client.closeFile(_share._tree, _fid);
    } on SmbException {
      // The connection went first.
    }
  }
}
