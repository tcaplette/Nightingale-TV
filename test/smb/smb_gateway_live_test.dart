// The gateway against the Samba test shares (tool/test_servers): readers
// that hang up mid-answer, as ffprobe and the player do when they seek,
// many times over on SMB 2/3 and SMB1. Nothing may be left unhandled (the
// test fails on any error that is), and every answer starts right.
//   SMB_LIVE=1 SMB_PASSWORD=… flutter test test/smb/smb_gateway_live_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

final _live = Platform.environment['SMB_LIVE'] == '1';
final _user = SmbCredentials(user: 'smbtest', password: Platform.environment['SMB_PASSWORD'] ?? '');

void main() {
  final media = Platform.environment['NIGHTINGALE_TEST_SMB_MEDIA'] ?? '${Platform.environment['HOME']}/.cache/nightingale-test-smb-media';
  const path = 'Formats/Old Disc (1997).mpg';

  setUpAll(() => SmbGateway.inIsolate = false);
  tearDownAll(SmbGateway.stop);

  for (final (name, at) in [('SMB 2/3', '1445/archive'), ('SMB1', '1447/oldguest')]) {
    test('$name: readers that hang up mid-answer, again and again', () async {
      final size = File('$media/$path').lengthSync();
      final g = await SmbGateway.ensureStarted();
      final target = 'live-${name.replaceAll(RegExp(r'\W'), '')}';
      await g.register(target, GatewayTarget(address: SmbAddress.parse('smb://127.0.0.1:$at')!, credentials: at.endsWith('guest') ? const SmbCredentials.guest() : _user, smb1: name == 'SMB1'));
      await g.setFiles(target, {'f': GatewayFile(path: path, size: size)});
      final expected = File('$media/$path').openSync();
      addTearDown(expected.closeSync);
      for (var i = 0; i < 40; i++) {
        final start = (size ~/ 41) * i;
        final socket = await Socket.connect(InternetAddress.loopbackIPv4, g.base.port);
        socket.write('GET ${g.uri(target, i.isEven ? 'f' : 'b', 'f').path} HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: bytes=$start-\r\n\r\n');
        final got = <int>[];
        final enough = Completer<void>();
        final sub = socket.listen((d) {
          got.addAll(d);
          if (got.length > 600000 && !enough.isCompleted) enough.complete();
        }, onDone: () => enough.isCompleted ? null : enough.complete());
        await enough.future.timeout(const Duration(seconds: 20));
        socket.destroy();
        await sub.cancel();
        // The body starts at the range asked for.
        final head = String.fromCharCodes(got.take(400));
        expect(head, startsWith('HTTP/1.1 206'), reason: 'request $i');
        final bodyAt = head.indexOf('\r\n\r\n') + 4;
        expected.setPositionSync(start);
        expect(got.sublist(bodyAt, bodyAt + 1000), expected.readSync(1000), reason: 'request $i');
      }
      // Readers gone: the reads on their way end, and nothing breaks.
      await Future<void>.delayed(const Duration(seconds: 3));
      final c = HttpClient();
      addTearDown(c.close);
      final again = await (await c.getUrl(g.uri(target, 'f', 'f'))).close();
      expect(again.statusCode, 200);
      await again.drain<void>();
    }, timeout: const Timeout(Duration(minutes: 3)), skip: !_live);
  }
}
