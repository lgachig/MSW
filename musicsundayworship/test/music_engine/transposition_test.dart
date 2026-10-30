import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/music_engine.dart';

void main() {
  group('Transposer', () {
    test('moves roots and slash basses', () {
      expect(Transposer.transpose(Chord.parse('D/F#')!, 2).toString(), 'E/G#');
      expect(Transposer.transpose(Chord.parse('D/F#')!, -2).toString(), 'C/E');
    });

    test('uses the destination key spelling', () {
      expect(
        Transposer.transposeToKey(
          Chord.parse('Em')!,
          MusicKey.parse('G')!,
          MusicKey.parse('A')!,
        ).toString(),
        'F#m',
      );
      expect(
        Transposer.transposeToKey(
          Chord.parse('D')!,
          MusicKey.parse('G')!,
          MusicKey.parse('Eb')!,
        ).toString(),
        'Bb',
      );
      expect(
        Transposer.transposeToKey(
          Chord.parse('Em')!,
          MusicKey.parse('G')!,
          MusicKey.parse('Eb')!,
        ).toString(),
        'Cm',
      );
    });

    test('calculates intervals and wraps octaves', () {
      expect(MusicKey.parse('G')!.semitonesTo(MusicKey.parse('A')!), 2);
      expect(MusicKey.parse('A')!.semitonesTo(MusicKey.parse('G')!), 10);
      expect(Transposer.transpose(Chord.parse('C')!, 12).toString(), 'C');
      expect(Transposer.transpose(Chord.parse('C')!, -12).toString(), 'C');
    });

    test('restores original sharp and flat spellings on a round trip', () {
      for (final name in ['C#', 'Bb']) {
        final chord = Chord.parse(name)!;
        final moved = Transposer.transpose(chord, 1);
        expect(Transposer.transpose(moved, -1).toString(), name);
      }
    });

    test('restores root and slash bass spellings on a round trip', () {
      final chord = Chord.parse('Db/F#')!;
      final moved = Transposer.transpose(chord, 2);
      expect(Transposer.transpose(moved, -2).toString(), 'Db/F#');
    });
  });
}
