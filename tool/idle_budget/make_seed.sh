#!/usr/bin/env bash
# Makes tool/idle_budget/seed/ (idle-cpu D4): a server config with an admin,
# one profile signed in to the test server (test-data.md) and exported.
# git-ignored: it holds the test server's token. Remake it when
# server_check.sh says the seed isn't signed in.
#
#   tool/idle_budget/make_seed.sh [bundle dir]
#
# Needs: the Playwright image and the ntv-offline network (see
# tool/web_admin_tests), a node_modules with playwright@1.56.1 in
# PLAYWRIGHT_MODULES, and test-data.md. The admin password is read from
# test-data.md ("idle check admin pass:").
set -uo pipefail
cd "$(dirname "$0")/../.."
. tool/idle_budget/lib.sh

BUNDLE="${1:-build/linux/x64/release/bundle}"
SEED=tool/idle_budget/seed
MODULES="${PLAYWRIGHT_MODULES:?set PLAYWRIGHT_MODULES to a folder with node_modules/playwright}"
WORK=$(mktemp -d)
trap 'stop_bundle; rm -rf "$WORK"' EXIT

field() { sed -n "s/^$1: *//p" test-data.md | head -1; }
ADMIN_PW=$(field 'idle check admin pass')
[ -n "$ADMIN_PW" ] || { echo "add 'idle check admin pass: <password>' to test-data.md first"; exit 1; }

start_bundle "$BUNDLE" "$WORK/config" "$WORK/app.log" || exit 1
wait_health 90 || { echo "FAIL the server didn't answer /health"; tail -20 "$WORK/app.log"; exit 1; }
TOKEN=$(sed -n 's/.*setup?token=\([^ ]*\) to set up.*/\1/p' "$WORK/app.log" | tail -1)
[ -n "$TOKEN" ] || { echo "FAIL no setup link in the log (not a fresh config?)"; exit 1; }
echo "server up, setup link found"

# Secrets go in a file only this user reads, never on a command line.
( umask 077
  { echo "NTV_URL=http://192.168.77.1:$SETUP_PORT"; echo "NTV_TOKEN=$TOKEN"; echo "NTV_ADMIN_PW=$ADMIN_PW"
    echo "MS_URL=$(field 'test server')"; echo "MS_USER=$(field 'test user')"; echo "MS_PW=$(field 'test pass')"
  } > "$WORK/env" )
sg docker -c "docker run --rm --network ntv-offline --env-file '$WORK/env' \
  -v '$MODULES/node_modules:/w/node_modules:ro' -v '$PWD/tool/idle_budget/make_seed.js:/w/make_seed.js:ro' -w /w \
  mcr.microsoft.com/playwright:v1.56.1-noble node make_seed.js" </dev/null \
  || { echo "FAIL the setup script failed"; tail -30 "$WORK/app.log"; exit 1; }
rm -f "$WORK/env"
stop_bundle

rm -rf "$SEED"
mkdir -p "$SEED"
# The household and settings; caches are made again on each run.
cp -a "$WORK/config/com.coffeehauslabs.nightingale_tv" "$SEED/"
[ -d "$WORK/config/config" ] && cp -a "$WORK/config/config" "$SEED/"
echo "seed saved to $SEED"
