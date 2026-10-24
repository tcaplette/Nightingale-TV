/// What the web admin asks of the browser beyond Flutter: opening a
/// download, and copying on a plain `http://` page. Stubs off the web, so the
/// pages also build in VM tests.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
