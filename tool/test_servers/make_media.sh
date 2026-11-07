#!/usr/bin/env bash
# Generates the test library the Docker Emby and Plex servers share:
#   3 shows x 2 seasons x 4 episodes (6-8 min, chaptered, with black and
#   silent act breaks), one show each in H.264/AAC, HEVC Main10/AC-3 and
#   H.264/DTS; 2 movies; 4 subtitle test movies (two embedded tracks neither
#   flagged default, one embedded default track, an external .en.srt sidecar
#   only, and HEVC Main10 with an embedded default track), every cue naming
#   its track and time; a Commercials folder of 40 clips and a chaptered
#   reel; 30 tagged songs; 6 music videos.
# Output goes to $NIGHTINGALE_TEST_MEDIA (default ~/.cache/nightingale-test-media).
# Re-running skips files that already exist.
set -euo pipefail

OUT="${NIGHTINGALE_TEST_MEDIA:-$HOME/.cache/nightingale-test-media}"
JOBS="${JOBS:-4}"
FONT="$(fc-match -f '%{file}' sans)"

command -v ffmpeg >/dev/null || { echo "ffmpeg is needed" >&2; exit 1; }
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Text for drawtext: escape the characters its parser treats specially.
esc() { printf '%s' "$1" | sed -e "s/\\\\/\\\\\\\\/g" -e "s/:/\\\\:/g" -e "s/'/\\\\'/g" -e 's/%/\\%/g'; }

# chapters <file> <total seconds> <break seconds...>: an ffmetadata file with
# one chapter per act.
chapters() {
  local file="$1" total="$2"; shift 2
  local start=0 n=1
  { echo ";FFMETADATA1"
    for b in "$@" "$total"; do
      printf '[CHAPTER]\nTIMEBASE=1/1000\nSTART=%d\nEND=%d\ntitle=Act %d\n' $((start * 1000)) $((b * 1000)) $n
      start=$b; n=$((n + 1))
    done
  } > "$file"
}

# video <out> <seconds> <label> <video args> <audio args> [break seconds...]
# A test pattern with the label on it and a tone; each break is 1.5 s of
# black and silence, and starts a chapter.
video() {
  local out="$1" secs="$2" label="$3" vargs="$4" aargs="$5"; shift 5
  [[ -s "$out" ]] && return 0
  mkdir -p "$(dirname "$out")"
  local enable="0"
  for b in "$@"; do enable="$enable+between(t,$b-1.5,$b)"; done
  local meta="$TMP/$(basename "$out").meta"
  chapters "$meta" "$secs" "$@"
  local tmp="${out%.*}.part.${out##*.}"
  # shellcheck disable=SC2086
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=s=1280x720:r=30000/1001:d=$secs" \
    -f lavfi -i "sine=f=$((300 + RANDOM % 500)):d=$secs:sample_rate=48000" \
    -i "$meta" -map 0:v -map 1:a -map_metadata 2 -map_chapters 2 \
    -vf "drawtext=fontfile=$FONT:text='$(esc "$label")':fontsize=56:fontcolor=white:box=1:boxcolor=black@0.6:x=(w-tw)/2:y=h-140,drawtext=fontfile=$FONT:text='%{pts\\:hms}':fontsize=40:fontcolor=yellow:x=40:y=40,drawbox=c=black:t=fill:enable='$enable'" \
    -af "volume=0:enable='$enable'" \
    $vargs $aargs -metadata title="$label" "$tmp"
  mv "$tmp" "$out"
}

H264_HI="-c:v libx264 -preset veryfast -b:v 5M -maxrate 5M -bufsize 10M -x264-params nal-hrd=cbr:keyint=60 -pix_fmt yuv420p"
H264="-c:v libx264 -preset veryfast -b:v 2M -maxrate 2M -bufsize 4M -x264-params keyint=60 -pix_fmt yuv420p"
HEVC10="-c:v libx265 -preset ultrafast -b:v 2M -pix_fmt yuv420p10le -profile:v main10 -tag:v hvc1 -x265-params log-level=error:keyint=60"
AAC="-c:a aac -b:a 160k -ac 2"
AC3="-c:a ac3 -b:a 448k -ac 6"
DTS="-af aformat=channel_layouts=5.1(side) -c:a dca -strict -2 -b:a 768k"

running=0
spawn() { "$@" & running=$((running + 1)); if ((running >= JOBS)); then wait -n; running=$((running - 1)); fi; }

