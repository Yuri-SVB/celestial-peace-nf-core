/// Injected time source for CPNF (`celestial-peace-nf-core`).
///
/// **Invariant (cpnf-step1-scheduler.md §0.4):** nothing in this package may read
/// the wall clock except through a [Clock]. Scheduler and session code call
/// `clock.now()` — never `DateTime.now()` — so scheduling is deterministic and
/// unit-testable, and every time read is auditable. The *real* clock (a
/// `SystemClock`) therefore lives OUTSIDE this package, in the consuming app's
/// host layer; this package carries only the interface and the test-facing
/// [FakeClock].
library;

/// A source of "now". The real implementation wraps the system clock (in the
/// app host, not here); tests inject a [FakeClock] they can advance.
abstract interface class Clock {
  DateTime now();
}

/// A deterministic, advanceable [Clock] for tests. Holds a fixed instant that
/// only moves when the test [advance]s it — it never reads the system clock, so
/// the package stays free of ambient time.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Move time forward by [d].
  void advance(Duration d) => _now = _now.add(d);

  /// Jump to an absolute instant.
  void set(DateTime t) => _now = t;
}
