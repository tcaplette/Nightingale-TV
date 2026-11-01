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
            prePool: 'bumpers',
            midPool: 'ads',
            postPool: 'ads',
            tailPool: 'promos',
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

    test('a saved plan with a fallback loads with it ignored, and saves without it', () {
      final plan = BreakPlan.fromJson({
        'mode': 'custom',
        'roles': {
          'preMs': 30000,
          'midIntervalMs': 480000,
          'midMs': 90000,
          'postMs': 120000,
          'tailMs': 1800000,
          'fallback': 'idCard',
          'pools': {'pre': 'bumpers', 'mid': 'ads', 'fallback': 'bumpers'},
        },
      });
      expect(
          plan,
          const BreakPlan(
            mode: BreakMode.custom,
            roles: CustomRoles(
              preRoll: Duration(seconds: 30),
              midInterval: Duration(minutes: 8),
              midLength: Duration(seconds: 90),
              postRoll: Duration(minutes: 2),
              tailGrid: Duration(minutes: 30),
              prePool: 'bumpers',
              midPool: 'ads',
            ),
          ));
      final saved = plan.toJson()['roles'] as Map<String, Object?>;
      expect(saved.containsKey('fallback'), isFalse);
      expect((saved['pools'] as Map).containsKey('fallback'), isFalse);
      expect(BreakPlan.fromJson({'mode': 'custom', 'roles': {'fallback': 'pool'}}).poolsUsed, isEmpty);
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
    Iterable<Duration> breaks(SlotPlan s) => [s.preRoll, for (var i = 0; i < s.midCount; i++) s.midLength, s.postRoll];

    test('22-minute sitcom: a half-hour slot, as before', () {
      final s = resolve(BreakPlan.automatic, _min(22));
      expect(s.slotLength, _min(30));
      expect(s.preRoll, const Duration(seconds: 15));
      expect(s.midCount, 2);
      expect(s.midLength, _min(3));
      expect(s.postRoll, _min(1.75));
      expect(s.tail, Duration.zero);
    });

    test('a show just under the half hour shrinks its ads to fit', () {
      // Californication: 28.2 minutes, 1.8 minutes of ads.
      final s = resolve(BreakPlan.automatic, _min(28.2));
      expect(s.slotLength, _min(30));
      expect(s.adTime, _min(1.8));
      expect(s.preRoll, const Duration(seconds: 15));
      expect(s.midCount, 2);
      expect(s.midLength, const Duration(seconds: 30));
      expect(s.postRoll, const Duration(seconds: 33));
    });

    test('a show just over the half hour gets the quarter hour, not the hour', () {
      final s = resolve(BreakPlan.automatic, _min(31));
      expect(s.slotLength, _min(45));
      expect(s.adTime, _min(14));
      expect(breaks(s), everyElement(lessThanOrEqualTo(_min(5))));
    });

    test('little ad time: fewer mid-rolls, each at least 30 s', () {
      // A 118-minute movie in a 120-minute slot.
      final s = resolve(BreakPlan.automatic, _min(118));
      expect(s.slotLength, _min(120));
      expect(s.preRoll, const Duration(seconds: 15));
      expect(s.midCount, 2);
      expect(s.midLength, const Duration(seconds: 30));
      expect(s.postRoll, const Duration(seconds: 45));
    });

    test('100-minute movie: a long post-roll is spread over the mid-rolls', () {
      final s = resolve(BreakPlan.automatic, _min(100));
      expect(s.midCount, 8);
      expect(s.slotLength, _min(120));
      // 19:45 of ads after the pre-roll; 80 % over 8 breaks is 1:58.5,
      // rounded down to 1:45, which would leave a 5:45 post-roll.
      expect(s.midLength, _min(2));
      expect(s.postRoll, _min(3.75));
    });

    test('short programs: the quarter hour, then the 5-minute grid', () {
      final s = resolve(BreakPlan.automatic, _min(11));
      expect(s.midCount, 1);
      expect(s.slotLength, _min(15));
      expect(resolve(BreakPlan.automatic, _min(12)).slotLength, _min(15));
      // 15 minutes would mean an 8-minute post-roll.
      expect(resolve(BreakPlan.automatic, _min(7)).slotLength, _min(10));
      // 16 minutes: the half hour and the quarter hour both break the limit.
      expect(resolve(BreakPlan.automatic, _min(16)).slotLength, _min(20));
    });

    test('no grid keeps the limit: mid-rolls are added on the 5-minute grid', () {
      // 4:40 + 30 s rounds up to 10 minutes: 5:20 of ads, and no mid-roll.
      final s = resolve(BreakPlan.automatic, _min(4) + const Duration(seconds: 40));
      expect(s.slotLength, _min(10));
      expect(s.midCount, 1);
      expect(breaks(s), everyElement(lessThanOrEqualTo(_min(5))));
    });

    test('every runtime from 1 to 180 minutes keeps every break within 5 minutes', () {
      for (var ms = 60000; ms <= 180 * 60000; ms += 6000) {
        final runtime = Duration(milliseconds: ms);
        final s = resolve(BreakPlan.automatic, runtime);
        final why = '$runtime';
        expect(breaks(s), everyElement(lessThanOrEqualTo(_min(5))), reason: why);
        expect(breaks(s), everyElement(greaterThanOrEqualTo(Duration.zero)), reason: why);
        if (s.midCount > 0) expect(s.midLength, greaterThanOrEqualTo(const Duration(seconds: 30)), reason: why);
        expect(s.midLength.inMilliseconds % 15000, 0, reason: why);
        expect(s.slotLength, greaterThanOrEqualTo(runtime + const Duration(seconds: 30)), reason: why);
        expect(s.slotLength.inMilliseconds % (5 * 60000), 0, reason: why);
        expect(s.slotLength, s.runtime + s.preRoll + s.midLength * s.midCount + s.postRoll, reason: why);
        expect(resolve(BreakPlan.automatic, runtime).slotLength, s.slotLength, reason: why);
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

  group('bumper settings', () {
    final roles = const CustomRoles(midInterval: Duration(minutes: 10)).withBumpers('idents');

    test('are carried by every copy, and round-trip through JSON', () {
      expect(roles.copyWith(postRoll: const Duration(minutes: 1)).bumperPool, 'idents');
      expect(roles.withPool(BreakRole.mid, 'ads').bumperPool, 'idents');
      final none = roles.withBumpers(null, none: true);
      expect((none.bumperPool, none.noBumpers), (null, true));
      expect(none.copyWith(postRoll: const Duration(minutes: 1)).noBumpers, isTrue);
      expect(none.withPool(BreakRole.mid, 'ads').noBumpers, isTrue);
      expect(CustomRoles.fromJson(roles.toJson()), roles);
      expect(CustomRoles.fromJson(none.toJson()), none);
      expect(roles == none, isFalse);
      expect(roles.hashCode == const CustomRoles(midInterval: Duration(minutes: 10)).hashCode, isFalse);
    });

    test('old saves load with all bumper pools', () {
      final old = CustomRoles.fromJson({'preMs': 0, 'pools': <String, Object?>{}});
      expect((old.bumperPool, old.noBumpers), (null, false));
      expect(const CustomRoles().toJson().containsKey('noBumpers'), isFalse);
      expect((const CustomRoles().toJson()['pools'] as Map), isEmpty);
    });

    test('withoutPool clears a matching bumper pool, and poolsUsed ignores it', () {
      expect(roles.withoutPool('idents').bumperPool, isNull);
      expect(roles.withoutPool('other').bumperPool, 'idents');
      expect(BreakPlan(mode: BreakMode.custom, roles: roles).poolsUsed, {null});
    });
  });
}
