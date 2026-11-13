import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 4, 12);
  const Cues unaided = Cues(rhoNum: 1, rhoDen: 2, exponent: 2, visible: 0);
  const Cues someStops = Cues(rhoNum: 1, rhoDen: 2, exponent: 2, visible: 3);
  const Cues allStops = Cues(rhoNum: 1, rhoDen: 2, exponent: 2);

  PracticeReason? reason(MemCard c, {bool aided = false, bool graded = false}) =>
      practiceReason(c, aided: aided, gradedThisSession: graded, now: now);

  test('a new map without stops is graded', () {
    expect(reason(MemCard.map(1, 2, unaided)), isNull);
  });

  test('stops shown: practice', () {
    expect(reason(MemCard.map(1, 2, someStops)), PracticeReason.stopsShown);
    expect(reason(MemCard.map(1, 2, allStops)), PracticeReason.stopsShown);
  });

  test('a route change during the attempt: practice', () {
    expect(reason(MemCard.map(1, 2, unaided), aided: true), PracticeReason.routeChanged);
  });

  test('graded already this session: practice', () {
    expect(reason(MemCard.map(1, 2, unaided), graded: true),
        PracticeReason.gradedThisSession);
  });

  test('not due yet: practice; due: graded', () {
    final MemCard later =
        MemCard.map(1, 2, unaided).copyWith(due: now.add(const Duration(days: 3)));
    expect(reason(later), PracticeReason.notDue);
    final MemCard due = MemCard.map(1, 2, unaided)
        .copyWith(due: now.subtract(const Duration(hours: 1)));
    expect(reason(due), isNull);
  });

  test('a session grades a map once, through the schedule', () {
    final FakeClock clock = FakeClock(now);
    final ReviewSession session = ReviewSession(MemSchedule(clock));
    final MemCard card = MemCard.map(1, 2, unaided);
    expect(session.practiceReasonFor(card), isNull);
    final MemCard next = session.record(card, honestGrade(succeeded: true));
    expect(next.repetitions, 1);
    expect(next.due!.isAfter(now), isTrue);
    expect(session.gradedThisSession(card), isTrue);
    expect(session.practiceReasonFor(next), PracticeReason.gradedThisSession);
    // A day on, in a new session, it is due again.
    clock.advance(const Duration(days: 1));
    session.clear();
    expect(session.practiceReasonFor(next), isNull);
  });

  test('a map with stops comes back unchanged, and a hint makes a find Again', () {
    final ReviewSession session = ReviewSession(MemSchedule(FakeClock(now)));
    final MemCard practised = MemCard.map(1, 2, someStops);
    expect(session.record(practised, Grade.good).repetitions, 0);
    expect(honestGrade(succeeded: true, usedHint: true), Grade.again);
  });
}
