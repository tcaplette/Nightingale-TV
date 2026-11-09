import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:http/browser_client.dart';

import 'api_client.dart';
import 'app.dart';
import '../l10n/tr.dart';

/// The web admin (docker-web-admin), served by the setup server. Built with
/// tool/build_web_admin.sh; it may only import code that runs in a browser
/// (design D2).
Future<void> main() async {
  // Real paths, so links, reloads and the setup link (/setup?token=) work.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await languageDataReady;
  // Screen readers and the browser's find-in-page read the semantics tree
  // (CanvasKit draws everything else).
  SemanticsBinding.instance.ensureSemantics();
  runApp(WebAdminApp(api: ApiClient(BrowserClient()..withCredentials = true)));
  // WebKit drops the frames drawn while its compositor starts, which
  // leaves a page that then sits still blank; these redraws show it.
  for (final ms in const [250, 500, 1000, 2000]) {
    Timer(Duration(milliseconds: ms), WidgetsBinding.instance.scheduleForcedFrame);
  }
}
