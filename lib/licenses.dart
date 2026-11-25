import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licences of what the app bundles that Flutter's licence page
/// doesn't list by itself (smb-sources): libsmb2 and OpenSSL inside
/// dart_smb2's library, and FFmpeg with x264, zimg and dav1d on Android.
/// Their texts are in `assets/licenses`.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, file) in const [
      (['dart_smb2'], 'dart_smb2'),
      (['libsmb2'], 'libsmb2'),
      (['OpenSSL'], 'openssl'),
      (['FFmpeg'], 'ffmpeg'),
      (['x264'], 'x264'),
      (['zimg'], 'zimg'),
      (['dav1d'], 'dav1d'),
    ]) {
      yield LicenseEntryWithLineBreaks(packages, await rootBundle.loadString('assets/licenses/$file.txt'));
    }
  });
}
