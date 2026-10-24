#!/usr/bin/env bash
# Builds the web admin (docker-web-admin design D1) into build/web: CanvasKit
# and fonts bundled, no CDN, no service worker, so it works with no internet.
# It fails if code the web admin imports can't run in a browser (dart:io).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web -t lib/web_admin/main.dart --release --no-web-resources-cdn --pwa-strategy=none "$@"
