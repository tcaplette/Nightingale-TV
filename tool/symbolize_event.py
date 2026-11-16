#!/usr/bin/env python3
"""Prints a GlitchTip event's stack frames with Dart names (library-scan-anr D4).

    tool/symbolize_event.py <event-id> [--dist DIR] [--apk FILE ...]

An ANR or native crash reports the frames of the app's compiled Dart code as
raw addresses in an APK ("base.apk (offset 18e8000)", 0x006a4da8). This
works out which library each offset is (from the release's APKs in dist/),
and runs the NDK's llvm-symbolizer on that release's saved debug files
(dist/<version>/symbols/, which tool/build_apk.sh and tool/build_bundle.sh
save) to print each libapp.so frame as a Dart function with file and line.
Frames are printed innermost first. Frames in other libraries are printed
with their library named; Java and Dart frames as GlitchTip has them.

--dist is the release's folder (default dist/<version> or dist/v<version>,
from the event's release tag). --apk names the APK(s) the device ran, when
they aren't the release's: for a Google Play install, pull the device's
split_config.<abi>.apk. The GlitchTip login is read from the git-ignored
glitchtip-credentials.txt at the repository root (URL:, Email:, Password:).
Needs Python 3 with requests, and the Android NDK.
"""

import argparse
import json
import os
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORG = 'coffeehauslabs'
PROJECT = 'nightingale-tv'
LIBAPP = 'libapp.so'


# ---- ELF -------------------------------------------------------------------

def build_id(data):
    """The GNU build ID (hex) of the ELF file in [data], or None."""
    if data[:4] != b'\x7fELF':
        return None
    is64 = data[4] == 2
    end = '<' if data[5] == 1 else '>'
    if is64:
        shoff, = struct.unpack_from(end + 'Q', data, 0x28)
        shentsize, shnum = struct.unpack_from(end + 'HH', data, 0x3A)
    else:
        shoff, = struct.unpack_from(end + 'I', data, 0x20)
        shentsize, shnum = struct.unpack_from(end + 'HH', data, 0x2E)
    for i in range(shnum):
        base = shoff + i * shentsize
        if is64:
            _, kind, _, _, offset, size = struct.unpack_from(end + 'IIQQQQ', data, base)
        else:
            _, kind, _, _, offset, size = struct.unpack_from(end + 'IIIIII', data, base)
        if kind != 7:  # SHT_NOTE
            continue
        at = offset
        while at + 12 <= offset + size:
            namesz, descsz, note = struct.unpack_from(end + 'III', data, at)
            name = data[at + 12:at + 12 + namesz]
            desc_at = at + 12 + ((namesz + 3) & ~3)
            if note == 3 and name.rstrip(b'\0') == b'GNU':
                return data[desc_at:desc_at + descsz].hex()
            at = desc_at + ((descsz + 3) & ~3)
    return None


# ---- APKs ------------------------------------------------------------------

def libraries(apk):
    """[(data offset, size, entry name)] of the uncompressed .so files in [apk]."""
    found = []
    with open(apk, 'rb') as raw, zipfile.ZipFile(apk) as z:
        for info in z.infolist():
            if not info.filename.endswith('.so') or info.compress_type != zipfile.ZIP_STORED:
                continue
            raw.seek(info.header_offset)
            header = raw.read(30)
            name_len, extra_len = struct.unpack_from('<HH', header, 26)
            found.append((info.header_offset + 30 + name_len + extra_len, info.file_size, info.filename))
    return found


def library_at(apk, offset):
    """The entry of [apk] whose data starts at [offset] (else holds it), or None."""
    libs = libraries(apk)
    for start, _, name in libs:
        if start == offset:
            return name
    for start, size, name in libs:
        if start <= offset < start + size:
            return name
    return None


def abi_of(entry):
    m = re.match(r'^(?:base/)?lib/([^/]+)/', entry)
    return m.group(1) if m else None


# ---- Tools -----------------------------------------------------------------

def version_key(path):
    return [int(p) if p.isdigit() else p for p in re.split(r'[.\-_]', path.name)]


def find_symbolizer():
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or str(Path.home() / 'Android' / 'Sdk')
    ndks = sorted((p for p in (Path(sdk) / 'ndk').glob('*') if p.is_dir()), key=version_key)
    for ndk in reversed(ndks):
        tool = ndk / 'toolchains' / 'llvm' / 'prebuilt' / 'linux-x86_64' / 'bin' / 'llvm-symbolizer'
        if tool.exists():
            return str(tool)
    for name in ('llvm-symbolizer',):
        for d in os.environ.get('PATH', '').split(os.pathsep):
            if (Path(d) / name).exists():
                return str(Path(d) / name)
    sys.exit(f'No llvm-symbolizer: install the Android NDK under {sdk}/ndk.')


