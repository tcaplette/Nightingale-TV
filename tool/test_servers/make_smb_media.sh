#!/usr/bin/env bash
# Generates what the SMB shares hold besides the shared test library
# (make_media.sh): video no Android device plays as it is, a damaged file,
# and files named, described and captioned in every way a share can have
# them. They are kept apart from the test library so a share and a media
# server holding that library stay the same.
#
#   Formats/   movies in WMV (VC-1), AVI (MPEG-4 ASP), MPEG-2, DTS, TrueHD (needs docker),
#              HDR10 HEVC and MJPEG, one cut-off file, one with no video
#   Names/TV, Names/Movies
#              every supported way of naming files, .nfo files, artwork and
#              sidecar subtitles
#   Home/      home videos
#   Commercials/, Bumpers/
#              short clips, some in old formats
#   Backups/   files that are not media
#
# Output goes to $NIGHTINGALE_TEST_SMB_MEDIA (default
# ~/.cache/nightingale-test-smb-media). Re-running skips what exists. The
# VC-1 clip can't be made by FFmpeg, so a 1 s one is downloaded from
# FFmpeg's test suite and looped.
set -euo pipefail

OUT="${NIGHTINGALE_TEST_SMB_MEDIA:-$HOME/.cache/nightingale-test-smb-media}"
VC1_URL=https://fate-suite.ffmpeg.org/vc1/SA10091.vc1
VC1_SHA256=c60a0da89873b40d7e436f1c29757c6cc71f3c51f2ac2ea8c6bd023762c94b6c
command -v ffmpeg >/dev/null || { echo "ffmpeg is needed" >&2; exit 1; }
# The TrueHD clip's sound needs a newer FFmpeg: the Jellyfin test image's.
JELLYFIN_IMAGE="$(sed -n 's/^ *image: *\(jellyfin\/jellyfin:.*\)$/\1/p' "$(dirname "$0")/compose.yaml" | head -1)"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ff() { ffmpeg -hide_banner -loglevel error -y "$@"; }

# clip <out> <seconds> <size> <output args...>: a test pattern and a tone.
clip() {
  local out="$1" secs="$2" size="$3"; shift 3
  [[ -s "$out" ]] && return 0
  mkdir -p "$(dirname "$out")"
  local tmp="${out%.*}.part.${out##*.}"
  ff -f lavfi -i "testsrc2=s=$size:r=30000/1001:d=$secs" -f lavfi -i "sine=f=440:d=$secs:sample_rate=48000" \
    -map 0:v -map 1:a "$@" "$tmp"
  mv "$tmp" "$out"
}

X264=(-c:v libx264 -preset veryfast -b:v 800k -pix_fmt yuv420p -g 60)
AAC=(-c:a aac -b:a 96k -ac 2)

# --- Formats ---------------------------------------------------------------
F="$OUT/Formats"
wmv="$F/Windows Media (2001).wmv"
if [[ ! -s "$wmv" ]]; then
  mkdir -p "$F"
  curl -fsSL -o "$TMP/clip.vc1" "$VC1_URL"
  echo "$VC1_SHA256  $TMP/clip.vc1" | sha256sum -c --quiet
  for _ in $(seq 180); do cat "$TMP/clip.vc1"; done > "$TMP/loop.vc1"
  ff -r 30000/1001 -f vc1 -i "$TMP/loop.vc1" -f lavfi -i "sine=f=400:d=180" -map 0:v -map 1:a \
    -c:v copy -c:a wmav2 -b:a 128k -t 180 "$wmv"
fi
clip "$F/DivX Movie (2002).avi" 180 640x480 -c:v mpeg4 -vtag DIVX -b:v 1500k -c:a libmp3lame -b:a 128k
clip "$F/Old Disc (1997).mpg" 180 720x480 -c:v mpeg2video -b:v 4M -c:a ac3 -b:a 192k
clip "$F/Surround DTS (2010).mkv" 180 1280x720 "${X264[@]}" -af "aformat=channel_layouts=5.1(side)" -c:a dca -strict -2 -b:a 768k
# TrueHD: FFmpeg before 7 writes streams current decoders refuse ("No
# restart header"), so its sound is encoded by the Jellyfin test image's
# FFmpeg 8.
if [[ ! -s "$F/Lossless TrueHD (2012).mkv" ]]; then
  clip "$TMP/truehd-src.mkv" 180 1280x720 "${X264[@]}" -af "aformat=channel_layouts=5.1" -c:a pcm_s16le
  sg docker -c "docker run --rm --network none --user $(id -u):$(id -g) --entrypoint /usr/lib/jellyfin-ffmpeg/ffmpeg \
    -v '$TMP:/in:ro' -v '$F:/out' $JELLYFIN_IMAGE -nostdin -hide_banner -loglevel error -y \
    -i /in/truehd-src.mkv -map 0 -c:v copy -c:a truehd -strict -2 '/out/Lossless TrueHD (2012).part.mkv'"
  mv "$F/Lossless TrueHD (2012).part.mkv" "$F/Lossless TrueHD (2012).mkv"
