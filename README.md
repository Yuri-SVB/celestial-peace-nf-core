# celestial-peace-nf-core (CPNF)

**Celestial Peace: Never Forget** — the spaced-repetition memory engine that
consolidates a user's tacit recall of a [Great Wall](https://github.com/yuri-svb)
fractal setup.

Pure Dart, UI-free, FFI-free, and **clock-injected**: nothing in this package
reads the wall clock. The consuming app supplies the real clock, the setup to
validate recall against, and the recognition UI.

## Status — Step 1 (scheduler core)

Implemented per great-wall-docs `next-steps/cpnf-step1-scheduler.md`:

- `Clock` (injected time) + `FakeClock` for deterministic tests.
- `Grade`, `CardKind` (point / fact), `MemCard`, `ReviewQueue` — the card model.
  A card holds only SM-2 schedule state; a point's answer stays in the encrypted
  setup and is read only to *validate* a recall attempt.
- `MemSchedule` — conservative **SM-2** (P. A. Woźniak, SuperMemo, 1990;
  <https://www.supermemo.com/en/archives1990-2015/english/ol/sm2>). Canonical
  E-Factor update and lapse handling, with four-button per-grade interval
  multipliers documented as a deliberate deviation.
- `honestGrade` — grades measure *memory, not outcome*: a success by luck, a
  guess, giving up, a hint, or a brute-force bailout is forced to `Again`.
- `buildDeck` — the card set for a setup (N point cards + fact cards).

**Later steps** (not here): the review-session flow, encryption-at-rest,
TLP-gated / graduation / inheritance. See `cpnf-lifecycle-and-deck.md`.

## Test

Pure Dart, no Flutter:

```
dart pub get
dart test
```

## Consuming it

Add as a path (or git) dependency; the app provides the real clock:

```dart
import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';

final schedule = MemSchedule(appSystemClock); // app supplies a Clock impl
final due = schedule.queue(cards);
final card2 = schedule.grade(card, honestGrade(succeeded: true, proposed: Grade.good));
```
