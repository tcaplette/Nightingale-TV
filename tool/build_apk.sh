#!/usr/bin/env bash
# Builds signed release APKs of Nightingale TV for sideloading on Android
# TVs, phones and tablets:
#   dist/nightingale-tv_<version>_arm64-v8a.apk    most TVs and phones
#   dist/nightingale-tv_<version>_armeabi-v7a.apk  older or cheaper TV boxes
#   dist/nightingale-tv_<version>_x86_64.apk       Android Studio emulators
#   dist/nightingale-tv_<version>_universal.apk    any of these (much larger)
#   dist/symbols/libapp-<abi>.debug                 the Dart code's debug files
# They are the free flavor (play-unlock): no Play Billing, no trial, nothing
# locked. Signed with the release key named in android/key.properties. Only a key
# listed in android/official_signing_cert.txt makes "Nightingale TV"; any
# other key makes "Nightingale TV (own build)", a separate app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tool/check_version.sh
# Converting files of SMB shares on the device (smb-conversion).
tool/build_ffmpeg_android.sh
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
# YouTube's shared Google client (youtube-subscriptions D4).
source tool/youtube_client.sh
youtube_client_check

if [[ ! -f android/key.properties ]]; then
  cat >&2 <<'HELP'
android/key.properties is missing, so there's no release key to sign with.

Create a key once, and keep it (and its passwords) somewhere safe outside
this repository. Every future update must be signed with the same key:

  keytool -genkey -v -keystore ~/nightingale-tv-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias nightingale-tv

Then create android/key.properties (it's git-ignored) with:

  storeFile=/home/<you>/nightingale-tv-release.jks
  storePassword=<keystore password>
  keyAlias=nightingale-tv
  keyPassword=<key password>

Or leave the two password lines out and pass them when building:

  NIGHTINGALE_TV_STORE_PASSWORD=... NIGHTINGALE_TV_KEY_PASSWORD=... tool/build_apk.sh
HELP
  exit 1
fi

VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
PLATFORMS=android-arm,android-arm64,android-x64
APKS=build/app/outputs/flutter-apk
# NTV_DIST puts the APKs in another folder, like dist/1.2.4.
DIST="${NTV_DIST:-$ROOT/dist}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
# The debug files of the Dart code (library-scan-anr D3), one per ABI, for
# tool/symbolize_event.py. Kept beside the APKs, never inside them.
SYMBOLS="$DIST/symbols"
mkdir -p "$SYMBOLS"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
APKSIGNER="$(ls -d "$SDK"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)"
AAPT2="$(ls -d "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
if [[ -z "$APKSIGNER" || -z "$AAPT2" ]]; then
  echo "apksigner or aapt2 not found under $SDK/build-tools; install the Android SDK build tools." >&2
  exit 1
fi

# One APK per architecture: Android picks the matching one, and each is a
# fraction of the universal APK's size. Built one at a time, because the
# debug file option names one file and every ABI would write it.
OUT=()
for target in android-arm64:arm64-v8a android-arm:armeabi-v7a android-x64:x86_64; do
  platform="${target%%:*}" abi="${target##*:}"
  debug="$SYMBOLS/libapp-$abi.debug" saving="$(debug_files_fresh "$SYMBOLS/libapp-$abi.debug")"
  flutter build apk --release --flavor free --split-per-abi --target-platform "$platform" \
    "$(debug_files_option "$saving")" ${DEFINES[@]+"${DEFINES[@]}"}
  debug_files_keep "$saving" "$debug"
  dest="$DIST/nightingale-tv_${VERSION}_${abi}.apk"
  cp "$APKS/app-${abi}-free-release.apk" "$dest"
  OUT+=("$dest")
done

# The universal APK needs no debug file of its own: the Dart compile is
# deterministic, so each ABI's libapp.so is the split APK's (the build ID
# check below proves it).
flutter build apk --release --flavor free --target-platform "$PLATFORMS" ${DEFINES[@]+"${DEFINES[@]}"}
dest="$DIST/nightingale-tv_${VERSION}_universal.apk"
cp "$APKS/app-free-release.apk" "$dest"
OUT+=("$dest")

for apk in "${OUT[@]}"; do
  "$APKSIGNER" verify "$apk"
  store_check_apk_has_no_billing "$AAPT2" "$apk"
done

# Every libapp.so has its ABI's debug file, and no APK holds one.
echo "Checking debug files:"
for apk in "${OUT[@]}"; do
  debug_files_check_android "$apk" "$SYMBOLS"
done
debug_files_engine "$SYMBOLS"

echo "Built and verified:"
for apk in "${OUT[@]}"; do
  echo "  $apk ($(du -h "$apk" | cut -f1))"
done
echo "Debug files (keep them with this release; tool/symbolize_event.py reads them):"
for debug in "$SYMBOLS"/libapp-*.debug; do
  echo "  $debug ($(du -h "$debug" | cut -f1))"
done

# The certificate the APKs were signed with, against the official ones
# (install-switching D5). Gradle made the same check when choosing the id.
cert="$("$APKSIGNER" verify --print-certs "${OUT[-1]}" | sed -n 's/.*certificate SHA-256 digest: *//p' | head -1)"
if ! tool/official_cert.sh "$cert"; then
  cat <<'WARNING'

These APKs aren't signed with the official Nightingale TV key, so they
install as "Nightingale TV (own build)": a separate app from the Google Play
version, with its own profiles, channels and settings.
Both can be installed on one device. To use the store version's setup here,
or this setup in the store version, open Backup & restore and pick
"Move my setup to …" before uninstalling either; uninstalling deletes that
app's setup.
WARNING
fi
