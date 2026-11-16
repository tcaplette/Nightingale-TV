#!/usr/bin/env python3
"""Tests of tool/symbolize_event.py's APK and ELF reading (library-scan-anr 6.2).

    python3 tool/test_symbolize_event.py

The release APKs live in the git-ignored dist/; a test whose APK isn't
there is skipped.
"""

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

# No __pycache__ beside the tool.
sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
spec = importlib.util.spec_from_file_location('symbolize_event', HERE / 'symbolize_event.py')
se = importlib.util.module_from_spec(spec)
spec.loader.exec_module(se)

# Issue 13's ANR: frames at "base.apk (offset 18e8000)" from 1.2.4+5006.
UNIVERSAL_124 = ROOT / 'dist' / 'v1.2.4' / 'nightingale-tv_1.2.4+5006_universal.apk'


@unittest.skipUnless(UNIVERSAL_124.exists(), f'{UNIVERSAL_124} is not here')
class OffsetToLibrary(unittest.TestCase):
    def test_issue_13_offset_is_the_armv7_dart_code(self):
        self.assertEqual(se.library_at(UNIVERSAL_124, 0x18e8000), 'lib/armeabi-v7a/libapp.so')

    def test_every_library_starts_at_its_own_offset(self):
        libs = se.libraries(UNIVERSAL_124)
        self.assertTrue(any(name == 'lib/arm64-v8a/libapp.so' for _, _, name in libs))
        for start, _, name in libs:
            self.assertEqual(se.library_at(UNIVERSAL_124, start), name)

    def test_an_offset_inside_a_library_names_it(self):
        start, size, name = next(l for l in se.libraries(UNIVERSAL_124) if l[2] == 'lib/x86_64/libapp.so')
        self.assertEqual(se.library_at(UNIVERSAL_124, start + size // 2), name)

    def test_an_offset_outside_every_library_is_none(self):
        self.assertIsNone(se.library_at(UNIVERSAL_124, 0))

    @unittest.skipUnless(shutil.which('readelf'), 'no readelf')
    def test_build_id_matches_readelf(self):
        with zipfile.ZipFile(UNIVERSAL_124) as z:
            data = z.read('lib/armeabi-v7a/libapp.so')
        with tempfile.NamedTemporaryFile(suffix='.so') as tmp:
            tmp.write(data)
            tmp.flush()
            notes = subprocess.run(['readelf', '-n', tmp.name], capture_output=True, text=True).stdout
        self.assertIn(f'Build ID: {se.build_id(data)}', notes)


class Parsing(unittest.TestCase):
    def test_release_tag(self):
        self.assertEqual(se.release_of({'tags': [{'key': 'release', 'value': 'nightingale-tv@1.2.4'}]}), '1.2.4')
        self.assertEqual(se.release_of({'release': 'nightingale-tv@1.2.5+5007'}), '1.2.5')
        self.assertIsNone(se.release_of({'tags': []}))

    def test_package_with_offset(self):
        m = se.PACKAGE.match('/data/app/~~x==/com.coffeehauslabs.nightingale_tv-y==/base.apk (offset 18e8000)')
        self.assertEqual(int(m.group('offset'), 16), 0x18e8000)
        self.assertIsNone(se.PACKAGE.match('/data/app/x/base.apk').group('offset'))

    def test_not_elf(self):
        self.assertIsNone(se.build_id(b'not an elf file'))


if __name__ == '__main__':
    sys.exit(unittest.main())