def symbolize(symbolizer, debug_file, addresses):
    """{address: [(function, file, line)]}, inlined frames first."""
    if not addresses:
        return {}
    out = subprocess.run([symbolizer, f'--obj={debug_file}', '--inlining', '--output-style=JSON'],
                         input='\n'.join(hex(a) for a in addresses) + '\n', capture_output=True, text=True, check=True)
    result = {}
    for line in out.stdout.splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        address = int(entry['Address'], 16)
        result[address] = [(s.get('FunctionName') or '??', s.get('FileName') or '', s.get('Line') or 0)
                           for s in entry.get('Symbol', [])]
    return result


# ---- GlitchTip -------------------------------------------------------------

def credentials(path):
    text = Path(path).read_text()
    def field(name):
        m = re.search(rf'^\s*{name}:\s*(\S+)', text, re.M)
        if not m:
            sys.exit(f'{path} has no "{name}:" line.')
        return m.group(1)
    return field('URL').rstrip('/'), field('Email'), field('Password')


def fetch_event(event_id, creds_path, org, project):
    import requests
    url, email, password = credentials(creds_path)
    s = requests.Session()
    s.get(f'{url}/_allauth/browser/v1/auth/session', timeout=30)
    r = s.post(f'{url}/_allauth/browser/v1/auth/login', json={'email': email, 'password': password},
               headers={'X-CSRFToken': s.cookies.get('csrftoken') or '', 'Referer': url + '/'}, timeout=30)
    if r.status_code != 200:
        sys.exit(f'GlitchTip login failed ({r.status_code}).')
    r = s.get(f'{url}/api/0/projects/{org}/{project}/events/{event_id}/',
              headers={'X-CSRFToken': s.cookies.get('csrftoken') or ''}, timeout=30)
    if r.status_code == 404:
        sys.exit(f'No event {event_id} in {org}/{project}.')
    r.raise_for_status()
    return r.json()


def release_of(event):
    tag = event.get('release') or next((t['value'] for t in event.get('tags', []) if t.get('key') == 'release'), None)
    if not tag:
        return None
    return tag.split('@', 1)[-1].split('+', 1)[0]


def stacks(event):
    """[(title, frames outermost first)] of the event's exceptions and threads."""
    found = []
    for entry in event.get('entries', []):
        if entry.get('type') == 'exception':
            for v in entry['data'].get('values') or []:
                frames = (v.get('stacktrace') or {}).get('frames') or []
                if frames:
                    found.append((f"{v.get('type')}: {v.get('value')}", frames))
        elif entry.get('type') == 'threads':
            for t in entry['data'].get('values') or []:
                frames = (t.get('stacktrace') or {}).get('frames') or []
                if frames and t.get('crashed'):
                    found.append((f"thread {t.get('name') or t.get('id')}", frames))
    return found


# ---- Main ------------------------------------------------------------------

# "…/base.apk (offset 18e8000)": a library inside the APK at that offset;
# "…/base.apk!libflutter.so (offset 26c0000)": one Android named itself.
PACKAGE = re.compile(r'^(?P<path>.*?\.apk)(?:!(?P<lib>[^ ]+))?(?: \(offset (?:0x)?(?P<offset>[0-9a-fA-F]+)\))?$')


