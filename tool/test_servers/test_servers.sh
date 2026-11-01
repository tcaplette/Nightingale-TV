#!/usr/bin/env bash
# Jellyfin, Emby and Plex test servers in Docker, one at a time, with a
# fake Live TV tuner (fake_tuner/) running beside whichever is up.
#
#   test_servers.sh up <jellyfin|emby|plex|tuner>
#                                       start one (stops the other servers
#                                       first); "tuner" starts the tuner alone
#   test_servers.sh up emby+plex        start Emby and Plex together on the
#                                       same library (multi-server's mirrored
#                                       test); refuses while an emulator runs
#                                       or memory is short
#   test_servers.sh down                stop everything
#   test_servers.sh status              what's running, and its address
#   test_servers.sh setup <jellyfin|emby|plex>
#                                       start it, create the admin user and
#                                       libraries, scan them, and add the fake
#                                       tuner and its guide to its Live TV
#
# Setup reads credentials only from the environment, never from files:
#   jellyfin: JELLYFIN_USER, JELLYFIN_PASSWORD
#   emby: EMBY_USER, EMBY_PASSWORD
#   plex: PLEX_CLAIM (from https://plex.tv/claim, valid 4 minutes; needed
#         the first time only, to link the server to the test account)
# Media comes from make_media.sh (run it first).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export TEST_MEDIA="${NIGHTINGALE_TEST_MEDIA:-$HOME/.cache/nightingale-test-media}"
export TEST_SERVERS_DATA="${NIGHTINGALE_TEST_SERVERS:-$HOME/.cache/nightingale-test-servers}"
export HOST_UID="$(id -u)" HOST_GID="$(id -g)"
JELLYFIN=http://127.0.0.1:8097
EMBY=http://127.0.0.1:8096
PLEX=http://127.0.0.1:32400
TUNER=http://127.0.0.1:5104
SERVERS="jellyfin emby plex"

# Docker, through `sg docker` when this shell doesn't have the group yet.
dk() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    sg docker -c "$(printf '%q ' docker "$@")"
  fi
}
compose() { dk compose -f "$HERE/compose.yaml" --profile jellyfin --profile emby --profile plex --profile tuner "$@"; }

running() { dk ps --format '{{.Names}}' | sed -n 's/^nightingale-//p'; }

wait_for() { # url, what
  for _ in $(seq 1 90); do
    curl -fsS -m 3 -o /dev/null "$1" 2>/dev/null && return 0
    sleep 2
  done
  echo "$2 did not start; see: docker logs nightingale-${2,,}" >&2
  exit 1
}

# The fake tuner makes its clips on first start (a minute or two).
up_tuner() {
  mkdir -p "$TEST_SERVERS_DATA/fake-tuner"
  compose up -d --build fake-tuner
  for _ in $(seq 1 150); do
    curl -fsS -m 3 -o /dev/null "$TUNER/discover.json" 2>/dev/null && return 0
    sleep 2
  done
  echo "The fake tuner did not start; see: docker logs nightingale-fake-tuner" >&2
  exit 1
}

# Memory Emby and Plex need together, beside the desktop (MiB).
PAIR_MEMORY=3072

# Two servers at once only with no emulator and enough memory free.
check_pair() {
  if pgrep -x 'qemu-system-x86_64' >/dev/null || pgrep -x 'qemu-system-x86_64-headless' >/dev/null; then
    echo "An Android emulator is running; close it before starting two servers." >&2
    exit 1
  fi
  local free
  free="$(awk '/^MemAvailable:/ {print int($2 / 1024)}' /proc/meminfo)"
  if (( free < PAIR_MEMORY )); then
    echo "Only ${free} MiB of memory is free; Emby and Plex together need ${PAIR_MEMORY} MiB." >&2
    exit 1
  fi
}

