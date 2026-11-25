import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/time_signature.dart';

void main() {
  group('TimeSignature', () {
    test('defines supported time signatures with correct beatsPerBar', () {
      expect(TimeSignature.twoFour.beatsPerBar, 2);
      expect(TimeSignature.twoFour.label, '2/4');

      expect(TimeSignature.threeFour.beatsPerBar, 3);
      expect(TimeSignature.threeFour.label, '3/4');

      expect(TimeSignature.fourFour.beatsPerBar, 4);
      expect(TimeSignature.fourFour.label, '4/4');

      expect(TimeSignature.sixEight.beatsPerBar, 6);
      expect(TimeSignature.sixEight.label, '6/8');
    });

    test('tryParse parses standard and relaxed representations', () {
      expect(TimeSignature.tryParse('4/4'), TimeSignature.fourFour);
      expect(TimeSignature.tryParse(' 3/4 '), TimeSignature.threeFour);
      expect(TimeSignature.tryParse('2/4'), TimeSignature.twoFour);
      expect(TimeSignature.tryParse('6/8'), TimeSignature.sixEight);
      expect(TimeSignature.tryParse('4:4'), TimeSignature.fourFour);
      expect(TimeSignature.tryParse('6:8'), TimeSignature.sixEight);
      expect(TimeSignature.tryParse('Compás 4/4'), TimeSignature.fourFour);
      expect(TimeSignature.tryParse('ritmo 6/8 balada'), TimeSignature.sixEight);
      expect(TimeSignature.tryParse(null), isNull);
      expect(TimeSignature.tryParse('invalid'), isNull);
    });

    test('isFirstBeat identifies beat 1', () {
      expect(TimeSignature.fourFour.isFirstBeat(1), isTrue);
      expect(TimeSignature.fourFour.isFirstBeat(2), isFalse);
      expect(TimeSignature.fourFour.isFirstBeat(3), isFalse);
      expect(TimeSignature.fourFour.isFirstBeat(4), isFalse);
    });

    test('isAccentBeat identifies primary and compound accents', () {
      expect(TimeSignature.fourFour.isAccentBeat(1), isTrue);
      expect(TimeSignature.fourFour.isAccentBeat(2), isFalse);

      // In 6/8, beat 1 (primary) and beat 4 (secondary) have accents
      expect(TimeSignature.sixEight.isAccentBeat(1), isTrue);
      expect(TimeSignature.sixEight.isAccentBeat(2), isFalse);
      expect(TimeSignature.sixEight.isAccentBeat(3), isFalse);
      expect(TimeSignature.sixEight.isAccentBeat(4), isTrue);
      expect(TimeSignature.sixEight.isAccentBeat(5), isFalse);
    });

    test('equality and toString', () {
      expect(TimeSignature.fourFour == TimeSignature.tryParse('4/4'), isTrue);
      expect(TimeSignature.fourFour.toString(), '4/4');
    });
  });
}

