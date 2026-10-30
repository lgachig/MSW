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
  });
}
