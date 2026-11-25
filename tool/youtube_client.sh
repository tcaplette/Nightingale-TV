# Sourced by the build scripts (youtube-shared-client D2). The app bundles its
# shared Google client from the git-ignored asset
#   assets/youtube/client/nightingale-tv-youtube.json
# (Google Cloud's download for a "TVs and Limited Input devices" client) and
# reads it at start-up, so every build carries it, however it's built. This
# only checks the file is there and is a client, and says so when it isn't;
# the build goes on either way.
youtube_client_check() {
  local src=assets/youtube/client/nightingale-tv-youtube.json
  if [[ -f "$src" ]] && python3 -I - "$src" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
ok = isinstance(data, dict) and any(
    isinstance(s, dict) and str(s.get("client_id") or "").strip() and str(s.get("client_secret") or "").strip()
    for s in data.values())
sys.exit(0 if ok else 1)
PY
  then
    return 0
  fi
  echo "Note: no YouTube client at $src; this build's YouTube button says it has none." >&2
}
