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
/// progress and JSON form. The review session and the post-graduation bundles
/// are later steps.
///
/// Spec: great-wall-docs `next-steps/cpnf-step1-scheduler.md`,
/// `cpnf-lifecycle-and-deck.md` and `cpnf-maintenance-bundles.md` §1.
library;

export 'src/card.dart';
export 'src/clock.dart';
export 'src/cues.dart';
export 'src/deck.dart';
export 'src/grading.dart';
export 'src/params.dart';
export 'src/schedule.dart';
