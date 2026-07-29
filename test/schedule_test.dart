import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';
import 'package:test/test.dart';

/// CPNF Step 1 scheduler tests (cpnf-step1-scheduler.md §6). Pure Dart with a
/// FakeClock — fully deterministic, no wall clock.
void main() {
  final DateTime day0 = DateTime(2026, 1, 1);

  MemCard point() => const MemSchedule(_FixedClock())
      .freshCard(id: 'point:0', kind: CardKind.point);

  group('interval ladder + per-grade multipliers', () {
    test('Good: 1d -> 6d -> round(6*EF), EF steady at 2.5', () {
      final FakeClock clock = FakeClock(day0);
      final MemSchedule s = MemSchedule(clock);
      MemCard c = point();

      c = s.grade(c, Grade.good);
      expect(c.repetitions, 1);
      expect(c.intervalDays, 1);
      expect(c.easeFactor, closeTo(2.5, 1e-9));
      expect(c.due, DateTime(2026, 1, 2));

      c = s.grade(c, Grade.good);
      expect(c.repetitions, 2);
      expect(c.intervalDays, 6);
      expect(c.due, DateTime(2026, 1, 7));

      c = s.grade(c, Grade.good);
      expect(c.repetitions, 3);
      expect(c.intervalDays, 15); // round(6 * 2.5)
      expect(c.easeFactor, closeTo(2.5, 1e-9));
    });

    test('from a rep>=2 card, Hard ×1.2 / Good ×EF / Easy ×EF×1.3', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      const MemCard base = MemCard(
        id: 'point:0',
        kind: CardKind.point,
        easeFactor: 2.5,
        repetitions: 2,
        intervalDays: 6,
      );

      final MemCard hard = s.grade(base, Grade.hard);
      expect(hard.intervalDays, 7); // round(6 * 1.2)
      expect(hard.easeFactor, closeTo(2.36, 1e-9)); // 2.5 - 0.14

      final MemCard good = s.grade(base, Grade.good);
      expect(good.intervalDays, 15); // round(6 * 2.5)
      expect(good.easeFactor, closeTo(2.5, 1e-9)); // unchanged at q=4

      final MemCard easy = s.grade(base, Grade.easy);
      expect(easy.easeFactor, closeTo(2.6, 1e-9)); // 2.5 + 0.1
      expect(easy.intervalDays, 20); // round(6 * 2.6 * 1.3) = round(20.28)
    });
  });

  group('EF update + floor', () {
    test('EF floors at 1.3 under repeated Hard', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      MemCard c = point();
      for (int i = 0; i < 20; i++) {
        c = s.grade(c, Grade.hard);
      }
      expect(c.easeFactor, MemSchedule.minEase);
    });
  });

  group('lapse (Again)', () {
    test('resets interval/reps, bumps lapses, and — per SM-2 — keeps EF', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      const MemCard mature = MemCard(
        id: 'point:0',
        kind: CardKind.point,
        easeFactor: 2.10,
        repetitions: 4,
        intervalDays: 40,
        lapses: 1,
      );
      final MemCard lapsed = s.grade(mature, Grade.again);
      expect(lapsed.repetitions, 0);
      expect(lapsed.intervalDays, 1);
      expect(lapsed.lapses, 2);
      expect(lapsed.easeFactor, closeTo(2.10, 1e-9),
          reason: 'SM-2 step 4: a failure does not change the E-Factor');
      expect(lapsed.due, DateTime(2026, 1, 2));
    });
  });

  group('queue (due filter + ordering)', () {
    test('returns only due cards, new-first then oldest-due; tracks the clock',
        () {
      final FakeClock clock = FakeClock(day0);
      final MemSchedule s = MemSchedule(clock);
      final MemCard overdue = const MemCard(id: 'point:0', kind: CardKind.point)
          .copyWith(
              due: DateTime(2025, 12, 31), repetitions: 1, intervalDays: 1);
      final MemCard future = const MemCard(id: 'point:1', kind: CardKind.point)
          .copyWith(due: DateTime(2026, 1, 6), repetitions: 1, intervalDays: 5);
      final MemCard fresh = s.freshCard(id: 'point:2', kind: CardKind.point);

      final ReviewQueue q0 = s.queue(<MemCard>[future, overdue, fresh]);
      expect(q0.due.map((MemCard c) => c.id).toList(),
          <String>['point:2', 'point:0'],
          reason: 'new (null due) first, then the overdue one; future excluded');

      clock.advance(const Duration(days: 5)); // now 2026-01-06
      final ReviewQueue q1 = s.queue(<MemCard>[future, overdue, fresh]);
      expect(q1.due.map((MemCard c) => c.id).toList(),
          <String>['point:2', 'point:0', 'point:1'],
          reason: 'advancing the clock makes the future card due');
    });
  });

  group('freshCard + deck builder', () {
    test('freshCard is new and due now', () {
      final MemCard c = point();
      expect(c.isNew, isTrue);
      expect(c.isDue(day0), isTrue);
      expect(c.intervalDays, 0);
      expect(c.repetitions, 0);
      expect(c.easeFactor, 2.5);
    });

    test('buildDeck: N point cards + the fact cards', () {
      final List<MemCard> deck = buildDeck(
        stageCount: 3,
        exportSalts: <String>['signing-1'],
        misc: <String>['anniversary'],
      );
      final List<MemCard> points =
          deck.where((MemCard c) => c.kind == CardKind.point).toList();
      final List<String> facts = deck
          .where((MemCard c) => c.kind == CardKind.fact)
          .map((MemCard c) => c.factId)
          .toList();
      expect(points.length, 3);
      expect(points.map((MemCard c) => c.stageIndex).toList(), <int>[0, 1, 2]);
      expect(facts, containsAll(<String>['m', 'N', 'D', 'salt', 'provenance']));
      expect(facts, contains('export:signing-1'));
      expect(facts, contains('misc:anniversary'));
    });
  });
}

/// A trivial fixed clock for constructing a bare [MemSchedule] where time is
/// irrelevant (only `freshCard`, which doesn't read the clock, is used).
class _FixedClock implements Clock {
  const _FixedClock();
  @override
  DateTime now() => DateTime.utc(2000);
}
