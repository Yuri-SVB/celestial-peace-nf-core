/// Celestial Peace: Never Forget (CPNF) — the spaced-repetition memory engine
/// for Great Wall setup recall.
///
/// Pure Dart, UI-free, FFI-free, and clock-injected: nothing here reads the wall
/// clock (see [Clock]). The consuming app supplies the real clock, the setup to
/// validate against, the encryption (the deck rides in the setup's encrypted
/// file), the routes the cues describe, and the recognition UI.
///
/// Here: the conservative SM-2 scheduler and its parameters, honest grading,
/// a card per memorised map with its landmark cues (an attempt is graded only
/// once no stop is shown), consolidation, reminders, and the deck with its
/// progress and JSON form; the review session's rules: which attempts
/// are graded and which are practice ([ReviewSession]); the forgetting curve
/// ([MemSchedule.recall]); and the graduation gate: a stage graduates when the
/// chance of recalling fewer than its `r_i` maps after a target gap is at most
/// `ε` ([graduationGates]). The post-graduation bundles are a later step.
///
/// Spec: great-wall-docs `next-steps/cpnf-step1-scheduler.md`,
/// `cpnf-lifecycle-and-deck.md` and `cpnf-maintenance-bundles.md` §1.
library;

export 'src/card.dart';
export 'src/clock.dart';
export 'src/cues.dart';
export 'src/deck.dart';
export 'src/grading.dart';
export 'src/graduation.dart';
export 'src/params.dart';
export 'src/review.dart';
export 'src/schedule.dart';
