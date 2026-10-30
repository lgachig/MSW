import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/chord.dart';
import 'package:musicsundayworship/music_engine/note_name.dart';

void main() {
  group('Chord', () {
    for (final text in [
      'C',
      'Am',
      'G7',
      'Cmaj7',
      'Dsus4',
      'Cadd9',
      'Csus2',
      'C6',
      'C9',
      'C11',
      'C13',
      'Cdim',
      'Caug',
      'C+',
      'C(b5)',
      'C7(b5)',
      'F#m',
      'Bb',
      'Am/G',
      'D/F#',
      'C7b5',
    ]) {
      test('reads and writes $text', () {
        expect(Chord.parse(text)?.toString(), text);
      });
    }

    for (final text in [
      'Hola',
      'am',
      'C/',
      'C//G',
      'H7',
      'C#b',
      'C123',
      'Cadd11',
      'C7(foo)',
      'C()',
    ]) {
      test('rejects $text', () {
        expect(Chord.parse(text), isNull);
      });
    }

    test('reads and writes Latin chords with accidentals and basses', () {
      for (final text in ['Sol#m', 'Sib', 'Fa#', 'Rem/Fa']) {
        expect(Chord.parse(text)?.toString(), text);
      }
    });

    test('converts notation without changing quality or bass', () {
      final latin = Chord.parse('Rem/Fa')!;
      expect(latin.toAmerican().toString(), 'Dm/F');
      expect(latin.toAmerican().toLatin().toString(), 'Rem/Fa');
      expect(Chord.parse('Cmaj7/E')!.toLatin().toString(), 'Domaj7/Mi');
      final complex = Chord.parse('Soladd9/Sib')!;
      expect(complex.toAmerican().toString(), 'Gadd9/Bb');
      expect(complex.toAmerican().toLatin().toString(), 'Soladd9/Sib');
    });

    test('does not interpret lyric words as chords', () {
      for (final text in ['la', 'mi', 'Hola']) {
        expect(Chord.parse(text), isNull);
      }
    });

    test('supports aliases, equality and transposition state', () {
      final chord = Chord.fromString('C7/E')!;
      expect(chord.inAmericanNotation(), chord);
      expect(chord.inLatinNotation().toString(), 'Do7/Mi');
      expect(chord, Chord.parse('C7/E'));
      expect(chord.hashCode, Chord.parse('C7/E')!.hashCode);
      expect(chord == Chord.parse('C/E'), isFalse);
      expect(chord == Object(), isFalse);

      const state = ChordTranspositionState(
        root: NoteName('C'),
        bass: NoteName('E'),
        semitones: 2,
      );
      final retained = chord.withTranspositionState(state);
      expect(retained.transpositionState, same(state));
      expect(retained.toString(), 'C7/E');
    });

    test('rejects malformed basses and empty values', () {
      for (final value in ['', 'C/H', 'C//', '/C']) {
        expect(Chord.parse(value), isNull);
      }
    });
  });
}