# --- TV -------------------------------------------------------------------
show() {
  local name="$1" year="$2" ext="$3" vargs="$4" aargs="$5"
  for s in 1 2; do
    for e in 1 2 3 4; do
      local secs=$((360 + (s * 4 + e) * 15 % 120))
      local b1=$((secs / 3)) b2=$((secs * 2 / 3))
      local tag; tag=$(printf 'S%02dE%02d' "$s" "$e")
      spawn video "$OUT/TV/$name ($year)/Season $(printf %02d "$s")/$name - $tag - Episode $e.$ext" \
        "$secs" "$name $tag" "$vargs" "$aargs" "$b1" "$b2"
    done
  done
}
show "Maple Street" 1987 mp4 "$H264_HI" "$AAC"
show "Signal Hill" 1993 mkv "$HEVC10" "$AC3"
show "Night Desk" 1979 mkv "$H264" "$DTS"

# Local artwork for one show, as both servers read it from the show's
# folder: a poster, and a clear logo (Emby: logo.png, Plex: clearlogo.png).
art="$OUT/TV/Maple Street (1987)"
[[ -s "$art/poster.jpg" ]] || ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0x1d4e89:s=600x900:d=1" \
  -vf "drawtext=fontfile=$FONT:text='MAPLE STREET':fontsize=72:fontcolor=white:x=(w-tw)/2:y=(h-th)/2" -frames:v 1 "$art/poster.jpg"
if [[ ! -s "$art/logo.png" ]]; then
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=black@0.0:s=800x310:d=1,format=rgba" \
    -vf "drawtext=fontfile=$FONT:text='Maple Street':fontsize=110:fontcolor=0xffcc33:x=(w-tw)/2:y=(h-th)/2" \
    -frames:v 1 "$art/logo.png"
  cp "$art/logo.png" "$art/clearlogo.png"
fi

# --- Movies ---------------------------------------------------------------
spawn video "$OUT/Movies/The Long Hallway (1984)/The Long Hallway (1984).mp4" 900 "The Long Hallway" "$H264" "$AAC" 300 600
spawn video "$OUT/Movies/Copper Moon (1991)/Copper Moon (1991).mkv" 840 "Copper Moon" "$HEVC10" "$AC3" 280 560

# --- Subtitle movies ------------------------------------------------------
# srt <file> <seconds> <track name>: a cue every 5 s reading "<TRACK> <n>s",
# so a screenshot shows which track is on screen and where.
srt() {
  local file="$1" secs="$2" name="$3" t n=1
  : > "$file"
  for ((t = 0; t < secs; t += 5)); do
    printf '%d\n%02d:%02d:%02d,000 --> %02d:%02d:%02d,000\n%s %ds\n\n' $n \
      $((t / 3600)) $((t / 60 % 60)) $((t % 60)) $(((t + 5) / 3600)) $(((t + 5) / 60 % 60)) $(((t + 5) % 60)) \
      "$name" "$t" >> "$file"
    n=$((n + 1))
  done
}

# subbed <out.mkv> <seconds> <label> <video args> <dispositions> <track:lang>...
# A test movie with embedded SRT tracks. The dispositions (for example
# "0 0" or "default") apply to the subtitle tracks in order; passthrough
# keeps the muxer from flagging the first track default on its own.
subbed() {
  local out="$1" secs="$2" label="$3" vargs="$4" disp="$5"; shift 5
  [[ -s "$out" ]] && return 0
  local base="$TMP/$(basename "$out" .mkv).base.mkv"
  video "$base" "$secs" "$label" "$vargs" "$AAC"
  local inputs=() maps=() meta=() i=0
  for spec in "$@"; do
    local name="${spec%%:*}" lang="${spec##*:}" f="$TMP/$(basename "$out" .mkv).$i.srt"
    srt "$f" "$secs" "$name"
    inputs+=(-i "$f"); maps+=(-map $((i + 1)):0)
    meta+=("-metadata:s:s:$i" "language=$lang")
    i=$((i + 1))
  done
  local d=() j=0
  for flag in $disp; do d+=("-disposition:s:$j" "$flag"); j=$((j + 1)); done
  mkdir -p "$(dirname "$out")"
  local tmp="${out%.mkv}.part.mkv"
  ffmpeg -hide_banner -loglevel error -y -i "$base" "${inputs[@]}" -map 0:v -map 0:a "${maps[@]}" \
    -c copy -c:s srt "${meta[@]}" "${d[@]}" -default_mode passthrough "$tmp"
  mv "$tmp" "$out"
  rm -f "$base"
}

