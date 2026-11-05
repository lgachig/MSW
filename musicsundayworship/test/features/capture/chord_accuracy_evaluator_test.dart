import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/features/capture/chord_accuracy_evaluator.dart';

void main() {
  group('ChordAccuracyEvaluator', () {
    const evaluator = ChordAccuracyEvaluator(targetAccuracy: 0.90);

    test('evaluates exact match to 1.0 (100%)', () {
      final groundTruth = {
        'title': 'Grita, canta, danza',
        'key': 'Cm',
        'source': 'foto_01.png',
        'lines': [
          {
            'text': 'Grita, canta, danza alegremente en su presencia',
            'chords': [
              {'name': 'Cm', 'position': 0},
              {'name': 'Ab', 'position': 45},
            ],
          },
          {
            'text': 'Gira, salta dando vueltas para Cristo',
            'chords': [
              {'name': 'Bb', 'position': 34},
            ],
          },
        ],
      };

      final detectedResult = {
        'title': 'Grita, canta, danza',
        'key': 'Cm',
        'sections': [
          {
            'name': 'Verso',
            'lines': [
              {
                'text': 'Grita, canta, danza alegremente en su presencia',
                'chords': [
                  {'chord': 'Cm', 'position': 0},
                  {'chord': 'Ab', 'position': 40},
                ],
              },
              {
                'text': 'Gira, salta dando vueltas para Cristo',
                'chords': [
                  {'chord': 'Bb', 'position': 30},
                ],
              },
            ],
          },
        ],
      };

      final result = evaluator.evaluateSingle(
        id: '01',
        groundTruthJson: groundTruth,
        digitizedResultJson: detectedResult,
      );

      expect(result.accuracy, 1.0);
      expect(result.keyMatches, isTrue);
      expect(result.expectedChordsCount, 3);
      expect(result.matchedChordsCount, 3);
      expect(result.comparisons.every((c) => c.isMatched), isTrue);
    });

    test('handles minor variations and extra lines correctly', () {
      final groundTruth = {
        'title': 'Sublime Gracia',
        'key': 'G',
        'source': 'gracia.png',
        'lines': [
          {
            'text': 'Sublime gracia del Señor',
            'chords': [
              {'name': 'G', 'position': 0},
              {'name': 'C', 'position': 10},
              {'name': 'G', 'position': 20},
            ],
          },
        ],
      };

      // 2 chords match, 1 is different (D instead of C)
      final detectedResult = {
        'title': 'Sublime Gracia',
        'key': 'G',
        'sections': [
          {
            'name': 'Verso 1',
            'lines': [
              {
                'text': 'Sublime gracia del Señor',
                'chords': [
                  {'chord': 'G', 'position': 0},
                  {'chord': 'D', 'position': 10},
                  {'chord': 'G', 'position': 20},
                ],
              },
            ],
          },
        ],
      };

      final result = evaluator.evaluateSingle(
        id: 'sample',
        groundTruthJson: groundTruth,
        digitizedResultJson: detectedResult,
      );

      expect(result.expectedChordsCount, 3);
      expect(result.matchedChordsCount, 2);
      expect(result.accuracy, closeTo(2 / 3, 0.01));
    });

    test('recognizes harmonically equivalent chords and notation', () {
      final groundTruth = {
        'title': 'Prueba Armónica',
        'key': 'F#m',
        'lines': [
          {
            'text': 'Al estar en la presencia',
            'chords': [
              {'name': 'A', 'position': 0},
              {'name': 'G#m', 'position': 10},
            ],
          },
        ],
      };

      final detectedResult = {
        'title': 'Prueba Armónica',
        'key': 'Gbm', // Enharmonic of F#m
        'sections': [
          {
            'name': 'Coro',
            'lines': [
              {
                'text': 'Al estar en la presencia',
                'chords': [
                  {'chord': 'A', 'position': 0},
                  {'chord': 'Abm', 'position': 10}, // Enharmonic of G#m
                ],
              },
            ],
          },
        ],
      };

      final result = evaluator.evaluateSingle(
        id: 'harmonic',
        groundTruthJson: groundTruth,
        digitizedResultJson: detectedResult,
      );

      expect(result.keyMatches, isTrue);
      expect(result.accuracy, 1.0);
    });

    test('generates complete markdown report meeting target threshold', () {
      final report = EvaluationReport(
        photoResults: const [
          PhotoEvaluationResult(
            id: '01',
            sourcePhoto: 'foto1.png',
            expectedTitle: 'Canción 1',
            detectedTitle: 'Canción 1',
            expectedKey: 'G',
            detectedKey: 'G',
            keyMatches: true,
            expectedChordsCount: 10,
            detectedChordsCount: 10,
            matchedChordsCount: 10,
            accuracy: 1.0,
            comparisons: [],
          ),
          PhotoEvaluationResult(
            id: '02',
            sourcePhoto: 'foto2.png',
            expectedTitle: 'Canción 2',
            detectedTitle: 'Canción 2',
            expectedKey: 'D',
            detectedKey: 'D',
            keyMatches: true,
            expectedChordsCount: 10,
            detectedChordsCount: 10,
            matchedChordsCount: 9,
            accuracy: 0.90,
            comparisons: [],
          ),
        ],
        totalExpectedChords: 20,
        totalDetectedChords: 20,
        totalMatchedChords: 19,
        overallAccuracy: 0.95,
        keysMatchedCount: 2,
        keyAccuracy: 1.0,
        targetAccuracy: 0.90,
      );

      expect(report.meetsTarget, isTrue);
      final md = report.toMarkdown();
      expect(md, contains('95.0%'));
      expect(md, contains('CUMPLE LA META'));
      expect(md, contains('APROBADO'));
    });
  });
}
