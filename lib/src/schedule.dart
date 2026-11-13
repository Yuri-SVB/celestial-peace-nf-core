import 'card.dart';
import 'clock.dart';
import 'params.dart';

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
/// Easy ×EF×1.3 ([Sm2Params]).
///
/// **Practice is not graded** (cpnf-maintenance-bundles.md §1): while a map
/// still shows landmark stops, an attempt leaves its SM-2 state untouched.
///
/// [MemSchedule] is **pure given a [Clock]**: every time read goes through the
/// clock, so it is fully deterministic under a [FakeClock].
class MemSchedule {
  const MemSchedule(
    this.clock, {
    this.sm2 = const Sm2Params(),
    this.consolidation = const ConsolidationParams(),
    this.reminders = const ReminderParams(),
  });

  final Clock clock;
  final Sm2Params sm2;
  final ConsolidationParams consolidation;
  final ReminderParams reminders;

  // SM-2's E-Factor update, `EF + (base - (top-q)(linear + (top-q)quadratic))`,
  // and its passing qualities: the reference's constants.
  static const double _efBase = 0.1;
  static const double _efLinear = 0.08;
  static const double _efQuadratic = 0.02;
  static const int _qualityTop = 5;
  static const int _qualityHard = 3;
  static const int _qualityGood = 4;
  static const int _qualityEasy = 5;

  /// Grade [card] with [g] and return the advanced card (never mutates
  /// [card]). A card that is not graded ([MemCard.isGraded]: a map still
  /// showing stops) comes back unchanged: the attempt was practice.
  MemCard grade(MemCard card, Grade g) {
    if (!card.isGraded) return card;
    if (g == Grade.again) {
      // SM-2 step 4: a failure restarts repetitions and leaves EF unchanged.
      // Deviation from the reference is intervals only — see class doc.
      return card.copyWith(
        repetitions: 0,
        intervalDays: sm2.lapseIntervalDays,
        lapses: card.lapses + 1,
        due: _dueIn(sm2.lapseIntervalDays),
      );
    }

    final double ef = _updatedEase(card.easeFactor, _quality(g));

    final int interval;
    if (card.repetitions == 0) {
      interval = sm2.firstIntervalDays; // SM-2 I(1).
    } else if (card.repetitions == 1) {
      interval = sm2.secondIntervalDays; // SM-2 I(2).
    } else {
      // DEVIATION FROM SM-2 (per brief §3): per-grade multiplier instead of the
      // reference's uniform ×EF, for four-button conservative scheduling.
      final double factor = switch (g) {
        Grade.hard => sm2.hardFactor,
        Grade.good => ef,
        Grade.easy => ef * sm2.easyBonus,
        Grade.again => throw StateError('handled above'),
      };
      final int next = (card.intervalDays * factor).round();
      interval = next < sm2.firstIntervalDays ? sm2.firstIntervalDays : next;
    }

    return card.copyWith(
      easeFactor: ef,
      repetitions: card.repetitions + 1,
      intervalDays: interval,
      due: _dueIn(interval),
    );
  }

  /// Cards due at `clock.now()`, oldest-due first (never-graded cards, having
  /// no `due`, sort first). cpnf-step1-scheduler.md §2 / acceptance §6.4.
  /// Maps still showing stops are never graded, so they are always here:
  /// practice is welcome at any time.
  ReviewQueue queue(List<MemCard> cards) {
    final DateTime now = clock.now();
    final List<MemCard> due = cards.where((MemCard c) => c.isDue(now)).toList();
    due.sort((MemCard a, MemCard b) {
      if (a.due == null && b.due == null) return 0;
      if (a.due == null) return -1; // never graded: most overdue
      if (b.due == null) return 1;
      return a.due!.compareTo(b.due!);
    });
    return ReviewQueue(due);
  }

  /// Whether [card] is consolidated ([ConsolidationParams]): graded, with a
  /// long enough interval and run of successes.
  bool consolidated(MemCard card) =>
      card.isGraded &&
      card.intervalDays >= consolidation.minIntervalDays &&
      card.repetitions >= consolidation.minRepetitions;

  /// When to remind the user next, given the last reminder: at most
  /// [ReminderParams.maxGap] later, sooner if a graded card falls due in
  /// between. A card already overdue at the last reminder does not bring the
  /// next one forward. No clock read.
  DateTime nextReminder(List<MemCard> cards, DateTime lastReminder) {
    DateTime next = lastReminder.add(reminders.maxGap);
    for (final MemCard c in cards) {
      final DateTime? d = c.due;
      if (c.isGraded &&
          d != null &&
          d.isAfter(lastReminder) &&
          d.isBefore(next)) {
        next = d;
      }
    }
    return next;
  }

  // --- SM-2 internals -------------------------------------------------------

  /// Map the passing grades to an SM-2 quality (3/4/5, the range over which
  /// the reference EF update is defined); [Grade.again] is a failure and is
  /// handled before this is ever called.
  int _quality(Grade g) => switch (g) {
        Grade.hard => _qualityHard,
        Grade.good => _qualityGood,
        Grade.easy => _qualityEasy,
        Grade.again => throw StateError('a failure has no passing quality'),
      };

  /// Canonical SM-2 E-Factor update, floored at [Sm2Params.minEase].
  double _updatedEase(double ef, int q) {
    final int miss = _qualityTop - q;
    final double next =
        ef + (_efBase - miss * (_efLinear + miss * _efQuadratic));
    return next < sm2.minEase ? sm2.minEase : next;
  }

  DateTime _dueIn(int days) => clock.now().add(Duration(days: days));
}
