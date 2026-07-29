/// Celestial Peace: Never Forget (CPNF) — the spaced-repetition memory engine
/// for Great Wall setup recall.
///
/// Pure Dart, UI-free, FFI-free, and clock-injected: nothing here reads the wall
/// clock (see [Clock]). The consuming app supplies the real clock, the setup to
/// validate against, and the recognition UI. Step 1 = the conservative SM-2
/// scheduler, the card/queue model, honest grading, and the deck builder; the
/// review-session flow, encryption-at-rest, and TLP/graduation are later steps.
///
/// Spec: great-wall-docs `next-steps/cpnf-step1-scheduler.md` and
/// `cpnf-lifecycle-and-deck.md`.
library;

export 'src/card.dart';
export 'src/clock.dart';
export 'src/deck.dart';
export 'src/grading.dart';
export 'src/schedule.dart';
