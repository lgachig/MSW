import 'chord.dart';
import 'note_name.dart';

class KeyVerificationResult {
  const KeyVerificationResult({
    required this.detectedKey,
    required this.confidence,
    required this.matchesCurrentKey,
    required this.explanation,
    required this.suggestedKeys,
  });

  final String detectedKey;
  final double confidence;
  final bool matchesCurrentKey;
  final String explanation;
  final List<String> suggestedKeys;
}

/// Intelligent harmonic key detector and analyzer for songs.
class MusicKeyDetector {
  const MusicKeyDetector._();

  static const List<String> commonMajorKeys = [
    'C',
    'G',
    'D',
    'A',
    'E',
    'B',
    'F#',
    'F',
    'Bb',
    'Eb',
    'Ab',
    'Db',
  ];

  static const List<String> commonMinorKeys = [
    'Am',
    'Em',
    'Bm',
    'F#m',
    'C#m',
    'G#m',
    'Dm',
    'Gm',
    'Cm',
    'Fm',
    'Bbm',
    'Ebm',
  ];

  static const List<String> allStandardKeys = [
    ...commonMajorKeys,
    ...commonMinorKeys,
  ];

  /// Detects the most likely musical key from a list of chord names.
  static String? detectKey(Iterable<String> chords) {
    final parsedChords = chords
        .map((c) => Chord.parse(c.trim()))
        .whereType<Chord>()
        .toList();
    if (parsedChords.isEmpty) return null;

    final scores = <String, double>{};
    for (final key in allStandardKeys) {
      scores[key] = _scoreKey(key, parsedChords);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty || sorted.first.value <= 0) {
      return parsedChords.first.root.toAmerican().toString();
    }

    return sorted.first.key;
  }

  /// Verifies a given [currentKey] against the chord progression in [chords].
  static KeyVerificationResult verifyKey(
    String? currentKey,
    Iterable<String> chords,
  ) {
    final parsedChords = chords
        .map((c) => Chord.parse(c.trim()))
        .whereType<Chord>()
        .toList();

    if (parsedChords.isEmpty) {
      final safeKey =
          (currentKey != null && currentKey.trim().isNotEmpty)
              ? currentKey.trim()
              : 'G';
      return KeyVerificationResult(
        detectedKey: safeKey,
        confidence: 0.5,
        matchesCurrentKey: true,
        explanation: 'No hay acordes suficientes para análisis armónico.',
        suggestedKeys: [safeKey],
      );
    }

    final scores = <String, double>{};
    for (final key in allStandardKeys) {
      scores[key] = _scoreKey(key, parsedChords);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestKey = sorted.first.key;
    final topScore = sorted.first.value;
    final secondScore = sorted.length > 1 ? sorted[1].value : 0.0;

    final confidence = topScore > 0
        ? ((topScore / (topScore + secondScore.clamp(0, double.infinity) + 1.0)) * 1.5)
            .clamp(0.4, 0.99)
        : 0.5;

    final normalizedCurrent = _normalizeKeyName(currentKey);
    final normalizedDetected = _normalizeKeyName(bestKey);
    final matches =
        normalizedCurrent != null && normalizedCurrent == normalizedDetected;

    final uniqueRoots = parsedChords.map((c) => c.toString()).toSet().take(5).join(', ');

    final explanation = matches
        ? 'Tonalidad coherente con la progresión armónica ($uniqueRoots).'
        : 'La progresión ($uniqueRoots) sugiere la tonalidad de $bestKey.';

    final suggested = sorted.take(4).map((e) => e.key).toList();

    return KeyVerificationResult(
      detectedKey: bestKey,
      confidence: confidence,
      matchesCurrentKey: matches,
      explanation: explanation,
      suggestedKeys: suggested,
    );
  }

  static double _scoreKey(String key, List<Chord> chords) {
    final isMinor = key.endsWith('m') && !key.endsWith('maj');
    final tonicName = isMinor ? key.substring(0, key.length - 1) : key;
    final tonicNote = NoteName.parse(tonicName);
    if (tonicNote == null) return 0.0;

    final tonicPitch = tonicNote.semitone;
    double score = 0.0;

    final diatonicIntervals = isMinor
        ? const {0: 4.0, 3: 2.0, 5: 2.5, 7: 3.5, 8: 2.5, 10: 2.0, 2: 1.0, 11: 1.5}
        : const {0: 4.0, 2: 2.0, 4: 1.5, 5: 3.0, 7: 3.5, 9: 2.5, 11: 1.0};

    for (var i = 0; i < chords.length; i++) {
      final chord = chords[i];
      final interval = (chord.root.semitone - tonicPitch + 12) % 12;
      final chordIsMinor =
          chord.quality.startsWith('m') && !chord.quality.startsWith('maj');

      if (diatonicIntervals.containsKey(interval)) {
        var baseWeight = diatonicIntervals[interval]!;

        if (interval == 0) {
          if (isMinor == chordIsMinor) {
            baseWeight += 1.5;
          } else {
            baseWeight -= 2.0;
          }
        } else if (!isMinor) {
          if ((interval == 2 || interval == 4 || interval == 9) && chordIsMinor) {
            baseWeight += 1.0;
          } else if ((interval == 5 || interval == 7) && !chordIsMinor) {
            baseWeight += 1.0;
          }
        } else {
          if (interval == 5 && chordIsMinor) {
            baseWeight += 1.0;
          } else if ((interval == 3 || interval == 8) && !chordIsMinor) {
            baseWeight += 1.0;
          }
        }

        if (i == 0 && interval == 0) {
          baseWeight += 3.5;
        }
        if (i == chords.length - 1 && interval == 0) {
          baseWeight += 2.5;
        }

        score += baseWeight;
      } else {
        score -= 1.0;
      }
    }

    return score;
  }

  static String? _normalizeKeyName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    final isMinor =
        trimmed.toLowerCase().endsWith('m') && !trimmed.toLowerCase().endsWith('maj');
    final rootPart = isMinor ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final note = NoteName.parse(rootPart);
    if (note == null) return trimmed;
    return '${note.toAmerican()}${isMinor ? 'm' : ''}';
  }
}

