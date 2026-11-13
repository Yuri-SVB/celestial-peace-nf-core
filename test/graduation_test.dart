import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';
import 'package:test/test.dart';

void main() {
  group('failure chance', () {
    test('certain recalls and none needed', () {
      expect(failureChance(<double>[1, 1, 0], 2), 0);
      expect(failureChance(<double>[0, 0], 0), 0);
      expect(failureChance(<double>[0, 0], 1), 1);
    });

    test('two maps at 90%, both needed: 19%', () {
      expect(failureChance(<double>[0.9, 0.9], 2), closeTo(0.19, 1e-12));
    });

    test('more maps lower the chance of falling short', () {
      final double three = failureChance(<double>[0.9, 0.9, 0.9], 2);
      final double nine = failureChance(List<double>.filled(9, 0.9), 2);
      expect(three, closeTo(0.028, 1e-12)); // 1 - (0.729 + 3·0.081)
      expect(nine, lessThan(three));
    });
  });

  group('the gate', () {
    final DateTime day0 = DateTime.utc(2026, 1, 1);
    const Cues unaided = Cues(rhoNum: 1, rhoDen: 2, exponent: 2, visible: 0);

    MemCard graded(MemSchedule s, int slot, int intervalDays, DateTime now) =>
        MemCard.map(0, slot, unaided).copyWith(
          intervalDays: intervalDays,
          due: now.add(Duration(days: intervalDays)),
        );

    test('r_i maps recalled very well pass; more recalled less well can too',
        () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final DateTime gap = day0.add(const Duration(days: 7));
      // Two maps with long intervals: each above 99.6% after a week.
      final Deck few = Deck(<MemCard>[
        graded(s, 1, 3650, day0),
        graded(s, 2, 3650, day0),
      ]);
      // Nine maps with shorter intervals.
      final Deck many = Deck(<MemCard>[
        for (int j = 1; j <= 9; j++) graded(s, j, 120, day0),
      ]);
      final StageGate a = graduationGates(few, <int>[2], gap, s).single;
      final StageGate b = graduationGates(many, <int>[2], gap, s).single;
      expect(a.passes, isFalse, reason: 'two maps: ${a.failure}');
      expect(b.passes, isTrue, reason: 'nine maps: ${b.failure}');
      expect(
          graduationGates(few, <int>[2], gap, s,
                  params: const GraduationParams(epsilon: 1e-2))
              .single
              .passes,
          isTrue);
    });

    test('maps never graded, or practised with stops, count as forgotten', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final Deck deck = Deck(<MemCard>[
        MemCard.map(0, 1, unaided),
        MemCard.map(0, 2, const Cues(rhoNum: 1, rhoDen: 2, exponent: 2))
            .copyWith(intervalDays: 3650, due: day0),
      ]);
      final StageGate g = graduationGates(deck, <int>[2], day0, s).single;
      expect(g.failure, 1);
      expect(g.passes, isFalse);
      expect(g.maps, 2);
    });
  });
}
