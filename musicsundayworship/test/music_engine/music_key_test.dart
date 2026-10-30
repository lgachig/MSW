import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/music_key.dart';

void main() {
  group('MusicKey', () {
    test('parses, aliases and renders tonic', () {
      final key = MusicKey.parse('Eb')!;
      expect(MusicKey.fromString('Eb'), key);
      expect(key.toString(), 'Eb');
      expect(key.semitone, 3);
      expect(MusicKey.parse('not-a-key'), isNull);
    });

    test('identifies flat-preferred keys', () {
      for (final name in ['F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb', 'Ab']) {
        expect(MusicKey.parse(name)!.prefersFlats, isTrue, reason: name);
      }
      for (final name in ['C', 'G', 'D', 'A', 'E', 'B']) {
        expect(MusicKey.parse(name)!.prefersFlats, isFalse, reason: name);
      }
      expect(MusicKey.parse('F#')!.prefersFlats, isFalse);
    });

    test('calculates ascending and reverse intervals', () {
      final c = MusicKey.parse('C')!;
      final b = MusicKey.parse('B')!;
      expect(c.semitonesTo(b), 11);
      expect(b.semitonesTo(c), 1);
      expect(c.semitonesTo(c), 0);
      expect(c.semitonesFrom(b), 1);
    });

    test('supports equality and hash codes', () {
      final c = MusicKey.parse('C')!;
      expect(c, MusicKey.fromString('C'));
      expect(c.hashCode, MusicKey.fromString('C')!.hashCode);
      expect(c == MusicKey.parse('D'), isFalse);
      expect(c == Object(), isFalse);
    });
  });
}