fi
clip "$F/High Range HDR10 (2018).mkv" 180 1920x1080 -c:v libx265 -preset ultrafast -b:v 4M -pix_fmt yuv420p10le \
  -x265-params "log-level=error:keyint=60:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400" \
  -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc "${AAC[@]}"
clip "$F/Motion JPEG (2000).avi" 120 640x480 -c:v mjpeg -q:v 6 -c:a pcm_s16le
if [[ ! -s "$F/Cut Off (2005).mp4" ]]; then
  clip "$TMP/whole.mp4" 120 640x480 "${X264[@]}" "${AAC[@]}"
  # The index is at the end of an MP4, so half of one can't be read at all.
  head -c "$(($(stat -c %s "$TMP/whole.mp4") / 2))" "$TMP/whole.mp4" > "$F/Cut Off (2005).mp4"
fi
[[ -s "$F/Sound Only (2006).mp4" ]] || ff -f lavfi -i "sine=f=300:d=120" -c:a aac "$F/Sound Only (2006).mp4"

# --- Names -----------------------------------------------------------------
clip "$TMP/small.mkv" 60 640x360 "${X264[@]}" "${AAC[@]}"
put() { [[ -s "$1" ]] || { mkdir -p "$(dirname "$1")"; cp "$TMP/small.mkv" "$1"; }; }
TV="$OUT/Names/TV"
put "$TV/Show A (2001)/Season 2/Show A S02E03.mkv"
put "$TV/Show A (2001)/Season 2/Show A S02E04E05.mkv"
put "$TV/Show A (2001)/Season 02/show.a.s02e06.720p.web.h264-grp.mkv"
put "$TV/Show B/Show B - 1x02 - The Second.mkv"
put "$TV/Daily Show [tvdbid-71256]/Daily Show - 2024-05-01 - Monday Guest.mkv"
put "$TV/Daily Show [tvdbid-71256]/Daily Show 2024.05.02.mkv"
put "$TV/Flat Show S01E01.mkv"
put "$TV/Show C/Season 1/E01 - Pilot.mkv"
put "$TV/Show C/Season 1/02.mkv"
put "$TV/Show C/Season 1/sample.mkv"
put "$TV/Show C/extras/Interview.mkv"
put "$TV/.hidden/Nope S01E01.mkv"
put "$TV/@eaDir/Nope S01E02.mkv"
M="$OUT/Names/Movies"
put "$M/Heat (1995) {tmdb-949}/Heat.mkv"
put "$M/Alien.1979.1080p.BluRay.x264-GRP.mkv"
put "$M/Yearless Movie.mkv"
put "$M/Described/film.mkv"
put "$M/Broken Info (2003)/Broken Info (2003).mkv"
put "$M/Captions (2020)/Captions (2020).mkv"
put "$M/Captions (2020)/trailers/Captions trailer.mkv"
cat > "$M/Described/movie.nfo" <<'NFO'
<?xml version="1.0" encoding="UTF-8"?>
<movie>
  <title>A Described Movie</title>
  <year>1988</year>
  <plot>Everything about it comes from its .nfo file.</plot>
  <genre>Comedy</genre>
  <genre>Family</genre>
  <mpaa>Rated PG-13</mpaa>
  <runtime>1</runtime>
  <uniqueid type="imdb" default="true">tt0088763</uniqueid>
  <uniqueid type="tmdb">105</uniqueid>
