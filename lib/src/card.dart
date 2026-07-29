/// CPNF card / queue model (cpnf-step1-scheduler.md §2).
///
/// A **deck** is one setup's spaced-repetition state. It tracks a recall score
/// for each stage's *point* plus explicit *fact* cards (`m`, `D`, salt, export
/// salts, download provenance, misc reminders). This file is the pure data
/// model only — no time reads, no crypto, no Flutter.
///
/// SECURITY (cpnf-step1-scheduler.md §0): a [MemCard] holds ONLY SM-2 schedule
/// state and non-secret identity (`id`, `stageIndex`, `factId`). For a point
/// card the "answer" — the true point — is NOT stored here; it lives in the
/// encrypted setup and is read only to *validate* a recall attempt. Never put
/// bits, `(o, p, q)`, coordinates, or bisection paths on a card.
library;

/// How well the user recalled a card, mapped to an SM-2 quality in [MemSchedule].
enum Grade {
  /// Failed to locate the point / wrong fact — the card lapses.
  again,

  /// Located but slow / after many attempts.
  hard,

  /// Located with reasonable confidence.
  good,

  /// Located immediately.
  easy,
}

/// What a card drills.
enum CardKind {
  /// One stage's point recall; the stored (encrypted) point grades the attempt.
  point,

  /// Explicit fact recall: `m`, `N`, `D`, salt/pepper, export salts, provenance,
  /// miscellaneous reminders.
  fact,
}

/// Persisted per-card SM-2 state. Identity fields are immutable; the schedule
/// fields advance via [MemSchedule] (which returns a new card — it never mutates
/// in place). At rest the whole deck is encrypted with the setup's key
/// (cpnf-step1-scheduler.md §0.1); this class is the in-memory, decrypted form.
class MemCard {
  const MemCard({
    required this.id,
    required this.kind,
    this.stageIndex = -1,
    this.factId = '',
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.due,
    this.lapses = 0,
  });

  /// Stable identity, e.g. `"point:3"`, `"fact:m"`, `"fact:export:2"`.
  final String id;
  final CardKind kind;

  /// Stage this point card belongs to (`0..N-1`); `-1` for fact cards.
  final int stageIndex;

  /// Fact identifier for fact cards, e.g. `"m"`, `"N"`, `"D"`, `"salt"`,
  /// `"export:2"`, `"provenance"`, `"misc:anniversary"`. Empty for point cards.
  final String factId;

  /// SM-2 ease factor. Starts 2.5, floored at 1.3.
  final double easeFactor;

  /// Consecutive successful (non-lapse) reviews.
  final int repetitions;

  /// Current scheduled interval, in days.
  final int intervalDays;

  /// When the card is next due (computed via the injected `Clock`). Null means
  /// a brand-new card that has never been scheduled (treated as due now).
  final DateTime? due;

  /// Times the card has lapsed (been graded [Grade.again]).
  final int lapses;

  /// A never-reviewed card.
  bool get isNew => due == null;

  /// Whether this card is due at [now] (new cards are always due).
  bool isDue(DateTime now) => due == null || !due!.isAfter(now);

  MemCard copyWith({
    double? easeFactor,
    int? repetitions,
    int? intervalDays,
    DateTime? due,
    int? lapses,
  }) =>
      MemCard(
        id: id,
        kind: kind,
        stageIndex: stageIndex,
        factId: factId,
        easeFactor: easeFactor ?? this.easeFactor,
        repetitions: repetitions ?? this.repetitions,
        intervalDays: intervalDays ?? this.intervalDays,
        due: due ?? this.due,
        lapses: lapses ?? this.lapses,
      );

  /// Redacted: even the identity is deck-scoped state that should not leak into
  /// logs. (There are no secret fields here, but keep the no-logging habit.)
  @override
  String toString() => 'MemCard($id, ${kind.name}, <schedule>)';
}

/// The set of cards due for review at a given instant, oldest-due first
/// (cpnf-step1-scheduler.md §2). Built by [MemSchedule.queue].
class ReviewQueue {
  const ReviewQueue(this.due);

  /// Cards with `due <= clock.now()`, ordered oldest-due first (new cards, which
  /// have no `due`, sort first).
  final List<MemCard> due;

  bool get isEmpty => due.isEmpty;
  int get length => due.length;
}
