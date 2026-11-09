/// The app's version, the x.y.z of `version:` in pubspec.yaml. Servers show
/// it as this app's version (Jellyfin and Emby's Devices page, Plex's).
///
/// Bump it with pubspec.yaml: test/app_version_test.dart and every release
/// build (tool/check_version.sh) fail while the two differ.
const appVersion = '1.2.1';
