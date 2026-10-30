import 'chord.dart';
import 'music_key.dart';
import 'note_name.dart';

/// Transposes chord pitches without changing their quality.
class Transposer {
  const Transposer();

  /// Moves [chord] by [semitones]. A [targetKey] controls enharmonic spelling.
  static Chord transpose(Chord chord, int semitones, {MusicKey? targetKey}) {
    final previous = chord.transpositionState;
    final original =
        previous ??
        ChordTranspositionState(
          root: chord.root,
          bass: chord.bass,
          semitones: 0,
        );
    final accumulated = (original.semitones + semitones) % 12;
    if (targetKey == null && previous != null && accumulated == 0) {
      return Chord(
        root: original.root,
        quality: chord.quality,
        bass: original.bass,
      );
    }

    final flats =
        targetKey?.prefersFlats ??
        (chord.root.accidental == 'b' || chord.bass?.accidental == 'b');
    final result = Chord(
      root: _move(chord.root, semitones, preferFlats: flats),
      quality: chord.quality,
      bass: chord.bass == null
          ? null
          : _move(chord.bass!, semitones, preferFlats: flats),
    );
    return result.withTranspositionState(
      accumulated == 0
          ? null
          : ChordTranspositionState(
              root: original.root,
              bass: original.bass,
              semitones: accumulated,
            ),
    );
  }

  /// Moves a chord from [sourceKey] to [targetKey].
  static Chord transposeToKey(
    Chord chord,
    MusicKey sourceKey,
    MusicKey targetKey,
  ) => transpose(chord, sourceKey.semitonesTo(targetKey), targetKey: targetKey);

  Chord move(Chord chord, int semitones, {MusicKey? targetKey}) =>
      transpose(chord, semitones, targetKey: targetKey);

  Chord toKey(Chord chord, MusicKey sourceKey, MusicKey targetKey) =>
      transposeToKey(chord, sourceKey, targetKey);

  static NoteName _move(
    NoteName note,
    int semitones, {
    required bool preferFlats,
  }) {
    final pitch = (note.semitone + semitones) % 12 < 0
        ? (note.semitone + semitones) % 12 + 12
        : (note.semitone + semitones) % 12;
    const sharps = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    const flats = [
      'C',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'Gb',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ];
    return NoteName.parse((preferFlats ? flats : sharps)[pitch])!;
  }
}
