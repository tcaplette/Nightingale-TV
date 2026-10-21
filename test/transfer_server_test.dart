import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/backup/backup_archive.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/backup/transfer_server.dart';
import 'package:nightingale_tv/profiles/household.dart';
import 'package:nightingale_tv/remote/remote_control.dart';

import 'backup_fixtures.dart';
import 'fixtures.dart';

void main() {
  late Directory dir;
  late Household h;
  late TransferServer server;
  late Uri url;
  final uploads = <StoredBackup>[];
  final client = HttpClient();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nightingale_tv_transfer');
    await writeHousehold(dir, momAndKids(), fakeLibrary());
    h = await openHousehold(dir);
    uploads.clear();
    server = TransferServer(h.backups!, onUpload: uploads.add);
    // Reached over loopback here; phones use the home-network address.
    url = (await server.start()).replace(host: '127.0.0.1');
  });
  tearDown(() async {
    await server.stop();
    h.backups!.dispose();
    await dir.delete(recursive: true);
  });
  tearDownAll(() => client.close(force: true));

  Future<(int, List<int>, HttpHeaders)> send(String method, Uri uri, {List<int>? body, Map<String, String>? headers}) async {
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    headers?.forEach(request.headers.set);
    if (body != null) request.add(body);
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    return (response.statusCode, bytes, response.headers);
  }

  Uri at(String path) => url.resolve(path);
  const action = {RemoteControl.actionHeader: '1'};

  test('the address holds a 128-bit token; any other address is not found', () async {
    expect(url.path, matches(RegExp(r'^/b/[0-9a-f]{32}/$')));
    expect((await send('GET', at('/'))).$1, HttpStatus.notFound);
    expect((await send('GET', at('/b/'))).$1, HttpStatus.notFound);
    expect((await send('GET', at('/b/0123456789abcdef0123456789abcdef/'))).$1, HttpStatus.notFound);
    expect((await send('GET', at('/b/0123456789abcdef0123456789abcdef/backup'))).$1, HttpStatus.notFound);
    expect((await send('POST', at('/b/0123456789abcdef0123456789abcdef/restore'), headers: action, body: [1])).$1,
        HttpStatus.notFound);
    final page = await send('GET', url);
    expect(page.$1, HttpStatus.ok);
    expect(String.fromCharCodes(page.$2), contains('Download backup'));
    // Without the slash, to the page's folder (its links are relative).
    final bare = await send('GET', at(url.path.substring(0, url.path.length - 1)));
    expect(bare.$1, HttpStatus.movedPermanently);
    expect(bare.$3.value(HttpHeaders.locationHeader), url.path);
  });

  test('the download is a fresh, valid backup, named for the time', () async {
    final (status, bytes, headers) = await send('GET', at('backup'));
    expect(status, HttpStatus.ok);
    expect(headers.value('content-disposition'), matches(RegExp(r'attachment; filename="nightingale-tv-\d{4}-\d\d-\d\d-\d{4}\.ntvbackup"')));
    final archive = BackupArchive.check(bytes);
    expect(archive.summary.profiles, ['Mom', 'Kids']);
    // A download isn't kept in the store.
    expect(await h.backups!.store.list(), isEmpty);
  });

  test('an upload without the remote\'s header is refused', () async {
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    expect((await send('POST', at('restore'), body: bytes)).$1, HttpStatus.forbidden);
    expect(uploads, isEmpty);
    expect(await h.backups!.store.list(), isEmpty);
  });

  test('an upload over 32 MB is refused, by its length or as it arrives', () async {
    // Turned down on its stated length, without reading it.
    final socket = await Socket.connect('127.0.0.1', url.port);
    socket.write('POST ${url.path}restore HTTP/1.1\r\nHost: 127.0.0.1\r\n'
        '${RemoteControl.actionHeader}: 1\r\nContent-Length: ${TransferServer.maxUpload + 1}\r\n\r\n');
    socket.add(List<int>.filled(TransferServer.maxUpload + 1, 7));
    await socket.flush();
    final reply = String.fromCharCodes(await socket.first.timeout(const Duration(seconds: 5)));
    socket.destroy();
    expect(reply, startsWith('HTTP/1.1 413'));
    final request = await client.postUrl(at('restore'));
    action.forEach(request.headers.set);
    request.headers.chunkedTransferEncoding = true;
    final chunk = List<int>.filled(1024 * 1024, 7);
    try {
      for (var i = 0; i < 34; i++) {
        request.add(chunk);
      }
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    } on Object {
      // The server may close the connection before the body is all sent.
    }
    expect(uploads, isEmpty);
    expect(await h.backups!.store.list(), isEmpty);
  });

  test('a damaged upload is turned down with its reason', () async {
    final (status, body, _) = await send('POST', at('restore'), headers: action, body: [1, 2, 3]);
    expect(status, HttpStatus.badRequest);
    expect(String.fromCharCodes(body), contains('isn\'t a Nightingale TV backup'));
    expect(uploads, isEmpty);
  });

  test('a good upload is kept as "From a file" and handed to the TV', () async {
    final bytes = (await h.backups!.build(BackupReason.manual)).bytes;
    final (status, _, _) = await send('POST', at('restore'), headers: action, body: bytes);
    expect(status, HttpStatus.ok);
    expect(uploads, hasLength(1));
    expect(uploads.single.kind, BackupReason.file);
    expect(uploads.single.kindLabel, 'From a file');
    final stored = await h.backups!.store.list();
    expect(stored.single.name, uploads.single.name);
  });

  test('it stops when closed, and after its idle time', () async {
    await server.stop();
    expect(server.running, isFalse);
    await expectLater(send('GET', url), throwsA(isA<SocketException>()));

    var idle = false;
    final short = TransferServer(h.backups!, onUpload: uploads.add, onIdle: () => idle = true,
        idleTimeout: const Duration(milliseconds: 300));
    final shortUrl = (await short.start()).replace(host: '127.0.0.1');
    // Requests keep it alive.
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect((await send('GET', shortUrl)).$1, HttpStatus.ok);
    }
    expect(idle, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(idle, isTrue);
    expect(short.running, isFalse);
    await expectLater(send('GET', shortUrl), throwsA(isA<SocketException>()));
  });
}
