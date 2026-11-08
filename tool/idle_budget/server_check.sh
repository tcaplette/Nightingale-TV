#!/usr/bin/env bash
# The server idle check (idle-cpu D4): runs the real server from the Linux
# release bundle or the Docker image with a copy of seed/, probes it the way
# Plex, Jellyfin and health checks do, watches one viewer come and go, then
# measures it against the idle budget.
#
#   tool/idle_budget/server_check.sh --bundle build/linux/x64/release/bundle
#   tool/idle_budget/server_check.sh --docker <image>
#
# One line per step; exits non-zero at the first step that fails.
# EXPORT_PORT: the seed profile's tuner port (default 5004).
# IDLE_WINDOW: the step 4 window in seconds (default 300).
# KEEP_GOING=1: carry on after a failing step 2-5 (to record every step's
# figures, as for the README's "before" row); still exits non-zero.
set -uo pipefail
cd "$(dirname "$0")/../.."
. tool/idle_budget/lib.sh

mode="${1:-}"
target="${2:-}"
[ "$mode" = --bundle ] || [ "$mode" = --docker ] || { echo "usage: server_check.sh --bundle <dir> | --docker <image>"; exit 2; }
[ -n "$target" ] || { echo "usage: server_check.sh --bundle <dir> | --docker <image>"; exit 2; }
SEED=tool/idle_budget/seed
[ -d "$SEED/com.coffeehauslabs.nightingale_tv" ] || { echo "FAIL no seed config: run tool/idle_budget/make_seed.sh"; exit 1; }
EXPORT_PORT="${EXPORT_PORT:-5004}"
WINDOW="${IDLE_WINDOW:-300}"
MEASURE=tool/idle_budget/measure.sh
WORK=$(mktemp -d)
CONTAINER="ntv-idle-check-$$"
CONFIG="$WORK/config"

