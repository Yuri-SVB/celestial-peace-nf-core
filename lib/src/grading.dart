import 'card.dart';

/// Honest grading — the foundation of CPNF's graduation gate
/// (cpnf-lifecycle-and-deck.md §3).
///
/// **Grades measure memory, not outcome.** A point (or fact) that came out
/// *right* but not by genuine recall — found by luck, by guessing, after the
/// user gave up, or via a hint / brute-force bailout — must be graded
/// [Grade.again] despite the success. Otherwise the schedule and the lockout
/// estimate consolidate on garbage, and the gate would lie about readiness.
///
/// This is the single choke point that enforces that rule, so the review flow
/// can't accidentally reward a dishonest success. It is pure (no time, no I/O)
/// and is applied to the raw attempt before [MemSchedule.grade].
///
/// `Again` stays available for an honest attempt too: the user may judge their
/// own recall shaky and pass `proposed: Grade.again` — that flows through
/// unchanged. The policy only ever *forces* `Again`, never upgrades away from it.
Grade honestGrade({
  /// The attempt objectively succeeded: the located point validated against the
  /// setup, or the recalled fact matched exactly.
  required bool succeeded,

  /// The canonical-island highlight / `H` hint was revealed during the attempt.
  bool usedHint = false,

  /// The stage was recovered by the error-locator / brute-force bailout rather
  /// than recalled.
  bool bailedOut = false,

  /// The user self-reports that the success was a lucky guess, or came only
  /// after they had given up on recalling it.
  bool luckyOrGaveUp = false,

  /// The grade the user would give an honest find ([Grade.hard]/good/easy, or
  /// [Grade.again] if they judge their own recall poor).
  Grade proposed = Grade.good,
}) {
  // A miss is always Again.
  if (!succeeded) return Grade.again;
  // A "success" that leaned on a hint, a bailout, a guess, or came after giving
  // up must not consolidate — force Again regardless of what was proposed.
  if (usedHint || bailedOut || luckyOrGaveUp) return Grade.again;
  // Honest success: the user's own self-assessed grade stands.
  return proposed;
}
