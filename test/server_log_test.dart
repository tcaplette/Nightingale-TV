import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/server/server_log.dart';

void main() {
  final lines = <String>[];
  late DebugPrintCallback saved;

  setUp(() {
    lines.clear();
    saved = debugPrint;
    ServerLog.output = lines.add;
    ServerLog.install();
  });
  tearDown(() {
    debugPrint = saved;
    ServerLog.reset();
  });

  test("the log never carries a token, the Plex token or a password", () {
    const jellyfinToken = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
    const plexToken = 'PxTk-9zYw8vU7tS6';
    const adminPassword = 'correct horse';
    const jellyfinPassword = 'hunter2hunter2';
    ServerLog.secret(jellyfinToken);
    ServerLog.secret(plexToken);
    ServerLog.secret(adminPassword);
    ServerLog.secret(jellyfinPassword);

    debugPrint('Live TV export: serving Mom on port 5004.');
    debugPrint('No art for s1 from al1: ClientException: http://jf.lan:8096/Items/al1/Images/Primary?api_key=$jellyfinToken');
    debugPrint('Plex image failed: https://10.0.0.5:32400/photo/:/transcode?url=x&X-Plex-Token=$plexToken');
    debugPrint('Request header was X-Plex-Token: $plexToken');
    debugPrint('MediaBrowser Client="Nightingale TV", Token="$jellyfinToken"');
    debugPrint('Sign-in failed for Mom with password $jellyfinPassword');
    debugPrint('Admin sign-in attempt "$adminPassword" refused');
    debugPrint('Live source failed: http://user:iptvpass@iptv.example/get.php?username=user&password=iptvpass');

    final log = lines.join('\n');
    for (final secret in [jellyfinToken, plexToken, adminPassword, jellyfinPassword, 'iptvpass']) {
      expect(log, isNot(contains(secret)), reason: secret);
    }
    expect(log, contains('serving Mom on port 5004'));
    expect(log, contains('http://jf.lan:8096/Items/al1/Images/Primary'));
    expect(lines.first, matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d ')));
  });

  test('the setup link is written as it is', () {
    ServerLog.raw('Open http://192.168.1.20:8484/setup?token=abc123 to set up Nightingale TV.');
    expect(lines.single, endsWith('Open http://192.168.1.20:8484/setup?token=abc123 to set up Nightingale TV.'));
  });
}
