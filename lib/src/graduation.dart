/// The graduation gate (cpnf-lifecycle-and-deck.md §3): a stage graduates when
/// the chance of recalling fewer than its `r_i` maps, after a target gap `T`,
/// is at most `ε`. Each map's chance comes from the forgetting curve
/// ([MemSchedule.recall]); a stage is rebuilt by any `r_i` of its maps, so
/// `r_i` maps recalled very well pass as well as more maps recalled less well.
///
/// The maps are taken as forgotten independently of one another. Forgetting is
/// correlated in practice, so the estimate errs optimistic — which is why `ε`
/// is set low.
library;

import 'card.dart';
import 'deck.dart';
import 'schedule.dart';

/// The gate's threshold.
class GraduationParams {
  const GraduationParams({this.epsilon = defaultEpsilon});

  /// `ε`: the highest acceptable chance of recalling fewer than `r_i` maps.
  /// Low because map recall is tacit knowledge, expected to fade faster than
  /// the explicit facts SM-2 was built for. The user tunes it.
  static const double defaultEpsilon = 1e-4;

  final double epsilon;
}

/// The chance that fewer than [required] events happen, each happening
/// independently with its chance in [chances] (a Poisson binomial tail).
double failureChance(Iterable<double> chances, int required) {
  if (required <= 0) return 0;
  // dist[k]: the chance that exactly k have happened so far.
  List<double> dist = <double>[1];
  for (final double p in chances) {
    final List<double> next = List<double>.filled(dist.length + 1, 0);
    for (int k = 0; k < dist.length; k++) {
      next[k] += dist[k] * (1 - p);
      next[k + 1] += dist[k] * p;
    }
    dist = next;
  }
  double fail = 0;
  for (int k = 0; k < required && k < dist.length; k++) {
    fail += dist[k];
  }
  return fail;
}

/// One stage at the gate.
class StageGate {
  const StageGate({
    required this.stage,
    required this.required,
    required this.maps,
    required this.failure,
    required this.passes,
  });

  final int stage;

  /// Its `r_i`, and the maps of the deck it has.
  final int required;
  final int maps;

  /// The chance of recalling fewer than [required] of its maps after the gap.
  final double failure;

  /// Whether [failure] is at most `ε`.
  final bool passes;
}

/// Every stage of [deck] at the gate, at [at] (now plus the target gap):
/// [required] holds each stage's `r_i`, indexed by stage. A map counts by its
/// chance of being recalled unaided; one never graded, or still practised with
/// stops, counts as forgotten.
List<StageGate> graduationGates(
  Deck deck,
  List<int> required,
  DateTime at,
  MemSchedule schedule, {
  GraduationParams params = const GraduationParams(),
}) {
  return <StageGate>[
    for (int i = 0; i < required.length; i++)
      () {
        final List<MemCard> maps = <MemCard>[
          for (final MemCard c in deck.cards)
            if (c.kind == CardKind.point && c.stageIndex == i) c,
        ];
        final double failure = failureChance(<double>[
          for (final MemCard c in maps)
            c.isGraded ? (schedule.recall(c, at) ?? 0) : 0,
        ], required[i]);
        return StageGate(
          stage: i,
          required: required[i],
          maps: maps.length,
          failure: failure,
          passes: failure <= params.epsilon,
        );
      }(),
  ];
}
