#!/usr/bin/env bash
# Measures an idle Nightingale TV process (idle-cpu design D3).
#
#   measure.sh <pid> <seconds> [--xvfb <pid>] [--no-cpu] [--host <name>]
#                                               the app (and its virtual display);
#                                               --no-cpu judges the stream count only
#   measure.sh --adb <package> <seconds> [--host <name>]
#                                               the app on an Android device,
#                                               failing too if it holds a codec
#
# --host (friend-presence D6): fails if the app has a TCP connection open to
# <name> (the sharing backend's host, from sharing.env) at any sample. The
# app's sockets are read from /proc/<pid>/net/tcp and tcp6, kept to the app's
# uid; <name> is resolved here, every address it has.
#   measure.sh --classify                       class each argv line on stdin
#
# CPU is CPU time over wall time, one core = 100%. Every ffmpeg under the app
# is classed by its arguments (lib/export/encode_args.dart and
# lib/commercials/analysis/ffmpeg_runner.dart):
#   stream    a channel's encode (EncodeArgs.segment/songSegment) or muxer
#   analysis  commercial analysis (FfmpegRunner.arguments)
#   card      a card chunk (EncodeArgs.cardChunk) or the encoder check
# Any other ffmpeg counts as a stream, so an unknown encode can't hide.
#
# Pass or fail is decided by the app's own CPU (plus Xvfb's, when given) and
# the count of stream ffmpeg seen; analysis and card work are printed as
# declared background work and never decide it. Exit 0 = within budget,
# 1 = over budget, 2 = couldn't measure.
set -uo pipefail

BUDGET_PCT="${IDLE_BUDGET_PCT:-1}"

# The class of one ffmpeg, from its arguments joined by spaces.
classify() {
  local a=" $1 "
  case "$a" in
    *blackdetect*|*silencedetect*) echo analysis; return ;;
    *testsrc2=*) echo card; return ;;
    *" -progress pipe:2 "*|*" -i pipe:0 "*) echo stream; return ;;
  esac
  # A card chunk: silent, written to a file rather than to stdout.
  if [[ "$a" == *anullsrc* && "$a" != *" pipe:1 " ]]; then
    echo card
    return
  fi
  echo stream
}

