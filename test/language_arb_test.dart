import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/language_names.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/server/languages.dart';

import 'language_arb_support.dart';

/// Values that are rightly the same as English: names, codes, numbers.
const _sameAsEnglish = <String>{
  '12 Mbps · 1080p',
  '4 Mbps · 720p',
  '40 Mbps · 4K',
  '8 Mbps · 1080p',
  'ACCENT ({label})',
  'ACCOUNT',
  'AUDIO',
  'Accent ({label})',
  'Action',
  'Action TV',
  'Admin',
  'Alternative',
  'Animation',
  'Arcade',
  'BACKUPS',
  'Backups',
  'Badges',
  'CH +',
  'CH {padLeft}',
  'CH −',
  'COLOR',
  'Color',
  'Country',
  'Crime',
  'DATES',
  'Dance',
  'Drama',
  'ENCODER',
  'Encoder',
  'Fantasy',
  'Fantasy TV',
  'File: {name}',
  'Folk',
  'GENRES',
  'GUIDE',
  'GUIDE (OPTIONAL)',
  'Game Show TV',
  'Genres',
  'Guide',
  'Guide: {guideFile}',
  'Home',
  'Horror',
  'Image',
  'Images',
  'Info',
  'LIVE',
  'Late Night',
  'Latin',
  'Live',
  'Live · {source}',
  'M Menu',
  'MID-ROLL',
  'Menu',
  'Mid-roll',
  'Mystery',
  'NIGHTINGALE TV GUIDE',
  'Name',
  'Natural',
  'OK',
  'Offline',
  'Oldies',
  'Online',
  'Original',
  'PIN',
  'PIN (optional)',
  'PLAYLIST',
  'POOLS',
  'POST-ROLL',
  'PRE-ROLL',
  'Password',
  'Pause',
  'Pools',
  'Port',
  'Post-roll',
  'Pre-roll',
  'Quick Connect',
  'Radio',
  'Reality',
  'Reality TV',
  'Romance',
  'Romance TV',
  'SCANLINES',
  'Scanlines',
  'Sci-Fi',
  'Sci-Fi & Fantasy',
  'Sci-Fi TV',
  'Songs ({songs})',
  'Soundtrack',
  'Standard',
  'TV',
  'TYPE',
  'Talk',
  'Thrill TV',
  'Thriller',
  'Toon TV',
  'Tuner',
  'VIGNETTE',
  'Video',
  'Vignette',
  'Warm',
  'Western',
  'XMLTV',
  'http://…/playlist.m3u',
  '{clips, plural, =1{{name}  ·  {clips} clip} other{{name}  ·  {clips} clips}}',
  '{commercialBreakLabel} in {left}',
  '{date}, {time}',
  '{decade} TV',
  '{decade} {genre} TV',
  '{inMinutes} min',
  '{inMinutes} minutes',
  '{n, plural, =1{{n} clip} other{{n} clips}}',
  '{name} (collection)',
  '{name} ({kind} {number})',
  '{name} ({kind})',
  '{name}: {stats}',
  '{profiles} · {channels} · {blocks}.',
  '{toStringAsFixed} Mbps',
};

const _translated = ['de', 'fr', 'es', 'pt', 'it'];

Set<String> _placeholders(String message) {
  final found = <String>{};
  for (final m in RegExp(r'\{(\w+)(?=[,}])').allMatches(message)) {
    found.add(m[1]!);
  }
  return found;
}

/// The Unicode characters in a TrueType font's cmap (formats 4 and 12).
Set<int> _fontCharacters(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final at = 12 + i * 16;
    if (String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes + at, 4)) == 'cmap') cmap = data.getUint32(at + 8);
  }
  final chars = <int>{};
  final records = data.getUint16(cmap + 2);
  for (var r = 0; r < records; r++) {
    final sub = cmap + data.getUint32(cmap + 4 + r * 8 + 4);
    final format = data.getUint16(sub);
    if (format == 4) {
      final seg = data.getUint16(sub + 6) ~/ 2;
      final ends = sub + 14;
      final starts = ends + seg * 2 + 2;
      for (var i = 0; i < seg; i++) {
        final end = data.getUint16(ends + i * 2), start = data.getUint16(starts + i * 2);
        if (start != 0xFFFF) chars.addAll([for (var c = start; c <= end; c++) c]);
      }
    } else if (format == 12) {
      final groups = data.getUint32(sub + 12);
      for (var i = 0; i < groups; i++) {
        final g = sub + 16 + i * 12;
        chars.addAll([for (var c = data.getUint32(g); c <= data.getUint32(g + 4); c++) c]);
      }
    }
  }
  return chars;
}

void main() {
  final en = readArb('en');
  final keys = [for (final k in en.keys) if (!k.startsWith('@')) k];

  for (final language in _translated) {
    group(language, () {
      final arb = readArb(language);

      test('has every message, and no others', () {
        expect([for (final k in keys) if (!arb.containsKey(k)) k], isEmpty, reason: 'missing in $language');
        expect([for (final k in arb.keys) if (!k.startsWith('@') && !en.containsKey(k)) k], isEmpty, reason: 'extra in $language');
      });

      test('has the same placeholders as English', () {
        final wrong = <String>[];
        for (final k in keys) {
          final declared = ((en['@$k'] as Map?)?['placeholders'] as Map?)?.keys.toSet() ?? <String>{};
          if (!_placeholders(arb[k] as String).containsAll(declared) || !declared.containsAll(_placeholders(arb[k] as String))) {
            wrong.add('$k: ${arb[k]}');
          }
        }
        expect(wrong, isEmpty);
      });

      test('its plurals are valid', () {
        final wrong = <String>[];
        for (final k in keys) {
          final m = arb[k] as String;
          var depth = 0;
          for (final c in m.split('')) {
            if (c == '{') depth++;
            if (c == '}') depth--;
            if (depth < 0) break;
          }
          if (depth != 0 || (m.contains(', plural,') && !m.contains('other{'))) wrong.add('$k: $m');
        }
        expect(wrong, isEmpty);
      });

      test('leaves nothing in English outside the allow-list', () {
        expect([for (final k in keys) if (arb[k] == en[k] && !_sameAsEnglish.contains(en[k])) '$k: ${en[k]}'], isEmpty);
      });

      test('names every caption language', () {
        final names = languageNameMaps[language]!;
        expect([for (final c in namedLanguageCodes) if (!names.containsKey(c)) c], isEmpty);
      });
    });
  }

  test('the bundled fonts can draw every character the translations use', () {
    final english = (en.values.whereType<String>().join()).runes.toSet();
    final used = <int, String>{};
    for (final language in _translated) {
      final arb = readArb(language);
      for (final k in keys) {
        for (final c in (arb[k] as String).runes) {
          // Symbols English uses already (arrows, ▲▼) draw as they always have.
          if (!english.contains(c)) used[c] = '$language $k';
        }
      }
    }
    for (final font in Directory('assets/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      final chars = _fontCharacters(font.path);
      final missing = {for (final e in used.entries) if (!chars.contains(e.key)) String.fromCharCode(e.key): e.value};
      expect(missing, isEmpty, reason: font.path);
    }
    expect(supportedLanguages, contains('pt'));
  });
}
