import 'package:flutter/services.dart';

/// Opens [url] (a download) in the browser. Nothing off the web.
void openDownload(String url) {}

/// Copies [text] (Flutter's clipboard off the web).
Future<bool> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}

/// The browser's languages, in order of preference. None off the web.
List<String> browserLanguages() => const [];

/// A saved value for this browser. None off the web.
String? readStored(String key) => null;

/// Saves (or with null, clears) a value for this browser. Off the web, nowhere.
void writeStored(String key, String? value) {}

/// Declares the page's language. Nothing off the web.
void setPageLanguage(String language) {}
