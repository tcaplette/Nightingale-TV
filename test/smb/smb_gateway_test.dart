import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

class _Reader implements SmbReader {
  _Reader(this.size);
  @override
  final int size;
  final reads = <(int, int)>[];
  @override
  Future<Uint8List> read(int offset, int length) async {
    reads.add((offset, length));
    final n = (offset + length).clamp(0, size) - offset;
    return Uint8List.fromList([for (var i = 0; i < n; i++) (offset + i) & 0xFF]);
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('ranges', () {
    expect(GatewayCore.parseRange('bytes=0-99', 1000), (0, 100));
    expect(GatewayCore.parseRange('bytes=900-', 1000), (900, 1000));
    expect(GatewayCore.parseRange('bytes=-100', 1000), (900, 1000));
    expect(GatewayCore.parseRange('bytes=990-2000', 1000), (990, 1000));
    expect(GatewayCore.parseRange('bytes=1000-', 1000), (1000, 1000), reason: 'past the end: 416');
    expect(GatewayCore.parseRange('bytes=5-2', 1000), isNull);
    expect(GatewayCore.parseRange(null, 1000), isNull);
    expect(GatewayCore.parseRange('items=0-1', 1000), isNull);
  });

  test('read-ahead: a small first read, then growing windows, every byte once', () async {
    final r = _Reader(30 << 20);
    final chunks = await GatewayCore.readAhead(r, 1000, 30 << 20).toList();
    final bytes = chunks.fold<int>(0, (n, c) => n + c.length);
    expect(bytes, (30 << 20) - 1000);
    expect(r.reads.first, (1000, 256 * 1024));
    expect(r.reads.map((x) => x.$2).reduce((a, b) => a > b ? a : b), 4 << 20);
    for (var i = 1; i < r.reads.length; i++) {
      expect(r.reads[i].$1, r.reads[i - 1].$1 + r.reads[i - 1].$2);
    }
  });

  test('a file that ends early is an error, not a short answer', () async {
    final r = _Reader(1000);
    await expectLater(GatewayCore.readAhead(r, 0, 5000).toList(), throwsA(isA<SmbException>()));
  });

  group('requests', () {
    late SmbGateway g;
    setUpAll(() async {
      SmbGateway.inIsolate = false;
      g = await SmbGateway.ensureStarted();
      // A share whose host doesn't answer.
      await g.register('dead', GatewayTarget(address: SmbAddress.parse('smb://127.0.0.1:1/x')!, credentials: const SmbCredentials.guest()));
      await g.setFiles('dead', {'abc': const GatewayFile(path: 'a.mkv', size: 10)});
    });
    tearDownAll(SmbGateway.stop);

    Future<int> status(Uri uri, {String method = 'GET'}) async {
      final c = HttpClient();
      try {
        final a = await (await c.openUrl(method, uri)).close();
        await a.drain<void>();
        return a.statusCode;
      } finally {
        c.close();
      }
    }

    test('an unreachable share answers 503; unknown ids, targets and secrets 404', () async {
      expect(await status(g.uri('dead', 'f', 'abc')), 503);
      expect(await status(g.uri('dead', 'f', 'nope')), 404);
      expect(await status(g.uri('other', 'f', 'abc')), 404);
      final wrong = g.uri('dead', 'f', 'abc').replace(pathSegments: ['f' * 40, 'dead', 'f', 'abc']);
      expect(await status(wrong), 404);
      // A path is never taken as a path.
      expect(await status(g.uri('dead', 'f', '..%2Fa.mkv')), 404);
      expect(await status(g.uri('dead', 'f', 'abc'), method: 'POST'), 405);
    });

    test("a reader that leaves mid-file: the file closes, reads on their way fail quietly", () async {
      final share = _ClosingShare(64 << 20);
      GatewayCore.openForTests = (address, who, {knownSmb1 = false, workers = 2}) async => share;
      addTearDown(() => GatewayCore.openForTests = null);
      await g.register('slow', GatewayTarget(address: SmbAddress.parse('smb://nas/slow')!, credentials: const SmbCredentials.guest()));
      await g.setFiles('slow', {'big': const GatewayFile(path: 'big.mkv', size: 64 << 20)});
      // A player that reads the first bytes, then goes (as it does when it
      // seeks), while the next window is still being read.
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, g.base.port);
      final uri = g.uri('slow', 'f', 'big');
      socket.write('GET ${uri.path} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
      final got = Completer<void>();
      final sub = socket.listen((data) {
        if (!got.isCompleted) got.complete();
      });
      await got.future;
      socket.destroy();
      await sub.cancel();
      // The gateway still answers.
      for (var i = 0; i < 50 && !share.closed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(share.closed, isTrue);
      // Reads still on their way fail once it's closed; their errors are
      // handled (any that weren't would fail this test).
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(await status(g.uri('dead', 'f', 'nope')), 404);
    });

    test('the secret changes each launch', () async {
      final first = g.base.secret;
      await SmbGateway.stop();
      g = await SmbGateway.ensureStarted();
      expect(g.base.secret, isNot(first));
      expect(g.base.secret.length, 40);
    });
  });
}

/// A share of one big file whose reads take a moment, and fail once the
/// file is closed (as an SMB1 read on a closed handle does).
class _ClosingShare implements SmbShare {
  _ClosingShare(this.size);
  final int size;
  bool closed = false;

  @override
  bool get smb1 => true;
  @override
  Future<SmbReader> open(String path) async => _SlowReader(this);
  @override
  Future<SmbEntry> stat(String path) async => SmbEntry(name: path, isFolder: false, size: size);
  @override
  Future<List<SmbEntry>> list(String path) async => const [];
  @override
  Future<void> write(String path, Uint8List data) async {}
  @override
  Future<void> rename(String from, String to) async {}
  @override
  Future<void> makeFolder(String path) async {}
  @override
  Future<void> delete(String path) async {}
  @override
  Future<void> close() async {}
}

class _SlowReader implements SmbReader {
  _SlowReader(this.share);
  final _ClosingShare share;
  @override
  int get size => share.size;
  @override
  Future<Uint8List> read(int offset, int length) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (share.closed) {
      throw const SmbException(SmbErrorKind.other, 'SMB1 status 0xc0000008');
    }
    return Uint8List(length);
  }

  @override
  Future<void> close() async => share.closed = true;
}