up() {
  local which="$1" keep="$1"
  if [[ "$which" == tuner ]]; then up_tuner; status; return; fi
  if [[ "$which" == emby+plex ]]; then
    check_pair
    keep="emby plex"
  fi
  [[ -d "$TEST_MEDIA/TV" ]] || { echo "No test media in $TEST_MEDIA; run make_media.sh first." >&2; exit 1; }
  for other in $(running); do
    if [[ " $keep " != *" $other "* && " $SERVERS " == *" $other "* ]]; then
      echo "Stopping $other first (one server at a time)."
      compose stop "$other" >/dev/null
    fi
  done
  up_tuner
  local one
  for one in $keep; do
    start_one "$one"
  done
  status
}

start_one() {
  local which="$1"
  mkdir -p "$TEST_SERVERS_DATA/$which"
  [[ "$which" == plex ]] && mkdir -p "$TEST_SERVERS_DATA/plex-transcode"
  [[ "$which" == jellyfin ]] && mkdir -p "$TEST_SERVERS_DATA/jellyfin/config" "$TEST_SERVERS_DATA/jellyfin/cache"
  compose up -d "$which"
  case "$which" in
    jellyfin)
      wait_for "$JELLYFIN/System/Info/Public" Jellyfin
      # Public info answers during migrations; everything else is 503 until done.
      for _ in $(seq 1 90); do
        [[ "$(curl -s -o /dev/null -w '%{http_code}' "$JELLYFIN/Users/Public")" != 503 ]] && break
        sleep 2
      done ;;
    emby) wait_for "$EMBY/System/Info/Public" Emby ;;
    plex)
      wait_for "$PLEX/identity" Plex
      # It answers while still starting, and turns library requests down until done.
      for _ in $(seq 1 90); do
        curl -fsS -H 'Accept: application/json' "$PLEX/identity" | grep -q startState || break
        sleep 2
      done ;;
  esac
}

down() { compose stop >/dev/null; echo "Stopped."; }

status() {
  local any=""
  for r in $(running); do
    any=1
    case "$r" in
      jellyfin) echo "Jellyfin is running: $JELLYFIN (emulator: http://10.0.2.2:8097)" ;;
      emby) echo "Emby is running: $EMBY (emulator: http://10.0.2.2:8096)" ;;
      plex) echo "Plex is running: $PLEX (emulator: http://10.0.2.2:32400)" ;;
      fake-tuner) echo "Fake tuner is running: $TUNER/channels.m3u, $TUNER/xmltv.xml.gz (emulator: http://10.0.2.2:5104)" ;;
      *) echo "Running: $r" ;;
    esac
  done
  [[ -n "$any" ]] || echo "No test server is running."
}

