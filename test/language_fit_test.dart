// Every language must fit (design D12): the layout sweep, on the narrowest
// phone and on a TV, in each translated language.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/tr.dart';

import 'language_arb_support.dart';
import 'portrait_harness.dart';
import 'portrait_layout_test.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final language in supportedLanguages.where((l) => l != 'en')) {
    group(language, () {
      // The device's language: the harness's household is on Automatic,
      // which follows it, so every screen shows [language].
      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.localesTestValue = [localeOf(language)];
        activeLanguage = language;
      });
      tearDown(() {
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.clearLocalesTestValue();
        activeLanguage = 'en';
      });
      group('phone', () => layoutSweep(windows: const [narrowPhone]));
      group('TV', () => layoutSweep(windows: const [Size(1920, 1080)], television: true));
    });
  }
}
