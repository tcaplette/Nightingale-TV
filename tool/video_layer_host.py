#!/usr/bin/env python3
"""Host side of integration_test/video_layer_test.dart (system-video-layer D9).

  tool/video_layer_host.py --apk app-free-debug.apk --out shots/ [--clips build/video_layer_clips]
      [--software] [--shield] [--hdr-display] [--only h264_720x480 ...]

      [--app]

Installs the test APK on the running emulator, copies the files into the
app's storage, starts it, takes a screenshot at every "VLT SNAP <name>" line,
and compares each with the file's own picture: the four border strips and the
4x4 colour grid, where a contained picture goes. Exit status 1 if any differ.

  --app          integration_test/video_layer_app_test.dart instead: half-hour
                 files (the clips, repeated), recordings, Home and back (a phone: turned
                 sideways and back)
  --software     debug.nightingale_tv.software_video: Android's own decoders
  --shield       ntv_treat_as_shield: Flutter draws with Skia
  --hdr-display  debug.nightingale_tv.hdr_display: the display counts as HDR
"""
import argparse
import os
import re
import subprocess
import sys
import threading
import time

import numpy as np
from PIL import Image

PACKAGE = 'com.coffeehauslabs.nightingale_tv.selfbuilt'
ACTIVITY = f'{PACKAGE}/com.coffeehauslabs.nightingale_tv.MainActivity'
ADB = os.path.expanduser('~/Android/Sdk/platform-tools/adb')
# Display shape, for files whose pixels aren't square.
SHAPES = {'h264_720x480': 4 / 3, 'mpeg2_720x480': 4 / 3}
BORDER = {'left': (220, 0, 200), 'right': (0, 200, 220), 'top': (230, 220, 20), 'bottom': (240, 130, 0)}


def adb(*args, **kw):
    return subprocess.run([ADB, *args], check=True, capture_output=True, text=True, **kw).stdout


def set_flag(name, on):
    # Android 7 takes no property name this long: only its own decoders there.
    subprocess.run([ADB, 'shell', f"setprop debug.nightingale_tv.{name} {'1' if on else '0'}"], capture_output=True)


def rect_of(name, size, screen):
    sw, sh = screen
    aspect = SHAPES.get(name, size[0] / size[1])
    w, h = (sw, sw / aspect) if sw / sh < aspect else (sh * aspect, sh)
    return (sw - w) / 2, (sh - h) / 2, w, h


def composed(rgb):
    v = rgb / 255
    lin = np.where(v < 0.081, v / 4.5, ((v + 0.099) / 1.099) ** (1 / 0.45))
    return 255 * np.where(lin <= .0031308, 12.92 * lin, 1.055 * np.maximum(lin, 0) ** (1 / 2.4) - .055)


def as_bt601(rgb):
    y = rgb @ [.2126, .7152, .0722]
    cb, cr = (rgb[:, 2] - y) / 1.8556, (rgb[:, 0] - y) / 1.5748
    return np.clip(np.stack([y + 1.402 * cr, y - .344136 * cb - .714136 * cr, y + 1.772 * cb], 1), 0, 255)


def layer_facts(dump):
    """The video's buffers, the part shown, and the dataspace, as SurfaceFlinger has them."""
    sizes = sorted(set(re.findall(r'SurfaceView\[.*?BLAST Consume.*?w/h:(\d+x\d+)', dump)))
    crops = sorted({f'{float(a):.0f}x{float(b):.0f}' for a, b in
                    re.findall(r'sourceCrop=\[0\.0+ 0\.0+ ([0-9.]+) ([0-9.]+)\]', dump)})
    spaces = sorted(set(re.findall(r'BLAST Consume.*?fourcc/mod:(?:842094169|808539481).*?dataspace: (0x[0-9a-f]+)', dump)))
    return f'buffers {sizes} shown {crops} video dataspaces {spaces}'


