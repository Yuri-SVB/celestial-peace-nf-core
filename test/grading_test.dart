import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';
import 'package:test/test.dart';

/// Honest-grading tests (cpnf-lifecycle-and-deck.md §3): grades measure memory,
/// not outcome — a dishonest success is forced to Again.
void main() {
  group('honestGrade', () {
    test('a miss is always Again', () {
      expect(honestGrade(succeeded: false, proposed: Grade.easy), Grade.again);
    });

    test('an honest success keeps the proposed grade', () {
      expect(honestGrade(succeeded: true, proposed: Grade.good), Grade.good);
      expect(honestGrade(succeeded: true, proposed: Grade.easy), Grade.easy);
      expect(honestGrade(succeeded: true, proposed: Grade.hard), Grade.hard);
    });

    test('a hint forces Again despite success', () {
      expect(
        honestGrade(succeeded: true, usedHint: true, proposed: Grade.good),
        Grade.again,
      );
    });

    test('a bailout forces Again despite success', () {
      expect(
        honestGrade(succeeded: true, bailedOut: true, proposed: Grade.easy),
        Grade.again,
      );
    });

    test('a lucky guess / giving up forces Again despite success', () {
      expect(
        honestGrade(succeeded: true, luckyOrGaveUp: true, proposed: Grade.good),
        Grade.again,
      );
    });

    test('the user may honestly self-assess Again on a clean find', () {
      expect(honestGrade(succeeded: true, proposed: Grade.again), Grade.again);
    });
  });
}
