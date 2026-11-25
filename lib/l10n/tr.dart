import 'dart:async';
import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';

import 'app_localizations.dart';

export 'app_localizations.dart' show AppLocalizations;

/// The app's languages (app-languages), as language tags. Portuguese is
/// Brazilian (app-languages D1); `zh-Hans` is the base `zh` ARB file
/// (cjk-languages D1).
const supportedLanguages = ['en', 'de', 'fr', 'es', 'pt', 'it', 'ja', 'zh-Hans', 'zh-Hant', 'zh-Hant-HK'];

/// Each language by its own name, whatever language is showing.
const languageNativeNames = {
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português (Brasil)',
  'it': 'Italiano',
  'ja': '日本語',
  'zh-Hans': '简体中文',
  'zh-Hant': '繁體中文',
  'zh-Hant-HK': '繁體中文（香港）',
};

/// The app's language where no zone names one (design D3). Only the app's
/// [LanguageController] and the web admin's language set this.
String activeLanguage = 'en';

/// The zone value naming this zone's language.
const _languageKey = #nightingaleLanguage;

/// The supported language [tag] (`de`, `de-AT`, `pt_PT`, `zh-TW`) belongs
/// to; null for none. Chinese goes by script and region (cjk-languages D1).
String? supportedLanguage(String? tag) {
  if (tag == null) return null;
  final parts = tag.trim().toLowerCase().split(RegExp('[-_]'));
  final base = parts.first;
  final rest = parts.skip(1).toList();
  if (base == 'zh' || base == 'yue') {
    final script = rest.isNotEmpty && rest.first.length == 4 ? rest.first : null;
    final region = rest.skip(script == null ? 0 : 1).firstOrNull;
    if (script == 'hans') return 'zh-Hans';
    if (base == 'yue' || region == 'hk' || region == 'mo') return 'zh-Hant-HK';
    if (script == 'hant' || region == 'tw') return 'zh-Hant';
    return 'zh-Hans';
  }
  return supportedLanguages.contains(base) ? base : null;
}

/// [language]'s `Locale`, with its script and region, for `MaterialApp`,
/// `Localizations` and the ARB lookup.
Locale localeOf(String language) {
  final parts = language.split('-');
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
    countryCode: parts.length > 2 ? parts[2] : (parts.length == 2 && parts[1].length == 2 ? parts[1] : null),
  );
}

/// [language]'s locale name for `intl`: the existing six map to themselves.
String intlLocaleOf(String language) => switch (language) {
      'zh-Hans' => 'zh',
      'zh-Hant' => 'zh_TW',
      'zh-Hant-HK' => 'zh_HK',
      _ => language,
    };

/// Whether [language] is written in Japanese or Chinese characters.
bool isCjk(String language) => language == 'ja' || language.startsWith('zh');

/// The first supported language of an `Accept-Language` header; null for none.
String? languageFromHeader(String? header) {
  if (header == null) return null;
  for (final part in header.split(',')) {
    if (supportedLanguage(part.split(';').first) case final language?) return language;
  }
  return null;
}

/// The language text is being written in here: this zone's, or the app's.
String get currentLanguage => Zone.current[_languageKey] as String? ?? activeLanguage;

/// Runs [body], and all async work it starts, in [language]; an unsupported
/// or null language means the surrounding language.
R runInLanguage<R>(String? language, R Function() body) {
  final supported = supportedLanguage(language);
  return supported == null ? body() : runZoned(body, zoneValues: {_languageKey: supported});
}

final _strings = <String, AppLocalizations>{};

/// The text in [language], whatever language is current.
AppLocalizations stringsFor(String language) =>
    _strings[language] ??= lookupAppLocalizations(localeOf(language));

/// The interface text in the current language (design D2): English in code
/// that sets no language, so tests read as they always did.
AppLocalizations get tr => stringsFor(currentLanguage);

/// `intl`'s date data; the app's entry points wait for it, and [format.dart]
/// asks for it too, so code that has no entry point can't miss it.
final Future<void> languageDataReady = initializeDateFormatting();

/// "Sam", "Sam and Alex", "Sam, Alex and Kim"; "サム、アレックスとキム".
String joinNames(List<String> names) => switch (names.length) {
      0 => '',
      1 => names.single,
      _ => tr.and(names.sublist(0, names.length - 1).join(tr.listSeparator), names.last),
    };