def release_apks(dist, version):
    apks = sorted(dist.glob(f'nightingale-tv_{version}*.apk')) if dist else []
    # The universal APK first: a sideloaded device most often has it.
    return sorted(apks, key=lambda p: 0 if p.name.endswith('_universal.apk') else 1)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('event_id')
    p.add_argument('--dist', help="the release's folder (default dist/<version> or dist/v<version>)")
    p.add_argument('--apk', action='append', default=[], help='an APK the device ran (repeatable)')
    p.add_argument('--credentials', default=str(ROOT / 'glitchtip-credentials.txt'))
    p.add_argument('--org', default=ORG)
    p.add_argument('--project', default=PROJECT)
    args = p.parse_args(argv)

    event = fetch_event(args.event_id, args.credentials, args.org, args.project)
    version = release_of(event)
    device = (event.get('contexts') or {}).get('device') or {}
    arch = device.get('arch') or next(iter(device.get('archs') or []), None)
    print(f"Event {args.event_id}: release {version or 'unknown'}, {device.get('model') or 'unknown device'}"
          f"{f' ({arch})' if arch else ''}")

    if args.dist:
        dist = Path(args.dist)
    else:
        dist = next((d for d in (ROOT / 'dist' / str(version), ROOT / 'dist' / f'v{version}') if version and d.is_dir()), None)
    apks = [Path(a) for a in args.apk] or release_apks(dist, version)
    symbols = dist / 'symbols' if dist else None
    debug_files = {}
    if symbols and symbols.is_dir():
        for f in symbols.rglob('*.debug'):
            bid = build_id(f.read_bytes())
            if bid:
                debug_files[bid] = f
    if not debug_files:
        where = symbols or ROOT / 'dist' / f'{version}' / 'symbols'
        print(f'No debug files for {version or "this release"}: {where} has none. Releases keep them from '
              f'library-scan-anr on (1.2.4 and earlier have none), so libapp.so frames are shown as addresses.')
    if not apks:
        print(f'No APKs of {version} found ({dist or "dist/"}): native frames are shown by APK offset.')

    symbolizer = find_symbolizer() if debug_files else None
    libs = {apk: libraries(apk) for apk in apks}
    ids = {}

    # Every APK of a release starts its first library at the same offset, so
    # one offset doesn't tell them apart: the APK the device ran is the one
    # where the most of the event's offsets are exactly a library's start.
    def offset_of(package):
        m = PACKAGE.match(package or '')
        if not m or not m.group('offset') or m.group('lib'):
            return None
        return Path(m.group('path')).name, int(m.group('offset'), 16)

    frame_offsets = {o for _, frames in stacks(event) for f in frames if (o := offset_of(f.get('package')))}

    def ran(apk_name):
        """The APK the device ran as [apk_name] (base.apk, split_config.….apk)."""
        named = [a for a in apks if a.name == apk_name]
        if named:
            return named[0]
        wanted = {off for name, off in frame_offsets if name == apk_name}
        def score(apk):
            starts = {start for start, _, _ in libs[apk]}
            abis = {abi_of(n) for _, _, n in libs[apk]}
            return (sum(o in starts for o in wanted), 1 if arch in abis else 0, 1 if apk.name.endswith('_universal.apk') else 0)
        return max(apks, key=score) if apks else None

    chosen = {name: ran(name) for name in {n for n, _ in frame_offsets}}
    for name, apk in sorted(chosen.items()):
        if apk:
            print(f'{name}: {apk.name}')

    def resolve(package):
        """(apk, entry) the frame's package and offset name, or None."""
        where = offset_of(package)
        apk = chosen.get(where[0]) if where else None
        if not apk:
            return None
        offset = where[1]
        for start, size, name in libs[apk]:
            if start == offset:
                return apk, name
        for start, size, name in libs[apk]:
            if start <= offset < start + size:
                return apk, name
        return None

    def debug_for(apk, entry):
        key = (apk, entry)
        if key not in ids:
            with zipfile.ZipFile(apk) as z:
                ids[key] = build_id(z.read(entry))
        return debug_files.get(ids[key])

    status = 0
    for title, frames in stacks(event):
        print(f'\n{title}')
        inner = list(reversed(frames))
        # Work out each native frame's library, then symbolize per debug file.
        placed = []
        wanted = {}
        for i, f in enumerate(inner):
            addr = f.get('instruction_addr') or f.get('instructionAddr')
            where = resolve(f.get('package')) if addr else None
            lookup = None
            if where and where[1].endswith('/' + LIBAPP):
                a = int(addr, 16)
                debug = debug_for(*where)
                thumb = abi_of(where[1]) == 'armeabi-v7a' and a & 1
                if debug and not thumb:
                    # A return address points after the call: look up the call.
                    lookup = (debug, a if i == 0 else a - 1)
                    wanted.setdefault(debug, set()).add(lookup[1])
            placed.append((f, addr, where, lookup))
        names = {debug: symbolize(symbolizer, debug, sorted(a)) for debug, a in wanted.items()}

        for n, (f, addr, where, lookup) in enumerate(placed):
            prefix = f'#{n:<3}'
            if lookup:
                syms = names[lookup[0]].get(lookup[1]) or [('??', '', 0)]
                for k, (fn, file, line) in enumerate(syms):
                    note = ' (inlined)' if k < len(syms) - 1 else ''
                    print(f'{prefix if k == 0 else "    "} {fn} ({file}:{line}){note}')
            elif addr:
                named = PACKAGE.match(f.get('package') or '')
                lib = where[1] if where else (named.group('lib') if named and named.group('lib') else f.get('package') or 'unknown library')
                why = ''
                if where and where[1].endswith('/' + LIBAPP):
                    status = 2
                    if abi_of(where[1]) == 'armeabi-v7a' and int(addr, 16) & 1:
                        why = ' (Thumb address)'
                    elif debug_files:
                        why = ' (no debug file with its build ID)'
                print(f'{prefix} {addr} in {lib}{why}')
            else:
                fn = f.get('function') or '??'
                module = f.get('module')
                file = f.get('filename') or f.get('absPath') or ''
                line = f.get('lineNo')
                name = f'{module}.{fn}' if module and f.get('platform') != 'dart' and not (f.get('filename') or '').endswith('.dart') else fn
                loc = f' ({file}:{line})' if file and line else (f' ({file})' if file else '')
                print(f'{prefix} {name}{loc}')
    if not debug_files:
        status = 2
    return status


if __name__ == '__main__':
    sys.exit(main())
