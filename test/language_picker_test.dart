import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/ui/language_picker.dart';
import 'package:nightingale_tv/ui/menu_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';

import 'portrait_harness.dart';

void main() {
  tearDown(() => activeLanguage = 'en');

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<PortraitHarness> open(WidgetTester tester, {bool television = true}) async {
    runAs(TargetPlatform.android, television: television);
    setWindow(tester, const Size(1920, 1080));
    final h = await PortraitHarness.start(tester);
    await h.show(tester, const MenuScreen());
    await settle(tester);
    await tester.ensureVisible(find.text('Language'));
    await tester.pump();
    await tester.tap(find.text('Language'));
    await settle(tester);
    return h;
  }

  testWidgets('the picker lists Automatic and each language by its own name', (tester) async {
    await open(tester);
    expect(find.byType(TvToggle), findsNWidgets(7));
    for (final name in ['Automatic', 'English', 'Deutsch', 'Français', 'Español', 'Português (Brasil)', 'Italiano']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('choosing keeps the picker open and focused, saves it, and leaves the menu', (tester) async {
    final h = await open(tester);
    final row = find.ancestor(of: find.text('Español'), matching: find.byType(TvToggle));
    await tester.tap(row);
    await tester.pump();
    await settle(tester);
    expect(h.household.current!.language, 'es');
    expect(find.text('Español'), findsOneWidget, reason: 'the picker stays open');
    expect(find.text('Idioma'), findsWidgets, reason: 'its title is in Spanish');
    expect(find.byType(MenuScreen), findsOneWidget, reason: 'the screen stays');
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<Dialog>(), isNotNull, reason: 'focus stays in the picker');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('French shows Automatic in French and German still as Deutsch', (tester) async {
    final h = await PortraitHarness.start(tester);
    await tester.runAsync(() => h.household.setLanguage(h.household.current!, 'fr'));
    runAs(TargetPlatform.android, television: true);
    setWindow(tester, const Size(1920, 1080));
    await h.show(tester, Builder(builder: (context) {
      return Center(child: TextButton(onPressed: () => showLanguagePicker(context, h.household.current!), child: const Text('open')));
    }));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Automatique'), findsWidgets);
    expect(find.text('Deutsch'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
