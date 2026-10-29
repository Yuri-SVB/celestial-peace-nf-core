/// Every number CPNF's schedule depends on, with its source. Callers may pass
/// their own values; the defaults are the ones below.
library;

/// The conservative SM-2 schedule (cpnf-step1-scheduler.md §3). The ease
/// values and the 1-day / 6-day rungs are SM-2's (Woźniak, 1990:
/// https://www.supermemo.com/en/archives1990-2015/english/ol/sm2); the Hard and
/// Easy multipliers are CPNF's deliberate deviation for four-button grading.
class Sm2Params {
  const Sm2Params({
    this.initialEase = defaultInitialEase,
    this.minEase = defaultMinEase,
    this.firstIntervalDays = defaultFirstIntervalDays,
    this.secondIntervalDays = defaultSecondIntervalDays,
    this.lapseIntervalDays = defaultLapseIntervalDays,
    this.hardFactor = defaultHardFactor,
    this.easyBonus = defaultEasyBonus,
  });

  /// SM-2's starting E-Factor.
  static const double defaultInitialEase = 2.5;

  /// SM-2's E-Factor floor.
  static const double defaultMinEase = 1.3;

  /// SM-2's I(1): the interval after the first success.
  static const int defaultFirstIntervalDays = 1;

  /// SM-2's I(2): the interval after the second consecutive success.
  static const int defaultSecondIntervalDays = 6;

  /// The interval after a lapse (SM-2 restarts the repetitions).
  static const int defaultLapseIntervalDays = 1;

  /// Hard grows the interval by this, not by the E-Factor (deviation).
  static const double defaultHardFactor = 1.2;

  /// Easy grows the interval by the E-Factor times this (deviation).
  static const double defaultEasyBonus = 1.3;

  final double initialEase;
  final double minEase;
  final int firstIntervalDays;
  final int secondIntervalDays;
  final int lapseIntervalDays;
  final double hardFactor;
  final double easyBonus;
}

/// When a card counts as consolidated (cpnf-lifecycle-and-deck.md §3): its
/// interval and its run of successes are both long enough. A lapse resets the
/// run, so it drops out at once. At the defaults this takes about two months.
class ConsolidationParams {
  const ConsolidationParams({
    this.minIntervalDays = defaultMinIntervalDays,
    this.minRepetitions = defaultMinRepetitions,
  });

  /// `Ic`: the interval a consolidated card has reached.
  static const int defaultMinIntervalDays = 90;

  /// `Rc`: the consecutive successes a consolidated card has had.
  static const int defaultMinRepetitions = 5;

  final int minIntervalDays;
  final int minRepetitions;
}

/// Reminder cadence (cpnf-maintenance-bundles.md §1): at least this often,
/// sooner when a graded card falls due.
class ReminderParams {
  const ReminderParams({this.maxGap = defaultMaxGap});

  /// Reminders at least daily.
  static const Duration defaultMaxGap = Duration(days: 1);

  final Duration maxGap;
}
