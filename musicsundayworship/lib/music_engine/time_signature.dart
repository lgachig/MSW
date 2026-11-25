/// Compases soportados por el metrónomo y motor musical.
class TimeSignature {
  const TimeSignature._({
    required this.numerator,
    required this.denominator,
    required this.label,
    required this.beatsPerBar,
  });

  /// Numerador del compás (ej. 2, 3, 4, 6).
  final int numerator;

  /// Denominador del compás (ej. 4, 8).
  final int denominator;

  /// Representación textual estándar (ej. '2/4', '3/4', '4/4', '6/8').
  final String label;

  /// Número de pulsos visuales por compás.
  final int beatsPerBar;

  static const twoFour = TimeSignature._(
    numerator: 2,
    denominator: 4,
    label: '2/4',
    beatsPerBar: 2,
  );

  static const threeFour = TimeSignature._(
    numerator: 3,
    denominator: 4,
    label: '3/4',
    beatsPerBar: 3,
  );

  static const fourFour = TimeSignature._(
    numerator: 4,
    denominator: 4,
    label: '4/4',
    beatsPerBar: 4,
  );

  static const sixEight = TimeSignature._(
    numerator: 6,
    denominator: 8,
    label: '6/8',
    beatsPerBar: 6,
  );

  /// Lista ordenada de compases comunes soportados.
  static const List<TimeSignature> commonSignatures = [
    twoFour,
    threeFour,
    fourFour,
    sixEight,
  ];

  /// Intenta parsear una cadena textual a [TimeSignature].
  /// Soporta formatos como '4/4', '3/4', '2/4', '6/8', '4:4', '6:8', etc.
  static TimeSignature? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().replaceAll(' ', '');
    for (final sig in commonSignatures) {
      if (sig.label == normalized) return sig;
      if (normalized == '${sig.numerator}:${sig.denominator}') return sig;
    }
    final match = RegExp(r'\b(2/4|3/4|4/4|6/8)\b').firstMatch(normalized);
    if (match != null) {
      return tryParse(match.group(1));
    }
    return null;
  }

  /// Indica si el pulso (1-based) corresponde al primer tiempo con acento principal.
  bool isFirstBeat(int beat) => beat == 1;

  /// Indica si el pulso (1-based) tiene algún acento (primario o secundario en 6/8).
  bool isAccentBeat(int beat) {
    if (beat == 1) return true;
    if (this == sixEight && beat == 4) return true;
    return false;
  }

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          numerator == other.numerator &&
          denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

