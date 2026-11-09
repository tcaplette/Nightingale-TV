import 'dart:convert';
import 'dart:io';

import 'package:nightingale_tv/l10n/tr.dart';

/// The ARB file of [language], with `@` entries.
Map<String, dynamic> readArb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, dynamic>;

final Map<String, Map<String, dynamic>> _arbs = {for (final l in supportedLanguages) l: readArb(l)};

/// [english] (a whole message with no placeholders) in the current language,
/// for tests that find text by what English says.
String translated(String english) {
  if (currentLanguage == 'en') return english;
  final en = _arbs['en']!;
  final key = en.keys.firstWhere((k) => en[k] == english, orElse: () => throw StateError('No message "$english"'));
  return _arbs[currentLanguage]![key] as String;
}
