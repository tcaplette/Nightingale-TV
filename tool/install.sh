#!/usr/bin/env bash
# Builds Nightingale TV and installs it for the current user:
#   app      → ~/.local/opt/nightingale-tv/
#   launcher → ~/.local/share/applications/com.coffeehauslabs.nightingale_tv.desktop
# Re-run to update. Remove with: tool/install.sh --uninstall
set -euo pipefail

APP_ID=com.coffeehauslabs.nightingale_tv
DEST="$HOME/.local/opt/nightingale-tv"
DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
ICON="$HOME/.local/share/icons/hicolor/scalable/apps/$APP_ID.svg"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$DEST" "$DESKTOP" "$ICON"
  echo "Removed Nightingale TV. (Your settings in ~/.local/share/$APP_ID were kept.)"
  exit 0
fi

cd "$ROOT"
flutter build linux --release
# Before the rename to Nightingale TV the app was installed as Retro TV;
# remove that copy and its menu entry. Its saved data moves to the new
# folder by itself the first time Nightingale TV starts.
OLD_ID=com.coffeehauslabs.retro_tv
rm -rf "$HOME/.local/opt/retro-tv" \
  "$HOME/.local/share/applications/$OLD_ID.desktop" \
  "$HOME/.local/share/icons/hicolor/scalable/apps/$OLD_ID.svg"
rm -rf "$DEST"
mkdir -p "$DEST" "$(dirname "$DESKTOP")" "$(dirname "$ICON")"
cp -r build/linux/x64/release/bundle/. "$DEST/"
cp linux/packaging/nightingale_tv.svg "$ICON"
cat > "$DESKTOP" <<DESKTOP_ENTRY
[Desktop Entry]
Type=Application
Name=Nightingale TV
Comment=Always-on cable TV channels from your Jellyfin library
Exec=$DEST/nightingale_tv
Icon=$APP_ID
Terminal=false
Categories=AudioVideo;Video;Player;TV;
StartupWMClass=$APP_ID
DESKTOP_ENTRY
update-desktop-database "$(dirname "$DESKTOP")" 2>/dev/null || true
gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "Installed. Launch \"Nightingale TV\" from your app menu, or run $DEST/nightingale_tv"
