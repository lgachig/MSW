import 'note_name.dart';

/// A musical key represented by its tonic.
class MusicKey {
  const MusicKey(this.tonic);

  final NoteName tonic;

  static MusicKey? parse(String value) {
    final note = NoteName.parse(value);
    return note == null ? null : MusicKey(note);
  }

  static MusicKey? fromString(String value) => parse(value);

  /// Whether notes in this key are normally written with flats.
  bool get prefersFlats =>
      tonic.accidental == 'b' ||
      const {
        'F',
        'Bb',
        'Eb',
        'Ab',
        'Db',
        'Gb',
        'Cb',
      }.contains(tonic.toString());

  int get semitone => tonic.semitone;

  /// The ascending interval from this key to [other], in semitones.
  int semitonesTo(MusicKey other) => (other.semitone - semitone) % 12;

  int semitonesFrom(MusicKey other) => other.semitonesTo(this);

  @override
  String toString() => tonic.toString();

  @override
  bool operator ==(Object other) => other is MusicKey && other.tonic == tonic;

  @override
  int get hashCode => tonic.hashCode;
}
