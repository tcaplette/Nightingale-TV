import 'dart:async';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';

import 'smb_share.dart';

/// A share over SMB 2 or 3 (libsmb2).
class Smb2Share implements SmbShare {
  Smb2Share._(this._pool);

  final Smb2Pool _pool;

  static const timeout = Duration(seconds: 12);

  /// Connects to [address] with [workers] connections. Signing and
  /// encryption follow what the host requires.
  static Future<Smb2Share> connect(SmbAddress address, SmbCredentials credentials, {int workers = 2}) async {
    Future<Smb2Share> attempt(String? user, String? password) async => Smb2Share._(await Smb2Pool.connect(
          host: address.target,
          share: address.share,
          user: user,
          password: password,
          domain: credentials.domain.isEmpty ? null : credentials.domain,
          workers: workers,
          timeout: timeout,
        ));
    return _asUser(credentials, attempt);
  }

  /// The host's disk shares, hidden ones left out.
  static Future<List<SmbShareInfo>> listShares(SmbAddress address, SmbCredentials credentials) =>
      _asUser(credentials, (user, password) async {
        final shares = await Smb2Pool.listSharesOn(
            host: address.target,
            user: user,
            password: password,
            domain: credentials.domain.isEmpty ? null : credentials.domain,
            timeout: timeout);
        return [
          for (final s in shares)
            if (s.isDisk && !s.isHidden) SmbShareInfo(s.name, comment: s.remark)
        ];
      });

  /// Runs [attempt] signed in as [credentials] says: a guest signs in with
  /// no name first, then as the Guest account, which some hosts want.
  static Future<T> _asUser<T>(SmbCredentials credentials, Future<T> Function(String? user, String? password) attempt) async {
    if (!credentials.isGuest) {
      return _guard(() => attempt(credentials.user, credentials.password));
    }
    SmbException? first;
    for (final (user, password) in const [(null, null), ('Guest', '')]) {
      try {
        return await _guard(() => attempt(user, password), guest: true);
      } on SmbException catch (e) {
        if (e.kind != SmbErrorKind.guestsRefused) rethrow;
        first ??= e;
      }
    }
    throw first!;
  }

  static Future<T> _guard<T>(Future<T> Function() task, {bool guest = false}) async {
    try {
      return await task();
    } on Smb2Exception catch (e) {
      throw SmbException(_kind(e, guest: guest), e.message);
    }
  }

  static SmbErrorKind _kind(Smb2Exception e, {required bool guest}) {
    if (guest && (e.isAuthError || e.type == Smb2ErrorType.accessDenied)) return SmbErrorKind.guestsRefused;
    if (e.isAuthError) return SmbErrorKind.wrongSignIn;
    if (e.isNotFound) return SmbErrorKind.gone;
    if (e.isNetworkFailure) return SmbErrorKind.unreachable;
    return switch (e.type) {
      Smb2ErrorType.accessDenied => SmbErrorKind.noAccess,
      Smb2ErrorType.notADirectory || Smb2ErrorType.isADirectory => SmbErrorKind.gone,
      _ => SmbErrorKind.other,
    };
  }

  @override
  bool get smb1 => false;

  static SmbEntry _entry(String name, Smb2Stat s) => SmbEntry(
        name: name,
        isFolder: s.isDirectory,
        size: s.size,
        modified: s.modified,
        created: s.created,
        // Hidden or system.
        hidden: s.attributes & 0x6 != 0,
        fileId: s.fileId,
      );

  @override
  Future<List<SmbEntry>> list(String path) => _guard(() async => [
        for (final e in await _pool.listDirectory(path))
          if (e.name != '.' && e.name != '..') _entry(e.name, e.stat)
      ]);

  @override
  Future<SmbEntry> stat(String path) =>
      _guard(() async => _entry(path.split('/').last, await _pool.stat(path)));

  @override
  Future<SmbReader> open(String path) => _guard(() async {
        final (handle, size) = await _pool.openFileWithSize(path);
        return _Smb2Reader(_pool, handle, size);
      });

  @override
  Future<void> write(String path, Uint8List data) => _guard(() => _pool.writeFile(path, data));

  @override
  Future<void> rename(String from, String to) => _guard(() => _pool.rename(from, to, overwrite: true));

  @override
  Future<void> makeFolder(String path) => _guard(() async => _pool.mkdir(path, recursive: true));

  @override
  Future<void> delete(String path) => _guard(() => _pool.deleteFile(path));

  @override
  Future<void> close() async {
    try {
      await _pool.disconnect();
    } on Smb2Exception {
      // Already gone.
    }
  }
}

class _Smb2Reader implements SmbReader {
  _Smb2Reader(this._pool, this._handle, this.size);

  final Smb2Pool _pool;
  final Smb2PoolHandle _handle;
  @override
  final int size;

  @override
  Future<Uint8List> read(int offset, int length) =>
      Smb2Share._guard(() => _pool.readFromHandle(_handle, offset: offset, length: length));

  @override
  Future<void> close() async {
    try {
      await _pool.closeHandle(_handle);
    } on Smb2Exception {
      // The connection went first.
    }
  }
}
