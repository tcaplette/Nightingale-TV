import 'package:flutter/services.dart';

/// Opens [url] (a download) in the browser. Nothing off the web.
void openDownload(String url) {}

/// Copies [text] (Flutter's clipboard off the web).
Future<bool> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}