json() { python3 -c "import sys,json; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

# Adds the fake tuner (M3U) and its XMLTV guide to Jellyfin's or Emby's Live
# TV, then refreshes the guide. Args: server url, auth header.
setup_live_tv() {
  local base="$1" h=(-fsS -H "$2" -H 'Content-Type: application/json')
  local conf
  conf="$(curl "${h[@]}" "$base/System/Configuration/livetv")"
  if ! grep -q 'fake-tuner:5104' <<<"$(json "json.dumps(d.get('TunerHosts', []))" <<<"$conf")"; then
    echo "Adding the fake tuner to Live TV."
    curl "${h[@]}" -X POST "$base/LiveTv/TunerHosts" \
      -d '{"Type":"m3u","Url":"http://fake-tuner:5104/server.m3u","FriendlyName":"Fake tuner","TunerCount":0,"ImportFavoritesOnly":false,"AllowHWTranscoding":false}' >/dev/null
  fi
  if ! grep -q 'fake-tuner:5104' <<<"$(json "json.dumps(d.get('ListingProviders', []))" <<<"$conf")"; then
    echo "Adding the fake tuner's XMLTV guide."
    curl "${h[@]}" -X POST "$base/LiveTv/ListingProviders" \
      -d '{"Type":"xmltv","Path":"http://fake-tuner:5104/xmltv.xml","EnableAllTuners":true}' >/dev/null
  fi
  local task
  task="$(curl "${h[@]}" "$base/ScheduledTasks" | json "[t['Id'] for t in d if t.get('Key')=='RefreshGuide'][0]")"
  curl "${h[@]}" -X POST "$base/ScheduledTasks/Running/$task" >/dev/null
  echo "Refreshing the guide."
  for _ in $(seq 1 100); do
    sleep 3
    [[ "$(curl "${h[@]}" "$base/ScheduledTasks/$task" | json "d.get('State')")" == "Idle" ]] && break
  done
  echo "Live TV: $(curl "${h[@]}" "$base/LiveTv/Channels?Limit=0" | json "d['TotalRecordCount']") channels, $(curl "${h[@]}" "$base/LiveTv/Programs?Limit=0" | json "d['TotalRecordCount']") programmes."
}

setup_jellyfin() {
  : "${JELLYFIN_USER:?set JELLYFIN_USER}" "${JELLYFIN_PASSWORD:?set JELLYFIN_PASSWORD}"
  up jellyfin
  local auth='MediaBrowser Client="Nightingale setup", Device="setup", DeviceId="nightingale-setup", Version="1.0"'
  local h=(-fsS -H "Authorization: $auth" -H 'Content-Type: application/json')
  # Until the startup wizard is done, its user step answers without sign-in.
  if curl -fsS -o /dev/null -H "Authorization: $auth" "$JELLYFIN/Startup/User" 2>/dev/null; then
    echo "Running Jellyfin's startup wizard."
    curl "${h[@]}" -X POST "$JELLYFIN/Startup/Configuration" \
      -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}' >/dev/null
    curl "${h[@]}" "$JELLYFIN/Startup/User" >/dev/null
    curl "${h[@]}" -X POST "$JELLYFIN/Startup/User" \
      -d "$(python3 -c 'import json,os; print(json.dumps({"Name":os.environ["JELLYFIN_USER"],"Password":os.environ["JELLYFIN_PASSWORD"]}))')" >/dev/null
    curl "${h[@]}" -X POST "$JELLYFIN/Startup/RemoteAccess" \
      -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' >/dev/null
    curl "${h[@]}" -X POST "$JELLYFIN/Startup/Complete" >/dev/null
  fi
  local token
  token="$(curl "${h[@]}" -X POST "$JELLYFIN/Users/AuthenticateByName" \
    -d "$(python3 -c 'import json,os; print(json.dumps({"Username":os.environ["JELLYFIN_USER"],"Pw":os.environ["JELLYFIN_PASSWORD"]}))')" \
    | json "d['AccessToken']")"
  local th="Authorization: MediaBrowser Client=\"Nightingale setup\", Device=\"setup\", DeviceId=\"nightingale-setup\", Version=\"1.0\", Token=\"$token\""
  h=(-fsS -H "$th" -H 'Content-Type: application/json')
  local have
  have="$(curl "${h[@]}" "$JELLYFIN/Library/VirtualFolders" | json "'|'.join(f['Name'] for f in d)")"
  add() { # name, collection type, folder
    if [[ "|$have|" == *"|$1|"* ]]; then return; fi
    echo "Adding library $1."
    curl "${h[@]}" -X POST -G "$JELLYFIN/Library/VirtualFolders" \
      --data-urlencode "name=$1" --data-urlencode "collectionType=$2" \
      --data-urlencode "paths=/media/$3" --data-urlencode "refreshLibrary=false" \
      -d '{"LibraryOptions":{"EnableRealtimeMonitor":false,"EnableChapterImageExtraction":false,"MetadataSavers":[]}}' >/dev/null
  }
  add "TV" tvshows TV
  add "Movies" movies Movies
  add "Home Videos" homevideos "Home Videos"
  add "Music" music Music
  add "Music Videos" musicvideos "Music Videos"
  curl "${h[@]}" -X POST "$JELLYFIN/Library/Refresh" >/dev/null
  echo "Scanning; waiting for it to finish."
  for _ in $(seq 1 120); do
    sleep 3
    local busy
    busy="$(curl "${h[@]}" "$JELLYFIN/ScheduledTasks" | json "any(t.get('State')=='Running' for t in d if t.get('Key')=='RefreshLibrary')")"
    [[ "$busy" == "False" ]] && break
  done
  curl "${h[@]}" "$JELLYFIN/Items/Counts" | json "', '.join(f'{k}: {v}' for k,v in d.items() if v)"
  setup_live_tv "$JELLYFIN" "$th"
  curl -fsS -X POST -H "$th" "$JELLYFIN/Sessions/Logout" >/dev/null || true
}

