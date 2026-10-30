import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/chord_line_detector.dart';

void main() {
  group('ChordLineDetector', () {
    test('classifies a chord line and preserves columns', () {
      final result = ChordLineDetector.detect('G   D   Em  C');

      expect(result.isChordLine, isTrue);
      expect(result.chords.map((token) => token.text), ['G', 'D', 'Em', 'C']);
      expect(result.chords.map((token) => token.column), [0, 4, 8, 12]);
      expect(result.chords.map((token) => token.end), [1, 5, 10, 13]);
    });

    test('rejects lyric text', () {
      final result = detectChordLine('Tómalo, tómalo todo');

      expect(result.isChordLine, isFalse);
      expect(result.chords, isEmpty);
      expect(result.tokenCount, 3);
    });

    test('supports separators and slash basses', () {
      final result = detectChordLine('G | D/F# - Em / C');

      expect(result.isChordLine, isTrue);
      expect(result.chords.map((token) => token.text), [
        'G',
        'D/F#',
        'Em',
        'C',
      ]);
      expect(result.chords.map((token) => token.column), [0, 4, 11, 16]);
    });

    test('handles mixed lines using a majority of valid chords', () {
      expect(detectChordLine('G toma D').isChordLine, isTrue);
      expect(detectChordLine('G toma').isChordLine, isFalse);
      expect(detectChordLine('G | toma').isChordLine, isFalse);
    });

    test('supports Latin and complex chords', () {
      final result = detectChordLine('Sol#m   Domaj7/Mi   Sib7(b5)');

      expect(result.isChordLine, isTrue);
      expect(
        result.chords.map((token) => token.chord.toAmerican().toString()),
        ['G#m', 'Cmaj7/E', 'Bb7(b5)'],
      );
    });
  });
}
