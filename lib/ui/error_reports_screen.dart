import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../reporting/error_reports.dart';
import '../reporting/report_switch.dart';
import '../theme/tv_theme.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// Error reports (error-reporting D8): this device's switch, what a report
/// holds, a test report, and the last report's ID for a tester to quote.
/// Builds without a reporting address show why nothing can be sent, with
/// the switch and the button disabled.
class ErrorReportsScreen extends StatefulWidget {
  const ErrorReportsScreen({super.key});

  @override
  State<ErrorReportsScreen> createState() => _ErrorReportsScreenState();
}

class _ErrorReportsScreenState extends State<ErrorReportsScreen> {
  bool _sending = false;

  /// The last test's outcome: its ID, or null when it couldn't be sent.
  ({String? id})? _test;

  Future<void> _sendTest() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _test = null;
    });
    final id = await ErrorReports.sendTest();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _test = (id: id == null ? null : ReportSwitch.shortId(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final available = ErrorReports.available;
    final reports = ReportSwitch.instance;
    Widget help(String text, {Color? color}) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100), child: Text(text, style: g.body(24, color: color ?? g.textDim)));

    return TvPage(
      title: tr.errorReports,
      hints: tr.moveOkSelectEscBack,
      onBack: () => Navigator.of(context).pop(),
      child: ListenableBuilder(
        listenable: reports,
        builder: (context, _) {
          final on = available && reports.on;
          final test = _test;
          return FocusTraversalGroup(
            child: ListView(
              padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 40, 100, 40)),
              children: [
                if (!available) ...[
                  help(tr.reportsNotInBuild, color: g.nowLine),
                  const SizedBox(height: 28),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TvToggle(
                    label: tr.sendErrorReportsFrom,
                    on: on,
                    autofocus: available,
                    onPressed: available ? () => ErrorReports.setOn(!reports.on) : null,
                  ),
                ),
                const SizedBox(height: 12),
                help(tr.errorReportsExplain),
                const SizedBox(height: 8),
                help(tr.errorReportsOff),
                const SizedBox(height: 40),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TvButton(
                    label: tr.sendATestReport,
                    icon: Icons.send,
                    // Stays enabled while sending, so focus stays put.
                    onPressed: on ? _sendTest : null,
                  ),
                ),
                const SizedBox(height: 18),
                if (test != null)
                  Text(test.id == null ? tr.testReportNotSent : tr.testReportSent(test.id!),
                      style: g.body(26, color: test.id == null ? g.nowLine : g.text))
                else if (available)
                  Text(reports.shortLastId == null ? tr.noReportSentYet : tr.lastReportId(reports.shortLastId!),
                      style: g.body(26, color: g.text)),
                if (test?.id != null || (test == null && available && reports.shortLastId != null)) ...[
                  const SizedBox(height: 8),
                  help(tr.quoteReportId),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
