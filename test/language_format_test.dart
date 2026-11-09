import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/channels/program_block.dart';
import 'package:nightingale_tv/l10n/tr.dart';
import 'package:nightingale_tv/ui/format.dart';

void main() {
  final evening = DateTime(2026, 10, 18, 19, 30);
  final later = DateTime(2026, 10, 18, 20);
  final moment = DateTime(2026, 10, 18, 21, 5);
  T inLang<T>(String l, T Function() f) => runInLanguage(l, f);

  group('English stays exactly as it was', () {
    test('every format', () {
      expect(formatTime(evening), '7:30 PM');
      expect(formatTime(evening, withPeriod: false), '7:30');
      expect(formatRange(evening, later), '7:30 – 8:00 PM');
      expect(formatRange(DateTime(2026, 1, 1, 11, 30), DateTime(2026, 1, 1, 12, 15)), '11:30 AM – 12:15 PM');
      expect(formatDate(evening), 'SUN OCT 18');
      expect(formatMoment(moment), 'Oct 18, 9:05 PM');
      expect(formatRecent(moment, now: moment), 'today 9:05 PM');
      expect(formatRecent(moment, now: moment.add(const Duration(days: 1))), 'yesterday 9:05 PM');
      expect(formatMinutes(const Duration(seconds: 20)), 'under a minute');
      expect(formatMinutes(const Duration(minutes: 22)), '22 min');
      expect(formatMinutes(const Duration(minutes: 60)), '1 hr');
      expect(formatMinutes(const Duration(minutes: 65)), '1 hr 5 min');
      expect(formatClockMinute(7 * 60), '7:00 AM');
      expect(formatBehind(const Duration(minutes: 12, seconds: 34)), '12:34 behind');
      expect(weekdayName(1), 'Mon');
      expect(monthName(12), 'Dec');
      expect(const MonthDay(12, 1).toString(), 'Dec 1');
      expect(describeDays({1, 3, 5}), 'Mon, Wed, Fri');
    });
  });

  group('the five other languages use 24-hour time and the day first', () {
    for (final language in ['de', 'fr', 'es', 'pt', 'it']) {
      test(language, () {
        inLang(language, () {
          expect(formatTime(evening), '19:30');
          expect(formatRange(evening, later), '19:30 – 20:00');
          expect(formatMoment(moment), allOf(contains('21:05'), startsWith('18')));
          expect(formatDate(evening), allOf(contains('18'), isNot(contains('.  '))));
          expect(formatMonthDay(10, 18), startsWith('18'));
        });
      });
    }

    test('month and weekday names are the language\'s', () {
      expect(inLang('fr', () => formatMoment(moment)), startsWith('18 oct'));
      expect(inLang('fr', () => formatMoment(moment)), contains('21:05'));
      expect(inLang('de', () => formatDate(evening)), 'SO 18. OKT');
      expect(inLang('it', () => monthName(10)), 'Ott');
      expect(inLang('es', () => weekdayName(7)), 'Dom');
    });
  });
}
