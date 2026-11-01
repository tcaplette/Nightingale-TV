#!/usr/bin/env python3
"""Clicks where a running integration test asks, with the uhid mouse.

Follows the test's log for "UHIDMOVE <x> <y>" (hover) and "UHID <x> <y>"
(click), in physical pixels: homes the pointer to the top-left corner and moves
there.
  drive.py <log file> <adb serial> [gain]
"""
import os, subprocess, sys, time

log, serial = sys.argv[1], sys.argv[2]
gain = float(sys.argv[3]) if len(sys.argv) > 3 else 2.04
mouse = subprocess.Popen(['adb', '-s', serial, 'shell', '/data/local/tmp/uhid_mouse'],
                         stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True)
def send(c):
    mouse.stdin.write(c + '\n'); mouse.stdin.flush()
n = 0
time.sleep(3)
with open(log, errors='replace') as f:
    while True:
        line = f.readline()
        if not line:
            time.sleep(0.2)
            continue
        if 'All tests passed' in line or 'Some tests failed' in line:
            break
        for word in ('UHIDMOVE ', 'UHID '):
            if word not in line:
                continue
            x, y = map(float, line.split(word)[1].split()[:2])
            send('go -1400 -1000'); time.sleep(3.5)
            send(f'go {round(x / gain)} {round(y / gain)}'); time.sleep(3)
            if word == 'UHID ':
                send('d'); time.sleep(0.15); send('u')
            print(word.strip(), x, y, flush=True)
            shots = os.environ.get('SNAP_DIR')
            if shots:
                n += 1
                time.sleep(0.8)
                with open(f'{shots}/uhid-{n}.png', 'wb') as out:
                    subprocess.run(['adb', '-s', serial, 'exec-out', 'screencap', '-p'], stdout=out)
            break
mouse.terminate()
