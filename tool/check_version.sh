#!/usr/bin/env bash
# Stops a release build when lib/app_version.dart's appVersion isn't the
# x.y.z of pubspec.yaml's version, so servers never see a stale version.
# The build scripts run it first; run it on its own any time.
set -euo pipefail
cd "$(dirname "$0")/.."

PUBSPEC="$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)"
APP="$(sed -n "s/^const appVersion = '\([^']*\)';/\1/p" lib/app_version.dart)"
if [[ -z "$PUBSPEC" || "$PUBSPEC" != "$APP" ]]; then
  echo "Version mismatch: pubspec.yaml says ${PUBSPEC:-?}, lib/app_version.dart says ${APP:-?}." >&2
  echo "Set appVersion in lib/app_version.dart to $PUBSPEC." >&2
  exit 1
fi
