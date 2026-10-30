import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/chord.dart';

void main() {
  group('Chord', () {
    for (final text in [
      'C',
      'Am',
      'G7',
      'Cmaj7',
      'Dsus4',
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

    for (final text in ['Hola', 'am', 'C/', 'C//G', 'H7', 'C#b']) {
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
    });

    test('does not interpret lyric words as chords', () {
      for (final text in ['la', 'mi', 'Hola']) {
        expect(Chord.parse(text), isNull);
      }
    });
  });
}
