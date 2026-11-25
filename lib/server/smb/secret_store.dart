import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../data/app_storage.dart';
import '../../platform/platform_info.dart';
import '../../platform/smb_platform.dart';
import '../server_log.dart';
import 'smb_share.dart';

/// Encrypts what [SecretStore] saves.
abstract interface class SecretCipher {
  Future<Uint8List> encrypt(Uint8List data);
  Future<Uint8List> decrypt(Uint8List data);
}

/// The Android Keystore's key, which never leaves it.
class KeystoreCipher implements SecretCipher {
  const KeystoreCipher();

  @override
  Future<Uint8List> encrypt(Uint8List data) => SmbPlatform.encrypt(data);

  @override
  Future<Uint8List> decrypt(Uint8List data) => SmbPlatform.decrypt(data);
}

/// AES-GCM with a key in a file only this user may read, outside the
/// profiles' folders (and so out of every backup).
class KeyFileCipher implements SecretCipher {
  KeyFileCipher(this.file);

  final File file;
  static final _aes = AesGcm.with256bits();

  Future<SecretKey>? _key;

  Future<SecretKey> _load() => _key ??= () async {
        if (!await file.exists()) {
          await file.parent.create(recursive: true);
          final rng = Random.secure();
          final tmp = File('${file.path}.${rng.nextInt(1 << 32).toRadixString(16)}.tmp');
          await tmp.create();
          await Process.run('chmod', ['600', tmp.path]);
          await tmp.writeAsBytes([for (var i = 0; i < 32; i++) rng.nextInt(256)], flush: true);
          // Another process may have made one meanwhile: the first stays.
          if (await file.exists()) {
            await tmp.delete();
          } else {
            await tmp.rename(file.path);
          }
        }
        return SecretKey(await file.readAsBytes());
      }();

  @override
  Future<Uint8List> encrypt(Uint8List data) async =>
      Uint8List.fromList((await _aes.encrypt(data, secretKey: await _load())).concatenation());

  @override
  Future<Uint8List> decrypt(Uint8List data) async => Uint8List.fromList(await _aes.decrypt(
      SecretBox.fromConcatenation(data, nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength),
      secretKey: await _load()));
}

/// A profile's secrets, encrypted in `smb_secrets.json`: SMB passwords
/// (smb-sources D6), and YouTube's Google refresh tokens and own client
/// secrets (youtube-subscriptions D4). A session only holds the reference
/// [put] or [putValues] gives. Never in a backup.
class SecretStore {
  SecretStore(this._storage, {SecretCipher? cipher}) : _cipher = cipher ?? cipherFor(_storage);

  final AppStorage _storage;
  final SecretCipher _cipher;

  static const file = 'smb_secrets.json';

  /// The key's file, in the app's own folder.
  static const keyFile = 'smb_key';

  /// The reference of a guest sign-in, which has nothing to keep.
  static const guestRef = 'guest';

  static SecretCipher cipherFor(AppStorage storage) => PlatformInfo.isAndroid
      ? const KeystoreCipher()
      : KeyFileCipher(File('${storage.logosDir.parent.path}/$keyFile'));

  Map<String, Object?>? _entries;

  Future<Map<String, Object?>> _load() async => _entries ??= switch (await _storage.readJson(file)) {
        final Map<String, Object?> m => {...m},
        _ => {},
      };

  Future<void> _save() async {
    final entries = _entries ?? const {};
    if (entries.isEmpty) {
      await _storage.delete(file);
    } else {
      await _storage.writeJson(file, entries, private: true);
    }
  }

  /// Saves [credentials] and returns their reference.
  Future<String> put(SmbCredentials credentials) async {
    if (credentials.isGuest) return guestRef;
    ServerLog.secret(credentials.password);
    final rng = Random.secure();
    final ref = 'smb-${List.generate(8, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final plain = utf8.encode(
        jsonEncode({'user': credentials.user, 'password': credentials.password, 'domain': credentials.domain}));
    final entries = await _load();
    entries[ref] = base64Encode(await _cipher.encrypt(plain));
    await _save();
    return ref;
  }

  /// The credentials [ref] stands for; null when they're gone or can't be
  /// decrypted on this device (the sign-in is then asked for again).
  Future<SmbCredentials?> get(String ref) async {
    if (ref == guestRef) return const SmbCredentials.guest();
    final saved = (await _load())[ref];
    if (saved is! String) return null;
    try {
      final json = jsonDecode(utf8.decode(await _cipher.decrypt(base64Decode(saved)))) as Map<String, Object?>;
      ServerLog.secret(json['password'] as String);
      return SmbCredentials(
          user: json['user'] as String, password: json['password'] as String, domain: json['domain'] as String? ?? '');
    } on Object catch (e) {
      debugPrint('A saved SMB sign-in can not be read: ${e.runtimeType}');
      return null;
    }
  }

  /// Saves [values] (a Google sign-in's refresh token and own client
  /// secret) under a new reference starting with [prefix].
  Future<String> putValues(String prefix, Map<String, String> values) async {
    final rng = Random.secure();
    final ref = '$prefix-${List.generate(8, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await replaceValues(ref, values);
    return ref;
  }

  /// Saves [values] under [ref], replacing what it held.
  Future<void> replaceValues(String ref, Map<String, String> values) async {
    values.values.forEach(ServerLog.secret);
    final entries = await _load();
    entries[ref] = base64Encode(await _cipher.encrypt(utf8.encode(jsonEncode(values))));
    await _save();
  }

  /// What [putValues] saved under [ref]; null when it's gone or can't be
  /// decrypted on this device.
  Future<Map<String, String>?> values(String ref) async {
    final saved = (await _load())[ref];
    if (saved is! String) return null;
    try {
      final json = (jsonDecode(utf8.decode(await _cipher.decrypt(base64Decode(saved)))) as Map).cast<String, String>();
      json.values.forEach(ServerLog.secret);
      return json;
    } on Object catch (e) {
      debugPrint('A saved secret can not be read: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> remove(String ref) async {
    if ((await _load()).remove(ref) != null) await _save();
  }

  /// Forgets every password but [keep]'s (sign-ins that went with a
  /// restore, or were removed while the app was closed).
  Future<void> prune(Set<String> keep) async {
    final entries = await _load();
    final before = entries.length;
    entries.removeWhere((ref, _) => !keep.contains(ref));
    if (entries.length != before) await _save();
  }

  /// Forgets every one (sign-out).
  Future<void> clear() async {
    _entries = {};
    await _storage.delete(file);
  }
}
