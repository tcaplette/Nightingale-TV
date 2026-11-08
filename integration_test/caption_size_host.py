#!/usr/bin/env python3
"""Host side of caption_size_live_test.dart: follows the test's log and carries
out each "CAP HOST <verb> ..." line, real input and screenshots included.

  caption_size_host.py <flutter log> <screenshot dir> [<adb serial>]

Verbs: key K | tap X Y | scale V | scale-clear | home | launch | snap NAME.
Without a serial (Linux), only snap works, taking the X display in $DISPLAY.
"""
import re
import subprocess
import sys
import time

log, shots = sys.argv[1], sys.argv[2]
serial = sys.argv[3] if len(sys.argv) > 3 else None
ACTIVITY = 'com.coffeehauslabs.nightingale_tv.selfbuilt/com.coffeehauslabs.nightingale_tv.MainActivity'
SETTING = 'accessibility_captioning_font_scale'


def adb(*args):
    return subprocess.run(['adb', '-s', serial, 'shell', *args], check=False)


def run(words):
    verb, rest = words[0], words[1:]
    if verb == 'snap':
        path = f'{shots}/{rest[0]}.png'
        if serial:
            with open(path, 'wb') as f:
                subprocess.run(['adb', '-s', serial, 'exec-out', 'screencap', '-p'], stdout=f, check=False)
        else:
            subprocess.run(['import', '-window', 'root', path], check=False)
    elif verb == 'key':
        adb('input', 'keyevent', f'KEYCODE_{rest[0]}')
    elif verb == 'tap':
        adb('input', 'tap', *rest)
    elif verb == 'scale':
        adb('settings', 'put', 'secure', SETTING, rest[0])
    elif verb == 'scale-clear':
        adb('settings', 'delete', 'secure', SETTING)
    elif verb == 'home':
        adb('input', 'keyevent', 'KEYCODE_HOME')
    elif verb == 'launch':
        adb('am', 'start', '-n', ACTIVITY)


with open(log, errors='replace') as f:
    while True:
        line = f.readline()
        if not line:
            time.sleep(0.05)
            continue
        if line.startswith('EXIT') or 'All tests passed' in line or 'Some tests failed' in line:
            break
        m = re.search(r'CAP HOST (.+)$', line.strip())
        if m:
            run(m.group(1).split())
