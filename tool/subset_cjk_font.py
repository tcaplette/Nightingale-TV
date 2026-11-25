#!/usr/bin/env python3
"""Builds the bundled CJK interface font (cjk-languages D2).

Downloads Noto Sans CJK SC Regular and Bold (SIL OFL 1.1) at a pinned
release, checks their checksums, and cuts them down to every character the
Japanese and Chinese interface text uses, plus CJK punctuation. All OpenType
layout features are kept, so `locl` still gives Japanese, Traditional and
Hong Kong character shapes from the one file.

Run it from the project root whenever a Japanese or Chinese message changes:

    python3 tool/subset_cjk_font.py

It writes:
    assets/fonts/NotoSansCJK-UI-Regular.otf
    assets/fonts/NotoSansCJK-UI-Bold.otf
    assets/fonts/NotoSansCJK-UI.json   (source version, checksums, characters)
    assets/fonts/OFL-NotoSansCJK.txt   (the licence)

Needs fontTools (`pip3 install --user fonttools`).
"""

import hashlib
import json
import os
import sys
import tempfile
import urllib.request

try:
    from fontTools import subset
    from fontTools.ttLib import TTFont
except ImportError:
    sys.exit('fontTools is missing: pip3 install --user fonttools')

RELEASE = 'Sans2.004'
BASE = f'https://raw.githubusercontent.com/notofonts/noto-cjk/{RELEASE}'
SOURCES = {
    'Regular': (f'{BASE}/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf',
                '2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b'),
    'Bold': (f'{BASE}/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Bold.otf',
             'b5f0d1a190a7f9b43c310a8850630af12553df32c4c050543f9059732d9b4c0a'),
}
LICENCE = (f'{BASE}/LICENSE', '6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2')

# The Japanese and Chinese interface text.
ARBS = ['app_ja.arb', 'app_zh.arb', 'app_zh_Hant.arb', 'app_zh_Hant_HK.arb']
# Dart files whose literals are shown in every language: the language
# picker's own names, and caption language names.
DART_SOURCES = ['tr.dart', 'language_names.dart']
# CJK symbols and punctuation, and full-width forms.
PUNCTUATION = [*range(0x3000, 0x3040), *range(0xFF01, 0xFF61), 0x30FB, 0x30FC]
# Characters whose shapes differ by language, for the glyph-shape test
# (test/language_glyph_shape_test.dart).
SHAPE_CHECK = '直骨写'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')
FONTS = os.path.join(ROOT, 'assets', 'fonts')


def interface_characters():
    """Every character the CJK interface can show."""
    chars = set(PUNCTUATION) | {ord(c) for c in SHAPE_CHECK}
    for name in ARBS:
        with open(os.path.join(L10N, name), encoding='utf-8') as f:
            arb = json.load(f)
        for key, value in arb.items():
            if not key.startswith('@') and isinstance(value, str):
                chars.update(ord(c) for c in value)
    for name in DART_SOURCES:
        with open(os.path.join(L10N, name), encoding='utf-8') as f:
            text = f.read()
        chars.update(ord(c) for c in text if ord(c) >= 0x2E80)
    # Control characters have no glyph.
    return sorted(c for c in chars if c >= 0x20)


def fetch(url, sha256, folder):
    path = os.path.join(folder, url.rsplit('/', 1)[1])
    if not os.path.exists(path):
        print(f'Downloading {url}')
        urllib.request.urlretrieve(url, path)
    with open(path, 'rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    if digest != sha256:
        os.remove(path)
        sys.exit(f'{url}: checksum {digest}, expected {sha256}')
    return path


def main():
    cache = os.environ.get('NTV_FONT_CACHE') or os.path.join(tempfile.gettempdir(), 'ntv-noto-cjk')
    os.makedirs(cache, exist_ok=True)
    chars = interface_characters()
    versions = {}
    for weight, (url, sha256) in SOURCES.items():
        source = fetch(url, sha256, cache)
        options = subset.Options()
        options.layout_features = ['*']
        options.layout_scripts = ['*']
        options.name_IDs = ['*']
        options.name_languages = ['*']
        options.notdef_outline = True
        options.glyph_names = False
        options.hinting = False
        options.drop_tables += ['VORG', 'vhea', 'vmtx']
        font = TTFont(source)
        versions[weight] = font['name'].getDebugName(5)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=chars)
        subsetter.subset(font)
        out = os.path.join(FONTS, f'NotoSansCJK-UI-{weight}.otf')
        font.save(out)
        print(f'{out}: {os.path.getsize(out)} bytes')
    licence = fetch(*LICENCE, cache)
    with open(licence, encoding='utf-8') as f, open(os.path.join(FONTS, 'OFL-NotoSansCJK.txt'), 'w', encoding='utf-8') as out:
        out.write(f.read())
    record = {
        'source': f'Noto Sans CJK SC {RELEASE} (notofonts/noto-cjk)',
        'version': versions,
        'sha256': {weight: sha256 for weight, (_, sha256) in SOURCES.items()},
        'characters': len(chars),
    }
    with open(os.path.join(FONTS, 'NotoSansCJK-UI.json'), 'w', encoding='utf-8') as f:
        json.dump(record, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'{len(chars)} characters')


if __name__ == '__main__':
    main()