if [ "${1:-}" = --classify ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && classify "$line"
  done
  exit 0
fi

die() { echo "measure: $*" >&2; exit 2; }

# The addresses <name> resolves to, one per line.
host_ips() { getent ahosts "$1" 2>/dev/null | awk '{print $1}' | sort -u; }

# How many of uid <uid>'s connections in the /proc/net/tcp{,6} text on stdin
# (established or opening) go to one of the addresses in the file <ips>.
# [inodes]: a file of socket inodes; only those count (Linux, where every
# process of the user shares the uid; an Android app has its own).
count_sockets() {
  python3 -c '
import ipaddress, sys
uid, ips = sys.argv[1], {ipaddress.ip_address(l.strip()) for l in open(sys.argv[2]) if l.strip()}
inodes = {l.strip() for l in open(sys.argv[3])} if len(sys.argv) > 3 else None
def addr(h):
    if len(h) == 8:
        return ipaddress.IPv4Address(bytes.fromhex(h)[::-1])
    raw = b"".join(bytes.fromhex(h[i:i + 8])[::-1] for i in range(0, 32, 8))
    a = ipaddress.IPv6Address(raw)
    return a.ipv4_mapped or a
n = 0
for line in sys.stdin:
    f = line.split()
    if len(f) < 8 or f[0] == "sl" or ":" not in f[2]:
        continue
    if f[7] != uid or f[3] not in ("01", "02", "03"):
        continue
    if inodes is not None and f[9] not in inodes:
        continue
    if addr(f[2].split(":")[0]) in ips:
        n += 1
print(n)
' "$@"
}

# utime + stime of a /proc/<pid>/stat line (the name may hold spaces).
ticks_of() { local s="${1##*) }"; local f=($s); echo $(( f[11] + f[12] )); }

pct() { awk -v t="$1" -v hz="$HZ" -v s="$2" 'BEGIN { printf "%.2f", t / hz / s * 100 }'; }

over() { awk -v p="$1" -v b="$BUDGET_PCT" 'BEGIN { exit !(p >= b) }'; }

if [ "${1:-}" = --adb ]; then
  pkg="${2:-}"
  secs="${3:-}"
  [ -n "$pkg" ] && [[ "$secs" =~ ^[0-9]+$ ]] || die "usage: measure.sh --adb <package> <seconds> [--host <name>]"
  host=
  [ "${4:-}" = --host ] && host="${5:-}"
  ADB="${ADB:-adb}"
  HZ=$($ADB shell getconf CLK_TCK 2>/dev/null | tr -d '\r')
  [[ "$HZ" =~ ^[0-9]+$ ]] || HZ=100
  pid=$($ADB shell pidof "$pkg" 2>/dev/null | tr -d '\r' | awk '{print $1}')
  [ -n "$pid" ] || die "$pkg isn't running"
  # Codecs the app holds: the media resource manager logs each codec
  # client's add and remove, newest first, so a client whose newest event is
  # an add is still open. (media.player and media.codec don't list owners on
  # current Android.)
  open_codecs() {
    $ADB shell dumpsys media.resource_manager 2>/dev/null | tr -d '\r' | awk -v pid="$pid" '
      /Events logs/ { ev = 1; next }
      ev && index($0, "(pid " pid ",") {
        if (!match($0, /clientId [0-9]+/)) next
        id = substr($0, RSTART + 9, RLENGTH - 9)
        if (id in seen) next
        seen[id] = 1
        if ($0 ~ /addResource/) n++
      }
      END { print n + 0 }'
  }
  socks_max=0
  if [ -n "$host" ]; then
    ips=$(mktemp); host_ips "$host" > "$ips"
    [ -s "$ips" ] || die "can't resolve $host"
    uid=$($ADB shell stat -c %u /proc/$pid 2>/dev/null | tr -d '\r')
    [[ "$uid" =~ ^[0-9]+$ ]] || die "can't read the uid of $pid"
  fi
  # The app's connections to the sharing host now.
  sharing_sockets() {
    $ADB shell cat /proc/$pid/net/tcp /proc/$pid/net/tcp6 2>/dev/null | tr -d '\r' | count_sockets "$uid" "$ips"
  }
  s0=$($ADB shell cat /proc/$pid/stat 2>/dev/null | tr -d '\r') || die "can't read /proc/$pid/stat"
  t0=$(ticks_of "$s0")
  start=$(date +%s.%N)
  open_max=0
  [ -n "$host" ] && socks_max=$(sharing_sockets)
  for ((i = 0; i < secs; i += 10)); do
    n=$(( secs - i < 10 ? secs - i : 10 ))
    sleep "$n"
    o=$(open_codecs)
    (( o > open_max )) && open_max=$o
    if [ -n "$host" ]; then
      k=$(sharing_sockets)
      (( k > socks_max )) && socks_max=$k
    fi
  done
  s1=$($ADB shell cat /proc/$pid/stat 2>/dev/null | tr -d '\r')
  [ -n "$s1" ] || die "$pkg stopped during the window"
  wall=$(awk -v a="$start" -v b="$(date +%s.%N)" 'BEGIN { print b - a }')
  app=$(pct $(( $(ticks_of "$s1") - t0 )) "$wall")
  echo "window ${secs}s"
  echo "app $app% (pid $pid, $pkg)"
  echo "codecs open $open_max"
  echo "stream 0"
  [ -n "$host" ] && echo "sharing sockets $socks_max ($host)"
  if over "$app" || (( open_max > 0 || socks_max > 0 )); then echo "FAIL"; exit 1; fi
  echo "PASS"
  exit 0
fi

pid="${1:-}"
secs="${2:-}"
[[ "$pid" =~ ^[0-9]+$ && "$secs" =~ ^[0-9]+$ ]] || die "usage: measure.sh <pid> <seconds> [--xvfb <pid>] [--host <name>]"
shift 2
xvfb=
cpu=1
host=
while [ $# -gt 0 ]; do
  case "$1" in
    --xvfb) xvfb="${2:-}"; shift 2 ;;
    --no-cpu) cpu=0; shift ;;
    --host) host="${2:-}"; shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done
HZ=$(getconf CLK_TCK)

