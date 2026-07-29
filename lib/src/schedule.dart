import 'clock.dart';
import 'card.dart';

/// CPNF spaced-repetition scheduler (cpnf-step1-scheduler.md §3).
///
/// Conservative **SM-2** (P. A. Woźniak, *Optimization of learning* /
/// SuperMemo, 1990) — cite the source, do not paraphrase from memory:
///   https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
///
/// Two things are canonical SM-2 and must stay faithful to that reference:
///   * the E-Factor update `EF' = max(1.3, EF + (0.1 - (5-q)(0.08 + (5-q)0.02)))`;
///   * SM-2 step 4: on a failure (`q < 3`) repetitions restart *without changing
///     the E-Factor* — so a lapse resets the interval but leaves `EF` untouched.
///
/// One thing is a **deliberate deviation from canonical SM-2**, taken from the
/// brief (§3) to get four-button grading and a conservative (more-frequent)
/// schedule: instead of always growing by `EF`, passing grades apply per-grade
/// multipliers once past the fixed 1-day / 6-day rungs — Hard ×1.2, Good ×EF,
/// Easy ×EF×1.3. This is commented wherever it appears so it is never mistaken
/// for the reference algorithm.
///
/// [MemSchedule] is **pure given a [Clock]**: every time read goes through the
/// clock, so it is fully deterministic under a [FakeClock].
class MemSchedule {
  const MemSchedule(this.clock);

  final Clock clock;

  /// SM-2 lower bound on the E-Factor.
  static const double minEase = 1.3;

  /// Grade [card] with [g] and return the advanced card (never mutates [card]).
  MemCard grade(MemCard card, Grade g) {
    if (g == Grade.again) {
      // SM-2 step 4: a failure restarts repetitions and leaves EF unchanged.
      // Deviation from the reference is intervals only — see class doc.
      return card.copyWith(
        repetitions: 0,
        intervalDays: 1,
        lapses: card.lapses + 1,
        due: _dueIn(1),
      );
    }

    final int q = _quality(g); // 3 = hard, 4 = good, 5 = easy
    final double ef = _updatedEase(card.easeFactor, q);

    final int interval;
    if (card.repetitions == 0) {
      interval = 1; // first success — fixed rung (SM-2 I(1)).
    } else if (card.repetitions == 1) {
      interval = 6; // second consecutive success — fixed rung (SM-2 I(2)).
    } else {
      // DEVIATION FROM SM-2 (per brief §3): per-grade multiplier instead of the
      // reference's uniform ×EF, for four-button conservative scheduling.
      final double factor = switch (g) {
        Grade.hard => 1.2,
        Grade.good => ef,
        Grade.easy => ef * 1.3,
        Grade.again => 1.0, // unreachable (handled above)
      };
      final int next = (card.intervalDays * factor).round();
      interval = next < 1 ? 1 : next;
    }

    return card.copyWith(
      easeFactor: ef,
      repetitions: card.repetitions + 1,
      intervalDays: interval,
      due: _dueIn(interval),
    );
  }

  /// Cards due at `clock.now()`, oldest-due first (new cards, having no `due`,
  /// sort first). cpnf-step1-scheduler.md §2 / acceptance §6.4.
  ReviewQueue queue(List<MemCard> cards) {
    final DateTime now = clock.now();
    final List<MemCard> due =
        cards.where((MemCard c) => c.isDue(now)).toList();
    due.sort((MemCard a, MemCard b) {
      if (a.due == null && b.due == null) return 0;
      if (a.due == null) return -1; // never-reviewed: most overdue
      if (b.due == null) return 1;
      return a.due!.compareTo(b.due!);
    });
    return ReviewQueue(due);
  }

  /// A brand-new card: interval 0, never reviewed, so it is due now (a null
  /// `due` reads as due — see [MemCard.isDue]).
  MemCard freshCard({
    required String id,
    required CardKind kind,
    int stageIndex = -1,
    String factId = '',
  }) =>
      MemCard(
        id: id,
        kind: kind,
        stageIndex: stageIndex,
        factId: factId,
      );

  // --- SM-2 internals -------------------------------------------------------

  /// Map the four UI grades to an SM-2 quality. Passing grades are 3/4/5 (the
  /// range over which the reference EF update is defined); [Grade.again] is a
  /// failure and is handled before this is ever called.
  int _quality(Grade g) => switch (g) {
        Grade.hard => 3,
        Grade.good => 4,
        Grade.easy => 5,
        Grade.again => 0, // unreachable
      };

  /// Canonical SM-2 E-Factor update, floored at [minEase].
  double _updatedEase(double ef, int q) {
    final double next = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    return next < minEase ? minEase : next;
  }

  DateTime _dueIn(int days) => clock.now().add(Duration(days: days));
}
