# sentry_flutter 10.3.0, Android and Apple plugins only

This is the upstream `sentry_flutter` 10.3.0 package (MIT, see `LICENSE`).
`pubspec.yaml` swaps it in with `dependency_overrides`.

## Changed

- `pubspec.yaml`: the `linux`, `windows` and `web` plugin entries are removed.
- The `linux/`, `windows/`, `sentry-native/`, `example/`, `test/` and
  `scripts/` folders are left out.

- `android/src/main/kotlin/io/sentry/flutter/NightingaleScrub.kt` (new), called
  from `SentryFlutterPlugin.setupBeforeSend`: Java/Kotlin crash and freeze
  events, which the Android SDK sends without passing through Dart, get the
  same personal-data scrub as Dart events (`lib/reporting/report_scrubber.dart`).
  `MainActivity` hands it the household's names.

The Dart code is unchanged.

## Why

Upstream's Linux and Windows plugin fetches sentry-native from GitHub during
`flutter build linux` and bundles `libsentry.so` and a crash handler. Nightingale
TV reports only Dart errors on Linux (error-reporting design D1), so the
Linux app and server mode start the pure-Dart `Sentry.init` from
`package:sentry` instead (`lib/reporting/error_reports.dart`), and the `.deb`
gains no native library and the build needs no network fetch. The web admin
doesn't report, so the web plugin isn't registered there either.

On Android the plugin is unchanged; `android/app/build.gradle.kts` excludes
`io.sentry:sentry-android-ndk`, so native (NDK) crash handling is off.
