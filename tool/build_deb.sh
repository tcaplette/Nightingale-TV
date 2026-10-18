#!/usr/bin/env bash
# Builds a Debian package of Nightingale TV for installing on other machines:
#   dist/nightingale-tv_<version>_amd64.deb
# Install it with:  sudo apt install ./nightingale-tv_<version>_amd64.deb
# (apt pulls in the GTK and mpv libraries and ffmpeg it needs.)
set -euo pipefail

APP_ID=com.coffeehauslabs.nightingale_tv
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# pubspec "1.0.0+1" is already a valid Debian version.
VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
ARCH=amd64
OUT="$ROOT/dist/nightingale-tv_${VERSION}_${ARCH}.deb"

flutter build linux --release

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/opt/nightingale-tv" "$STAGE/usr/bin" "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps" "$STAGE/DEBIAN"
cp -r build/linux/x64/release/bundle/. "$STAGE/opt/nightingale-tv/"
ln -s /opt/nightingale-tv/nightingale_tv "$STAGE/usr/bin/nightingale-tv"
cp linux/packaging/nightingale_tv.svg "$STAGE/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"
# The license travels with the package, as Debian expects.
mkdir -p "$STAGE/usr/share/doc/nightingale-tv"
cp LICENSE "$STAGE/usr/share/doc/nightingale-tv/copyright"
cp assets/fonts/OFL.txt "$STAGE/usr/share/doc/nightingale-tv/barlow-fonts-OFL.txt"

cat > "$STAGE/usr/share/applications/$APP_ID.desktop" <<DESKTOP_ENTRY
[Desktop Entry]
Type=Application
Name=Nightingale TV
Comment=Always-on cable TV channels from your Jellyfin library
Exec=/opt/nightingale-tv/nightingale_tv
Icon=$APP_ID
Terminal=false
Categories=AudioVideo;Video;Player;TV;
StartupWMClass=$APP_ID
DESKTOP_ENTRY

# Ubuntu 24.04+ renamed GTK's package (t64); older releases use the old name.
# ffmpeg splits long commercial videos into ads and finds scene breaks.
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: nightingale-tv
Version: $VERSION
Architecture: $ARCH
Maintainer: Nightingale TV <noreply@localhost>
Depends: libgtk-3-0t64 | libgtk-3-0, libmpv2, ffmpeg, libc6, libstdc++6
Section: video
Priority: optional
Installed-Size: $(du -sk "$STAGE/opt" | cut -f1)
Description: Always-on cable TV channels from your Jellyfin library
 Turns a Jellyfin library into always-on cable TV channels with a program
 guide, programming blocks, commercial breaks, profiles and a phone remote.
CONTROL

mkdir -p "$ROOT/dist"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT" >/dev/null
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
echo "Install on another machine with: sudo apt install ./$(basename "$OUT")"
