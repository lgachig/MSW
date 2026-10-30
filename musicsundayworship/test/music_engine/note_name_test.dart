import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/note_name.dart';

void main() {
  group('NoteName', () {
    test('parses American and Latin names and exposes aliases', () {
      expect(NoteName.parse('C#'), NoteName.fromString('C#'));
      expect(NoteName.parse('Solb')?.letter, 'G');
      expect(NoteName.parse('Solb')?.notation, NoteNotation.latin);
      expect(NoteName.parse('Solb')?.toAmerican().toString(), 'Gb');
      expect(NoteName.parse('Gb')?.toLatin().toString(), 'Solb');
    });

    test('rejects invalid names', () {
      for (final value in ['c', 'H', 'Do##', '', 'Sibm']) {
        expect(NoteName.parse(value), isNull);
      }
    });

    test('calculates pitch classes including wrapped flats', () {
      expect(NoteName.pitchClass(const NoteName('C', accidental: 'b')), 11);
      expect(const NoteName('C', accidental: 'b').semitone, 11);
      expect(NoteName.pitchClass(const NoteName('C')), 0);
      expect(NoteName.pitchClass(const NoteName('B')), 11);
    });

    test('supports equality, hash codes and rendering', () {
      const american = NoteName('A', accidental: '#');
      expect(american.toString(), 'A#');
      expect(american.toLatin().toString(), 'La#');
      expect(american, NoteName.fromString('A#'));
      expect(american.hashCode, NoteName.fromString('A#')!.hashCode);
      expect(american == const NoteName('A'), isFalse);
      expect(american == Object(), isFalse);
    });
  });
}
