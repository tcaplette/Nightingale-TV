#!/usr/bin/env bash
# Exits 0 when the certificate SHA-256 given (keytool's AA:BB:… or
# apksigner's plain hex) is listed in android/official_signing_cert.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
want="$(printf '%s' "${1:-}" | tr -d ': ' | tr 'A-F' 'a-f')"
[[ -n "$want" ]] || exit 1
[[ -f "$ROOT/android/official_signing_cert.txt" ]] || exit 1
sed 's/#.*//' "$ROOT/android/official_signing_cert.txt" | tr -d ': \t\r' | tr 'A-F' 'a-f' | grep -qx "$want"
