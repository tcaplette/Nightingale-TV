#!/usr/bin/env bash
# Builds the Google Play app bundle of Nightingale TV:
#   dist/nightingale-tv_<version>.aab
#   dist/symbols/play/libapp-<abi>.debug   the Dart code's debug files
# It is the play flavor (play-unlock): Google Play Billing, a 14-day free
# trial and the one-time unlock.
# Only with the official key (android/official_signing_cert.txt): with any
# other key the bundle would be "Nightingale TV (own build)", which isn't the
# store app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tool/check_version.sh
source tool/store_checks.sh
source tool/debug_files.sh
store_refuse_test_defines error_reporting.env
store_refuse_test_defines sharing.env

# Official builds report errors to the Nightingale TV GlitchTip project
# (error-reporting D2). The DSN lives in the git-ignored error_reporting.env;
# without it the app is built with reporting off.
DEFINES=()
[[ -f error_reporting.env ]] && DEFINES=(--dart-define-from-file=error_reporting.env)
# Sharing (share-accounts D2): the backend's address, public key and
# invite-link host live in the git-ignored sharing.env (the official backend's,
# or your own: sharing.env.example, SELF_HOSTING.md); without it the app is
# built with no sharing at all.
[[ -f sharing.env ]] && DEFINES+=(--dart-define-from-file=sharing.env)

if [[ ! -f android/key.properties ]]; then
  echo "android/key.properties is missing, so there's no key to sign the store bundle with." >&2
  echo "Store bundles must be signed with the official Nightingale TV key; see tool/build_apk.sh for the file's contents." >&2
  exit 1
fi

prop() { sed -n "s/^$1=//p" android/key.properties | head -1; }
STORE_FILE="$(prop storeFile)"
KEY_ALIAS="$(prop keyAlias)"
# Relative paths in key.properties are from android/app, as Gradle reads them.
[[ "$STORE_FILE" = /* ]] || STORE_FILE="android/app/$STORE_FILE"
export NTV_STORE_PASSWORD="$(prop storePassword)"
NTV_STORE_PASSWORD="${NTV_STORE_PASSWORD:-${NIGHTINGALE_TV_STORE_PASSWORD:-}}"

cert="$(keytool -list -v -keystore "$STORE_FILE" -alias "$KEY_ALIAS" -storepass:env NTV_STORE_PASSWORD 2>/dev/null \
  | sed -n 's/^[[:space:]]*SHA256: *//p' | head -1)" || true
if [[ -z "$cert" ]]; then
  echo "Couldn't read the key \"$KEY_ALIAS\" from $STORE_FILE (check android/key.properties and its passwords)." >&2
  exit 1
fi
if ! tool/official_cert.sh "$cert"; then
  cat >&2 <<'HELP'
Store bundles must be signed with the official Nightingale TV key, and the
key in android/key.properties isn't listed in android/official_signing_cert.txt.
With any other key the bundle would be "Nightingale TV (own build)".
To sideload your own build, use tool/build_apk.sh.
HELP
  exit 1
fi

# The play flavor's purchase module (android/app/src/play/, git-ignored) is
# kept off the public repository: without it there's no store bundle.
if [[ ! -d android/app/src/play ]]; then
  echo "android/app/src/play/ is missing: the Google Play purchase module isn't in the public repository," >&2
  echo "so this checkout can't build the store bundle. Use tool/build_apk.sh for the free APKs." >&2
  exit 1
fi

VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
# NTV_DIST puts the bundle in another folder, like dist/1.2.4.
DIST="${NTV_DIST:-$ROOT/dist}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
# The debug files of the Dart code (library-scan-anr D3), one per ABI, for
# tool/symbolize_event.py. The play flavor's code isn't the APKs', so its
# files have their own folder. Kept beside the bundle, never inside it.
SYMBOLS="$DIST/symbols/play"
mkdir -p "$SYMBOLS"

# The debug file option names one file, and every ABI would write it: one
# build per ABI saves them. Only their debug files are kept.
for target in android-arm64:arm64-v8a android-arm:armeabi-v7a android-x64:x86_64; do
  platform="${target%%:*}" abi="${target##*:}"
  debug="$SYMBOLS/libapp-$abi.debug" saving="$(debug_files_fresh "$SYMBOLS/libapp-$abi.debug")"
  flutter build appbundle --release --flavor play --target-platform "$platform" \
    "$(debug_files_option "$saving")" ${DEFINES[@]+"${DEFINES[@]}"}
  debug_files_keep "$saving" "$debug"
done

# The store bundle, with every ABI. The Dart compile is deterministic, so
# its libapp.so files are the ones above (the build ID check proves it).
flutter build appbundle --release --flavor play ${DEFINES[@]+"${DEFINES[@]}"}
dest="$DIST/nightingale-tv_${VERSION}.aab"
cp build/app/outputs/bundle/playRelease/app-play-release.aab "$dest"
store_check_bundle "$dest" "${VERSION#*+}"
echo "Checking debug files:"
debug_files_check_android "$dest" "$SYMBOLS"

echo "Built:"
echo "  $dest ($(du -h "$dest" | cut -f1))"
echo "Debug files (keep them with this release; tool/symbolize_event.py reads them):"
for debug in "$SYMBOLS"/libapp-*.debug; do
  echo "  $debug ($(du -h "$debug" | cut -f1))"
done
