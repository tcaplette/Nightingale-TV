#!/usr/bin/env python3
"""Checks the colours of a paused picture against the source file
(android-playback, "NVIDIA Shield draws video through OpenGL ES").

A channel is paused with timeshift in a diagnostics build, which logs
    PLAYDBG ... SHIFT held item=<id> at=<seconds>s
and a screenshot is taken (adb exec-out screencap -p). This script decodes the
frames around that place from the server's file with ffmpeg, picks the one that
looks most like the screenshot (the logged place can be a few seconds off for
a server conversion, which starts at a keyframe), and compares the mean colour of each cell of a grid over the picture. Every
cell must be within the tolerance on every channel. Wrong YUV-to-RGB
conversion (green, cyan or purple pictures, swapped or lost chroma) is off by
far more than that in most cells.

  tool/video_color_check.py --screenshot shot.png --log logcat.txt \\
      --test-data test-data.md [--ignore x,y,w,h ...] [--tolerance 14]

The server and account come from test-data.md ("test server", "test user",
"test pass"), or from NTV_SERVER / NTV_USER / NTV_PW. Nothing secret is printed.
Exit status: 0 pass, 1 fail, 2 could not check.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image


def read_test_data(path):
    values = {}
    with open(path) as f:
        for line in f:
            if ':' in line:
                k, v = line.split(':', 1)
                values[k.strip()] = v.strip()
    return values.get('test server'), values.get('test user'), values.get('test pass')


def sign_in(server, user, password):
    body = json.dumps({'Username': user, 'Pw': password}).encode()
    req = urllib.request.Request(
        server.rstrip('/') + '/Users/AuthenticateByName', data=body, method='POST',
        headers={
            'Content-Type': 'application/json',
            'X-Emby-Authorization': 'MediaBrowser Client="ntv-color-check", Device="host", '
                                    'DeviceId="ntv-color-check", Version="1.0"',
        })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)['AccessToken']


def held_from_log(path):
    held = None
    with open(path, errors='replace') as f:
        for line in f:
            m = re.search(r'SHIFT held item=(\S+) at=([0-9.]+)s', line)
            if m:
                held = (m.group(1), float(m.group(2)))
    return held


def picture_rect(screen_w, screen_h, video_w, video_h):
    """Where a picture fitted (contain) and centred on the screen is drawn."""
    scale = min(screen_w / video_w, screen_h / video_h)
    w, h = round(video_w * scale), round(video_h * scale)
    return (screen_w - w) // 2, (screen_h - h) // 2, w, h


def probe_size(url):
    out = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
         'stream=width,height,sample_aspect_ratio', '-of', 'json', url],
        capture_output=True, text=True, timeout=60, check=True).stdout
    s = json.loads(out)['streams'][0]
    w, h = s['width'], s['height']
    sar = s.get('sample_aspect_ratio', '1:1')
    if sar and sar not in ('0:1', '1:1', 'N/A'):
        n, d = (int(x) for x in sar.split(':'))
        w = round(w * n / d)
    return w, h


def decode(url, start, duration, size, index=None):
    """Frames from start for duration seconds, scaled to size, as RGB arrays;
    only frame number index of them when given."""
    w, h = size
    vf = f'scale={w}:{h}:in_range=auto:in_color_matrix=auto,format=rgb24'
    if index is not None:
        vf = f'select=eq(n\\,{index}),' + vf
    cmd = ['ffmpeg', '-v', 'error', '-ss', f'{start:.3f}', '-i', url, '-t', f'{duration:.3f}',
           '-vf', vf, '-vsync', '0', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1']
    if index is not None:
        cmd[-1:-1] = ['-frames:v', '1']
    raw = subprocess.run(cmd, capture_output=True, check=True, timeout=600).stdout
    n = len(raw) // (w * h * 3)
    return [np.frombuffer(raw, np.uint8, w * h * 3, i * w * h * 3).reshape(h, w, 3).astype(np.float64)
            for i in range(n)]


def cell_means(img, grid, keep):
    """Mean RGB of each grid cell, over the pixels in keep."""
    h, w = img.shape[:2]
    means = np.zeros((grid, grid, 3))
    for r in range(grid):
        for c in range(grid):
            y0, y1 = h * r // grid, h * (r + 1) // grid
            x0, x1 = w * c // grid, w * (c + 1) // grid
            k = keep[y0:y1, x0:x1]
            means[r, c] = img[y0:y1, x0:x1][k].mean(axis=0)
    return means


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--screenshot', required=True)
    p.add_argument('--log', help='logcat with the PLAYDBG "SHIFT held" line')
    p.add_argument('--item', help='item id (instead of --log)')
    p.add_argument('--at', type=float, help='seconds into the file (instead of --log)')
    p.add_argument('--test-data', default='test-data.md')
    p.add_argument('--rect', help='x,y,w,h of the picture on the screenshot (default: fitted to the screen)')
    p.add_argument('--ignore', action='append', default=[],
                   help='x,y,w,h on the screenshot to leave out (overlays such as the Paused chip)')
    p.add_argument('--grid', type=int, default=4)
    p.add_argument('--tolerance', type=float, default=14.0, help='largest per-channel difference of a cell mean (0-255)')
    p.add_argument('--window', type=float, default=5.0, help='seconds either side of the position to search')
    p.add_argument('--save', help='folder to save the matched pictures in')
    a = p.parse_args()

    item, at = a.item, a.at
    if a.log:
        held = held_from_log(a.log)
        if held is None:
            print('no "SHIFT held" line in the log', file=sys.stderr)
            return 2
        item, at = held
    if item is None or at is None:
        print('need --log, or --item and --at', file=sys.stderr)
        return 2

    server, user, password = (os.environ.get('NTV_SERVER'), os.environ.get('NTV_USER'), os.environ.get('NTV_PW'))
    if not (server and user and password):
        server, user, password = read_test_data(a.test_data)
    token = sign_in(server, user, password)
    url = (server.rstrip('/') + f'/Videos/{urllib.parse.quote(item)}/stream?static=true&api_key={token}')

    shot = np.asarray(Image.open(a.screenshot).convert('RGB'), dtype=np.float64)
    sh, sw = shot.shape[:2]
    vw, vh = probe_size(url)
    if a.rect:
        x, y, w, h = (int(v) for v in a.rect.split(','))
    else:
        x, y, w, h = picture_rect(sw, sh, vw, vh)
    picture = shot[y:y + h, x:x + w]
    keep = np.ones((h, w), dtype=bool)
    for box in a.ignore:
        ix, iy, iw, ih = (int(v) for v in box.split(','))
        keep[max(0, iy - y):max(0, iy - y + ih), max(0, ix - x):max(0, ix - x + iw)] = False

    # Find the held frame: the closest small picture in the window (the
    # logged place can be a few seconds off for a conversion, which starts at
    # a keyframe), then compare that frame at full size.
    start = max(0.0, at - a.window)
    small = (max(16, w // 10), max(16, h // 10))
    shot_small = np.asarray(Image.fromarray(picture.astype(np.uint8)).resize(small, Image.BILINEAR), dtype=np.float64)
    keep_small = np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).resize(small, Image.NEAREST)) > 0
    candidates = decode(url, start, 2 * a.window, small)
    if not candidates:
        print('ffmpeg decoded no frames there', file=sys.stderr)
        return 2
    errors = [((f - shot_small)[keep_small] ** 2).mean() for f in candidates]
    i = int(np.argmin(errors))
    frame = decode(url, start, 2 * a.window, (w, h), index=i)[0]
    got = cell_means(picture, a.grid, keep)
    diff = np.abs(cell_means(frame, a.grid, keep) - got)
    frames = candidates
    worst = diff.max()
    print(f'item={item} at={at:.3f}s source={vw}x{vh} picture={x},{y},{w},{h} '
          f'frames searched={len(frames)} best=#{i} (~{start + i * 2 * a.window / max(1, len(frames)):.2f}s)')
    print(f'cell differences (largest channel per cell, 0-255), tolerance {a.tolerance}:')
    for r in range(a.grid):
        print('  ' + ' '.join(f'{diff[r, c].max():6.1f}' for c in range(a.grid)))
    print('screen means (R,G,B) vs source means per cell:')
    ref = cell_means(frame, a.grid, keep)
    for r in range(a.grid):
        print('  ' + ' | '.join(
            f'{tuple(int(v) for v in got[r, c])} {tuple(int(v) for v in ref[r, c])}' for c in range(a.grid)))
    if a.save:
        os.makedirs(a.save, exist_ok=True)
        Image.fromarray(picture.astype(np.uint8)).save(os.path.join(a.save, 'screen.png'))
        Image.fromarray(frame.astype(np.uint8)).save(os.path.join(a.save, 'source.png'))
    ok = worst <= a.tolerance
    print(f'{"PASS" if ok else "FAIL"}: worst cell {worst:.1f}')
    return 0 if ok else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as e:
        # The command holds the access token: name the tool only.
        err = e.stderr.decode(errors='replace') if isinstance(e.stderr, bytes) else (e.stderr or '')
        err = re.sub(r'api_key=[^&\s]+', 'api_key=…', err).strip()[-500:]
        print(f'{e.cmd[0]} failed with exit status {e.returncode}: {err}', file=sys.stderr)
        sys.exit(2)
