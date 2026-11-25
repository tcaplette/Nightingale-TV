# libsmb2 binaries

The libsmb2-r14 release binaries of [dart_smb2](https://github.com/ales-drnz/dart_smb2)
0.5.0, for the platforms Nightingale TV is built for. `pubspec.yaml` points
dart_smb2's build hook at this folder (`hooks.user_defines`), so a build
needs no network and a removed download can't break a release.

- libsmb2, LGPL-2.1-or-later, loaded as a shared library; OpenSSL's
  libcrypto, Apache-2.0, is linked into it.
- Corresponding source: https://github.com/ales-drnz/libsmb2-scripts, at the
  commit named by the libsmb2-r14 release of dart_smb2.
- `SHA256SUMS` holds the checksums dart_smb2 pins for that release;
  `test/smb/libsmb2_binaries_test.dart` checks the files against it, since
  the hook doesn't check local copies.

To use a build of your own, replace a file with one built by libsmb2-scripts
at the same release. A new dart_smb2 version needs the files of the release
it names in `lib/src/libsmb2_release.dart`.
