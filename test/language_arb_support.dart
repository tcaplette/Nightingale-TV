import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:nightingale_tv/l10n/tr.dart';

/// The ARB file name part of [language]: `zh-Hant-HK` is `app_zh_Hant_HK.arb`,
/// and Simplified Chinese is the base `app_zh.arb` (cjk-languages D1).
String arbName(String language) => language == 'zh-Hans' ? 'zh' : language.replaceAll('-', '_');

/// The ARB file of [language], with `@` entries.
Map<String, dynamic> readArb(String language) =>
    jsonDecode(File('lib/l10n/app_${arbName(language)}.arb').readAsStringSync()) as Map<String, dynamic>;

final Map<String, Map<String, dynamic>> _arbs = {for (final l in supportedLanguages) l: readArb(l)};

/// [english] (a whole message with no placeholders) in the current language,
/// for tests that find text by what English says.
String translated(String english) {
  if (currentLanguage == 'en') return english;
  final en = _arbs['en']!;
  final key = en.keys.firstWhere((k) => en[k] == english, orElse: () => throw StateError('No message "$english"'));
  return _arbs[currentLanguage]![key] as String;
}


/// Loads the app's bundled fonts (Barlow, Barlow Condensed, VT323 and the
/// Japanese and Chinese font) under their families, as pubspec.yaml lists
/// them, so text in tests has its real width.
Future<void> loadAppFonts() async {
  final families = <String, List<String>>{};
  String? family;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final f = RegExp(r'^\s+- family: (\S+)').firstMatch(line);
    if (f != null) families[family = f[1]!] = [];
    final a = RegExp(r'^\s+- asset: (assets/fonts/\S+)').firstMatch(line);
    if (a != null && family != null) families[family]!.add(a[1]!);
  }
  for (final MapEntry(key: name, value: files) in families.entries) {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
    }
    await loader.load();
  }
}
