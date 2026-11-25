import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/pin_dialog.dart';

/// The PIN pad's keys are a fixed width: a long label (キャンセル, Abbrechen)
/// is drawn smaller to fit, never cut short.
void main() {
  tearDown(() => activeLanguage = 'en');

  for (final language in supportedLanguages) {
    testWidgets('no PIN key is cut short in $language', (tester) async {
      activeLanguage = language;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: GuideTheme.cableGuide.toThemeData(),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => askPin(context, title: tr.enterPin, check: (_) => false), child: const Text('open')),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(tr.cancel), findsOneWidget);
      final cut = [
        for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText)))
          if (p.didExceedMaxLines) p.text.toPlainText(),
      ];
      expect(cut, isEmpty);
    });
  }
}