cleanup() {
  if [ "$mode" = --docker ]; then
    sg docker -c "docker rm -f $CONTAINER" >/dev/null 2>&1
  else
    stop_bundle
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

FAILED=0
fail() {
  echo "FAIL step $1: $2"
  FAILED=1
  if [ "${KEEP_GOING:-0}" = 1 ] && [ "$1" != 1 ]; then return 0; fi
  [ -f "$WORK/app.log" ] && tail -15 "$WORK/app.log" | sed 's/^/  log: /'
  exit 1
}
pids_in_container() {
  sg docker -c "docker top $CONTAINER -eo pid,comm" 2>/dev/null | awk -v c="$1" '$2 == c { print $1; exit }'
}

mkdir -p "$CONFIG"
cp -a "$SEED/." "$CONFIG/"

if [ "$mode" = --bundle ]; then
  start_bundle "$target" "$CONFIG" "$WORK/app.log" || fail 1 "the server didn't start"
else
  sg docker -c "docker run -d --name $CONTAINER --hostname nightingale-tv \
    -p $SETUP_PORT:8484 -p 5004-5009:5004-5009 -e PUID=$(id -u) -e PGID=$(id -g) \
    -e TZ=${TZ:-$(cat /etc/timezone 2>/dev/null || echo UTC)} -v '$CONFIG:/config' '$target'" >/dev/null \
    || fail 1 "the container didn't start"
  ( sg docker -c "docker logs -f $CONTAINER" > "$WORK/app.log" 2>&1 & )
fi

# 1. Up, signed in, settled.
wait_health 120 || fail 1 "/health never answered 200"
if [ "$mode" = --docker ]; then
  APP_PID=$(pids_in_container nightingale_tv)
  XVFB_PID=$(pids_in_container Xvfb)
  [ -n "$APP_PID" ] && [ -n "$XVFB_PID" ] || fail 1 "can't find the app's processes in the container"
fi
lineup=""
for _ in $(seq 60); do
  lineup=$(curl -s --max-time 5 "http://127.0.0.1:$EXPORT_PORT/lineup.json")
  [[ "$lineup" == \[*URL* ]] && break
  sleep 2
done
[[ "$lineup" == \[*URL* ]] || fail 1 "no lineup on port $EXPORT_PORT: the seed config isn't signed in (remake it with make_seed.sh)"
# Channel 1's stream, through loopback.
STREAM=$(printf '%s' "$lineup" | python3 -c 'import json,sys,re; c=json.load(sys.stdin)[0]; print(re.sub(r"^http://[^/]+", "", c["URL"]))')
STREAM="http://127.0.0.1:$EXPORT_PORT$STREAM"
sleep 60
echo "PASS step 1: up and signed in, settled 60 s (app $APP_PID, Xvfb $XVFB_PID, stream $STREAM)"

# 2. HEAD every 5 s for 60 s: no stream ever starts.
"$MEASURE" "$APP_PID" 62 --no-cpu > "$WORK/m2" &
m=$!
codes=()
for _ in $(seq 12); do
  codes+=("$(curl -s -o /dev/null -I --max-time 4 -w '%{http_code}' "$STREAM")")
  sleep 5
done
wait "$m"
r=$?
bad=$(printf '%s\n' "${codes[@]}" | grep -vc '^200$')
ok=1
[ "$bad" = 0 ] || { fail 2 "HEAD answers: ${codes[*]}"; ok=0; }
[ "$r" = 0 ] || { fail 2 "HEAD started a stream: $(grep '^stream' "$WORK/m2")"; ok=0; }
(( ok )) && echo "PASS step 2: 12 HEADs, all 200, $(grep '^stream' "$WORK/m2") ffmpeg"

# 3. One viewer for 10 s, then 20 s after it leaves: no stream ffmpeg.
curl -s --max-time 10 -o "$WORK/view.ts" "$STREAM"
bytes=$(stat -c %s "$WORK/view.ts" 2>/dev/null || echo 0)
ok=1
(( bytes > 0 )) || { fail 3 "the viewer got no video"; ok=0; }
sleep 20
"$MEASURE" "$APP_PID" 2 --no-cpu > "$WORK/m3" || { fail 3 "a stream is still running 20 s after the viewer left: $(grep '^stream' "$WORK/m3")"; ok=0; }
(( ok )) && echo "PASS step 3: viewer got $((bytes / 1024)) KB in 10 s, $(grep '^stream' "$WORK/m3") ffmpeg 20 s after it left"

# 4. The idle budget.
"$MEASURE" "$APP_PID" "$WINDOW" --xvfb "$XVFB_PID" > "$WORK/m4"
r=$?
summary=$(grep -E '^(app|xvfb|app\+xvfb|stream|background)' "$WORK/m4" | paste -sd ';' | sed 's/;/; /g')
if [ "$r" = 0 ]; then echo "PASS step 4: ${WINDOW} s idle: $summary"; else fail 4 "over the idle budget: $summary"; fi

# 5. Stopped: no ffmpeg left.
if [ "$mode" = --docker ]; then
  seen=$(awk '{print $1}' < <(sg docker -c "docker top $CONTAINER -eo pid,comm" | awk '$2 == "ffmpeg"'))
  sg docker -c "docker stop -t 15 $CONTAINER" >/dev/null || fail 5 "the container didn't stop"
  left=""
  for p in $seen; do [ -e "/proc/$p" ] && left+=" $p"; done
  running=$(sg docker -c "docker ps -q --filter name=$CONTAINER")
  if [ -z "$left" ] && [ -z "$running" ]; then echo "PASS step 5: server stopped, no ffmpeg left"; else fail 5 "left running after stop:${left} ${running}"; fi
else
  stop_bundle
  sleep 1
  left=$(leftover_ffmpeg "$CONFIG" | paste -sd ' ')
  if [ -z "$left" ]; then echo "PASS step 5: server stopped, no ffmpeg left"; else fail 5 "ffmpeg left running after stop: $left"; fi
fi
[ "$FAILED" = 0 ] || exit 1
echo "PASS all 5 steps"
