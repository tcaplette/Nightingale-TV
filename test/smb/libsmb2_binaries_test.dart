import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the libsmb2 binaries are the ones dart_smb2 pins', () async {
    final folder = Directory('third_party/libsmb2');
    final sums = {
      for (final line in await File('${folder.path}/SHA256SUMS').readAsLines())
        if (line.trim().isNotEmpty) line.split(RegExp(r'\s+'))[1]: line.split(RegExp(r'\s+'))[0],
    };
    final files = folder.listSync().whereType<File>().where((f) => f.path.endsWith('.so')).toList();
    expect({for (final f in files) f.uri.pathSegments.last}, sums.keys.toSet());
    for (final f in files) {
      expect(sha256.convert(await f.readAsBytes()).toString(), sums[f.uri.pathSegments.last], reason: f.path);
    }
    // The package's own table names the same files.
    final hook = await File(
            '${Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache'}/hosted/pub.dev/dart_smb2-0.5.0/hook/build.dart')
        .readAsString();
    for (final e in sums.entries) {
      expect(hook, contains(e.value), reason: e.key);
    }
  });
}
