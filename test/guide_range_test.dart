import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/app_state.dart';
import 'package:nightingale_tv/data/app_storage.dart';

AppSettings _read(Map<String, Object?> j) =>
    AppSettings.fromJson(jsonDecode(jsonEncode({'installId': 'x', 'commercialsEnabled': false, ...j})) as Map<String, Object?>);

void main() {
  group('setting', () {
    test('a new profile has 8 hours', () {
      expect(AppSettings(installId: 'x').guideRangeHours, 8);
      expect(AppSettings(installId: 'x').guideRange, const Duration(hours: 8));
    });

    test('each choice round-trips', () {
      for (final h in GuideRange.choices) {
        final s = AppSettings(installId: 'x', guideRangeHours: h);
        expect(_read(s.toJson()).guideRangeHours, h);
      }
    });

    test('a profile saved before this setting loads with 8 hours', () {
      expect(_read({}).guideRangeHours, 8);
    });

    test('an unrecognized value loads as 8 hours', () {
      expect(_read({'guideRangeHours': 4}).guideRangeHours, 8);
      expect(_read({'guideRangeHours': 'five'}).guideRangeHours, 8);
    });
  });

  group('app state', () {
    late Directory dir;
    late AppState app;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('guide_range');
      app = AppState(await AppStorage.at(dir));
      await app.start();
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('the setting saves and loads; other values are ignored', () async {
      await app.setGuideRange(3);
      await app.setGuideRange(4);
      final again = AppState(app.storage);
      await again.start();
      expect(again.settings.guideRangeHours, 3);
    });
  });
}
