/// A review session's rules (cpnf-maintenance-bundles.md §1): which attempts
/// at a map are graded and which are practice, and the grading of the ones
/// that are. Pure, given the schedule's clock.
library;

import 'card.dart';
import 'schedule.dart';

/// Why an attempt is practice — it leaves the card's schedule untouched.
enum PracticeReason {
  /// The map still shows landmark stops.
  stopsShown,

  /// Stops were shown or hidden (the route changed) during the attempt.
  routeChanged,

  /// The map was graded already in this session: its answer has been seen.
  gradedThisSession,

  /// The map is not due yet ([MemCard.due]).
  notDue,
}

/// Why an attempt at [card] at [now] is practice, or null when it is graded:
/// only with no stop shown, no route change during it ([aided]), not graded
/// already this session, and when due.
PracticeReason? practiceReason(
  MemCard card, {
  required bool aided,
  required bool gradedThisSession,
  required DateTime now,
}) {
  if (!card.isGraded) return PracticeReason.stopsShown;
  if (aided) return PracticeReason.routeChanged;
  if (gradedThisSession) return PracticeReason.gradedThisSession;
  final DateTime? due = card.due;
  if (due != null && due.isAfter(now)) return PracticeReason.notDue;
  return null;
}

/// One review session: the maps graded in it, each graded through
/// [schedule] at most once.
class ReviewSession {
  ReviewSession(this.schedule);

  final MemSchedule schedule;
  final Set<String> _graded = <String>{};

  /// Whether [card] was graded in this session.
  bool gradedThisSession(MemCard card) => _graded.contains(card.id);

  /// Why an attempt at [card] now is practice, or null when graded
  /// ([practiceReason]).
  PracticeReason? practiceReasonFor(MemCard card, {bool aided = false}) =>
      practiceReason(card,
          aided: aided,
          gradedThisSession: gradedThisSession(card),
          now: schedule.clock.now());

  /// [card] graded [grade]; it is graded no more this session. A card that
  /// is not graded ([MemCard.isGraded]) comes back unchanged.
  MemCard record(MemCard card, Grade grade) {
    final MemCard next = schedule.grade(card, grade);
    _graded.add(card.id);
    return next;
  }

  /// A new session: every map gradable again.
  void clear() => _graded.clear();
}
