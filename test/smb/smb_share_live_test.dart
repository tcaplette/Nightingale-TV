import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_open.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

/// The share interface against every Samba share (tool/test_servers):
/// `SMB_PASSWORD=… tool/test_servers/test_servers.sh up samba`, then
/// `SMB_LIVE=1 SMB_PASSWORD=… flutter test test/smb/smb_share_live_test.dart`.
final _live = Platform.environment['SMB_LIVE'] == '1';
final _user = SmbCredentials(
    user: Platform.environment['SMB_USER'] ?? 'smbtest', password: Platform.environment['SMB_PASSWORD'] ?? '');
const _guest = SmbCredentials.guest();
SmbAddress _at(String s) => SmbAddress.parse('smb://127.0.0.1:$s')!;

Matcher _fails(SmbErrorKind kind) =>
    throwsA(isA<SmbException>().having((e) => e.kind, 'kind', kind).having((e) => '$e', 'text', isNot(contains(_user.password))));

void main() {
  final media = Platform.environment['NIGHTINGALE_TEST_MEDIA'] ?? '${Platform.environment['HOME']}/.cache/nightingale-test-media';
  final formats =
      Platform.environment['NIGHTINGALE_TEST_SMB_MEDIA'] ?? '${Platform.environment['HOME']}/.cache/nightingale-test-smb-media';

  for (final (name, who, smb1, writable, root) in [
    ('1445/media', _user, false, true, media),
    ('1445/archive', _user, false, true, formats),
    ('1445/guest', _guest, false, true, formats),
    ('1445/readonly', _user, false, false, media),
    ('1446/signed', _user, false, true, media),
    ('1447/old', _user, true, true, media),
    ('1447/oldguest', _guest, true, true, formats),
  ]) {
    test('$name connects, lists, reads and writes', () async {
      final share = await openSmbShare(_at(name), who);
      addTearDown(share.close);
      expect(share.smb1, smb1);

      // The same listing as the folder itself.
      Future<void> compare(String path) async {
        final here = {
          for (final e in Directory('$root${path.isEmpty ? '' : '/$path'}').listSync())
            e.uri.pathSegments.lastWhere((s) => s.isNotEmpty): e
        };
        final entries = {for (final e in await share.list(path)) e.name: e};
        expect(entries.keys.toSet(), here.keys.toSet(), reason: path);
        for (final e in entries.entries) {
          final entity = here[e.key]!;
          expect(e.value.isFolder, entity is Directory, reason: e.key);
          if (entity is File) {
            expect(e.value.size, entity.lengthSync(), reason: e.key);
            expect(e.value.modified!.difference(entity.lastModifiedSync()).inSeconds.abs(), lessThan(3), reason: e.key);
          }
        }
      }

      await compare('');
      await compare(root == media ? 'Movies' : 'Names/Movies');
      final big = Directory(root).listSync(recursive: true).whereType<File>().reduce((a, b) => a.lengthSync() > b.lengthSync() ? a : b);
      final path = big.path.substring(root.length + 1);
      final stat = await share.stat(path);
      expect(stat.size, big.lengthSync());
      expect((await share.stat('')).isFolder, isTrue);

      final reader = await share.open(path);
      expect(reader.size, big.lengthSync());
      final raf = big.openSync();
      for (final (offset, length) in [(0, 100), (12345, 300000), (reader.size - 70000, 100000), (reader.size, 10)]) {
        raf.setPositionSync(offset);
        expect(sha1.convert(await reader.read(offset, length)), sha1.convert(raf.readSync(length)), reason: '$offset+$length');
      }
      raf.closeSync();
      final clock = Stopwatch()..start();
      var read = 0;
      while (read < reader.size && read < 60 << 20) {
        read += (await reader.read(read, 1 << 20)).length;
      }
      // ignore: avoid_print
      print('$name: ${(read / 1e6 / (clock.elapsedMilliseconds / 1000)).round()} MB/s');
      await reader.close();

      await expectLater(share.stat('nope/nothing.mkv'), _fails(SmbErrorKind.gone));
      await expectLater(share.open('nope.mkv'), _fails(SmbErrorKind.gone));

      if (!writable) {
        await expectLater(share.write('nightingale-write-check.tmp', Uint8List(1)), _fails(SmbErrorKind.noAccess));
        return;
      }
      final folder = '.nightingale/live-${DateTime.now().microsecondsSinceEpoch}';
      await share.makeFolder(folder);
      await share.makeFolder(folder);
      for (final size in [5, 200000]) {
        final data = Uint8List.fromList([for (var i = 0; i < size; i++) i * 7 & 0xFF]);
        await share.write('$folder/a.tmp', data);
        final id = (await share.stat('$folder/a.tmp')).fileId;
        expect(id, isNot(0), reason: 'every file has an id');
        await share.rename('$folder/a.tmp', '$folder/a.json');
        expect(await share.readAll('$folder/a.json'), data);
        expect((await share.stat('$folder/a.json')).fileId, id, reason: 'a renamed file keeps its id');
        expect([for (final e in await share.list(folder)) e.fileId], [id], reason: 'listed with the same id');
      }
      expect([for (final e in await share.list(folder)) e.name], ['a.json']);
      await share.delete('$folder/a.json');
      expect(await share.list(folder), isEmpty);
      Directory('$root/$folder').deleteSync();
      if (Directory('$root/.nightingale').listSync().isEmpty) Directory('$root/.nightingale').deleteSync();
    }, timeout: const Timeout(Duration(seconds: 90)), skip: !_live);
  }

  test('a thousand files are all listed', () async {
    final folder = Directory('$formats/Backups/many')..createSync();
    addTearDown(() => folder.deleteSync(recursive: true));
    for (var i = 0; i < 1300; i++) {
      File('${folder.path}/A fairly long file name, number $i, é日本.txt').writeAsStringSync('x');
    }
    for (final at in ['1445/archive', '1447/oldguest']) {
      final share = await openSmbShare(_at(at), at.endsWith('guest') ? _guest : _user);
      addTearDown(share.close);
      final names = {for (final e in await share.list('Backups/many')) e.name};
      expect(names.length, 1300, reason: at);
      expect(names, contains('A fairly long file name, number 777, é日本.txt'));
    }
  }, skip: !_live);

  test('failures say what went wrong', () async {
    final wrong = SmbCredentials(user: _user.user, password: 'not-the-password');
    await expectLater(openSmbShare(_at('1445/media'), wrong), _fails(SmbErrorKind.wrongSignIn));
    await expectLater(openSmbShare(_at('1447/old'), wrong), _fails(SmbErrorKind.wrongSignIn));
    await expectLater(openSmbShare(_at('1445/media'), _guest), _fails(SmbErrorKind.guestsRefused));
    await expectLater(openSmbShare(_at('1446/signed'), _guest), _fails(SmbErrorKind.guestsRefused));
    await expectLater(openSmbShare(_at('1447/old'), _guest), _fails(SmbErrorKind.guestsRefused));
    await expectLater(openSmbShare(_at('1445/private'), _user), _fails(SmbErrorKind.noAccess));
    await expectLater(openSmbShare(_at('1445/nothere'), _user), _fails(SmbErrorKind.gone));
    await expectLater(openSmbShare(_at('1447/nothere'), _user), _fails(SmbErrorKind.gone));
    await expectLater(openSmbShare(_at('1999/media'), _user), _fails(SmbErrorKind.unreachable));
    await expectLater(openSmbShare(SmbAddress.parse('smb://nowhere.invalid/media')!, _user), _fails(SmbErrorKind.unreachable));
  }, timeout: const Timeout(Duration(seconds: 90)), skip: !_live);

  test('share lists', () async {
    final newer = await listSmbShares(_at('1445'), _user);
    expect(newer.smb1, isFalse);
    expect([for (final s in newer.shares) s.name], ['media', 'archive', 'guest', 'readonly', 'private']);
    expect([for (final s in (await listSmbShares(_at('1445'), _guest)).shares) s.name], contains('guest'));
    final old = await listSmbShares(_at('1447'), _user);
    expect(old.smb1, isTrue);
    expect([for (final s in old.shares) s.name], ['old', 'oldguest']);
    expect([for (final s in (await listSmbShares(_at('1447'), _guest)).shares) s.name], ['old', 'oldguest']);
    await expectLater(listSmbShares(_at('1446'), _guest), _fails(SmbErrorKind.guestsRefused));
  }, skip: !_live);

  test('a host that was SMB1 and is newer now connects as newer', () async {
    final share = await openSmbShare(_at('1445/media'), _user, knownSmb1: true);
    addTearDown(share.close);
    expect(share.smb1, isFalse);
  }, skip: !_live);
}
