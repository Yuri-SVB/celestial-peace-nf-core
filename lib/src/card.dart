/// CPNF card / queue model (cpnf-step1-scheduler.md §2,
/// cpnf-maintenance-bundles.md §1).
///
/// A **deck** is one setup's spaced-repetition state: a card per **map** the
/// user chose to memorise (stage `i`, slot `j`) plus explicit *fact* cards
/// (`m`, `D`, salt, export salts, download provenance, misc reminders). Any
/// `r_i` of a stage's maps give its Shamir polynomial, so which maps, and in
/// what order, is the user's choice. This file is the pure data model only —
/// no time reads, no crypto, no Flutter.
///
/// SECURITY (cpnf-step1-scheduler.md §0): a [MemCard] holds ONLY SM-2 schedule
/// state, the map's cues and non-secret identity. For a point card the
/// "answer" — the true point — is NOT stored here; it lives in the encrypted
/// setup and is read only to *validate* a recall attempt. Never put bits,
/// `(o, p, q)`, coordinates, or bisection paths on a card. The deck as a whole
/// is still sensitive (it shows which maps are memorised and how well) and is
/// stored encrypted, like the setup.
library;

import 'cues.dart';
import 'params.dart';

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
  /// One map's point recall; the stored (encrypted) point grades the attempt.
  point,

  /// Explicit fact recall: `m`, `N`, `D`, salt/pepper, export salts, provenance,
  /// miscellaneous reminders.
  fact,
}

/// Persisted per-card state. Identity fields are immutable; the schedule
/// fields advance via [MemSchedule] (which returns a new card — it never
/// mutates in place). At rest the whole deck is encrypted with the setup's key
/// (cpnf-step1-scheduler.md §0.1); this class is the in-memory, decrypted form.
class MemCard {
  const MemCard({
    required this.id,
    required this.kind,
    this.stageIndex = -1,
    this.slot = -1,
    this.factId = '',
    this.cues,
    this.easeFactor = Sm2Params.defaultInitialEase,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.due,
    this.lapses = 0,
  });

  /// A map's card: stage [stage], slot [slot] (`1..s_i`), starting [cues].
  factory MemCard.map(int stage, int slot, Cues cues) => MemCard(
        id: mapId(stage, slot),
        kind: CardKind.point,
        stageIndex: stage,
        slot: slot,
        cues: cues,
      );

  /// A fact's card.
  factory MemCard.fact(String factId) =>
      MemCard(id: 'fact:$factId', kind: CardKind.fact, factId: factId);

  /// The id of stage [stage], slot [slot]'s card.
  static String mapId(int stage, int slot) => 'point:$stage:$slot';

  /// Stable identity, e.g. `"point:1:2"`, `"fact:m"`, `"fact:export:2"`.
  final String id;
  final CardKind kind;

  /// Stage this point card belongs to (`0..N`); `-1` for fact cards.
  final int stageIndex;

  /// The map's slot within its stage (`1..s_i`); `-1` for fact cards.
  final int slot;

  /// Fact identifier for fact cards, e.g. `"m"`, `"N"`, `"D"`, `"salt"`,
  /// `"export:2"`, `"provenance"`, `"misc:anniversary"`. Empty for point cards.
  final String factId;

  /// The map's landmark cues; null for fact cards.
  final Cues? cues;

  /// SM-2 ease factor. Starts 2.5, floored at 1.3 ([Sm2Params]).
  final double easeFactor;

  /// Consecutive successful (non-lapse) reviews.
  final int repetitions;

  /// Current scheduled interval, in days.
  final int intervalDays;

  /// When the card is next due (computed via the injected `Clock`). Null means
  /// a card never graded (treated as due now).
  final DateTime? due;

  /// Times the card has lapsed (been graded [Grade.again]).
  final int lapses;

  /// A never-graded card.
  bool get isNew => due == null;

  /// Whether this card is due at [now] (never-graded cards are always due).
  bool isDue(DateTime now) => due == null || !due!.isAfter(now);

  /// Whether an attempt at this card is graded: a fact, or a map with no stop
  /// shown. A map still showing stops is practised, not graded.
  bool get isGraded => cues?.unaided ?? true;

  MemCard copyWith({
    Cues? cues,
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
        slot: slot,
        factId: factId,
        cues: cues ?? this.cues,
        easeFactor: easeFactor ?? this.easeFactor,
        repetitions: repetitions ?? this.repetitions,
        intervalDays: intervalDays ?? this.intervalDays,
        due: due ?? this.due,
        lapses: lapses ?? this.lapses,
      );

  /// `due` is stored as UTC ISO-8601.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        if (kind == CardKind.point) 'stage': stageIndex,
        if (kind == CardKind.point) 'slot': slot,
        if (kind == CardKind.fact) 'fact': factId,
        if (cues != null) 'cues': cues!.toJson(),
        'ease': easeFactor,
        'reps': repetitions,
        'interval': intervalDays,
        if (due != null) 'due': due!.toUtc().toIso8601String(),
        'lapses': lapses,
      };

  /// Throws a [FormatException] that echoes no value on any bad field.
  factory MemCard.fromJson(Map<String, dynamic> json) {
    T field<T>(String key) {
      final Object? v = json[key];
      return v is T ? v : throw const FormatException('bad card');
    }

    final CardKind kind = CardKind.values.firstWhere(
      (CardKind k) => k.name == json['kind'],
      orElse: () => throw const FormatException('bad card'),
    );
    final Object? rawCues = json['cues'];
    final Object? rawDue = json['due'];
    final DateTime? due = rawDue == null
        ? null
        : rawDue is String
            ? DateTime.tryParse(rawDue) ??
                (throw const FormatException('bad card'))
            : throw const FormatException('bad card');
    final num ease = field<num>('ease');
    return MemCard(
      id: field<String>('id'),
      kind: kind,
      stageIndex: kind == CardKind.point ? field<int>('stage') : -1,
      slot: kind == CardKind.point ? field<int>('slot') : -1,
      factId: kind == CardKind.fact ? field<String>('fact') : '',
      cues: rawCues == null
          ? null
          : Cues.fromJson(rawCues is Map<String, dynamic>
              ? rawCues
              : throw const FormatException('bad card')),
      easeFactor: ease.toDouble(),
      repetitions: field<int>('reps'),
      intervalDays: field<int>('interval'),
      due: due,
      lapses: field<int>('lapses'),
    );
  }

  /// Redacted: even the identity is deck-scoped state that should not leak into
  /// logs.
  @override
  String toString() => 'MemCard(<redacted>)';
}

/// The set of cards due for review at a given instant, oldest-due first
/// (cpnf-step1-scheduler.md §2). Built by [MemSchedule.queue].
class ReviewQueue {
  const ReviewQueue(this.due);

  /// Cards with `due <= clock.now()`, ordered oldest-due first (never-graded
  /// cards, which have no `due`, sort first).
  final List<MemCard> due;

  bool get isEmpty => due.isEmpty;
  int get length => due.length;
}
