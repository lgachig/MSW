import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/music_key_detector.dart';

void main() {
  group('MusicKeyDetector - Key Detection', () {
    test('detects G major from G-D-Em-C progression', () {
      final key = MusicKeyDetector.detectKey(['G', 'D', 'Em', 'C']);
      expect(key, 'G');
    });

    test('detects D major from D-G-A-Bm progression', () {
      final key = MusicKeyDetector.detectKey(['D', 'G', 'A', 'Bm']);
      expect(key, 'D');
    });

    test('detects E major from E-B-C#m-A progression', () {
      final key = MusicKeyDetector.detectKey(['E', 'B', 'C#m', 'A']);
      expect(key, 'E');
    });

    test('detects C major from C-F-G-Am progression', () {
      final key = MusicKeyDetector.detectKey(['C', 'F', 'G', 'Am']);
      expect(key, 'C');
    });

    test('detects F major from F-Bb-C-Dm progression', () {
      final key = MusicKeyDetector.detectKey(['F', 'Bb', 'C', 'Dm']);
      expect(key, 'F');
    });

    test('detects A minor from Am-Dm-E-F progression', () {
      final key = MusicKeyDetector.detectKey(['Am', 'Dm', 'E', 'F']);
      expect(key, 'Am');
    });

    test('detects E minor from Em-C-G-D progression starting on Em', () {
      final key = MusicKeyDetector.detectKey(['Em', 'C', 'G', 'D', 'Em']);
      expect(key, 'Em');
    });

    test('detects key from Latin notation chords', () {
      final key = MusicKeyDetector.detectKey(['Sol', 'Do', 'Re', 'Mim']);
      expect(key, 'G');
    });

    test('returns null when chords list is empty', () {
      final key = MusicKeyDetector.detectKey([]);
      expect(key, isNull);
    });
  });

  group('MusicKeyDetector - Key Verification', () {
    test('verifies coherent key as matching', () {
      final result = MusicKeyDetector.verifyKey('G', ['G', 'C', 'D', 'Em']);
      expect(result.matchesCurrentKey, isTrue);
      expect(result.detectedKey, 'G');
      expect(result.confidence, greaterThanOrEqualTo(0.6));
      expect(result.explanation, contains('Tonalidad coherente'));
    });

    test('detects mismatch and suggests correct key when current key is wrong', () {
      // User or fallback has 'G', but chords are D-A-Bm-G (clearly D major)
      final result = MusicKeyDetector.verifyKey('G', ['D', 'A', 'Bm', 'G', 'D']);
      expect(result.matchesCurrentKey, isFalse);
      expect(result.detectedKey, 'D');
      expect(result.explanation, contains('sugiere la tonalidad de D'));
      expect(result.suggestedKeys, contains('D'));
    });

    test('handles minor key verification', () {
      final result = MusicKeyDetector.verifyKey('Am', ['Am', 'Dm', 'E7', 'Am']);
      expect(result.matchesCurrentKey, isTrue);
      expect(result.detectedKey, 'Am');
    });

    test('handles empty chords gracefully', () {
      final result = MusicKeyDetector.verifyKey('D', []);
      expect(result.matchesCurrentKey, isTrue);
      expect(result.detectedKey, 'D');
    });
  });
}

