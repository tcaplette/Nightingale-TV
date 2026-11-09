import 'dart:js_interop';

@JS('window.location.assign')
external void _assign(String url);

@JS('window.isSecureContext')
external bool get _secure;

@JS('document.createElement')
external _Element _create(String tag);

@JS('document.body.appendChild')
external void _append(_Element e);

@JS('document.execCommand')
external bool _exec(String command);

@JS('navigator.clipboard.writeText')
external JSPromise<JSAny?> _writeText(String text);

extension type _Element(JSObject _) implements JSObject {
  external set value(String v);
  external void select();
  external void remove();
  external _Style get style;
}

extension type _Style(JSObject _) implements JSObject {
  external set cssText(String v);
}

/// Opens [url] (a download: the server answers with an attachment, so the
/// page stays where it is).
void openDownload(String url) => _assign(url);

/// Copies [text]. On a plain `http://` LAN page the Clipboard API isn't
/// offered, so a hidden textarea and the browser's copy command do it
/// (inside the button press, which counts as the user's gesture).
Future<bool> copyText(String text) async {
  if (_secure) {
    try {
      await _writeText(text).toDart;
      return true;
    } on Object {
      // Below.
    }
  }
  final area = _create('textarea')
    ..value = text
    ..style.cssText = 'position:fixed;top:0;left:0;opacity:0';
  _append(area);
  area.select();
  try {
    return _exec('copy');
  } finally {
    area.remove();
  }
}

@JS('navigator.languages')
external JSArray<JSString>? get _languages;

@JS('localStorage.getItem')
external JSString? _getItem(String key);

@JS('localStorage.setItem')
external void _setItem(String key, String value);

@JS('localStorage.removeItem')
external void _removeItem(String key);

@JS('document.documentElement.setAttribute')
external void _setRootAttribute(String name, String value);

/// The browser's languages, in order of preference.
List<String> browserLanguages() {
  try {
    return [for (final l in _languages?.toDart ?? const <JSString>[]) l.toDart];
  } on Object {
    return const [];
  }
}

/// A value saved in this browser; null with private browsing or blocked storage.
String? readStored(String key) {
  try {
    return _getItem(key)?.toDart;
  } on Object {
    return null;
  }
}

/// Saves (or with null, clears) a value in this browser.
void writeStored(String key, String? value) {
  try {
    if (value == null) {
      _removeItem(key);
    } else {
      _setItem(key, value);
    }
  } on Object {
    // Blocked storage: the choice lasts until the page reloads.
  }
}

/// Declares the page's language (`<html lang>`).
void setPageLanguage(String language) => _setRootAttribute('lang', language);
