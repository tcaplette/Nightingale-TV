import 'smb1_client.dart';
import 'smb1_share.dart';
import 'smb2_share.dart';
import 'smb_share.dart';

/// Connects to the share at [address] (design D2): with SMB 2 or 3, or with
/// SMB1 when the host speaks nothing newer. [knownSmb1] saves asking first
/// when it was SMB1 last time. A refused sign-in is never tried again with
/// SMB1.
Future<SmbShare> openSmbShare(SmbAddress address, SmbCredentials credentials, {bool knownSmb1 = false, int workers = 2}) =>
    _choose(
      address,
      knownSmb1: knownSmb1,
      newer: () => Smb2Share.connect(address, credentials, workers: workers),
      smb1: () => Smb1Share.connect(address, credentials),
    );

/// The disk shares of [address]'s host, and whether it only speaks SMB1.
Future<({List<SmbShareInfo> shares, bool smb1})> listSmbShares(SmbAddress address, SmbCredentials credentials) => _choose(
      address,
      knownSmb1: false,
      newer: () async => (shares: await Smb2Share.listShares(address, credentials), smb1: false),
      smb1: () async => (shares: await Smb1Share.listShares(address, credentials), smb1: true),
    );

Future<T> _choose<T>(SmbAddress address,
    {required bool knownSmb1, required Future<T> Function() newer, required Future<T> Function() smb1}) async {
  if (knownSmb1) {
    try {
      return await smb1();
    } on SmbSpeaksNewer {
      return newer();
    }
  }
  try {
    return await newer();
  } on SmbException catch (e) {
    // Only a failed connection can be a host that speaks SMB1 alone.
    if (e.kind != SmbErrorKind.unreachable || !await _onlySmb1(address)) rethrow;
    return smb1();
  }
}

Future<bool> _onlySmb1(SmbAddress address) async {
  try {
    final client = (await Smb1Client.negotiate(address)).client;
    await client?.close();
    return client != null;
  } on SmbException {
    return false;
  }
}
