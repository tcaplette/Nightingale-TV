import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

void main() {
  late Directory dir;
  late AppStorage storage;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secrets');
    storage = await AppStorage.at(Directory('${dir.path}/profile'), logosDir: Directory('${dir.path}/logos'));
  });
  tearDown(() => dir.delete(recursive: true));

  test('passwords are kept encrypted, with the key outside the profile, readable only by this user', () async {
    final store = SecretStore(storage);
    final ref = await store.put(const SmbCredentials(user: 'alice', password: 'correct horse', domain: 'HOME'));
    await storage.flush();
    final file = File('${dir.path}/profile/${SecretStore.file}');
    expect(file.readAsStringSync(), isNot(contains('correct horse')));
    expect(file.readAsStringSync(), isNot(contains('alice')));
    expect(file.statSync().modeString(), 'rw-------');
    final key = File('${dir.path}/${SecretStore.keyFile}');
    expect(key.statSync().modeString(), 'rw-------');
    expect(key.lengthSync(), 32);
    // Another store on the same files reads it.
    final again = await SecretStore(storage).get(ref);
    expect((again!.user, again.password, again.domain), ('alice', 'correct horse', 'HOME'));
  });

  test('a guest has nothing to keep', () async {
    final store = SecretStore(storage);
    expect(await store.put(const SmbCredentials.guest()), SecretStore.guestRef);
    expect((await store.get(SecretStore.guestRef))!.isGuest, isTrue);
    expect(File('${dir.path}/profile/${SecretStore.file}').existsSync(), isFalse);
  });

  test('removed, pruned and cleared; another key reads nothing', () async {
    final store = SecretStore(storage);
    final a = await store.put(const SmbCredentials(user: 'a', password: 'pa'));
    final b = await store.put(const SmbCredentials(user: 'b', password: 'pb'));
    await store.remove(a);
    expect(await store.get(a), isNull);
    expect(await store.get(b), isNotNull);
    await store.prune({});
    expect(await store.get(b), isNull);
    await storage.flush();
    expect(File('${dir.path}/profile/${SecretStore.file}').existsSync(), isFalse);
    final c = await store.put(const SmbCredentials(user: 'c', password: 'pc'));
    await storage.flush();
    File('${dir.path}/${SecretStore.keyFile}').writeAsBytesSync(List.filled(32, 7));
    expect(await SecretStore(storage).get(c), isNull, reason: 'a wrong key reads nothing, it never throws');
    expect(jsonDecode(File('${dir.path}/profile/${SecretStore.file}').readAsStringSync()), contains(c));
  });
}
