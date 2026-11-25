// A TV pairing with a running Nightingale TV server's "Convert for other
// TVs" (the Docker image, or the Linux app with --server) and having it
// convert a share's file. HELPER is its address, HELPER_CODE the code its web
// admin shows, SHARE_ID the share's id there (`.nightingale/share.json`).
//   HELPER=127.0.0.1:8487 HELPER_CODE=… SHARE_ID=… flutter test test/smb/helper_server_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/convert/conversion.dart';
import 'package:nightingale_tv/convert/convert_helpers.dart';
import 'package:nightingale_tv/data/app_storage.dart';

final _env = Platform.environment;

void main() {
  test('paired by its code, it converts a file of the share for this TV', () async {
    final dir = await Directory.systemTemp.createTemp('tv');
    addTearDown(() => dir.delete(recursive: true));
    final tv = ConvertHelpers(await AppStorage.at(Directory(dir.path)), deviceName: 'Test TV');
    final url = ConvertHelpers.parseAddress(_env['HELPER']!)!;
    expect(await tv.pair(url, _env['HELPER_CODE']!), isTrue);
    final helper = tv.helpers.single;
    expect(await tv.helperFor(_env['SHARE_ID']!), helper.id, reason: 'it has the share');
    // The file, as the TV's own scan knows it.
    const path = 'Formats/Windows Media (2001).wmv';
    final file = File('${_env['HOME']}/.cache/nightingale-test-smb-media/$path');
    final id = sha256.convert(utf8.encode(path)).toString().substring(0, 20);
    final query = {
      ...const ConversionSpec(videoBitrate: 2000000, startAt: Duration(seconds: 20)).toQuery(),
      'share': _env['SHARE_ID']!, 'item': id, 'size': '${file.lengthSync()}', //
      'modified': '${file.lastModifiedSync().millisecondsSinceEpoch}',
    };
    final c = HttpClient();
    addTearDown(() => c.close(force: true));
    final r = await c.getUrl(helper.url.replace(path: '/convert', queryParameters: query));
    r.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${helper.key}');
    final a = await r.close();
    expect(a.statusCode, 200);
    var n = 0, first = -1;
    await for (final chunk in a) {
      if (first < 0 && chunk.isNotEmpty) first = chunk[0];
      n += chunk.length;
      if (n > 500000) break;
    }
    expect(first, 0x47, reason: 'MPEG-TS');
    // ignore: avoid_print
    print('converted on the server: $n bytes');
  }, skip: _env['HELPER'] == null);
}
