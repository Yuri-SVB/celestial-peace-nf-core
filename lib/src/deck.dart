import 'card.dart';

/// Builds the fresh card set for a setup (cpnf-step1-scheduler.md §2,
/// cpnf-lifecycle-and-deck.md §2): one **point** card per stage plus the
/// explicit **fact** cards the user must recall. Pure — no time, no crypto.
///
/// The fact parameters (`m`, `N`, `D`, salts, export salts, provenance, misc)
/// are labels/parameters, not the tacit seed, so drilling them does not weaken
/// coercion-resistance (cpnf-step1-scheduler.md §0.3). No fact *value* is stored
/// on a card here — only its identity; values live in the encrypted setup/deck.
List<MemCard> buildDeck({
  required int stageCount,
  List<String> exportSalts = const <String>[],
  List<String> misc = const <String>[],
  bool includeProvenance = true,
}) {
  final List<MemCard> cards = <MemCard>[];

  // One point card per stage.
  for (int i = 0; i < stageCount; i++) {
    cards.add(MemCard(id: 'point:$i', kind: CardKind.point, stageIndex: i));
  }

  // Core fact cards (§0.3 / §2). `m`, `N`, `D` are exact-recall; `salt` is the
  // σ-date; provenance enables a supply-chain-resistant hard reset.
  const List<String> core = <String>['m', 'N', 'D', 'salt'];
  for (final String f in core) {
    cards.add(_fact(f));
  }
  if (includeProvenance) cards.add(_fact('provenance'));

  // Per-stage user-defined export salts, then misc reminders.
  for (final String s in exportSalts) {
    cards.add(_fact('export:$s'));
  }
  for (final String m in misc) {
    cards.add(_fact('misc:$m'));
  }

  return cards;
}

MemCard _fact(String factId) =>
    MemCard(id: 'fact:$factId', kind: CardKind.fact, factId: factId);
