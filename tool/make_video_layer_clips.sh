#!/usr/bin/env bash
# Makes the files integration_test/video_layer_test.dart plays
# (system-video-layer D9), into build/video_layer_clips (or the folder given):
#   h264_720x480   H.264, 4:3 flag (a decoder that pads uses 768 columns)
#   h264_698x480   H.264 (padded to 704)
#   h264_1280x534  H.264 (padded to 544 rows)
#   h264_1920x1080 H.264 (padded to 1088 rows)
#   mpeg2_720x480  MPEG-2, 4:3 flag, the Shield reports' codec
#   hevc8          HEVC Main
#   hevc10         HEVC Main 10, SDR
#   hevc_pq        HEVC Main 10, BT.2020 PQ
#   av1_10, av1_pq the same two in AV1: no emulator decoder takes 10-bit HEVC
# Every picture has an 8-pixel border (left magenta, right cyan, top yellow,
# bottom orange), a numbered ruler inside it, a 4×4 grid of flat colours and
# a moving marker, so a missing or extra column, a wrong shape and wrong
# colours are visible. <name>.png is the picture without the marker, at the
# file's own size. Needs ffmpeg (libx264, libx265, libaom) and python3 with Pillow.
set -euo pipefail
out="${1:-$(cd "$(dirname "$0")/.." && pwd)/build/video_layer_clips}"
mkdir -p "$out"

frame() { # width height file
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
w, h, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
img = Image.new('RGB', (w, h), (40, 40, 40))
d = ImageDraw.Draw(img)
colours = [
    (190, 30, 30), (30, 160, 50), (40, 60, 200), (200, 190, 40),
    (40, 180, 180), (180, 50, 170), (230, 230, 230), (120, 120, 120),
    (200, 110, 40), (90, 40, 130), (60, 110, 70), (150, 170, 220),
    (235, 170, 150), (60, 60, 60), (20, 90, 120), (130, 130, 40),
]
gx0, gy0, gx1, gy1 = w // 8, h // 6, w - w // 8, h - h // 6
for i, c in enumerate(colours):
    x, y = i % 4, i // 4
    d.rectangle([gx0 + (gx1 - gx0) * x // 4, gy0 + (gy1 - gy0) * y // 4,
                 gx0 + (gx1 - gx0) * (x + 1) // 4 - 1, gy0 + (gy1 - gy0) * (y + 1) // 4 - 1], fill=c)
font = ImageFont.load_default()
for x in range(0, w, 16):
    long = x % 80 == 0
    for y0, s in ((8, 1), (h - 9, -1)):
        d.line([x, y0, x, y0 + s * (12 if long else 6)], fill=(255, 255, 255))
    if long and 16 <= x < w - 32:
        d.text((x + 2, 12), str(x), font=font, fill=(255, 255, 255))
        d.text((x + 2, h - 26), str(x), font=font, fill=(255, 255, 255))
for y in range(0, h, 16):
    long = y % 80 == 0
    for x0, s in ((8, 1), (w - 9, -1)):
        d.line([x0, y, x0 + s * (12 if long else 6), y], fill=(255, 255, 255))
    if long and 32 <= y < h - 32:
        d.text((24, y - 5), str(y), font=font, fill=(255, 255, 255))
        d.text((w - 52, y - 5), str(y), font=font, fill=(255, 255, 255))
d.rectangle([0, 0, w - 1, 7], fill=(230, 220, 20))
d.rectangle([0, h - 8, w - 1, h - 1], fill=(240, 130, 0))
d.rectangle([0, 0, 7, h - 1], fill=(220, 0, 200))
d.rectangle([w - 8, 0, w - 1, h - 1], fill=(0, 200, 220))
img.save(path)
PY
}

ext=mp4
# name width height matrix sar, then the encoder's arguments
clip() {
  local name=$1 w=$2 h=$3 matrix=$4 sar=$5
  shift 5
  # A clip already made is kept, as the slow encoders take minutes.
  if [ -s "$out/$name.$ext" ]; then return; fi
  frame "$w" "$h" "$out/$name.png"
  ffmpeg -v error -y -loop 1 -framerate 30 -i "$out/$name.png" \
    -f lavfi -i "color=white:size=12x12:rate=30" -f lavfi -i "sine=frequency=440:sample_rate=48000" \
    -filter_complex "[0:v][1:v]overlay=x='mod(t*120,main_w-60)+24':y='main_h*0.9-6',scale=out_color_matrix=$matrix:out_range=tv,setsar=$sar" \
    -t 30 -r 30 -g 30 "$@" -c:a aac -b:a 96k -movflags +faststart "$out/$name.$ext"
  echo "$out/$name.$ext"
}

x264=(-c:v libx264 -profile:v high -pix_fmt yuv420p -preset medium -crf 12)
sd=(-colorspace smpte170m -color_primaries smpte170m -color_trc smpte170m)
hd=(-colorspace bt709 -color_primaries bt709 -color_trc bt709)
clip h264_720x480 720 480 bt601 8/9 "${x264[@]}" "${sd[@]}"
clip h264_698x480 698 480 bt601 1 "${x264[@]}" "${sd[@]}"
clip h264_1280x534 1280 534 bt709 1 "${x264[@]}" "${hd[@]}"
clip h264_1920x1080 1920 1080 bt709 1 "${x264[@]}" "${hd[@]}"
clip hevc8 1920 1080 bt709 1 -c:v libx265 -pix_fmt yuv420p -preset fast -crf 12 -tag:v hvc1 -x265-params "log-level=error:keyint=30" "${hd[@]}"
clip hevc10 1920 1080 bt709 1 -c:v libx265 -pix_fmt yuv420p10le -preset fast -crf 12 -tag:v hvc1 -x265-params "log-level=error:keyint=30" "${hd[@]}"
clip hevc_pq 1920 1080 bt2020 1 -c:v libx265 -pix_fmt yuv420p10le -preset fast -crf 12 -tag:v hvc1 \
  -x265-params "log-level=error:keyint=30:hdr10=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,50):max-cll=1000,400" \
  -colorspace bt2020nc -color_primaries bt2020 -color_trc smpte2084
aom=(-c:v libaom-av1 -cpu-used 8 -row-mt 1 -crf 20 -pix_fmt yuv420p10le)
clip av1_10 1920 1080 bt709 1 "${aom[@]}" "${hd[@]}"
clip av1_pq 1920 1080 bt2020 1 "${aom[@]}" -colorspace bt2020nc -color_primaries bt2020 -color_trc smpte2084
ext=ts
clip mpeg2_720x480 720 480 bt601 8/9 -c:v mpeg2video -pix_fmt yuv420p -q:v 2 "${sd[@]}"
