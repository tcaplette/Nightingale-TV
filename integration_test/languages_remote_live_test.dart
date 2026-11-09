// The phone remote and backup transfer pages follow the TV's language
// (app-languages 8.8). The app side of tool/web_admin_tests/languages_remote.js:
// it writes the ports and code to $REMOTE_DIR/info.json, then does what
// $REMOTE_DIR/command says (`lang de`, `transfer`, `done`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nightingale_tv/backup/transfer_server.dart';
import 'package:nightingale_tv/backup/backup_scheduler.dart';
import 'package:nightingale_tv/backup/backup_store.dart';
import 'package:nightingale_tv/l10n/tr.dart';

import '../test/fixtures.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('remote and transfer pages', (tester) async {
    final out = Platform.environment['REMOTE_DIR'];
    if (out == null) {
      markTestSkipped('Set REMOTE_DIR.');
      return;
    }
    final h = await UiHarness.start(tester, fakeLibrary(shows: const {'Cheers': 20}), remote: true);
    final household = h.household;
    await tester.runAsync(() => household.setLanguage(household.current!, 'de'));
    await languageDataReady;
    expect(activeLanguage, 'de');
    final remote = household.remote!;
    remote.openPairing();
    final backups = household.backups ??= BackupScheduler(household, BackupStore(Directory('$out/backups')));
    TransferServer? transfer;
    final info = File('$out/info.json');
    final command = File('$out/command');
    Future<void> write(Map<String, Object?> extra) async =>
        tester.runAsync(() => info.writeAsString(jsonEncode({'port': remote.port, 'code': remote.pairingCode, ...extra})));
    await write({});
    var last = '';
    var extra = <String, Object?>{};
    for (var i = 0; i < 2400; i++) {
      await h.wait(const Duration(milliseconds: 100));
      final now = await tester.runAsync(() async => await command.exists() ? (await command.readAsString()).trim() : '');
      if (now == last || now == null || now.isEmpty) continue;
      last = now;
      final words = now.split(' ');
      if (words[1] == 'done') break;
      if (words[1] == 'lang') {
        await tester.runAsync(() => household.setLanguage(household.current!, words[2]));
        extra = {...extra, 'lang': activeLanguage, 'seq': words[0]};
      } else if (words[1] == 'transfer') {
        transfer = TransferServer(backups, onUpload: (_) {});
        final url = (await tester.runAsync(transfer.start))!;
        extra = {...extra, 'transfer': url.toString().replaceFirst(url.host, '127.0.0.1'), 'seq': words[0]};
      }
      await write(extra);
    }
    await tester.runAsync(() async => transfer?.stop());
    await h.dispose();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
