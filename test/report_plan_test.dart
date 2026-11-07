import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/schedule.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';
import 'package:nightingale_tv/library/library_index.dart';
import 'package:nightingale_tv/playback/report_plan.dart';

void main() {
  const episode = MediaEntry(id: 'ep', kind: MediaKind.episode, title: 'Ep', runtime: Duration(minutes: 22));
  const ad = MediaEntry(id: 'reel@47000', kind: MediaKind.commercial, title: 'Ad', runtime: Duration(seconds: 30));
  final slot = DateTime(2026, 10, 17, 18);

  ScheduledProgram part(int fromMin, int toMin, {DateTime? layoutStart}) => ScheduledProgram(
        item: episode,
        start: slot.add(Duration(minutes: fromMin + 1)),
        end: slot.add(Duration(minutes: toMin + 1)),
        layoutStart: layoutStart ?? slot,
        itemFrom: Duration(minutes: fromMin),
      );

  ScheduledProgram commercial({DateTime? layoutStart, MediaEntry program = episode}) => ScheduledProgram(
        item: ad,
        start: slot.add(const Duration(minutes: 8)),
        end: slot.add(const Duration(minutes: 8, seconds: 30)),
        layoutStart: layoutStart ?? slot,
        role: BreakRole.mid,
        program: program,
        itemFrom: const Duration(seconds: 47),
      );

  test('the parts of a program and its breaks are one viewing', () {
    final first = part(0, 7);
    expect(reportStep(null, 'ch', first), ReportStep.start);
    final viewing = viewingOf('ch', first)!;
    expect(reportStep(viewing, 'ch', commercial()), ReportStep.keep);
    expect(reportStep(viewing, 'ch', part(7, 14)), ReportStep.keep);
  });

  test('commercials are never a viewing of their own', () {
    expect(viewingOf('ch', commercial()), isNull);
    expect(reportStep(null, 'ch', commercial()), ReportStep.none);
    // Even played outside a break, a commercial item is never reported.
    final loose = ScheduledProgram(item: ad, start: slot, end: slot.add(const Duration(seconds: 30)));
    expect(viewingOf('ch', loose), isNull);
  });

  test('songs and music videos are never reported', () {
    for (final kind in [MediaKind.song, MediaKind.musicVideo]) {
      final music = ScheduledProgram(
          item: MediaEntry(id: 'm', kind: kind, title: 'Song', runtime: const Duration(minutes: 4)),
          start: slot,
          end: slot.add(const Duration(minutes: 4)));
      expect(viewingOf('radio', music), isNull, reason: kind.name);
      expect(reportStep(null, 'radio', music), ReportStep.none);
      // A song after a show ends the show's viewing and starts none.
      expect(reportStep(viewingOf('ch', part(0, 22)), 'ch', music), ReportStep.finish);
    }
  });

  test('a new slot, or another channel, ends the viewing', () {
    final viewing = viewingOf('ch', part(0, 7))!;
    final nextSlot = slot.add(const Duration(minutes: 30));
    expect(reportStep(viewing, 'ch', part(0, 7, layoutStart: nextSlot)), ReportStep.finishAndStart,
        reason: 'the same episode again later is a new viewing');
    expect(reportStep(viewing, 'other', part(0, 7)), ReportStep.finishAndStart);
    expect(reportStep(viewing, 'ch', commercial(layoutStart: nextSlot)), ReportStep.finish);
    expect(reportStep(viewing, 'ch', ScheduledProgram(item: null, start: slot, end: slot)), ReportStep.finish,
        reason: 'off the air');
  });

  test('watched to the end counts as watched; a partial viewing reports the resume point from before it', () {
    expect(stoppedPosition(episode, const Duration(minutes: 22)), const Duration(minutes: 22));
    expect(stoppedPosition(episode, const Duration(minutes: 20)), const Duration(minutes: 20),
        reason: 'missing only the end credits');
    expect(stoppedPosition(episode, const Duration(minutes: 14)), Duration.zero, reason: 'no resume point');
    const five = Duration(minutes: 5);
    expect(stoppedPosition(episode, const Duration(seconds: 30), resumePoint: five), five,
        reason: 'a glimpse keeps the resume point made elsewhere');
    expect(stoppedPosition(episode, const Duration(minutes: 14), resumePoint: five), five,
        reason: 'even past it, a partial viewing never moves it');
    expect(stoppedPosition(episode, const Duration(minutes: 21), resumePoint: five), const Duration(minutes: 21),
        reason: 'watched: reported where it got to');
    expect(stoppedPosition(episode, const Duration(minutes: 21), resumePoint: five, cut: true), five,
        reason: 'Truncate cut it: never watched');
    expect(stoppedPosition(episode, const Duration(minutes: 21), cut: true), Duration.zero);
  });
}
