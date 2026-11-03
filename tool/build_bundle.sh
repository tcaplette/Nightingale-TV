#!/usr/bin/env bash
# Builds the Google Play app bundle of Nightingale TV:
#   dist/nightingale-tv_<version>.aab
# Only with the official key (android/official_signing_cert.txt): with any
# other key the bundle would be "Nightingale TV (own build)", which isn't the
# store app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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

VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
DIST="$ROOT/dist"
mkdir -p "$DIST"

flutter build appbundle --release
dest="$DIST/nightingale-tv_${VERSION}.aab"
cp build/app/outputs/bundle/release/app-release.aab "$dest"

echo "Built:"
echo "  $dest ($(du -h "$dest" | cut -f1))"
