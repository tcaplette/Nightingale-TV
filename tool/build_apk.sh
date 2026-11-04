#!/usr/bin/env bash
# Builds signed release APKs of Nightingale TV for sideloading on Android
# TVs, phones and tablets:
#   dist/nightingale-tv_<version>_arm64-v8a.apk    most TVs and phones
#   dist/nightingale-tv_<version>_armeabi-v7a.apk  older or cheaper TV boxes
#   dist/nightingale-tv_<version>_x86_64.apk       Android Studio emulators
#   dist/nightingale-tv_<version>_universal.apk    any of these (much larger)
# Signed with the release key named in android/key.properties. Only a key
# listed in android/official_signing_cert.txt makes "Nightingale TV"; any
# other key makes "Nightingale TV (own build)", a separate app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tool/check_version.sh

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
DIST="$ROOT/dist"
mkdir -p "$DIST"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
APKSIGNER="$(ls -d "$SDK"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)"
if [[ -z "$APKSIGNER" ]]; then
  echo "apksigner not found under $SDK/build-tools; install the Android SDK build tools." >&2
  exit 1
fi

# One APK per architecture: Android picks the matching one, and each is a
# fraction of the universal APK's size.
flutter build apk --release --split-per-abi --target-platform "$PLATFORMS"
OUT=()
for abi in arm64-v8a armeabi-v7a x86_64; do
  dest="$DIST/nightingale-tv_${VERSION}_${abi}.apk"
  cp "$APKS/app-${abi}-release.apk" "$dest"
  OUT+=("$dest")
done

flutter build apk --release --target-platform "$PLATFORMS"
dest="$DIST/nightingale-tv_${VERSION}_universal.apk"
cp "$APKS/app-release.apk" "$dest"
OUT+=("$dest")

for apk in "${OUT[@]}"; do
  "$APKSIGNER" verify "$apk"
done

echo "Built and verified:"
for apk in "${OUT[@]}"; do
  echo "  $apk ($(du -h "$apk" | cut -f1))"
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
