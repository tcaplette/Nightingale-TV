import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the bundled libraries are on the licence page', () async {
    registerBundledLicenses();
    final packages = <String>{};
    await for (final e in LicenseRegistry.licenses) {
      packages.addAll(e.packages);
    }
    expect(packages, containsAll(['dart_smb2', 'libsmb2', 'OpenSSL', 'FFmpeg', 'x264', 'zimg', 'dav1d']));
  });
}
