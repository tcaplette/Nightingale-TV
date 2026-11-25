import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/language_names.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/server/languages.dart';

import 'language_arb_support.dart';

/// Values that are rightly the same as English: names, codes, numbers.
const _sameAsEnglish = <String>{
  ', ',
  // The undo point's confirmation title: its action and time (backup-simplify).
  '{action} · {time}',
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
  // Quality YouTube chooses (player-options): 'Auto' in YouTube's own menus.
  'Auto',
  'Avatar',
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
  'Licences',
  'Live',
  'Live · {source}',
  'M Menu',
  'MID-ROLL',
  'Magenta',
  'Menu',
  'Mid-roll',
  'Mystery',
  'NIGHTINGALE TV GUIDE',
  'NEW',
  'Name',
  'Natural',
  'OK',
  'Offline',
  'Oldies',
  'Olive',
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
  'YouTube',
  'http://…/playlist.m3u',
  'http://provider.example/get.php?username=…&type=m3u_plus',
  '{clips, plural, =1{{name}  ·  {clips} clip} other{{name}  ·  {clips} clips}}',
  '{color} · {name}',
  '{commercialBreakLabel} in {left}',
  '{date}, {time}',
  '{mbps} Mbps',
  '{decade} TV',
  '{decade} {genre} TV',
  '{decade}s',
  '{decades} {genres}',
  '{inMinutes} min',
  '{inMinutes} minutes',
  '{label}: {value}',
  '.',
  '{n, plural, =1{{n} clip} other{{n} clips}}',
  '{name} (collection)',
  '{name} ({kind} {number})',
  '{name} ({kind})',
  '{name}: {stats}',
  '{profiles} · {channels} · {blocks}.',
  '{toStringAsFixed} Mbps',
};

final _translated = [for (final l in supportedLanguages) if (l != 'en') l];

/// The bundled Japanese and Chinese font (cjk-languages D2).
const _cjkFont = 'assets/fonts/NotoSansCJK-UI-Regular.otf';
const _cjkFontBold = 'assets/fonts/NotoSansCJK-UI-Bold.otf';

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

  test('the bundled Latin fonts can draw every character the Latin-script translations use', () {
    final english = (en.values.whereType<String>().join()).runes.toSet();
    final used = <int, String>{};
    for (final language in _translated.where((l) => !isCjk(l))) {
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

  test('the bundled CJK font has every character the Japanese and Chinese text uses', () {
    final english = (en.values.whereType<String>().join()).runes.toSet();
    final used = <int, String>{};
    for (final language in _translated.where(isCjk)) {
      final arb = readArb(language);
      for (final k in keys) {
        for (final c in (arb[k] as String).runes) {
          if (!english.contains(c)) used[c] = '$language $k';
        }
      }
    }
    // The picker lists every language by its own name, in every language.
    for (final MapEntry(:key, :value) in languageNativeNames.entries.where((e) => isCjk(e.key))) {
      for (final c in value.runes) {
        if (!english.contains(c)) used[c] = 'the language name of $key';
      }
    }
    // Caption language names in Japanese and Chinese.
    for (final language in _translated.where(isCjk)) {
      for (final MapEntry(:key, :value) in languageNameMaps[language]!.entries) {
        for (final c in value.runes) {
          if (!english.contains(c)) used[c] = '$language caption name $key';
        }
      }
    }
    expect(used, isNotEmpty);
    for (final font in [_cjkFont, _cjkFontBold]) {
      final chars = _fontCharacters(font);
      final missing = [
        for (final e in used.entries)
          if (!chars.contains(e.key)) '${String.fromCharCode(e.key)} (U+${e.key.toRadixString(16).toUpperCase()}) in ${e.value}',
      ];
      expect(missing, isEmpty, reason: '$font is out of date: run python3 tool/subset_cjk_font.py');
    }
  });

  test('the CJK font records where it came from', () {
    final record = jsonDecode(File('assets/fonts/NotoSansCJK-UI.json').readAsStringSync()) as Map<String, dynamic>;
    expect(record['source'], contains('Noto Sans CJK'));
    expect((record['sha256'] as Map).keys, containsAll(['Regular', 'Bold']));
    expect(File('assets/fonts/OFL-NotoSansCJK.txt').readAsStringSync(), contains('SIL Open Font License'));
  });
}
