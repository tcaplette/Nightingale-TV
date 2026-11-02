#!/usr/bin/env bash
# Builds a Debian package of Nightingale TV for installing on other machines:
#   dist/nightingale-tv_<version>.<build stamp>_amd64.deb
# Install it with:  sudo apt install ./nightingale-tv_<version>.<build stamp>_amd64.deb
# (apt pulls in the GTK and mpv libraries and ffmpeg it needs.)
# tool/install.sh runs this and installs the result on this machine.
set -euo pipefail

APP_ID=com.coffeehauslabs.nightingale_tv
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# pubspec "1.0.0+1" is already a valid Debian version. The UTC build time
# after it makes every build newer than the last, so apt always upgrades
# the installed app in place, even when pubspec's version hasn't changed.
VERSION="$(sed -n 's/^version: *//p' pubspec.yaml).$(date -u +%Y%m%d%H%M%S)"
ARCH=amd64
OUT="$ROOT/dist/nightingale-tv_${VERSION}_${ARCH}.deb"

flutter build linux --release

# The libmpv package is named after the library version the build linked
# (libmpv1 on Ubuntu 22.04, libmpv2 on 24.04+), so ask dpkg which package
# provides the one this build uses.
MPV_LIB="$(ldd build/linux/x64/release/bundle/lib/libmedia_kit_video_plugin.so \
  | awk '/libmpv\.so/ {print $3; exit}')"
MPV_PKG="$(dpkg -S "$(readlink -f "$MPV_LIB")" 2>/dev/null | cut -d: -f1 || true)"
if [[ -z "$MPV_PKG" ]]; then
  echo "Can't find the package that provides libmpv; install libmpv-dev first." >&2
  exit 1
fi

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
# The app was called Retro TV before; installing it removes that package.
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: nightingale-tv
Version: $VERSION
Architecture: $ARCH
Maintainer: Nightingale TV <noreply@localhost>
Depends: libgtk-3-0t64 | libgtk-3-0, $MPV_PKG, ffmpeg, libc6, libstdc++6
Replaces: retro-tv
Conflicts: retro-tv
Provides: retro-tv
Section: video
Priority: optional
Installed-Size: $(du -sk "$STAGE/opt" | cut -f1)
Description: Always-on cable TV channels from your Jellyfin library
 Turns a Jellyfin library into always-on cable TV channels with a program
 guide, programming blocks, commercial breaks, profiles and a phone remote.
CONTROL

mkdir -p "$ROOT/dist"
# Only the newest package stays, so ./dist/nightingale-tv_*_amd64.deb
# matches one file. APKs and the release .tar.gz are left alone.
rm -f "$ROOT"/dist/nightingale-tv_*_"$ARCH".deb
dpkg-deb --root-owner-group --build "$STAGE" "$OUT" >/dev/null
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
echo "Install on another machine with: sudo apt install ./$(basename "$OUT")"
