import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/convert/conversion.dart';
import 'package:nightingale_tv/convert/convert_helper.dart';
import 'package:nightingale_tv/convert/convert_helpers.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/server/smb/secret_store.dart';
import 'package:nightingale_tv/server/smb/smb_gateway.dart';
import 'package:nightingale_tv/server/smb/smb_library.dart';
import 'package:nightingale_tv/server/smb/smb_open.dart';
import 'package:nightingale_tv/server/smb/smb_share.dart';

/// A helper converting a Samba share's file for a paired TV:
/// `SMB_LIVE=1 SMB_PASSWORD=… flutter test test/smb/convert_helper_live_test.dart`.
final _live = Platform.environment['SMB_LIVE'] == '1';

void main() {
  late Directory dir;
  late ConvertHelper helper;
  late ConvertHelpers tv;
  late SmbScan scan;
  const shareId = 'smb-helper-test';
  const port = 18487;

  setUpAll(() async {
    if (!_live) return;
    SmbGateway.inIsolate = false;
    dir = await Directory.systemTemp.createTemp('helper');
    // The helper's household: one profile with the share, Formats mapped.
    final root = await AppStorage.at(Directory('${dir.path}/helper'));
    final profile = await AppStorage.at(Directory('${dir.path}/helper/profiles/p1'), logosDir: root.logosDir);
    final ref = await SecretStore(profile)
        .put(SmbCredentials(user: 'smbtest', password: Platform.environment['SMB_PASSWORD'] ?? ''));
    await profile.writeJson('session.json', {
      'kind': 'smb', 'serverUrl': 'smb://127.0.0.1:1445/archive', 'serverName': 'archive', 'serverId': shareId, //
      'userId': 'smbtest', 'userName': 'smbtest', 'accessToken': ref, 'deviceId': 'd',
    });
    await profile.writeJson('smb_shares.json', {
      'shares': {
        shareId: {
          'folders': [
            {'path': 'Formats', 'type': 'movies'}
          ]
        }
      }
    });
    final share = await openSmbShare(SmbAddress.parse('smb://127.0.0.1:1445/archive')!,
        SmbCredentials(user: 'smbtest', password: Platform.environment['SMB_PASSWORD'] ?? ''));
    scan = await SmbScanner(share, const [SmbMapping('Formats', SmbFolderType.movies), SmbMapping('Commercials', SmbFolderType.commercials)]).scan();
    await share.close();
    await profile.writeJson('smb_scan/${smbIdOf(shareId)}.json', scan.toJson());
    await profile.flush();
    helper = ConvertHelper(root, deviceName: 'Test PC', port: port);
    await helper.load();
    await helper.setOn(true);
    tv = ConvertHelpers(await AppStorage.at(Directory('${dir.path}/tv')), deviceName: 'Living room TV');
    await SmbGateway.ensureStarted();
  });

  tearDownAll(() async {
    if (!_live) return;
    await helper.stop();
    await SmbGateway.stop();
    await dir.delete(recursive: true);
  });

  Future<(int, int)> get(Uri uri, {String? key, int want = 300000}) async {
    final c = HttpClient();
    try {
      final r = await c.getUrl(uri);
      if (key != null) r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      final a = await r.close();
      var n = 0, first = -1;
      await for (final chunk in a) {
        if (first < 0 && chunk.isNotEmpty) first = chunk[0];
        n += chunk.length;
        if (n >= want) break;
      }
      return (a.statusCode, first);
    } finally {
      c.close(force: true);
    }
  }

  test('found by SSDP, paired by its code, wrong codes change it', () async {
    final found = await tv.find();
    expect(found.map((f) => f.name), contains('Test PC'));
    final url = ConvertHelpers.parseAddress('127.0.0.1:$port')!;
    final code = helper.code!;
    for (var i = 0; i < 5; i++) {
      expect(await tv.pair(url, '000000' == code ? '111111' : '000000'), isFalse);
    }
    expect(helper.code, isNot(code), reason: 'five wrong codes make a new one');
    expect(await tv.pair(url, helper.code!), isTrue);
    expect(helper.pairings.single.name, 'Living room TV');
    // Only a hash of the key is kept on the helper.
    final saved = File('${dir.path}/helper/${ConvertHelper.file}').readAsStringSync();
    expect(saved, isNot(contains(tv.helpers.single.key)));
    expect(await tv.helperFor(shareId), tv.helpers.single.id);
    expect(await tv.helperFor('another-share'), isNull);
    expect(tv.knownFor(shareId), isTrue);
  }, skip: !_live, timeout: const Timeout(Duration(seconds: 60)));

  test('refused without a key, outside the mapped folders, or for a changed file; converts otherwise', () async {
    final base = Uri.parse('http://127.0.0.1:$port/convert');
    final wmv = scan.items.firstWhere((i) => i.path == 'Formats/Windows Media (2001).wmv');
    final spot = scan.items.firstWhere((i) => i.path.startsWith('Commercials/'));
    Map<String, String> ask(SmbItem i) => {
          ...const ConversionSpec(videoBitrate: 2000000, startAt: Duration(seconds: 20)).toQuery(),
          'share': shareId, 'item': i.id, 'size': '${i.size}', 'modified': '${i.modified}',
        };
    // No key: nothing at all, not even the list.
    expect((await get(base.replace(queryParameters: ask(wmv)))).$1, 401);
    expect((await get(Uri.parse('http://127.0.0.1:$port/info'))).$1, 401);
    final about = jsonDecode(await (await (await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$port/about'))).close()).transform(utf8.decoder).join());
    expect((about as Map).keys.toSet(), {'service', 'name', 'id'});
    final key = tv.helpers.single.key;
    expect((await get(base.replace(queryParameters: ask(spot)), key: key)).$1, 403, reason: 'not in a folder mapped there');
    expect((await get(base.replace(queryParameters: {...ask(wmv), 'size': '1'}), key: key)).$1, 403);
    // The TV's own gateway asks the helper: the address, path and password
    // of the share are never in the request.
    final got = await get(base.replace(queryParameters: ask(wmv)), key: key);
    expect(got, (200, 0x47));
    final gateway = SmbGateway.instance;
    await gateway.register('tv', GatewayTarget(address: SmbAddress.parse('smb://127.0.0.1:1445/archive')!, credentials: const SmbCredentials.guest(), serverId: shareId));
    await gateway.setFiles('tv', {wmv.id: GatewayFile(path: wmv.path, size: wmv.size, modified: wmv.modified)});
    await tv.helperFor(shareId);
    final viaTv = gateway.uri('tv', 'c', wmv.id, const ConversionSpec(startAt: Duration(seconds: 5)).copyWith(job: 'j1', helper: () => tv.helpers.single.id).toQuery());
    expect(await get(viaTv), (200, 0x47));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(helper.running, 0, reason: 'the TV left, and the conversion ended');
  }, skip: !_live, timeout: const Timeout(Duration(seconds: 90)));
}
