/// The spelling of a pitch in American notation.
class NoteName {
  const NoteName(this.letter, {this.accidental = ''})
    : assert(
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

  /// Parses a note such as `C`, `F#`, or `Bb`.
  static NoteName? parse(String value) {
    final match = RegExp(r'^([A-G])([#b]?)$').firstMatch(value);
    if (match == null) return null;
    return NoteName(match.group(1)!, accidental: match.group(2)!);
  }

  static NoteName? fromString(String value) => parse(value);

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
  String toString() => '$letter$accidental';

  @override
  bool operator ==(Object other) =>
      other is NoteName &&
      other.letter == letter &&
      other.accidental == accidental;

  @override
  int get hashCode => Object.hash(letter, accidental);
}
