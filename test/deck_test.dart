import 'package:celestial_peace_nf_core/celestial_peace_nf_core.dart';
import 'package:test/test.dart';

/// Step 2 (cpnf-maintenance-bundles.md §1): a card per map with its landmark
/// cues, practice until no stop is shown, consolidation, reminders, and the
/// deck — free map choice, progress, JSON.
void main() {
  final DateTime day0 = DateTime.utc(2026, 1, 1);
  const Cues route = Cues(rhoNum: 1, rhoDen: 1, exponent: 2);

  group('cues', () {
    test('a new route shows every stop again; visible keeps the route', () {
      final Cues shown = route.withVisible(3);
      expect(shown.visible, 3);
      final Cues rerouted = shown.withRoute(rhoNum: 1, rhoDen: 2, exponent: 3);
      expect(rerouted.visible, isNull);
      expect((rerouted.rhoNum, rerouted.rhoDen, rerouted.exponent), (1, 2, 3));
      expect(route.withVisible(0).unaided, isTrue);
      expect(route.unaided, isFalse);
    });

    test('bad cues fail opaquely', () {
      expect(
        () => Cues.fromJson(<String, dynamic>{
          'rhoNum': 1,
          'rhoDen': 0,
          'exponent': 2,
        }),
        throwsA(isA<FormatException>()
            .having((FormatException e) => e.message, 'message', 'bad cues')),
      );
    });
  });

  group('practice and grading', () {
    test('a map showing stops is practised: grading leaves it unchanged', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final MemCard cued = MemCard.map(1, 2, route.withVisible(2));
      expect(cued.isGraded, isFalse);
      expect(identical(s.grade(cued, Grade.good), cued), isTrue);
      expect(identical(s.grade(cued, Grade.again), cued), isTrue);
    });

    test('at 0 stops the map is graded', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final MemCard unaided = MemCard.map(1, 2, route.withVisible(0));
      final MemCard graded = s.grade(unaided, Grade.good);
      expect(graded.repetitions, 1);
      expect(graded.due, day0.add(const Duration(days: 1)));
      expect(graded.cues, unaided.cues);
    });

    test('cued maps are always in the queue, for practice', () {
      final FakeClock clock = FakeClock(day0);
      final MemSchedule s = MemSchedule(clock);
      final MemCard graded =
          s.grade(MemCard.map(1, 1, route.withVisible(0)), Grade.good);
      final MemCard cued = MemCard.map(1, 2, route);
      expect(s.queue(<MemCard>[graded, cued]).due, <MemCard>[cued]);
    });
  });

  group('consolidation', () {
    test('needs the interval and the run of successes, and graded', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final MemCard ripe = MemCard.map(1, 1, route.withVisible(0)).copyWith(
        repetitions: ConsolidationParams.defaultMinRepetitions,
        intervalDays: ConsolidationParams.defaultMinIntervalDays,
      );
      expect(s.consolidated(ripe), isTrue);
      expect(
          s.consolidated(ripe.copyWith(
              intervalDays: ConsolidationParams.defaultMinIntervalDays - 1)),
          isFalse);
      expect(s.consolidated(s.grade(ripe, Grade.again)), isFalse,
          reason: 'a lapse resets the run');
      expect(s.consolidated(ripe.copyWith(cues: route)), isFalse,
          reason: 'a map showing stops again is not graded');
    });
  });

  group('reminders', () {
    test('at least daily, sooner when a graded card falls due', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      final DateTime last = day0;
      expect(s.nextReminder(<MemCard>[], last),
          last.add(ReminderParams.defaultMaxGap));
      final MemCard soon = MemCard.fact('m')
          .copyWith(due: last.add(const Duration(hours: 5)), repetitions: 1);
      expect(s.nextReminder(<MemCard>[soon], last),
          last.add(const Duration(hours: 5)));
      final MemCard overdue = MemCard.fact('D').copyWith(
          due: last.subtract(const Duration(days: 3)), repetitions: 1);
      expect(s.nextReminder(<MemCard>[overdue], last),
          last.add(ReminderParams.defaultMaxGap),
          reason: 'already overdue at the last reminder');
      final MemCard cued = MemCard.map(1, 1, route)
          .copyWith(due: last.add(const Duration(hours: 1)));
      expect(s.nextReminder(<MemCard>[cued], last),
          last.add(ReminderParams.defaultMaxGap),
          reason: 'practice follows the daily cadence');
    });
  });

  group('deck', () {
    Deck deck() => buildDeck(
          maps: <List<int>>[
            <int>[1, 2],
            <int>[1, 2, 3],
          ],
          cues: route,
          exportSalts: <String>['signing-1'],
          misc: <String>['anniversary'],
        );

    test('a card per placed map plus the fact cards', () {
      final Deck d = deck();
      final List<MemCard> maps =
          d.cards.where((MemCard c) => c.kind == CardKind.point).toList();
      expect(maps.map((MemCard c) => c.id).toList(), <String>[
        'point:0:1',
        'point:0:2',
        'point:1:1',
        'point:1:2',
        'point:1:3',
      ]);
      expect(maps.every((MemCard c) => c.cues == route), isTrue);
      final List<String> facts = d.cards
          .where((MemCard c) => c.kind == CardKind.fact)
          .map((MemCard c) => c.factId)
          .toList();
      expect(facts, containsAll(<String>['m', 'N', 'D', 'salt', 'provenance']));
      expect(facts, contains('export:signing-1'));
      expect(facts, contains('misc:anniversary'));
    });

    test('maps are swapped freely; progress counts against r_i', () {
      final MemSchedule s = MemSchedule(FakeClock(day0));
      Deck d = deck().removeMap(1, 3).addMap(1, 5, route);
      expect(d.map(1, 3), isNull);
      expect(d.map(1, 5)!.cues, route);
      expect(identical(d.addMap(1, 5, route.withVisible(0)), d), isTrue,
          reason: 'an existing map keeps its card');
      d = d.withCard(d.map(1, 5)!.copyWith(cues: route.withVisible(0)));
      d = d.removeMap(1, 2);
      final DeckProgress p = d.progress(<int>[2, 3], s);
      expect(<(int, int, int, int)>[
        for (final StageProgress sp in p.stages)
          (sp.required, sp.maps, sp.unaided, sp.mapsMissing),
      ], <(int, int, int, int)>[
        (2, 2, 0, 0),
        (3, 2, 1, 1)
      ]);
      expect(p.facts, 7);
      expect(p.factsConsolidated, 0);
    });

    test('JSON round trip; bad JSON fails opaquely', () {
      final FakeClock clock = FakeClock(day0);
      final MemSchedule s = MemSchedule(clock);
      Deck d = deck();
      d = d.withCard(s.grade(d.cards.last, Grade.easy));
      d = d.withCard(d.map(0, 1)!.copyWith(cues: route.withVisible(4)));
      final Deck back = Deck.fromJson(d.toJson());
      expect(back.toJson(), d.toJson());
      expect(back.cards.last.due!.isAtSameMomentAs(d.cards.last.due!), isTrue);
      expect(back.map(0, 1)!.cues, route.withVisible(4));
      expect(
          () => Deck.fromJson(<String, dynamic>{'v': 2, 'cards': <dynamic>[]}),
          throwsFormatException);
      final Map<String, dynamic> broken = d.toJson();
      (broken['cards'] as List<dynamic>)[0] = <String, dynamic>{'id': 7};
      expect(() => Deck.fromJson(broken), throwsFormatException);
    });

    test('nothing secret-shaped is serialised, and toString is redacted', () {
      final Deck d = deck();
      final String json = d.toJson().toString();
      for (final String banned in <String>['re', 'im', 'bits', 'path']) {
        expect(json.contains("'$banned'"), isFalse, reason: banned);
      }
      expect(d.toString(), 'Deck(<redacted>)');
      expect(d.cards.first.toString(), 'MemCard(<redacted>)');
    });
  });
}
