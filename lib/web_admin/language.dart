import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'browser.dart';

/// The web admin's language (design D8): the browser's own, until someone
/// picks one here. The choice stays in this browser and changes no profile.
class WebLanguage extends ChangeNotifier {
  WebLanguage({this._languages = browserLanguages}) {
    _choice = supportedLanguage(readStored(_key));
    _apply();
  }

  static const _key = 'nightingale-language';

  final List<String> Function() _languages;
  String? _choice;

  /// The pick; null is Automatic.
  String? get choice => _choice;

  String get language {
    if (_choice case final chosen?) return chosen;
    for (final tag in _languages()) {
      if (supportedLanguage(tag) case final found?) return found;
    }
    return 'en';
  }

  void choose(String? language) {
    _choice = supportedLanguage(language);
    writeStored(_key, _choice);
    _apply();
    notifyListeners();
  }

  void _apply() {
    activeLanguage = language;
    setPageLanguage(activeLanguage);
  }
}

/// The one for this page.
final webLanguage = WebLanguage();

/// The Language menu, in the shell and on the sign-in page.
class WebLanguageButton extends StatelessWidget {
  const WebLanguageButton({super.key, this.asTile = false});

  /// A row of the side navigation, rather than an icon button.
  final bool asTile;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: tr.languageTitle,
        icon: asTile ? null : const Icon(Icons.language),
        // '' for Automatic: a popup menu can't pick null.
        initialValue: webLanguage.choice ?? '',
        onSelected: (value) => webLanguage.choose(value.isEmpty ? null : value),
        itemBuilder: (_) => [
          PopupMenuItem(value: '', child: Text(tr.languageAutomatic)),
          for (final language in supportedLanguages)
            PopupMenuItem(value: language, child: Text(languageNativeNames[language]!)),
        ],
        child: asTile
            ? ListTile(leading: const Icon(Icons.language), title: Text(tr.languageTitle), shape: const StadiumBorder())
            : null,
      );
}