setup_emby() {
  : "${EMBY_USER:?set EMBY_USER}" "${EMBY_PASSWORD?set EMBY_PASSWORD (may be empty)}"
  up emby
  local auth='Emby Client="Nightingale setup", Device="setup", DeviceId="nightingale-setup", Version="1.0"'
  # Until the startup wizard is done, its user step answers without sign-in.
  if curl -fsS -o /dev/null -H "X-Emby-Authorization: $auth" "$EMBY/Startup/User" 2>/dev/null; then
    echo "Running Emby's startup wizard."
    local h=(-fsS -H "X-Emby-Authorization: $auth" -H 'Content-Type: application/json')
    curl "${h[@]}" -X POST "$EMBY/Startup/Configuration" \
      -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}' >/dev/null
    curl "${h[@]}" "$EMBY/Startup/User" >/dev/null
    curl "${h[@]}" -X POST "$EMBY/Startup/User" \
      -d "$(python3 -c 'import json,os; print(json.dumps({"Name":os.environ["EMBY_USER"],"Password":os.environ["EMBY_PASSWORD"]}))')" >/dev/null
    curl "${h[@]}" -X POST "$EMBY/Startup/RemoteAccess" \
      -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' >/dev/null
    curl "${h[@]}" -X POST "$EMBY/Startup/Complete" >/dev/null
  fi
  local token
  token="$(curl -fsS -H "X-Emby-Authorization: $auth" -H 'Content-Type: application/json' \
    -X POST "$EMBY/Users/AuthenticateByName" \
    -d "$(python3 -c 'import json,os; print(json.dumps({"Username":os.environ["EMBY_USER"],"Pw":os.environ["EMBY_PASSWORD"]}))')" \
    | json "d['AccessToken']")"
  local h=(-fsS -H "X-Emby-Token: $token" -H 'Content-Type: application/json')
  local have
  have="$(curl "${h[@]}" "$EMBY/Library/VirtualFolders" | json "'|'.join(f['Name'] for f in d)")"
  add() { # name, collection type, folder
    if [[ "|$have|" == *"|$1|"* ]]; then return; fi
    echo "Adding library $1."
    curl "${h[@]}" -X POST "$EMBY/Library/VirtualFolders?refreshLibrary=false" \
      -d "$(python3 -c 'import json,sys; print(json.dumps({"Name":sys.argv[1],"CollectionType":sys.argv[2],"Paths":["/media/"+sys.argv[3]],"LibraryOptions":{"PathInfos":[{"Path":"/media/"+sys.argv[3]}],"EnableRealtimeMonitor":False,"EnableChapterImageExtraction":False,"MetadataSavers":[],"DownloadImagesInAdvance":False}}))' "$1" "$2" "$3")" >/dev/null
  }
  add "TV" tvshows TV
  add "Movies" movies Movies
  add "Home Videos" homevideos "Home Videos"
  add "Music" music Music
  add "Music Videos" musicvideos "Music Videos"
  curl "${h[@]}" -X POST "$EMBY/Library/Refresh" >/dev/null
  echo "Scanning; waiting for it to finish."
  for _ in $(seq 1 120); do
    sleep 3
    local busy
    busy="$(curl "${h[@]}" "$EMBY/ScheduledTasks" | json "any(t.get('State')=='Running' for t in d if t.get('Key')=='RefreshLibrary')")"
    [[ "$busy" == "False" ]] && break
  done
  curl "${h[@]}" "$EMBY/Items/Counts" | json "', '.join(f'{k}: {v}' for k,v in d.items() if v)"
  setup_live_tv "$EMBY" "X-Emby-Token: $token"
  if [[ "$(curl "${h[@]}" "$EMBY/LiveTv/Channels?Limit=0" | json "d['TotalRecordCount']")" == 0 ]]; then
    echo "Note: Emby shows Live TV channels only with an active Emby Premiere subscription (Settings -> Emby Premiere)." >&2
  fi
  curl -fsS -X POST -H "X-Emby-Token: $token" "$EMBY/Sessions/Logout" >/dev/null || true
}

