#!/usr/bin/env python3
"""Makes the video report's test cards (video-report, design D6).

Draws a 1920x1080 card, encodes it into three 1 s, 24 fps clips with one
keyframe, signalled BT.709 limited range (h264 High, hevc Main, hevc10
Main10), decodes each again with ffmpeg and writes what each should measure
to card_expected.json. The measurement is design D2's, ported line for line
from lib/reporting/picture_measure.dart; test/picture_measure_test.dart
checks the two agree on the decoded h264 card, which this also writes as a
PNG fixture.

  tool/make_video_test_card.py [--out assets/video_test]
      [--fixture test/fixtures/video_test/card_h264.png]

Needs Pillow, numpy and ffmpeg with libx264 and libx265.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

W, H = 1920, 1080
COLS, ROWS = 16, 9

# Every clip: 1 s at 24 fps, one keyframe, BT.709 limited range.
FPS = 24
FRAMES = 24

CLIPS = {
    'h264': {
        'pix_fmt': 'yuv420p',
        'args': ['-c:v', 'libx264', '-profile:v', 'high', '-preset', 'veryslow', '-crf', '12',
                 '-x264-params', 'keyint=24:min-keyint=24:scenecut=0:bframes=0:'
                                 'colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off'],
    },
    'hevc': {
        'pix_fmt': 'yuv420p',
        'args': ['-c:v', 'libx265', '-profile:v', 'main', '-preset', 'slow', '-crf', '12', '-tag:v', 'hvc1',
                 '-x265-params', 'log-level=error:keyint=24:min-keyint=24:scenecut=0:bframes=0:'
                                 'colorprim=bt709:transfer=bt709:colormatrix=bt709:range=limited'],
    },
    'hevc10': {
        'pix_fmt': 'yuv420p10le',
        'args': ['-c:v', 'libx265', '-profile:v', 'main10', '-preset', 'slow', '-crf', '12', '-tag:v', 'hvc1',
                 '-x265-params', 'log-level=error:keyint=24:min-keyint=24:scenecut=0:bframes=0:'
                                 'colorprim=bt709:transfer=bt709:colormatrix=bt709:range=limited'],
    },
}


def draw_card():
    """The card: colour bars, a 16-step grey ramp, fine luma detail, and a
    distinct colour in each corner (red, green, blue, white)."""
    a = np.full((H, W, 3), 96, np.uint8)
    # Corners: 240x240, each 2x2 grid cells.
    a[0:240, 0:240] = (220, 30, 30)
    a[0:240, W - 240:W] = (30, 200, 40)
    a[H - 240:H, 0:240] = (30, 40, 220)
    a[H - 240:H, W - 240:W] = (235, 235, 235)
    # Eight 75% colour bars, between the top corners.
    bars = [(191, 191, 191), (191, 191, 0), (0, 191, 191), (0, 191, 0),
            (191, 0, 191), (191, 0, 0), (0, 0, 191), (16, 16, 16)]
    bw = (W - 480) // 8
    for i, c in enumerate(bars):
        a[0:480, 240 + i * bw:240 + (i + 1) * bw] = c
    # A 16-step grey ramp across the width: one step per grid column.
    for i in range(16):
        v = round(16 + i * (235 - 16) / 15)
        a[480:720, i * 120:(i + 1) * 120] = (v, v, v)
    # Fine luma detail between the bottom corners: 1-px stripes, 2-px
    # stripes and a 1-px checkerboard, 480 px wide each.
    y0, y1 = 720, H
    x = np.arange(480)
    yy = np.arange(y1 - y0)[:, None]
    stripes1 = np.where(x % 2 == 0, 200, 50).astype(np.uint8)[None, :].repeat(y1 - y0, 0)
    stripes2 = np.where((yy // 2) % 2 == 0, 200, 50).astype(np.uint8).repeat(480, 1)
    checker = np.where((x[None, :] + yy) % 2 == 0, 200, 50).astype(np.uint8)
    for i, block in enumerate([stripes1, stripes2, checker]):
        a[y0:y1, 240 + i * 480:240 + (i + 1) * 480] = block[:, :, None]
    return a


# ---- The measurement (design D2): lib/reporting/picture_measure.dart --------

def luma(r, g, b):
    """Integer BT.601-weighted luma, 0-255, as the Dart port computes it."""
    return (77 * r + 150 * g + 29 * b + 128) >> 8


def measure(rgb, left=0, top=0, width=None, height=None):
    """The 16x9 grid of mean colours (rrggbb) and the detail figure: the mean
    absolute luma difference between neighbouring pixels, horizontally and
    vertically, over the sub-rectangle."""
    if width is None:
        width = rgb.shape[1] - left
    if height is None:
        height = rgb.shape[0] - top
    region = rgb[top:top + height, left:left + width].astype(np.int64)
    grid = []
    for row in range(ROWS):
        ya, yb = row * height // ROWS, (row + 1) * height // ROWS
        for col in range(COLS):
            xa, xb = col * width // COLS, (col + 1) * width // COLS
            cell = region[ya:yb, xa:xb]
            n = cell.shape[0] * cell.shape[1]
            if n == 0:
                grid.append('000000')
                continue
            sums = cell.reshape(-1, 3).sum(0)
            mean = [(int(s) + n // 2) // n for s in sums]
            grid.append('%02x%02x%02x' % tuple(mean))
    y = luma(region[:, :, 0], region[:, :, 1], region[:, :, 2])
    diffs = int(np.abs(np.diff(y, axis=1)).sum()) + int(np.abs(np.diff(y, axis=0)).sum())
    pairs = (width - 1) * height + width * (height - 1)
    detail = diffs / pairs if pairs > 0 else 0.0
    return {'grid': grid, 'detail': round(detail, 3)}


def run(cmd):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.stderr.write(r.stderr.decode(errors='replace'))
        raise SystemExit('failed: ' + ' '.join(cmd))
    return r.stdout


def encode(png, out, clip):
    run(['ffmpeg', '-v', 'error', '-y', '-loop', '1', '-framerate', str(FPS), '-i', png,
         '-frames:v', str(FRAMES),
         '-vf', 'scale=out_color_matrix=bt709:out_range=tv:flags=accurate_rnd+full_chroma_int,'
                'format=' + clip['pix_fmt'],
         '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-color_range', 'tv',
         *clip['args'], '-an', '-movflags', '+faststart', out])


def decode_first_frame(path):
    """The clip's first frame, as RGB, converted with BT.709 limited range."""
    raw = run(['ffmpeg', '-v', 'error', '-i', path, '-frames:v', '1',
               '-vf', 'scale=in_color_matrix=bt709:in_range=tv:out_range=pc:'
                      'flags=accurate_rnd+full_chroma_int:sws_dither=none,format=rgb24',
               '-f', 'rawvideo', '-'])
    return np.frombuffer(raw, np.uint8).reshape(H, W, 3)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    p = argparse.ArgumentParser()
    p.add_argument('--out', default=os.path.join(root, 'assets', 'video_test'))
    p.add_argument('--fixture', default=os.path.join(root, 'test', 'fixtures', 'video_test', 'card_h264.png'))
    args = p.parse_args()
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(os.path.dirname(args.fixture), exist_ok=True)

    card = draw_card()
    expected = {'width': W, 'height': H, 'tolerance': 14, 'detailTolerance': 0.25, 'cards': {}}
    with tempfile.TemporaryDirectory() as tmp:
        png = os.path.join(tmp, 'card.png')
        Image.fromarray(card).save(png)
        for name, clip in CLIPS.items():
            out = os.path.join(args.out, name + '.mp4')
            encode(png, out, clip)
            frame = decode_first_frame(out)
            m = measure(frame)
            expected['cards'][name] = {
                'file': name + '.mp4',
                'bitDepth': 10 if name == 'hevc10' else 8,
                **m,
            }
            if name == 'h264':
                Image.fromarray(frame).save(args.fixture, optimize=True)
            print(f'{name}: {os.path.getsize(out)} bytes, detail {m["detail"]}')
    with open(os.path.join(args.out, 'card_expected.json'), 'w') as f:
        json.dump(expected, f, indent=1)
        f.write('\n')
    # The fixture's own measurement, for the Dart parity test.
    with open(os.path.splitext(args.fixture)[0] + '.json', 'w') as f:
        json.dump(measure(np.asarray(Image.open(args.fixture).convert('RGB'))), f, indent=1)
        f.write('\n')
    total = sum(os.path.getsize(os.path.join(args.out, n)) for n in os.listdir(args.out))
    print(f'assets/video_test: {total} bytes in all')
    if total > 600 * 1024:
        raise SystemExit('over 600 KB')


if __name__ == '__main__':
    main()
