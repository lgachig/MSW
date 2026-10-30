/// The notation used when rendering a note.
enum NoteNotation { american, latin }

/// The spelling of a pitch.
class NoteName {
  const NoteName(
    this.letter, {
    this.accidental = '',
    this.notation = NoteNotation.american,
  }) : assert(
         letter == 'A' ||
             letter == 'B' ||
             letter == 'C' ||
             letter == 'D' ||
             letter == 'E' ||
             letter == 'F' ||
             letter == 'G',
       ),
       assert(accidental == '' || accidental == '#' || accidental == 'b');

  final String letter;
  final String accidental;
  final NoteNotation notation;

  /// Parses American notes and Latin notes such as `C`, `F#`, `Bb`, `Do`,
  /// `Sol#`, and `Sib`.
  static NoteName? parse(String value) {
    final american = RegExp(r'^([A-G])([#b]?)$').firstMatch(value);
    if (american != null) {
      return NoteName(american.group(1)!, accidental: american.group(2)!);
    }
    for (final entry in _latinNames.entries) {
      final match = RegExp('^${entry.key}([#b]?)\$').firstMatch(value);
      if (match != null) {
        return NoteName(
          entry.value,
          accidental: match.group(1)!,
          notation: NoteNotation.latin,
        );
      }
    }
    return null;
  }

  static NoteName? fromString(String value) => parse(value);

  NoteName toAmerican() => NoteName(letter, accidental: accidental);

  NoteName toLatin() =>
      NoteName(letter, accidental: accidental, notation: NoteNotation.latin);

  /// The pitch class of this note, with C represented by zero.
  int get semitone => NoteName.pitchClass(this);

  static int pitchClass(NoteName note) {
    const natural = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final offset = note.accidental == '#'
        ? 1
        : note.accidental == 'b'
        ? -1
        : 0;
    return (natural[note.letter]! + offset) % 12 < 0
        ? (natural[note.letter]! + offset) % 12 + 12
        : (natural[note.letter]! + offset) % 12;
  }

  @override
  String toString() {
    if (notation == NoteNotation.american) return '$letter$accidental';
    const latin = {
      'C': 'Do',
      'D': 'Re',
      'E': 'Mi',
      'F': 'Fa',
      'G': 'Sol',
      'A': 'La',
      'B': 'Si',
    };
    return '${latin[letter]}$accidental';
  }

  @override
  bool operator ==(Object other) =>
      other is NoteName &&
      other.letter == letter &&
      other.accidental == accidental;

  @override
  int get hashCode => Object.hash(letter, accidental);

  static const _latinNames = <String, String>{
    'Sol': 'G',
    'Do': 'C',
    'Re': 'D',
    'Mi': 'E',
    'Fa': 'F',
    'La': 'A',
    'Si': 'B',
  };
}
