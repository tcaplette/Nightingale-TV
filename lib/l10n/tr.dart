import 'dart:async';
import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';

import 'app_localizations.dart';

export 'app_localizations.dart' show AppLocalizations;

/// The app's languages (app-languages). Portuguese is Brazilian (design D1).
const supportedLanguages = ['en', 'de', 'fr', 'es', 'pt', 'it'];

/// Each language by its own name, whatever language is showing.
const languageNativeNames = {
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português (Brasil)',
  'it': 'Italiano',
};

/// The app's language where no zone names one (design D3). Only the app's
/// [LanguageController] and the web admin's language set this.
String activeLanguage = 'en';

/// The zone value naming this zone's language.
const _languageKey = #nightingaleLanguage;

/// The supported language [tag] (`de`, `de-AT`, `pt_PT`) belongs to; null
/// for none.
String? supportedLanguage(String? tag) {
  if (tag == null) return null;
  final base = tag.trim().toLowerCase().split(RegExp('[-_]')).first;
  return supportedLanguages.contains(base) ? base : null;
}

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
    _strings[language] ??= lookupAppLocalizations(Locale(language));

/// The interface text in the current language (design D2): English in code
/// that sets no language, so tests read as they always did.
AppLocalizations get tr => stringsFor(currentLanguage);

/// `intl`'s date data; the app's entry points wait for it, and [format.dart]
/// asks for it too, so code that has no entry point can't miss it.
final Future<void> languageDataReady = initializeDateFormatting();
