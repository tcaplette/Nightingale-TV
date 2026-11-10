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

# Official builds report errors to the Nightingale TV GlitchTip project
# (error-reporting D2). The DSN lives in the git-ignored error_reporting.env;
# without it the app is built with reporting off.
DEFINES=()
[[ -f error_reporting.env ]] && DEFINES=(--dart-define-from-file=error_reporting.env)

VERSION="${1:-$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)}"
FILE="nightingale-tv-linux-x64-${VERSION}.tar.gz"

flutter build linux --release ${DEFINES[@]+"${DEFINES[@]}"}
tool/build_web_admin.sh

BUNDLE=build/linux/x64/release/bundle
rm -rf "$BUNDLE/web"
cp -r build/web "$BUNDLE/web"
# The service worker isn't used (--pwa-strategy=none leaves a stub).
rm -f "$BUNDLE/web/flutter_service_worker.js"

# NTV_DIST puts the archive in another folder, like dist/1.2.4.
DIST="${NTV_DIST:-dist}"
mkdir -p "$DIST"
tar -C "$BUNDLE" -czf "$DIST/$FILE" .
(cd "$DIST" && sha256sum "$FILE" > "$FILE.sha256" && cat "$FILE.sha256")
