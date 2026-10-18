import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/commercials/break_plan.dart';

Duration _min(num m) => Duration(milliseconds: (m * 60000).round());

void main() {
  group('JSON', () {
    test('every mode and setting round-trips', () {
      const plans = [
        BreakPlan.off,
        BreakPlan.automatic,
        BreakPlan.legacy,
        BreakPlan(
          mode: BreakMode.custom,
          roles: CustomRoles(
            preRoll: Duration(seconds: 30),
            midInterval: Duration(minutes: 8),
            midLength: Duration(seconds: 90),
            postRoll: Duration(minutes: 4),
            tailGrid: Duration(minutes: 60),
            fallback: FallbackKind.pool,
            prePool: 'bumpers',
            midPool: 'ads',
            postPool: 'ads',
            tailPool: 'promos',
            fallbackPool: 'bumpers',
          ),
        ),
      ];
      for (final plan in plans) {
        final copy = BreakPlan.fromJson(plan.toJson());
        expect(copy, plan);
        expect(copy.hashCode, plan.hashCode);
      }
    });

    test('Custom settings survive while another mode is chosen', () {
      final custom = BreakPlan.legacy.withRoles(
          BreakPlan.legacy.roles.copyWith(midInterval: () => const Duration(minutes: 12)));
      final auto = BreakPlan.fromJson(custom.withMode(BreakMode.automatic).toJson());
      expect(auto.mode, BreakMode.automatic);
      expect(auto.withMode(BreakMode.custom), custom);
    });

    test('unknown or missing values fall back to defaults', () {
      final plan = BreakPlan.fromJson({'mode': 'someday'});
      expect(plan.mode, BreakMode.off);
      expect(plan.roles, const CustomRoles());
    });

    test('removing a pool switches its roles to all pools', () {
      const roles = CustomRoles(midPool: 'a', postPool: 'b', tailPool: 'a');
      final r = roles.withoutPool('a');
      expect(r.midPool, isNull);
      expect(r.tailPool, isNull);
      expect(r.postPool, 'b');
    });
  });

  group('Automatic', () {
    test('22-minute sitcom', () {
      final s = resolve(BreakPlan.automatic, _min(22));
      expect(s.slotLength, _min(30));
      expect(s.preRoll, const Duration(seconds: 15));
      expect(s.midCount, 2);
      expect(s.midLength, _min(3));
      expect(s.postRoll, _min(1.75));
      expect(s.tail, Duration.zero);
    });

    test('100-minute movie', () {
      final s = resolve(BreakPlan.automatic, _min(100));
      expect(s.midCount, 8);
      expect(s.slotLength, _min(120));
      // 19:45 of ads after the pre-roll; 80 % over 8 breaks is 1:58.5,
      // rounded down to 1:45.
      expect(s.midLength, _min(1.75));
      expect(s.postRoll, _min(19.75) - _min(1.75) * 8);
    });

    test('programs under 12 minutes use the 15-minute grid', () {
      final s = resolve(BreakPlan.automatic, _min(11));
      expect(s.midCount, 1);
      expect(s.slotLength, _min(15));
      expect(resolve(BreakPlan.automatic, _min(7)).slotLength, _min(15));
      expect(resolve(BreakPlan.automatic, _min(12)).slotLength, _min(30));
    });

    test('mid-rolls are never longer than 4 minutes, and always 15-second steps', () {
      for (var m = 1; m <= 200; m++) {
        final s = resolve(BreakPlan.automatic, _min(m));
        expect(s.midLength, lessThanOrEqualTo(_min(4)));
        expect(s.midLength.inMilliseconds % 15000, 0);
        expect(s.postRoll, greaterThanOrEqualTo(Duration.zero));
        expect(s.slotLength.inMinutes % 15, 0, reason: '$m min');
        expect(s.slotLength, s.runtime + s.preRoll + s.midLength * s.midCount + s.postRoll);
      }
    });

    test('programs over an hour break every 12 minutes', () {
      expect(resolve(BreakPlan.automatic, _min(60)).midCount, 5);
      expect(resolve(BreakPlan.automatic, _min(61)).midCount, 5);
      expect(resolve(BreakPlan.automatic, _min(73)).midCount, 6);
    });
  });

  group('Custom', () {
    test('mid-rolls on a long episode', () {
      const roles = CustomRoles(
        preRoll: Duration(seconds: 30),
        midInterval: Duration(minutes: 10),
        midLength: Duration(minutes: 2),
        postRoll: Duration(minutes: 1),
      );
      final s = resolve(const BreakPlan(mode: BreakMode.custom, roles: roles), _min(44));
      expect(s.midCount, 4);
      expect(s.midLength, _min(2));
      expect(s.tail, Duration.zero);
      expect(s.slotLength, _min(52) + roles.preRoll + roles.postRoll);
    });

    test('tail pads to the clock boundary', () {
      const plan = BreakPlan(
        mode: BreakMode.custom,
        roles: CustomRoles(
          preRoll: Duration(seconds: 30),
          postRoll: Duration(minutes: 1),
          tailGrid: Duration(minutes: 30),
        ),
      );
      final s = resolve(plan, _min(22));
      expect(s.midCount, 0);
      expect(s.slotLength, _min(30));
      expect(s.tail, _min(6.5));
    });

    test('one mid-roll fewer than runtime ÷ interval, rounded up', () {
      expect(midRollCount(_min(40), _min(10)), 3);
      expect(midRollCount(_min(41), _min(10)), 4);
      expect(midRollCount(_min(5), _min(10)), 0);
      expect(midRollCount(Duration.zero, _min(10)), 0);
    });

    test('the legacy plan pads to the quarter hour like before', () {
      for (final (m, slot) in [(22, 30), (30, 30), (31, 45), (95, 105)]) {
        final s = resolve(BreakPlan.legacy, _min(m));
        expect(s.slotLength, _min(slot));
        expect(s.preRoll + s.postRoll + s.midLength * s.midCount, Duration.zero);
      }
    });
  });

  test('Off leaves the program alone', () {
    final s = resolve(BreakPlan.off, _min(22));
    expect(s.slotLength, _min(22));
    expect(s.hasBreaks, isFalse);
  });

  test('pools used and alignment', () {
    expect(BreakPlan.off.poolsUsed, isEmpty);
    expect(BreakPlan.automatic.poolsUsed, {null});
    expect(BreakPlan.legacy.poolsUsed, {null});
    expect(
        const BreakPlan(mode: BreakMode.custom, roles: CustomRoles(preRoll: Duration(seconds: 15), prePool: 'b'))
            .poolsUsed,
        {'b'});
    expect(BreakPlan.automatic.alignment, _min(30));
    expect(BreakPlan.legacy.alignment, _min(15));
    expect(BreakPlan.off.alignment, isNull);
  });
}
