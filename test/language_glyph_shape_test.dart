import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/theme/fonts.dart';

/// Shared Han characters take each language's own shapes from the one
/// bundled CJK font, through `locl` and the paragraph locale (cjk-languages
/// D4): 直 and 骨 differ between Japanese, Simplified and Traditional, and 写
/// between Japanese and Simplified.
void main() {
  setUpAll(() async {
    final loader = FontLoader(cjkFontFallback.single);
    for (final weight in ['Regular', 'Bold']) {
      final bytes = File('assets/fonts/NotoSansCJK-UI-$weight.otf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Future<Uint8List> render(WidgetTester tester, String language, String text) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: localeOf(language),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFFFFFFFF),
              child: Text(text, style: const TextStyle(fontFamily: 'Barlow', fontFamilyFallback: cjkFontFallback, fontSize: 96, color: Color(0xFF000000))),
            ),
          ),
        ),
      ),
    ));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  testWidgets('each language draws its own shapes', (tester) async {
    final shapes = {
      for (final language in ['ja', 'zh-Hans', 'zh-Hant', 'zh-Hant-HK'])
        language: {for (final c in ['直', '骨', '写']) c: await render(tester, language, c)},
    };
    // The text drew: not a blank or an empty box the same for every character.
    expect(shapes['zh-Hans']!['直'], isNot(equals(shapes['zh-Hans']!['骨'])));
    // The same language draws the same way twice, so a difference is the shape.
    expect(await render(tester, 'ja', '直'), equals(shapes['ja']!['直']));
    expect(shapes['zh-Hant']!['写'], equals(shapes['zh-Hans']!['写']), reason: '写 has one Chinese shape');
    expect(shapes['ja']!['直'], isNot(equals(shapes['zh-Hans']!['直'])), reason: '直: Japanese and Simplified');
    expect(shapes['ja']!['写'], isNot(equals(shapes['zh-Hans']!['写'])), reason: '写: Japanese and Simplified');
    expect(shapes['zh-Hant']!['骨'], isNot(equals(shapes['zh-Hans']!['骨'])), reason: '骨: Taiwan and Simplified');
    expect(shapes['zh-Hant-HK']!['骨'], isNot(equals(shapes['zh-Hans']!['骨'])), reason: '骨: Hong Kong and Simplified');
  });
}
