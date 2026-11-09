import 'dart:convert';

import 'tr.dart';

/// Fills an HTML page's `@@key@@` text and gives its scripts the text as
/// `T`, with `LANG`, at the `/*TEXTS*/` marker (design D9).
String fillPage(String template, Map<String, String> texts) {
  final script = 'const T = ${jsonEncode(texts).replaceAll('<', r'<')}; '
      'const LANG = ${jsonEncode(currentLanguage)};';
  return template
      .replaceFirst('<html lang="en">', '<html lang="$currentLanguage">')
      .replaceFirst('/*TEXTS*/', script)
      .replaceAllMapped(RegExp(r'@@(\w+)@@'), (m) => const HtmlEscape(HtmlEscapeMode.element).convert(texts[m[1]]!));
}
