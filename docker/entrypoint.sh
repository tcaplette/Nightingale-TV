#!/bin/bash
# Starts the virtual display, then Nightingale TV in server mode as PUID:PGID.
# Exits with the app's status when either stops; SIGTERM stops the app first
# (it has up to 9 s to stop its streams and write its files), then the
# display.
set -uo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

run_as=()
if [ "$(id -u)" = 0 ]; then
  [ "$(id -g ntv)" = "$PGID" ] || groupmod -o -g "$PGID" ntv
  [ "$(id -u ntv)" = "$PUID" ] || usermod -o -u "$PUID" ntv >/dev/null
  mkdir -p /config
  # Only when it isn't theirs already, so a large /config is walked once.
  if [ "$(stat -c %u:%g /config)" != "$PUID:$PGID" ]; then
    echo "Giving /config to $PUID:$PGID."
    chown -R "$PUID:$PGID" /config
  fi
  run_as=(gosu ntv)
fi

# A display lock left by a killed container would stop Xvfb from starting.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Its keymap warnings are noise; a failure to start is reported below.
"${run_as[@]}" Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
xvfb=$!
for _ in $(seq 100); do
  [ -S /tmp/.X11-unix/X99 ] && break
  kill -0 "$xvfb" 2>/dev/null || { echo "The virtual display didn't start."; exit 1; }
  sleep 0.1
done

"${run_as[@]}" /opt/nightingale-tv/nightingale_tv --server "$@" &
app=$!

trap 'kill -TERM "$app" 2>/dev/null' TERM INT

status=1
while :; do
  ended=
  wait -n -p ended "$xvfb" "$app"
  rc=$?
  # A signal interrupts the wait and leaves "ended" unset.
  if [ "${ended:-}" = "$app" ]; then
    status=$rc
    break
  elif [ "${ended:-}" = "$xvfb" ]; then
    echo "The virtual display stopped."
    kill -TERM "$app" 2>/dev/null
    wait "$app"
    status=$?
    [ "$status" = 0 ] && status=1
    break
  fi
  # Woken by a signal (the trap has passed it on): keep waiting.
done

kill -TERM "$xvfb" 2>/dev/null
wait "$xvfb" 2>/dev/null
exit "$status"