</movie>
NFO
printf '<movie><title>Never closed' > "$M/Broken Info (2003)/movie.nfo"
cat > "$TV/Show A (2001)/tvshow.nfo" <<'NFO'
<tvshow><title>Show A</title><year>2001</year><genre>Drama</genre><mpaa>TV-PG</mpaa><uniqueid type="tvdb">4242</uniqueid></tvshow>
NFO
cat > "$TV/Show A (2001)/Season 2/Show A S02E03.nfo" <<'NFO'
<episodedetails><title>The Third One</title><season>2</season><episode>3</episode><plot>From the .nfo.</plot><aired>2002-03-04</aired></episodedetails>
NFO
[[ -s "$TV/Show A (2001)/poster.jpg" ]] || ff -f lavfi -i "color=c=0x7a2a2a:s=600x900:d=1" -frames:v 1 "$TV/Show A (2001)/poster.jpg"
[[ -s "$TV/Show A (2001)/clearlogo.png" ]] || ff -f lavfi -i "color=c=yellow:s=400x120:d=1" -frames:v 1 "$TV/Show A (2001)/clearlogo.png"
[[ -s "$M/Captions (2020)/Captions (2020)-poster.jpg" ]] || ff -f lavfi -i "color=c=0x2a7a2a:s=600x900:d=1" -frames:v 1 "$M/Captions (2020)/Captions (2020)-poster.jpg"
cues() { # file, words
  : > "$1"
  for t in $(seq 0 5 55); do
    printf '%d\n00:00:%02d,000 --> 00:00:%02d,900\n%s %ds\n\n' $((t / 5 + 1)) "$t" $((t + 4)) "$2" "$t" >> "$1"
  done
}
cues "$M/Captions (2020)/Captions (2020).en.forced.srt" "ENGLISH FORCED"
cues "$M/Captions (2020)/Captions (2020).es.default.srt" "SPANISH"
cues "$TMP/fr.srt" "FRENCH"
[[ -s "$M/Captions (2020)/Captions (2020).fr.ass" ]] || ff -i "$TMP/fr.srt" "$M/Captions (2020)/Captions (2020).fr.ass"
[[ -s "$M/Captions (2020)/Captions (2020).de.vtt" ]] || ff -i "$TMP/fr.srt" "$M/Captions (2020)/Captions (2020).de.vtt"

# A picture subtitle track (DVD) and a text one, in a file that also needs
# its picture converting.
image="$M/Image Captions (2019)/Image Captions (2019).mkv"
if [[ ! -s "$image" ]]; then
  mkdir -p "$(dirname "$image")"
  # FFmpeg draws no text into picture subtitles, so the pictures are a
  # bright bar, made by a small script.
  python3 - "$TMP/cues.sup" <<'PY'
import struct, sys
# A PGS stream: a 320x40 white bar for 4 of every 5 s of a 60 s file.
def seg(pts, kind, body):
    return b'PG' + struct.pack('>IIBH', pts, 0, kind, len(body)) + body
out = b''
W, H, w, h = 640, 360, 320, 40
rle = b''.join(b'\x00' + bytes([0xC0 | (w >> 8), w & 0xFF, 1]) + b'\x00\x00' for _ in range(h))
n = 0
for t in range(0, 60, 5):
    pts = (t * 90000) or 90
    pcs = struct.pack('>HHBHBBBB', W, H, 0x10, n, 0x80, 0, 0, 1) + struct.pack('>HBBHH', 0, 0, 0, 160, 300)
    wds = bytes([1, 0]) + struct.pack('>HHHH', 160, 300, w, h)
    pds = bytes([0, 0, 1, 235, 128, 128, 255])
    ods = struct.pack('>HBB', 0, 0, 0xC0) + struct.pack('>I', len(rle) + 4)[1:] + struct.pack('>HH', w, h) + rle
    out += seg(pts, 0x16, pcs) + seg(pts, 0x17, wds) + seg(pts, 0x14, pds) + seg(pts, 0x15, ods) + seg(pts, 0x80, b'')
    n += 1
    end = (t + 4) * 90000
    out += seg(end, 0x16, struct.pack('>HHBHBBBB', W, H, 0x10, n, 0, 0, 0, 0)) + seg(end, 0x17, wds) + seg(end, 0x80, b'')
    n += 1
open(sys.argv[1], 'wb').write(out)
PY
  cues "$TMP/en.srt" "TEXT"
  ff -i "$TMP/small.mkv" -i "$TMP/cues.sup" -i "$TMP/en.srt" -map 0:v -map 0:a -map 1:s -map 2:s \
    -c:v mpeg4 -b:v 1M -c:a copy -c:s:0 copy -c:s:1 srt -metadata:s:s:0 language=eng -metadata:s:s:1 language=eng "$image"
fi

# --- Home videos, commercials, bumpers --------------------------------------
for n in 1 2 3 4 5; do put "$OUT/Home/Summer 2019/Beach day $n.mkv"; done
put "$OUT/Home/Birthday.mkv"
for n in 1 2 3 4; do
  clip "$OUT/Commercials/Soda Spot $n.mp4" $((15 + n * 5)) 640x480 "${X264[@]}" "${AAC[@]}"
done
clip "$OUT/Commercials/Old Spot 1.avi" 30 640x480 -c:v mpeg4 -vtag DIVX -b:v 1500k -c:a libmp3lame -b:a 128k
clip "$OUT/Commercials/Old Spot 2.mpg" 30 720x480 -c:v mpeg2video -b:v 3M -c:a mp2 -b:a 192k
clip "$OUT/Bumpers/We'll be right back.mp4" 6 640x480 "${X264[@]}" "${AAC[@]}"
mkdir -p "$OUT/Backups"
[[ -s "$OUT/Backups/notes.txt" ]] || echo "Not media." > "$OUT/Backups/notes.txt"

du -sh "$OUT"
