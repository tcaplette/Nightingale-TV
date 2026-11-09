import 'package:flutter/material.dart';

import '../playback/sleep_timer.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// The picker's label for [choice]; [programEnd] is when the program on
/// screen ends, if known.
String sleepChoiceLabel(SleepChoice choice, {DateTime? programEnd}) {
  if (choice.isOff) return tr.off;
  if (choice.atProgramEnd) {
    return programEnd == null ? tr.endOfThisProgram : tr.endOfThis(formatTime(programEnd));
  }
  return tr.min('${choice.minutes}');
}

/// Said under "End of this program" when it can't be chosen.
String get sleepNoEndNote => tr.whatsOnNow;

/// The sleep timer's line while one is set: "Sleep in 23 min" or "Sleep at
/// end of program" (the banner, design D3). Null with no timer.
String? sleepLine(SleepTimer? timer) {
  if (timer == null || !timer.armed) return null;
  if (timer.choice.atProgramEnd && timer.phase == SleepPhase.armed) return tr.sleepAtEnd;
  return tr.sleepInMin(timer.minutesLeft ?? 1);
}

/// The sleep timer picker (design D2): Off, End of this program and the
/// minute timers, focus on the current choice. Choosing sets [timer], which
/// says so in a toast, and closes the picker. True when a row was chosen.
Future<bool> showSleepPicker(BuildContext context, SleepTimer timer) async {
  final chosen = await showDialog<SleepChoice>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      final end = timer.programEnd(choosing: true);
      final current = timer.armed ? timer.choice : SleepChoice.off;
      final left = timer.minutesLeft;
      return Dialog(
        backgroundColor: g.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(g.radius * 2),
          side: BorderSide(color: g.cellBorder, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding(context)),
          child: SizedBox(
            width: dialogWidth(context, 720, padding: dialogPadding(context)),
            child: dialogBody(
              context,
              FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(left == null ? tr.sleepTimer : tr.sleepTimerMin(left),
                        style: g.display(48, weight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    for (final choice in SleepChoice.all) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TvToggle(
                          label: sleepChoiceLabel(choice, programEnd: end),
                          radio: true,
                          on: choice == current,
                          // Focus on the current choice; Off when it can't be
                          // chosen any more.
                          autofocus: choice == current && (!choice.atProgramEnd || end != null) ||
                              choice.isOff && current.atProgramEnd && end == null,
                          onPressed: choice.atProgramEnd && end == null ? null : () => Navigator.pop(context, choice),
                        ),
                      ),
                      if (choice.atProgramEnd && end == null)
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 4),
                          child: Text(sleepNoEndNote, style: g.body(24, color: g.textDim)),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  if (chosen == null) return false;
  timer.choose(chosen);
  return true;
}
