import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'tr.dart';

/// Which language the app shows (design D4): the active profile's choice;
/// with no profile, the last explicit choice on this device; then the
/// device's languages in order of preference; then English.
class LanguageController extends ChangeNotifier with WidgetsBindingObserver {
  LanguageController({List<String> Function()? deviceLanguages})
      : _deviceLanguages = deviceLanguages ?? _platformLanguages {
    _apply();
  }

  final List<String> Function() _deviceLanguages;

  /// Saves the language for screens with no profile; null when it follows
  /// the device, so the profile picker keeps following it too.
  void Function(String? language)? onLastChanged;

  bool _hasProfile = false;
  String? _profileChoice;
  String? _last;

  static List<String> _platformLanguages() =>
      [for (final l in PlatformDispatcher.instance.locales) l.languageCode];

  /// What Automatic means on this device right now.
  String get automatic {
    for (final tag in _deviceLanguages()) {
      final language = supportedLanguage(tag);
      if (language != null) return language;
    }
    return 'en';
  }

  /// The language a profile choice (null: Automatic) shows.
  String resolve(String? choice) => supportedLanguage(choice) ?? automatic;

  /// The language showing now.
  String get language => _hasProfile ? resolve(_profileChoice) : resolve(_last);

  Locale get locale => Locale(language);

  /// What was saved for screens with no profile, at start-up.
  void restoreLast(String? language) {
    _last = supportedLanguage(language);
    _apply();
  }

  /// The profile now on screen; null when the profile picker is.
  void setProfile({required bool active, String? choice}) {
    _hasProfile = active;
    _profileChoice = active ? supportedLanguage(choice) : null;
    if (active && _last != _profileChoice) {
      _last = _profileChoice;
      onLastChanged?.call(_last);
    }
    _apply();
  }

  /// The device's languages changed while the app runs.
  @override
  void didChangeLocales(List<Locale>? locales) => _apply();

  String? _shown;

  void _apply() {
    final now = language;
    if (now == _shown) return;
    _shown = now;
    activeLanguage = now;
    notifyListeners();
  }
}