# A claimed server wants its token even from this machine; it's read from
# the server's own settings when it has one.
plex_token() {
  local prefs="$TEST_SERVERS_DATA/plex/Library/Application Support/Plex Media Server/Preferences.xml"
  [[ -f "$prefs" ]] && sed -n 's/.*PlexOnlineToken="\([^"]*\)".*/\1/p' "$prefs"
}

setup_plex() {
  if [[ ! -f "$TEST_SERVERS_DATA/plex/Library/Application Support/Plex Media Server/Preferences.xml" && -z "${PLEX_CLAIM:-}" ]]; then
    echo "Note: no PLEX_CLAIM given; the server will run unclaimed (local API only, no plex.tv sign-in)." >&2
  fi
  up plex
  local q=(-fsS -H 'Accept: application/json' -H "X-Plex-Token: $(plex_token)")
  local have
  have="$(curl "${q[@]}" "$PLEX/library/sections" | json "'|'.join(s['title'] for s in d['MediaContainer'].get('Directory', []))")"
  add() { # name, type, scanner, agent, folder
    if [[ "|$have|" == *"|$1|"* ]]; then return; fi
    echo "Adding library $1."
    curl "${q[@]}" -X POST -G "$PLEX/library/sections" \
      --data-urlencode "name=$1" --data-urlencode "type=$2" --data-urlencode "scanner=$3" \
      --data-urlencode "agent=$4" --data-urlencode "language=xn" \
      --data-urlencode "location=/media/$5" >/dev/null
  }
  add "TV" show "Plex TV Series" tv.plex.agents.none TV
  add "Movies" movie "Plex Movie" tv.plex.agents.none Movies
  add "Home Videos" movie "Plex Video Files" tv.plex.agents.none "Home Videos"
  add "Music" artist "Plex Music" tv.plex.agents.none Music
  curl "${q[@]}" "$PLEX/library/sections/all/refresh" >/dev/null
  echo "Scanning; waiting for it to finish."
  for _ in $(seq 1 120); do
    sleep 3
    local busy
    busy="$(curl "${q[@]}" "$PLEX/library/sections" | json "any(s.get('refreshing') for s in d['MediaContainer'].get('Directory', []))")"
    [[ "$busy" == "False" ]] && break
  done
  # A collection of 20 clips from Home Videos, to pick as a commercial pool.
  local home machine
  home="$(curl "${q[@]}" "$PLEX/library/sections" | json "[s['key'] for s in d['MediaContainer']['Directory'] if s['title']=='Home Videos'][0]")"
  if [[ "$(curl "${q[@]}" "$PLEX/library/sections/$home/collections" | json "d['MediaContainer'].get('size', 0)")" == "0" ]]; then
    machine="$(curl "${q[@]}" "$PLEX/identity" | json "d['MediaContainer']['machineIdentifier']")"
    local ids
    ids="$(curl "${q[@]}" "$PLEX/library/sections/$home/all?type=1" | json "','.join([m['ratingKey'] for m in d['MediaContainer']['Metadata'] if 'Reel' not in m['title']][:20])")"
    echo "Adding collection Trailers."
    curl "${q[@]}" -X POST -G "$PLEX/library/collections" --data-urlencode type=1 --data-urlencode title=Trailers \
      --data-urlencode smart=0 --data-urlencode "sectionId=$home" \
      --data-urlencode "uri=server://$machine/com.plexapp.plugins.library/library/metadata/$ids" >/dev/null
  fi
  curl "${q[@]}" "$PLEX/library/sections" | json "', '.join(s['title']+' ('+s['type']+')' for s in d['MediaContainer'].get('Directory', []))"
  setup_plex_dvr
}

