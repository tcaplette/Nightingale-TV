#!/usr/bin/env bash
# Builds the Linux release the Docker image downloads (docker-web-admin D10):
#   dist/nightingale-tv-linux-x64-<version>.tar.gz and its .sha256
# The Linux app's bundle, with the web admin in its web/ folder (where server
# mode serves it from). Fails if either doesn't build, so a shared model that
# picks up dart:io fails the release instead of shipping.
#
#   tool/build_linux_release.sh 1.2.0
# The "Linux release" workflow runs this for a version tag.
set -euo pipefail
cd "$(dirname "$0")/.."
tool/check_version.sh
source tool/debug_files.sh

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

VERSION="${1:-$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)}"
FILE="nightingale-tv-linux-x64-${VERSION}.tar.gz"
# NTV_DIST puts the archive in another folder, like dist/1.2.4.
DIST="${NTV_DIST:-dist}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
# The debug file of the Dart code (library-scan-anr D3), for
# tool/symbolize_event.py. Kept beside the archive, never inside it.
DEBUG="$DIST/symbols/libapp-linux-x64.debug"
mkdir -p "$DIST/symbols"
SAVING="$(debug_files_fresh "$DEBUG")"

flutter build linux --release "$(debug_files_option "$SAVING")" ${DEFINES[@]+"${DEFINES[@]}"}
debug_files_keep "$SAVING" "$DEBUG"
tool/build_web_admin.sh

# Where `flutter build linux` puts the app: the default flavor's folder
# (pubspec default-flavor: free), not build/linux/x64/release.
BUNDLE=build/linux/x64/free/release/bundle
rm -rf "$BUNDLE/web"
cp -r build/web "$BUNDLE/web"
# The service worker isn't used (--pwa-strategy=none leaves a stub).
rm -f "$BUNDLE/web/flutter_service_worker.js"

echo "Checking the debug file:"
debug_files_check_linux "$BUNDLE/lib/libapp.so" "$DEBUG"
tar -C "$BUNDLE" -czf "$DIST/$FILE" .
tar -tzf "$DIST/$FILE" | debug_files_none_inside "$FILE"
(cd "$DIST" && sha256sum "$FILE" > "$FILE.sha256" && cat "$FILE.sha256")
echo "Debug file (keep it with this release; tool/symbolize_event.py reads it): $DEBUG"
