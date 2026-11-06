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
  /// Automatically resolves shorthand chord variants (e.g. A4 -> Asus4, A2 -> Asus2, E7(4/9) -> E7sus4(9)).
  static Chord? parse(String value) {
    final components = _parseComponents(value);
    if (components == null) return null;
    return Chord(
      root: components.$1,
      quality: components.$2,
      bass: components.$3,
    );
  }

  static (NoteName, String, NoteName?)? _parseComponents(String value) {
    if (value.isEmpty) return null;

    // Find bass slash outside of parentheses where following token is a NoteName
    int? slashIndex;
    int parenDepth = 0;
    for (int i = value.length - 1; i >= 0; i--) {
      if (value[i] == ')') {
        parenDepth++;
      } else if (value[i] == '(') {
        parenDepth--;
      } else if (value[i] == '/' && parenDepth == 0) {
        final after = value.substring(i + 1);
        if (NoteName.parse(after) != null) {
          slashIndex = i;
          break;
        } else if (after.isEmpty) {
          // e.g. "C/"
          return null;
        }
      }
    }

    final chordPart =
        slashIndex != null ? value.substring(0, slashIndex) : value;
    final bassPart =
        slashIndex != null ? value.substring(slashIndex + 1) : null;

    if (chordPart.contains('/')) {
      final subSlash = chordPart.indexOf('/');
      final isInsideParen = chordPart.indexOf('(') < subSlash &&
          chordPart.indexOf(')') > subSlash;
      if (!isInsideParen &&
          !chordPart.contains('6/9') &&
          !chordPart.contains('4/9')) {
        return null;
      }
    }

    final bass = bassPart != null ? NoteName.parse(bassPart) : null;
    if (bassPart != null && bass == null) return null;

    final rootResult = _parseNotePrefix(chordPart);
    if (rootResult == null) return null;
    final root = rootResult.$1;
    final rawQuality = rootResult.$2;

    final quality = _normalizeQuality(rawQuality);
    if (quality == null) return null;

    return (root, quality, bass);
  }

  static String? _normalizeQuality(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return '';

    // Direct shorthands & equivalents:
    // A4, D4, D4+, D+4 -> sus4
    if (q == '4' ||
        q == '(4)' ||
        q == '4+' ||
        q == '+4' ||
        q == '(4+)' ||
        q == '(+4)') {
      return 'sus4';
    }
    // A2, C2, D2+, D+2 -> sus2
    if (q == '2' ||
        q == '(2)' ||
        q == '2+' ||
        q == '+2' ||
        q == '(2+)' ||
        q == '(+2)') {
      return 'sus2';
    }
    // D7M, 7Maj, 7maj, M7, Maj7 -> maj7
    if (q == '7M' ||
        q == '7Maj' ||
        q == '7maj' ||
        q == 'M7' ||
        q == 'Maj7') {
      return 'maj7';
    }
    // E7(-), E7-, E-7, E7m -> m7
    if (RegExp(r'^(?:7\s*[\(\[]?\s*-\s*[\)\]]?|-7|7m|7-)$').hasMatch(q)) {
      return 'm7';
    }
    // E- -> m
    if (q == '-') return 'm';

    // F5-, F(5-), F(-5) -> (b5)
    if (RegExp(r'^[\(\[]?\s*(?:5\s*-|-\s*5)\s*[\)\]]?$').hasMatch(q)) {
      return '(b5)';
    }

    // C#5+, C#(5+), C#(+5) -> aug
    if (RegExp(r'^[\(\[]?\s*(?:5\s*\+|\+\s*5)\s*[\)\]]?$').hasMatch(q)) {
      return 'aug';
    }

    // 7(5-), 7(-5), 7-5 -> 7(b5)
    if (RegExp(r'^7\s*[\(\[]?\s*(?:5\s*-|-\s*5)\s*[\)\]]?$').hasMatch(q) ||
        q == '7-5') {
      return '7(b5)';
    }

    // m7(5-), m7(-5), m7-5 -> m7(b5)
    if (RegExp(r'^m7\s*[\(\[]?\s*(?:5\s*-|-\s*5)\s*[\)\]]?$').hasMatch(q) ||
        q == 'm7-5') {
      return 'm7(b5)';
    }

    // 7(5+), 7(+5), 7+5 -> 7(#5)
    if (RegExp(r'^7\s*[\(\[]?\s*(?:5\s*\+|\+\s*5)\s*[\)\]]?$').hasMatch(q) ||
        q == '7+5') {
      return '7(#5)';
    }

    // E7(4/9), E7(4,9) -> 7sus4(9)
    if (RegExp(r'^7\s*[\(\[]\s*4\s*[\/,]\s*9\s*[\)\]]$').hasMatch(q)) {
      return '7sus4(9)';
    }
    // E7(4), E7/4 -> 7sus4
    if (RegExp(r'^7\s*[\(\[]\s*4\s*[\)\]]$').hasMatch(q) || q == '7/4') {
      return '7sus4';
    }
    // (4/9) or 4/9 -> sus4(9)
    if (RegExp(r'^[\(\[]?\s*4\s*[\/,]\s*9\s*[\)\]]?$').hasMatch(q)) {
      return 'sus4(9)';
    }
    // 6/9 or (6/9)
    if (RegExp(r'^[\(\[]?\s*6\s*[\/,]\s*9\s*[\)\]]?$').hasMatch(q)) {
      return '6/9';
    }

    if (_isQuality(q)) return q;
    return null;
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
    if (quality == '6/9' || quality == '7sus4(9)' || quality == 'sus4(9)') {
      return true;
    }
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