def check(name, shot_path, clips, rect=None):
    """What differs between the screenshot and the file's picture."""
    src = Image.open(f'{clips}/{name}.png').convert('RGB')
    shot = Image.open(shot_path).convert('RGB')
    x, y, w, h = rect or rect_of(name, src.size, shot.size)
    a = np.asarray(shot, dtype=float)
    sx, sy = w / src.size[0], h / src.size[1]
    wrong = []

    def mean(x0, y0, x1, y1):
        return a[int(round(y0)):max(int(round(y1)), int(round(y0)) + 1),
                 int(round(x0)):max(int(round(x1)), int(round(x0)) + 1)].reshape(-1, 3).mean(axis=0)

    # The middle half of each border strip, along the middle of its side.
    strips = {
        'left': (x + 2 * sx, y + h * .3, x + 6 * sx, y + h * .6),
        'right': (x + w - 6 * sx, y + h * .3, x + w - 2 * sx, y + h * .6),
        'top': (x + w * .3, y + 2 * sy, x + w * .6, y + 6 * sy),
        'bottom': (x + w * .3, y + h - 6 * sy, x + w * .6, y + h - 2 * sy),
    }
    # The emulators' GPU scrambles 10-bit YUV, whoever shows it: those files
    # are for the dataspace and the decoder.
    if name.startswith(('av1', 'hevc10', 'hevc_pq')):
        return [], 0.0
    s = np.asarray(src, dtype=float)
    gx0, gy0, gx1, gy1 = src.size[0] // 8, src.size[1] // 6, src.size[0] - src.size[0] // 8, src.size[1] - src.size[1] // 6
    want, shown = [], []
    for r in range(4):
        for c in range(4):
            cx, cy = gx0 + (gx1 - gx0) * (c + .5) / 4, gy0 + (gy1 - gy0) * (r + .5) / 4
            shown.append(mean(x + (cx - 8) * sx, y + (cy - 8) * sy, x + (cx + 8) * sx, y + (cy + 8) * sy))
            want.append(s[int(cy), int(cx)])
    want, shown = np.array(want), np.array(shown)
    # As the file's own colours; or as SurfaceFlinger composes video on the
    # GPU (the video transfer turned into sRGB's); HD through the emulators'
    # GPU import besides, which reads BT.709 as BT.601.
    tries = {'exact': lambda v: v, 'system': composed}
    if src.size[1] >= 534:
        tries['system, emulator BT.601 import'] = lambda v: composed(as_bt601(v))
        tries['exact, emulator BT.601 import'] = as_bt601
    kind, worst = min(((k, np.abs(f(want) - shown).max()) for k, f in tries.items()), key=lambda t: t[1])
    for side, box in strips.items():
        got = mean(*box)
        if np.abs(got - tries[kind](np.array([BORDER[side]], dtype=float))[0]).max() > 12:
            wrong.append(f'{side} border {tuple(int(v) for v in got)}')
    print(f'   colours: {kind}, worst {worst:.1f}')
    if worst > 8:
        wrong.append(f'colours off by {worst:.0f}')
    # Nothing but black round the picture.
    outside = [v for v in (
        a[:, :int(x) - 2] if x > 4 else None, a[:, int(x + w) + 3:] if x > 4 else None,
        a[:int(y) - 2] if y > 4 else None, a[int(y + h) + 3:] if y > 4 else None) if v is not None and v.size]
    if any(v.max() > 24 for v in outside):
        wrong.append('something outside the picture')
    return wrong, worst


