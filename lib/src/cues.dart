/// A map's landmark cues (cpnf-maintenance-bundles.md §1).
///
/// The route is great-wall-core's landmark path for the map's point, under ρ
/// (`rhoNum / rhoDen`) and the badness exponent: values from the engine's
/// lists of choices, stored as values so the route stays reproducible. CPNF
/// stores them; the app computes and draws the route. [visible] is how many of
/// the route's stops before the leaf are shown, the shallowest hidden first
/// (null: all). The leaf's own stop is never shown in a review: it is the
/// answer.
///
/// With stops still shown, an attempt is practice; once [visible] is 0 the
/// map is unaided and its attempts are graded.
library;

class Cues {
  const Cues({
    required this.rhoNum,
    required this.rhoDen,
    required this.exponent,
    this.visible,
  })  : assert(rhoDen > 0),
        assert(visible == null || visible >= 0);

  final int rhoNum;
  final int rhoDen;
  final int exponent;

  /// Stops shown before the leaf; null for all of them.
  final int? visible;

  /// No stop shown: attempts are graded.
  bool get unaided => visible == 0;

  /// A new route. It shows different stops, so every stop shows again.
  Cues withRoute({
    required int rhoNum,
    required int rhoDen,
    required int exponent,
  }) =>
      Cues(rhoNum: rhoNum, rhoDen: rhoDen, exponent: exponent);

  /// The same route with [visible] stops shown (null: all).
  Cues withVisible(int? visible) => Cues(
        rhoNum: rhoNum,
        rhoDen: rhoDen,
        exponent: exponent,
        visible: visible,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rhoNum': rhoNum,
        'rhoDen': rhoDen,
        'exponent': exponent,
        if (visible != null) 'visible': visible,
      };

  /// Throws a [FormatException] that echoes no value on any bad field.
  factory Cues.fromJson(Map<String, dynamic> json) {
    final Object? num = json['rhoNum'];
    final Object? den = json['rhoDen'];
    final Object? exponent = json['exponent'];
    final Object? visible = json['visible'];
    if (num is! int ||
        den is! int ||
        den <= 0 ||
        exponent is! int ||
        (visible != null && (visible is! int || visible < 0))) {
      throw const FormatException('bad cues');
    }
    return Cues(
      rhoNum: num,
      rhoDen: den,
      exponent: exponent,
      visible: visible as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Cues &&
      other.rhoNum == rhoNum &&
      other.rhoDen == rhoDen &&
      other.exponent == exponent &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(rhoNum, rhoDen, exponent, visible);

  @override
  String toString() => 'Cues(<redacted>)';
}
