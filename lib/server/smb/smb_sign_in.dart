import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'smb_discovery.dart';
import 'smb_library.dart';
import 'smb_share.dart';

/// Where an SMB sign-in is, besides the stage (smb-sources).
class SmbStep {
  const SmbStep({
    this.hosts = const [],
    this.searching = false,
    this.host,
    this.shares = const [],
    this.share,
    this.smb1 = false,
    this.user = '',
    this.folder = '',
    this.folders = const [],
    this.mappings = const {},
    this.historyName = '',
    this.keepLocal = false,
    this.writable = true,
  });

  final List<SmbHost> hosts;
  final bool searching;

  /// The host chosen or typed (no share).
  final SmbAddress? host;
  final List<SmbShareInfo> shares;

  /// The share being added.
  final String? share;

  /// The host speaks only SMB1 (old and not encrypted).
  final bool smb1;

  /// The user name to suggest.
  final String user;

  /// The folder the mapping step shows, and its folders.
  final String folder;
  final List<String> folders;

  /// Mapped folders, by path.
  final Map<String, SmbFolderType> mappings;
  final String historyName;
  final bool keepLocal;

  /// The share can be written to (history can be kept on it).
  final bool writable;

  SmbStep copyWith({
    List<SmbHost>? hosts,
    bool? searching,
    SmbAddress? Function()? host,
    List<SmbShareInfo>? shares,
    String? Function()? share,
    bool? smb1,
    String? user,
    String? folder,
    List<String>? folders,
    Map<String, SmbFolderType>? mappings,
    String? historyName,
    bool? keepLocal,
    bool? writable,
  }) =>
      SmbStep(
        hosts: hosts ?? this.hosts,
        searching: searching ?? this.searching,
        host: host == null ? this.host : host(),
        shares: shares ?? this.shares,
        share: share == null ? this.share : share(),
        smb1: smb1 ?? this.smb1,
        user: user ?? this.user,
        folder: folder ?? this.folder,
        folders: folders ?? this.folders,
        mappings: mappings ?? this.mappings,
        historyName: historyName ?? this.historyName,
        keepLocal: keepLocal ?? this.keepLocal,
        writable: writable ?? this.writable,
      );

  /// The type a folder at [path] has: its own mapping, else the nearest
  /// mapped folder's around it.
  SmbFolderType? typeAt(String path) {
    String? best;
    for (final p in mappings.keys) {
      if (smbInside(path, p) && (best == null || p.length > best.length)) best = p;
    }
    return best == null ? null : mappings[best];
  }
}

/// A share's own id (design D4): from `.nightingale/share.json`, written
/// there when the share is writable; otherwise its root folder's id and
/// created time, or, when the host gives neither, its host and name.
/// Returns the id and whether the share took a write.
Future<({String id, bool writable})> smbServerId(SmbShare share, SmbAddress address) async {
  const file = '.nightingale/share.json';
  final rng = Random.secure();
  try {
    final json = jsonDecode(utf8.decode(await share.readAll(file, limit: 4096)));
    if (json case {'id': final String id} when id.isNotEmpty) {
      // Written through another share of the same folder, perhaps: whether
      // this one takes writes is its own.
      final probe = '.nightingale/write.${rng.nextInt(1 << 30).toRadixString(36)}.tmp';
      try {
        await share.write(probe, Uint8List(0));
        await share.delete(probe);
        return (id: id, writable: true);
      } on SmbException catch (e) {
        if (e.kind == SmbErrorKind.unreachable) rethrow;
        return (id: id, writable: false);
      }
    }
  } on SmbException catch (e) {
    if (e.kind == SmbErrorKind.unreachable) rethrow;
    // Not there yet, or unreadable.
  } on FormatException {
    // Not ours.
  }
  final id = 'smb-${List.generate(10, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  try {
    await share.makeFolder('.nightingale');
    final tmp = '$file.${rng.nextInt(1 << 30).toRadixString(36)}.tmp';
    await share.write(tmp, Uint8List.fromList(utf8.encode(jsonEncode({'id': id}))));
    await share.rename(tmp, file);
    return (id: id, writable: true);
  } on SmbException catch (e) {
    if (e.kind == SmbErrorKind.unreachable) rethrow;
  }
  final root = await share.stat('');
  final created = root.created?.microsecondsSinceEpoch;
  final basis = root.fileId != 0 || created != null
      ? '${address.share.toLowerCase()}|${root.fileId}|${created ?? ''}'
      : '${address.host.toLowerCase()}|${address.share.toLowerCase()}';
  return (id: 'smb-${sha256.convert(utf8.encode(basis)).toString().substring(0, 20)}', writable: false);
}
