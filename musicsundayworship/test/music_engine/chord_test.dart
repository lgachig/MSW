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

    test('resolves shorthand chord variants to standard equivalents', () {
      // A4 -> Asus4
      final a4 = Chord.parse('A4');
      expect(a4, isNotNull);
      expect(a4.toString(), 'Asus4');
      expect(a4!.toLatin().toString(), 'Lasus4');

      // E7(4/9) -> E7sus4(9)
      final e7 = Chord.parse('E7(4/9)');
      expect(e7, isNotNull);
      expect(e7.toString(), 'E7sus4(9)');
      expect(e7!.toLatin().toString(), 'Mi7sus4(9)');

      // A2 -> Asus2
      final a2 = Chord.parse('A2');
      expect(a2?.toString(), 'Asus2');

      // C6/9 and slash chords
      final c69 = Chord.parse('C6/9');
      expect(c69?.toString(), 'C6/9');

      final c69G = Chord.parse('C6/9/G');
      expect(c69G?.toString(), 'C6/9/G');
      expect(c69G?.bass?.toString(), 'G');

      // User requested variants: E7(-), D7M, F5-, C#5+, D4+
      // E7(-) -> Em7 (Mim7)
      final e7minus = Chord.parse('E7(-)');
      expect(e7minus?.toString(), 'Em7');
      expect(e7minus?.toLatin().toString(), 'Mim7');

      // D7M -> Dmaj7 (Remaj7)
      final d7M = Chord.parse('D7M');
      expect(d7M?.toString(), 'Dmaj7');
      expect(d7M?.toLatin().toString(), 'Remaj7');

      final d7MSlash = Chord.parse('D7M/F#');
      expect(d7MSlash?.toString(), 'Dmaj7/F#');
      expect(d7MSlash?.toLatin().toString(), 'Remaj7/Fa#');

      // F5- -> F(b5) (Fa(b5))
      final f5minus = Chord.parse('F5-');
      expect(f5minus?.toString(), 'F(b5)');
      expect(f5minus?.toLatin().toString(), 'Fa(b5)');

      // C#5+ -> C#aug (Do#aug)
      final cs5plus = Chord.parse('C#5+');
      expect(cs5plus?.toString(), 'C#aug');
      expect(cs5plus?.toLatin().toString(), 'Do#aug');

      // D4+ -> Dsus4 (Resus4)
      final d4plus = Chord.parse('D4+');
      expect(d4plus?.toString(), 'Dsus4');
      expect(d4plus?.toLatin().toString(), 'Resus4');
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
