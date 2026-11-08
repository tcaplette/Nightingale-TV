# Shared by make_seed.sh and server_check.sh: run the Linux bundle in server
# mode on a private virtual display, with its own data dirs laid out like
# the Docker image's /config.
#
# XVFB: the Xvfb binary (default: Xvfb on the PATH). XVFB_DISPLAY: its
# display number (default 77).

XVFB="${XVFB:-Xvfb}"
XVFB_DISPLAY="${XVFB_DISPLAY:-77}"
SETUP_PORT="${NTV_SETUP_PORT:-8484}"

# start_bundle <bundle dir> <config dir> <log file>: sets XVFB_PID, APP_PID.
start_bundle() {
  local bundle="$1" config="$2" log="$3"
  [ -x "$bundle/nightingale_tv" ] || { echo "no app in $bundle" >&2; return 1; }
  if [ -e "/tmp/.X11-unix/X$XVFB_DISPLAY" ]; then
    echo "display :$XVFB_DISPLAY is in use" >&2
    return 1
  fi
  "$XVFB" ":$XVFB_DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
  XVFB_PID=$!
  for _ in $(seq 100); do
    [ -S "/tmp/.X11-unix/X$XVFB_DISPLAY" ] && break
    kill -0 "$XVFB_PID" 2>/dev/null || { echo "Xvfb didn't start" >&2; return 1; }
    sleep 0.1
  done
  mkdir -p "$config/cache" "$config/config"
  env -i PATH="$PATH" TZ="${TZ:-$(cat /etc/timezone 2>/dev/null || echo UTC)}" \
    HOME="$config" XDG_DATA_HOME="$config" XDG_CACHE_HOME="$config/cache" XDG_CONFIG_HOME="$config/config" \
    DISPLAY=":$XVFB_DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 GSETTINGS_BACKEND=memory NO_AT_BRIDGE=1 \
    NTV_SETUP_PORT="$SETUP_PORT" NTV_IDLE_CHECK="$config" \
    "$bundle/nightingale_tv" --server >"$log" 2>&1 &
  APP_PID=$!
}

# stop_bundle: the app first (it stops its streams), then the display.
stop_bundle() {
  if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill -TERM "$APP_PID"
    for _ in $(seq 120); do kill -0 "$APP_PID" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$APP_PID" 2>/dev/null
    wait "$APP_PID" 2>/dev/null
  fi
  if [ -n "${XVFB_PID:-}" ] && kill -0 "$XVFB_PID" 2>/dev/null; then
    kill -TERM "$XVFB_PID"
    wait "$XVFB_PID" 2>/dev/null
  fi
  APP_PID=
  XVFB_PID=
}

# The ffmpeg processes still running from the bundle started with [config]
# (they inherit its NTV_IDLE_CHECK marker, even once orphaned).
leftover_ffmpeg() {
  local p
  for p in $(pgrep -x ffmpeg); do
    { tr '\0' '\n' < /proc/$p/environ; } 2>/dev/null | grep -qxF "NTV_IDLE_CHECK=$1" && echo "$p"
  done
}

# wait_health <seconds>: until /health answers 200.
wait_health() {
  local code
  for _ in $(seq "$1"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$SETUP_PORT/health" 2>/dev/null)
    [ "$code" = 200 ] && return 0
    sleep 1
  done
  return 1
}
