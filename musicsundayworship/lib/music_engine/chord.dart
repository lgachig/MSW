import 'note_name.dart';

/// A chord with a root, quality and optional slash bass note.
class Chord {
  const Chord({
    required this.root,
    this.quality = '',
    this.bass,
    this.transpositionState,
  });

  final NoteName root;
  final String quality;
  final NoteName? bass;
  final ChordTranspositionState? transpositionState;

  Chord withTranspositionState(ChordTranspositionState? state) => Chord(
    root: root,
    quality: quality,
    bass: bass,
    transpositionState: state,
  );

  /// Reads a chord in American notation, or returns null for invalid text.
  static Chord? parse(String value) {
    final parts = value.split('/');
    if (parts.length > 2 || parts.isEmpty) return null;
    final rootResult = _parseNotePrefix(parts.first);
    if (rootResult == null) return null;
    final root = rootResult.$1;
    final quality = rootResult.$2;
    final bassText = parts.length == 2 ? parts[1] : null;
    final bass = bassText == null ? null : NoteName.parse(bassText);
    if (bassText != null && bass == null) return null;
    if (!_isQuality(quality)) return null;
    return Chord(root: root, quality: quality, bass: bass);
  }

  static Chord? fromString(String value) => parse(value);

  /// Returns this chord rendered with American note names.
  Chord toAmerican() => _withNotation(NoteNotation.american);

  /// Returns this chord rendered with Latin note names.
  Chord toLatin() => _withNotation(NoteNotation.latin);

  Chord inAmericanNotation() => toAmerican();

  Chord inLatinNotation() => toLatin();

  Chord _withNotation(NoteNotation notation) => Chord(
    root: notation == NoteNotation.latin ? root.toLatin() : root.toAmerican(),
    quality: quality,
    bass: bass == null
        ? null
        : notation == NoteNotation.latin
        ? bass!.toLatin()
        : bass!.toAmerican(),
  );

  static (NoteName, String)? _parseNotePrefix(String value) {
    final names = <String>[
      'Sol',
      'Do',
      'Re',
      'Mi',
      'Fa',
      'La',
      'Si',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
    ];
    for (final name in names) {
      for (final accidental in ['#', 'b', '']) {
        final token = '$name$accidental';
        if (!value.startsWith(token)) continue;
        final note = NoteName.parse(token);
        if (note != null) return (note, value.substring(token.length));
      }
    }
    return null;
  }

  static bool _isQuality(String quality) {
    if (quality.isEmpty) return true;
    // Keep the accepted vocabulary explicit so ordinary words are not chords.
    return RegExp(
      r'^(?:(?:(?:m|min|maj|dim|aug|sus2|sus4)?'
      r'(?:6|7|9|11|13)|m|min|maj|dim|aug|\+|sus2|sus4|add9)'
      r'(?:add9|b5|#5|b9|#9|\((?:add9|b5|#5|b9|#9)\))*'
      r'|\((?:add9|b5|#5|b9|#9)\)+)$',
    ).hasMatch(quality);
  }

  @override
  String toString() => '$root$quality${bass == null ? '' : '/$bass'}';

  @override
  bool operator ==(Object other) =>
      other is Chord &&
      other.root == root &&
      other.quality == quality &&
      other.bass == bass;

  @override
  int get hashCode => Object.hash(root, quality, bass);
}

/// Retains the original spellings while a chord is being transposed.
class ChordTranspositionState {
  const ChordTranspositionState({
    required this.root,
    required this.bass,
    required this.semitones,
  });

  final NoteName root;
  final NoteName? bass;
  final int semitones;
}