def record(name, seconds, out):
    device = f'/sdcard/vlt_{name}.mp4'
    adb('shell', 'screenrecord', '--bit-rate', '16000000', '--time-limit', seconds, device)
    adb('pull', device, f'{out}/{name}.mp4')
    adb('shell', 'rm', device)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--apk')
    p.add_argument('--out', required=True)
    p.add_argument('--clips', default=os.path.join(os.path.dirname(__file__), '..', 'build', 'video_layer_clips'))
    p.add_argument('--software', action='store_true')
    p.add_argument('--shield', action='store_true')
    p.add_argument('--hdr-display', action='store_true')
    p.add_argument('--app', action='store_true')
    p.add_argument('--only', nargs='*')
    p.add_argument('--timeout', type=int, default=240)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if a.apk:
        # Not adb install: it hangs on an Android 7 image.
        adb('push', a.apk, '/data/local/tmp/vlt.apk')
        adb('shell', 'pm install -r -d -t /data/local/tmp/vlt.apk && rm /data/local/tmp/vlt.apk')
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'run-as', PACKAGE, 'mkdir', '-p', 'files/video_layer')
    had = adb('shell', 'run-as', PACKAGE, 'ls', 'files/video_layer').split()
    if a.app:
        for name in ('h264_720x480', 'h264_1920x1080', 'h264_1280x534'):
            if not os.path.exists(f'{a.clips}/long_{name}.mp4'):
                subprocess.run(['ffmpeg', '-v', 'error', '-stream_loop', '59', '-i', f'{a.clips}/{name}.mp4',
                                '-c', 'copy', '-movflags', '+faststart', f'{a.clips}/long_{name}.mp4'], check=True)
    for f in had:
        if not a.app:
            adb('shell', 'run-as', PACKAGE, 'rm', f'files/video_layer/{f}')
    for f in sorted(os.listdir(a.clips)):
        name, ext = os.path.splitext(f)
        if ext not in ('.mp4', '.ts') or (a.only and name not in a.only):
            continue
        if name.startswith('long_') != a.app or (a.app and f in had):
            continue
        adb('push', f'{a.clips}/{f}', f'/data/local/tmp/{f}')
        adb('shell', f'run-as {PACKAGE} cp /data/local/tmp/{f} files/video_layer/{f} && rm /data/local/tmp/{f}')
    for prop, on in (('software_video', a.software), ('hdr_display', a.hdr_display)):
        set_flag(prop, on)
    adb('logcat', '-c')
    log = open(f'{a.out}/log.txt', 'w')
    tail = subprocess.Popen([ADB, 'logcat', '-v', 'time', '-s', 'flutter:*', 'NightingaleTV:*', 'AndroidRuntime:E'],
                            stdout=subprocess.PIPE, text=True, errors='replace')
    threading.Timer(a.timeout, tail.kill).start()
    start = ['shell', 'am', 'start', '-n', ACTIVITY]
    if a.shield:
        start += ['--ez', 'ntv_treat_as_shield', 'true']
    adb(*start)
    failed, recordings = [], []
    done = False
    for line in tail.stdout:
        log.write(line)
        log.flush()
        if 'VLT ' in line:
            print(line.strip().split('): ', 1)[-1], flush=True)
        if 'VLT SNAP ' in line:
            name = line.split('VLT SNAP ', 1)[1].split()[0]
            time.sleep(.3)
            path = f'{a.out}/{name}.png'
            with open(path, 'wb') as f:
                subprocess.run([ADB, 'exec-out', 'screencap', '-p'], stdout=f, check=True)
            if os.path.exists(f'{a.clips}/{name}.png'):
                wrong, worst = check(name, path, a.clips)
                print(f"   {'FAIL ' + '; '.join(wrong) if wrong else 'ok'}", flush=True)
                if wrong:
                    failed.append(name)
            # What the system composites, for the dataspace and the layers.
            dump = adb('shell', 'dumpsys', 'SurfaceFlinger')
            with open(f'{a.out}/{name}.layers.txt', 'w') as f:
                f.write(dump)
            print(f'   {layer_facts(dump)}', flush=True)
        if 'VLT REC ' in line:
            name, seconds = line.split('VLT REC ', 1)[1].split()[:2]
            recordings.append(threading.Thread(target=record, args=(name, seconds, a.out)))
            recordings[-1].start()
        if 'VLT HOST home' in line:
            adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        if 'VLT HOST rotate' in line:
            adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
            adb('shell', 'settings', 'put', 'system', 'user_rotation', line.split('HOST rotate')[1].split()[0])
        if 'VLT HOST tap' in line:
            adb('shell', 'input', 'tap', *line.split('HOST tap')[1].split()[:2])
        if 'VLT HOST launch' in line:
            adb('shell', 'am', 'start', '-n', ACTIVITY)
        if 'VLT DONE' in line:
            done = True
            break
        if 'FATAL EXCEPTION' in line:
            print(line.strip())
            break
    tail.kill()
    for r in recordings:
        r.join(30)
    for prop in ('software_video', 'hdr_display'):
        set_flag(prop, False)
    print(f"{'FAIL ' + ', '.join(failed) if failed else 'PASS' if done else 'NOT FINISHED'}")
    os._exit(0 if done and not failed else 1)


if __name__ == '__main__':
    main()
