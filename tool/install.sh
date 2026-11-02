#!/usr/bin/env bash
# Builds Nightingale TV's Debian package and installs it with apt:
#   app      → /opt/nightingale-tv/
#   launcher → /usr/share/applications/com.coffeehauslabs.nightingale_tv.desktop
#   command  → nightingale-tv
# Re-run to update: every build is a newer version, so apt replaces the
# installed app in place. Remove with: tool/install.sh --uninstall
set -euo pipefail

APP_ID=com.coffeehauslabs.nightingale_tv
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Earlier versions of this script copied the app into the home folder, and
# that menu entry hides the package's one. Remove it, and the copy from
# before the rename to Nightingale TV. Saved data is never touched (Retro
# TV's moves to the new folder by itself the first time the app starts).
remove_user_copies() {
  local id
  rm -rf "$HOME/.local/opt/nightingale-tv" "$HOME/.local/opt/retro-tv"
  for id in "$APP_ID" com.coffeehauslabs.retro_tv; do
    rm -f "$HOME/.local/share/applications/$id.desktop" \
      "$HOME/.local/share/icons/hicolor/scalable/apps/$id.svg"
  done
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
  remove_user_copies
  if dpkg-query -W -f='${Status}' nightingale-tv 2>/dev/null | grep -q "ok installed"; then
    echo "Removing the nightingale-tv package (apt needs your password)..."
    sudo apt remove -y nightingale-tv
  fi
  echo "Removed Nightingale TV. (Your settings in ~/.local/share/$APP_ID were kept.)"
  exit 0
fi

cd "$ROOT"
tool/build_deb.sh
DEB="$(ls "$ROOT"/dist/nightingale-tv_*_amd64.deb)"
remove_user_copies
echo "Installing $(basename "$DEB") with apt (it needs your password)..."
sudo apt install -y "$DEB"
echo "Installed. Launch \"Nightingale TV\" from your app menu, or run nightingale-tv"
