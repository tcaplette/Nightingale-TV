import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../convert/convert_speeds.dart';
import '../../data/app_storage.dart';
import '../media_server.dart';
import 'secret_store.dart';
import 'smb_connection.dart';
import 'smb_server.dart';
import 'smb_share.dart';

/// A profile's SMB shares (smb-sources): their settings, passwords and
/// clients, and what they need of the rest of the app.
class SmbProfile implements SmbProfileContext {
  SmbProfile(this.storage,
      {required String Function() profileName,
      required this.hold,
      required void Function(SmbServer server, {required bool last}) onFilesReady,
      required VoidCallback onChanged,
      SecretStore? secrets,
      this.open})
      : _profileName = profileName, // ignore: prefer_initializing_formals
        _onFilesReady = onFilesReady, // ignore: prefer_initializing_formals
        _onChanged = onChanged, // ignore: prefer_initializing_formals
        secrets = secrets ?? SecretStore(storage);

  @override
  final AppStorage storage;
  final SecretStore secrets;
  final String Function() _profileName;
  final void Function(SmbServer server, {required bool last}) _onFilesReady;
  final VoidCallback _onChanged;

  /// Opens shares (tests give a fake).
  final SmbOpener? open;

  /// Tests: how every profile's shares are opened.
  @visibleForTesting
  static SmbOpener? openOverride;

  @override
  final ValueListenable<bool> hold;

  static const file = 'smb_shares.json';

  final _configs = <String, SmbShareConfig>{};
  String? _historyFileId;
  bool _loaded = false;

  /// The paired Nightingale TVs this device converts with, by the share
  /// they're asked about.
  Future<String?> Function(String serverId)? helpers;

  final _closing = <Future<void>>[];

  @override
  void closing(Future<void> work) => _closing.add(work);

  /// What closed shares still write, done.
  Future<void> settled() async {
    while (_closing.isNotEmpty) {
      final work = [..._closing];
      _closing.clear();
      await Future.wait(work);
    }
  }

  @override
  late final speeds = ConvertSpeeds(File('${storage.logosDir.parent.path}/convert_speed.json'));

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final json = await storage.readJson(file);
    if (json is Map<String, Object?>) {
      for (final e in (json['shares'] as Map? ?? const {}).cast<String, Object?>().entries) {
        _configs[e.key] = SmbShareConfig.fromJson(e.value);
      }
      _historyFileId = json['historyFile'] as String?;
    }
  }

  /// Whether the profile has any share settings saved (a profile without
  /// shares writes no file).
  bool get hasShares => _configs.isNotEmpty;

  @override
  SmbShareConfig configOf(String serverId) => _configs.putIfAbsent(serverId, SmbShareConfig.new);

  @override
  Future<void> saveConfig(String serverId) => _save();

  Future<void> _save() async {
    if (_configs.isEmpty) {
      await storage.delete(file);
      return;
    }
    await storage.writeJson(file, {
      'shares': {for (final e in _configs.entries) e.key: e.value.toJson()},
      'historyFile': historyFileId,
    });
  }

  /// Forgets share [serverId]'s settings and what was read of it.
  Future<void> removeShare(String serverId) async {
    _configs.remove(serverId);
    await _save();
  }

  @override
  Future<SmbCredentials?> credentials(String ref) => secrets.get(ref);

  @override
  Future<void> forget(String ref) => secrets.remove(ref);

  @override
  String get profileName => _profileName();

  @override
  String get historyFileId => _historyFileId ??= () {
        final rng = Random.secure();
        return List.generate(12, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      }();

  @override
  Future<String?> helperFor(String serverId) async => await helpers?.call(serverId);

  /// Whether a helper had share [serverId] lately (see ConvertHelpers.knownFor).
  bool Function(String serverId)? helperKnown;

  @override
  bool helperSeen(String serverId) => helperKnown?.call(serverId) ?? false;

  @override
  void filesReady(SmbServer server, {required bool last}) => _onFilesReady(server, last: last);

  @override
  void changed() => _onChanged();

  /// A client for [session], a share's sign-in.
  SmbServer client(ServerSession session) => SmbServer(session, this, open: open ?? openOverride);
}
