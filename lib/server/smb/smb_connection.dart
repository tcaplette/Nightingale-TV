import 'dart:async';

import 'smb_open.dart';
import 'smb_share.dart';

/// Opens a share; tests give a fake.
typedef SmbOpener = Future<SmbShare> Function(SmbAddress address, SmbCredentials credentials, {bool knownSmb1, int workers});

/// A share's connections, opened when needed and closed after
/// [idleClose] without use (smb-sources, "Idle shares cost nothing").
class SmbConnection {
  SmbConnection(this.address, this._credentials, {this.knownSmb1 = false, this.workers = 2, SmbOpener? open})
      : _open = open ?? openSmbShare;

  static const idleClose = Duration(seconds: 60);

  final SmbAddress address;

  /// Asked each time it connects; null when the sign-in is gone.
  final Future<SmbCredentials?> Function() _credentials;
  bool knownSmb1;
  final int workers;
  final SmbOpener _open;

  Future<SmbShare>? _share;
  Timer? _idle;
  int _users = 0;
  bool _closed = false;

  bool get isOpen => _share != null;

  /// Told which version each connection came up with.
  void Function(bool smb1)? onVersion;

  /// Runs [task] with the share connected.
  Future<T> use<T>(Future<T> Function(SmbShare share) task) async {
    if (_closed) throw const SmbException(SmbErrorKind.unreachable, 'closed');
    _users++;
    _idle?.cancel();
    final opening = _share ??= _connect();
    try {
      final SmbShare share;
      try {
        share = await opening;
      } on Object {
        if (identical(_share, opening)) _share = null;
        rethrow;
      }
      return await task(share);
    } finally {
      _users--;
      if (_users == 0 && !_closed) {
        _idle?.cancel();
        _idle = Timer(idleClose, () => unawaited(drop()));
      }
    }
  }

  Future<SmbShare> _connect() async {
    final credentials = await _credentials();
    if (credentials == null) throw const SmbException(SmbErrorKind.wrongSignIn, 'no saved sign-in');
    final share = await _open(address, credentials, knownSmb1: knownSmb1, workers: workers);
    if (share.smb1 != knownSmb1) {
      knownSmb1 = share.smb1;
      onVersion?.call(share.smb1);
    }
    return share;
  }

  /// Disconnects; the next use connects again.
  Future<void> drop() async {
    _idle?.cancel();
    final share = _share;
    _share = null;
    try {
      await (await share)?.close();
    } on Object {
      // It never opened, or is gone.
    }
  }

  Future<void> close() {
    _closed = true;
    return drop();
  }
}
