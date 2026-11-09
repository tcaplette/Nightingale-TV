import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/data/app_storage.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/reporting/error_reports.dart';
import 'package:nightingale_tv/reporting/report_switch.dart';
import 'package:nightingale_tv/theme/tv_theme.dart';
import 'package:nightingale_tv/ui/error_reports_screen.dart';
import 'package:nightingale_tv/ui/widgets/tv_focus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Keeps what would have gone to GlitchTip.
class _Sent implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }
}

void main() {
  late Directory dir;
  late AppStorage storage;
  late _Sent sent;

  void testHooks({bool dsn = true}) {
    ErrorReports.debugDsn = dsn ? 'https://public@reports.invalid/2' : '';
    ErrorReports.debugTransport = sent;
    ErrorReports.debugInstallHandlers = false;
  }

  Future<void> show(WidgetTester tester, {bool dsn = true}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sent = _Sent();
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('nightingale_tv_error_reports');
      storage = await AppStorage.at(dir);
      await ErrorReports.debugReset();
      ReportSwitch.instance.reset();
      testHooks(dsn: dsn);
      await ErrorReports.startApp(storage);
    });
    await tester.pumpWidget(MaterialApp(
      theme: GuideTheme.cableGuide.toThemeData(),
      home: const ErrorReportsScreen(),
    ));
    await tester.pumpAndSettle();
    addTearDown(() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.runAsync(() async {
        await ErrorReports.debugReset();
        ReportSwitch.instance.reset();
        await storage.flush();
        await dir.delete(recursive: true);
      });
    });
  }

  /// What has focus: a button's label, or "back".
  String? focused() {
    final node = FocusManager.instance.primaryFocus;
    if (node?.debugLabel == 'back button') return 'back';
    return node?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  /// Lets real file and transport work finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('D-pad: switch, test button and back, Select works each', (tester) async {
    await show(tester);
    expect(find.text(tr.errorReportsExplain), findsOneWidget);
    expect(focused(), tr.sendErrorReportsFrom, reason: 'the switch has focus first');
    expect(tester.widget<TvToggle>(find.byType(TvToggle)).on, isTrue, reason: 'on by default');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), tr.sendATestReport);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(sent.envelopes, hasLength(1));
    final id = ReportSwitch.shortId(sent.envelopes.single.header.eventId.toString());
    expect(find.text(tr.testReportSent(id)), findsOneWidget, reason: 'the ID shows at once');
    expect(ReportSwitch.instance.shortLastId, id);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), tr.sendErrorReportsFrom);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(ReportSwitch.instance.on, isFalse);
    expect(ErrorReports.running, isFalse, reason: 'off stops reporting at once');
    expect(tester.widget<TvToggle>(find.byType(TvToggle)).on, isFalse);
    expect(tester.widget<TvButton>(find.widgetWithText(TvButton, tr.sendATestReport)).onPressed, isNull);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'back');
  });

  testWidgets('pointer and touch: tapping the switch and the button', (tester) async {
    await show(tester);
    await tester.tap(find.text(tr.sendATestReport), kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(sent.envelopes, hasLength(1));
    await tester.tap(find.text(tr.sendErrorReportsFrom), kind: PointerDeviceKind.touch);
    await settle(tester);
    expect(ReportSwitch.instance.on, isFalse);
    await tester.tap(find.text(tr.sendErrorReportsFrom), kind: PointerDeviceKind.touch);
    await settle(tester);
    expect(ReportSwitch.instance.on, isTrue);
    expect(ErrorReports.running, isTrue);
  });

  testWidgets('the switch is saved for this device and survives a restart', (tester) async {
    await show(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(ReportSwitch.instance.on, isFalse);
    await tester.runAsync(() async {
      await storage.flush();
      ReportSwitch.instance.reset();
      await ErrorReports.debugReset();
      testHooks();
      await ErrorReports.startApp(await AppStorage.at(dir));
    });
    expect(ReportSwitch.instance.on, isFalse);
    expect(ErrorReports.running, isFalse, reason: 'off: the SDK is never started');
  });

  testWidgets('a build without a DSN: says so, nothing can be pressed', (tester) async {
    await show(tester, dsn: false);
    expect(ErrorReports.running, isFalse);
    expect(find.text(tr.reportsNotInBuild), findsOneWidget);
    expect(tester.widget<TvToggle>(find.byType(TvToggle)).onPressed, isNull);
    expect(tester.widget<TvToggle>(find.byType(TvToggle)).on, isFalse);
    expect(tester.widget<TvButton>(find.widgetWithText(TvButton, tr.sendATestReport)).onPressed, isNull);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'back', reason: 'the back button is all there is to focus');
    await tester.tap(find.text(tr.sendATestReport));
    await settle(tester);
    expect(sent.envelopes, isEmpty);
  });
}