# Every ffmpeg under the app: "pid ticks" lines.
ffmpegs() {
  awk -v root="$pid" '
    {
      line = $0
      i = index(line, " (")
      p = substr(line, 1, i - 1)
      j = length(line); while (substr(line, j, 1) != ")") j--
      name = substr(line, i + 2, j - i - 2)
      split(substr(line, j + 2), f, " ")
      parent[p] = f[2]; nm[p] = name; t[p] = f[12] + f[13]
    }
    END {
      for (p in parent) {
        if (nm[p] != "ffmpeg") continue
        q = parent[p]
        for (d = 0; d < 64 && q != "" && q != 0; d++) {
          if (q == root) { print p, t[p]; break }
          q = parent[q]
        }
      }
    }' /proc/[0-9]*/stat 2>/dev/null
}

declare -A first last class
sample() {
  local p t
  while read -r p t; do
    if [ -z "${class[$p]:-}" ]; then
      class[$p]=$(classify "$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null)")
      # Started during the window: all of its time counts.
      first[$p]=$([ "$1" = start ] && echo "$t" || echo 0)
    fi
    last[$p]=$t
  done < <(ffmpegs)
}

read_ticks() { local s; s=$(cat /proc/$1/stat 2>/dev/null) || return 1; ticks_of "$s"; }

socks_max=0
if [ -n "$host" ]; then
  ips=$(mktemp); host_ips "$host" > "$ips"
  [ -s "$ips" ] || die "can't resolve $host"
  uid=$(stat -c %u /proc/$pid) || die "no process $pid"
fi
sharing_sockets() {
  local own; own=$(mktemp)
  find /proc/$pid/fd -lname 'socket:*' -printf '%l\n' 2>/dev/null | sed 's/^socket:\[\(.*\)\]$/\1/' > "$own"
  cat /proc/$pid/net/tcp /proc/$pid/net/tcp6 2>/dev/null | count_sockets "$uid" "$ips" "$own"
  rm -f "$own"
}

a0=$(read_ticks "$pid") || die "no process $pid"
x0=0
[ -n "$xvfb" ] && { x0=$(read_ticks "$xvfb") || die "no Xvfb process $xvfb"; }
start=$(date +%s.%N)
sample start
for ((i = 0; i < secs; i++)); do
  sleep 1
  kill -0 "$pid" 2>/dev/null || [ -e /proc/$pid ] || die "process $pid stopped during the window"
  sample during
  if [ -n "$host" ] && (( i % 10 == 0 )); then
    k=$(sharing_sockets)
    (( k > socks_max )) && socks_max=$k
  fi
done
a1=$(read_ticks "$pid") || die "process $pid stopped during the window"
x1=0
[ -n "$xvfb" ] && { x1=$(read_ticks "$xvfb") || die "Xvfb $xvfb stopped during the window"; }
wall=$(awk -v a="$start" -v b="$(date +%s.%N)" 'BEGIN { print b - a }')

app=$(pct $(( a1 - a0 )) "$wall")
echo "window ${secs}s"
echo "app $app% (pid $pid)"
checked=$app
if [ -n "$xvfb" ]; then
  xv=$(pct $(( x1 - x0 )) "$wall")
  checked=$(awk -v a="$app" -v b="$xv" 'BEGIN { printf "%.2f", a + b }')
  echo "xvfb $xv% (pid $xvfb)"
  echo "app+xvfb $checked%"
fi

declare -A n ticks
n[stream]=0; n[analysis]=0; n[card]=0
ticks[stream]=0; ticks[analysis]=0; ticks[card]=0
streams=()
for p in "${!class[@]}"; do
  c=${class[$p]}
  n[$c]=$(( n[$c] + 1 ))
  ticks[$c]=$(( ticks[$c] + last[$p] - first[$p] ))
  [ "$c" = stream ] && streams+=("$p")
done
echo "stream ${n[stream]}${streams:+ (pids ${streams[*]})}"
echo "background analysis $(pct "${ticks[analysis]}" "$wall")% (${n[analysis]} ffmpeg), card $(pct "${ticks[card]}" "$wall")% (${n[card]} ffmpeg)"
[ -n "$host" ] && echo "sharing sockets $socks_max ($host)"
if { (( cpu )) && over "$checked"; } || (( n[stream] > 0 || socks_max > 0 )); then echo "FAIL"; exit 1; fi
echo "PASS"
