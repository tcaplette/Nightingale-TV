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