# The fake tuner as an HDHomeRun DVR with its XMLTV guide. Plex reaches the
# tuner at 127.0.0.1 (host network). Its Live TV may need Plex Pass on the
# server owner's account; if Plex refuses, setup says so and carries on.
setup_plex_dvr() {
  local q=(-fsS -H 'Accept: application/json' -H "X-Plex-Token: $(plex_token)")
  local device=device://tv.plex.grabbers.hdhomerun/10ABCDEF
  local lineup="lineup://tv.plex.providers.epg.xmltv/$TUNER/xmltv.xml#Fake tuner guide"
  if [[ "$(curl "${q[@]}" "$PLEX/livetv/dvrs" | json "d['MediaContainer'].get('size', 0)")" != 0 ]]; then
    echo "Live TV: $(curl "${q[@]}" "$PLEX/livetv/dvrs" | json "', '.join(x['lineupTitle'] for x in d['MediaContainer']['Dvr'])") DVR already set up."
    return
  fi
  echo "Adding the fake tuner as a Plex DVR."
  if ! curl "${q[@]}" -X POST -G "$PLEX/media/grabbers/devices" --data-urlencode "uri=$TUNER" >/dev/null \
    || ! curl "${q[@]}" -X POST -G "$PLEX/livetv/dvrs" --data-urlencode "device=$device" \
      --data-urlencode "lineup=$lineup" --data-urlencode "language=eng" >/dev/null; then
    echo "Note: Plex refused the DVR. Plex Live TV needs Plex Pass on the server owner's account." >&2
    return
  fi
  local key map=()
  key="$(curl "${q[@]}" "$PLEX/media/grabbers/devices" | json "[x['key'] for x in d['MediaContainer']['Device'] if x['uuid']=='$device'][0]")"
  while read -r number channel; do
    map+=(--data-urlencode "channelMappingByKey[$number]=$channel" --data-urlencode "channelMapping[$number]=$number")
  done < <(curl "${q[@]}" -G "$PLEX/livetv/epg/channelmap" --data-urlencode "device=$device" --data-urlencode "lineup=$lineup" \
    | json "'\\n'.join(m['deviceIdentifier']+' '+m['channelKey'] for m in d['MediaContainer']['ChannelMapping'] if m.get('channelKey'))")
  curl "${q[@]}" -X PUT -G "$PLEX/media/grabbers/devices/$key/channelmap" "${map[@]}" \
    --data-urlencode "channelsEnabled=$(curl "${q[@]}" "$PLEX/media/grabbers/devices/$key/channels" | json "','.join(c['identifier'] for c in d['MediaContainer']['DeviceChannel'])")" >/dev/null
  echo "Live TV: DVR set up; Plex loads the guide in the background."
}

case "${1:-}" in
  up) [[ "${2:-}" =~ ^(jellyfin|emby|plex|tuner|emby\+plex)$ ]] || { echo "up jellyfin|emby|plex|tuner|emby+plex" >&2; exit 2; }; up "$2" ;;
  down) down ;;
  status) status ;;
  setup)
    case "${2:-}" in
      jellyfin) setup_jellyfin ;;
      emby) setup_emby ;;
      plex) setup_plex ;;
      *) echo "setup jellyfin|emby|plex" >&2; exit 2 ;;
    esac ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
