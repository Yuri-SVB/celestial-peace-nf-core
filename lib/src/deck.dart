import 'card.dart';
import 'cues.dart';
import 'schedule.dart';

/// One setup's deck (cpnf-step1-scheduler.md §2, cpnf-lifecycle-and-deck.md
/// §2, cpnf-maintenance-bundles.md §1): a card per map the user memorises,
/// plus the fact cards. Immutable: every change returns a new deck. Pure — no
/// time, no crypto.
///
/// **The user chooses.** Which maps of a stage, in what order, studied
/// together or one after another, swapped for easier ones: all free. Any
/// `r_i` of a stage's maps give its Shamir polynomial, so nothing is rekeyed
/// by a swap. CPNF only reports what is still to memorise ([progress]).
class Deck {
  Deck(List<MemCard> cards) : cards = List<MemCard>.unmodifiable(cards);

  /// Serialization version of [toJson].
  static const int formatVersion = 1;

  final List<MemCard> cards;

  /// The card of stage [stage]'s map [slot], or null if it is not in the deck.
  MemCard? map(int stage, int slot) {
    final String id = MemCard.mapId(stage, slot);
    for (final MemCard c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The deck with [card] in place of the card with its id (or added).
  Deck withCard(MemCard card) {
    final List<MemCard> next = <MemCard>[
      for (final MemCard c in cards)
        if (c.id != card.id) c,
    ];
    final int at = cards.indexWhere((MemCard c) => c.id == card.id);
    next.insert(at < 0 ? next.length : at, card);
    return Deck(next);
  }

  /// The deck with stage [stage]'s map [slot] added, as a new card with
  /// [cues] (unchanged if it is already there).
  Deck addMap(int stage, int slot, Cues cues) => map(stage, slot) != null
      ? this
      : withCard(MemCard.map(stage, slot, cues));

  /// The deck without stage [stage]'s map [slot] (its schedule is dropped).
  Deck removeMap(int stage, int slot) {
    final String id = MemCard.mapId(stage, slot);
    return Deck(<MemCard>[
      for (final MemCard c in cards)
        if (c.id != id) c,
    ]);
  }

  /// What is memorised and what is left: per stage, against its `r_i`
  /// ([required], indexed by stage), and for the facts.
  DeckProgress progress(List<int> required, MemSchedule schedule) {
    List<MemCard> of(int stage) => <MemCard>[
          for (final MemCard c in cards)
            if (c.kind == CardKind.point && c.stageIndex == stage) c,
        ];
    final List<MemCard> facts = <MemCard>[
      for (final MemCard c in cards)
        if (c.kind == CardKind.fact) c,
    ];
    return DeckProgress(
      stages: <StageProgress>[
        for (int i = 0; i < required.length; i++)
          StageProgress(
            required: required[i],
            maps: of(i).length,
            unaided: of(i).where((MemCard c) => c.isGraded).length,
            consolidated: of(i).where(schedule.consolidated).length,
          ),
      ],
      facts: facts.length,
      factsConsolidated: facts.where(schedule.consolidated).length,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': formatVersion,
        'cards': <Map<String, dynamic>>[
          for (final MemCard c in cards) c.toJson(),
        ],
      };

  /// Throws a [FormatException] that echoes no value on any bad field or an
  /// unknown version.
  factory Deck.fromJson(Map<String, dynamic> json) {
    final Object? rawCards = json['cards'];
    if (json['v'] != formatVersion || rawCards is! List) {
      throw const FormatException('bad deck');
    }
    return Deck(<MemCard>[
      for (final Object? c in rawCards)
        MemCard.fromJson(c is Map<String, dynamic>
            ? c
            : throw const FormatException('bad deck')),
    ]);
  }

  @override
  String toString() => 'Deck(<redacted>)';
}

/// One stage's progress: its `r_i`, the maps in the deck, and how many of
/// them are unaided (no stop shown, so graded) and consolidated.
class StageProgress {
  const StageProgress({
    required this.required,
    required this.maps,
    required this.unaided,
    required this.consolidated,
  });

  final int required;
  final int maps;
  final int unaided;
  final int consolidated;

  /// Maps still to add before the stage has its `r_i`.
  int get mapsMissing => maps < required ? required - maps : 0;
}

/// A deck's progress ([Deck.progress]).
class DeckProgress {
  const DeckProgress({
    required this.stages,
    required this.facts,
    required this.factsConsolidated,
  });

  final List<StageProgress> stages;
  final int facts;
  final int factsConsolidated;
}

/// Builds the fresh deck for a setup: a card for each map in [maps] (per
/// stage, the slots the user placed), each starting with [cues], plus the
/// explicit fact cards the user must recall. Pure — no time, no crypto.
///
/// The fact parameters (`m`, `N`, `D`, salts, export salts, provenance, misc)
/// are labels/parameters, not the tacit seed, so drilling them does not weaken
/// coercion-resistance (cpnf-step1-scheduler.md §0.3). No fact *value* is
/// stored on a card here — only its identity; values live in the encrypted
/// setup.
Deck buildDeck({
  required List<List<int>> maps,
  required Cues cues,
  List<String> exportSalts = const <String>[],
  List<String> misc = const <String>[],
  bool includeProvenance = true,
}) {
  // Core fact cards (§0.3 / §2). `m`, `N`, `D` are exact-recall; `salt` is the
  // σ-date; provenance enables a supply-chain-resistant hard reset.
  const List<String> core = <String>['m', 'N', 'D', 'salt'];
  return Deck(<MemCard>[
    for (int stage = 0; stage < maps.length; stage++)
      for (final int slot in maps[stage]) MemCard.map(stage, slot, cues),
    for (final String f in core) MemCard.fact(f),
    if (includeProvenance) MemCard.fact('provenance'),
    for (final String s in exportSalts) MemCard.fact('export:$s'),
    for (final String m in misc) MemCard.fact('misc:$m'),
  ]);
}