SUB_SECS=600
H264_SUB="-c:v libx264 -preset veryfast -b:v 1M -maxrate 1M -bufsize 2M -x264-params keyint=60 -pix_fmt yuv420p"
HEVC10_SUB="-c:v libx265 -preset ultrafast -b:v 1M -pix_fmt yuv420p10le -profile:v main10 -x265-params log-level=error:keyint=60"
sub="$OUT/Movies/Sub Test"
spawn subbed "$sub Embedded (2026)/Sub Test Embedded (2026).mkv" $SUB_SECS "Sub Test Embedded" "$H264_SUB" "0 0" \
  "EMBEDDED ENGLISH:eng" "EMBEDDED SPANISH:spa"
spawn subbed "$sub Default (2026)/Sub Test Default (2026).mkv" $SUB_SECS "Sub Test Default" "$H264_SUB" "default" \
  "EMBEDDED DEFAULT:eng"
spawn subbed "$sub Transcode (2026)/Sub Test Transcode (2026).mkv" $SUB_SECS "Sub Test Transcode" "$HEVC10_SUB" "default" \
  "EMBEDDED TRANSCODE:eng"
ext="$sub External (2026)/Sub Test External (2026)"
spawn subbed "$ext.mkv" $SUB_SECS "Sub Test External" "$H264_SUB" ""
[[ -s "$ext.en.srt" ]] || { mkdir -p "$(dirname "$ext")"; srt "$ext.en.srt" $SUB_SECS "EXTERNAL SIDECAR"; }
wait
running=0

# --- Commercials ----------------------------------------------------------
brands=(Fizzo Crunchos Glimmer Zapp Toastee Brightway Kool Snappers Wavelength Mellow
  Rocket Sunny Pebble Velvet Boomer Tidal Juniper Orbit Dazzle Hearth)
for i in $(seq 1 40); do
  brand="${brands[$(((i - 1) % ${#brands[@]}))]}"
  secs=$((15 + (i * 7) % 4 * 15))
  spawn video "$OUT/Home Videos/Commercials/$(printf '%02d' "$i") $brand Spot $(((i - 1) / ${#brands[@]} + 1)).mp4" \
    "$secs" "$brand" "$H264" "$AAC"
done
wait
running=0

# A reel: 8 spots back to back, a chapter per spot, black between them.
reel="$OUT/Home Videos/Commercials/Reels/Saturday Morning Reel 1985.mkv"
if [[ ! -s "$reel" ]]; then
  marks=(); t=0
  for i in 1 2 3 4 5 6 7; do t=$((t + 30)); marks+=("$t"); done
  video "$reel" 240 "Saturday Morning Reel" "$H264" "$AAC" "${marks[@]}"
fi

# --- Music ----------------------------------------------------------------
artists=("The Paper Kites Club" "Vera Lune" "Static Orchard" "Hollow Pines" "DJ Marmalade")
genres=(Rock Pop Rock Folk Electronic)
song=0
for a in 0 1 2 3 4; do
  for album in 1 2; do
    year=$((1978 + a * 3 + album))
    title="Album $album"
    for track in 1 2 3; do
      song=$((song + 1))
      f="$OUT/Music/${artists[$a]}/$title ($year)/$(printf '%02d' "$track") - Song $song.mp3"
      [[ -s "$f" ]] && continue
      mkdir -p "$(dirname "$f")"
      ffmpeg -hide_banner -loglevel error -y \
        -f lavfi -i "sine=f=$((220 + song * 20)):d=$((120 + song % 4 * 20)):sample_rate=44100" \
        -af "volume=0.5,tremolo=f=$((2 + track)):d=0.6" -c:a libmp3lame -b:a 128k -id3v2_version 3 \
        -metadata title="Song $song" -metadata artist="${artists[$a]}" -metadata album_artist="${artists[$a]}" \
        -metadata album="$title" -metadata genre="${genres[$a]}" -metadata date="$year" \
        -metadata track="$track/3" "$f"
    done
  done
done

# --- Music videos ---------------------------------------------------------
# Emby (and Jellyfin) read a Music Videos library. Plex reads music videos
# from inside the artist's folder, named after the track with -video.
for i in 1 2 3 4 5 6; do
  a=$(((i - 1) % 5))
  artist="${artists[$a]}"
  name="Song $((a * 6 + 1 + (i - 1) / 5))"
  f="$OUT/Music Videos/$artist - $name.mp4"
  spawn video "$f" $((150 + i * 10)) "$artist - $name" "$H264" "$AAC"
done
wait
for i in 1 2 3 4 5 6; do
  a=$(((i - 1) % 5))
  artist="${artists[$a]}"
  name="Song $((a * 6 + 1 + (i - 1) / 5))"
  plex="$OUT/Music/$artist/$name-video.mp4"
  [[ -s "$plex" ]] || ln "$OUT/Music Videos/$artist - $name.mp4" "$plex"
done

du -sh "$OUT"
