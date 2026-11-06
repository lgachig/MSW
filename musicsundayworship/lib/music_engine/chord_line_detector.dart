import 'chord.dart';

/// A chord found in a line, retaining its exact position in the source.
class ChordLineToken {
  const ChordLineToken({
    required this.text,
    required this.chord,
    required this.start,
    required this.end,
  });

  final String text;
  final Chord chord;

  /// UTF-16 offsets (and therefore Dart [String] offsets) in the source line.
  final int start;
  final int end;

  int get column => start;
}

/// The result of classifying one line of imported or OCR text.
class ChordLineResult {
  const ChordLineResult({
    required this.source,
    required this.isChordLine,
    required this.tokens,
    required this.tokenCount,
  });

  final String source;
  final bool isChordLine;
  final List<ChordLineToken> tokens;
  final int tokenCount;

  List<ChordLineToken> get chords => tokens;
  double get chordRatio => tokenCount == 0 ? 0 : tokens.length / tokenCount;
}

/// Detects chord lines without depending on Flutter or platform services.
class ChordLineDetector {
  const ChordLineDetector();

  static ChordLineResult detect(String line) {
    final found = <ChordLineToken>[];
    var tokenCount = 0;

    // Matches non-whitespace, non-pipe sequences
    final tokenPattern = RegExp(r'[^\s|]+');
    for (final match in tokenPattern.allMatches(line)) {
      final text = match.group(0)!;
      // Skip standalone separators like /, -, –, —
      if (text == '/' || text == '-' || text == '–' || text == '—') continue;

      // Check if text directly forms a valid chord (e.g. E7(-), F5-, C#5+, D7M, D4+)
      final directChord = Chord.parse(text);
      if (directChord != null) {
        tokenCount++;
        found.add(
          ChordLineToken(
            text: text,
            chord: directChord,
            start: match.start,
            end: match.end,
          ),
        );
        continue;
      }

      // If text contains dashes separating multiple chords (e.g. "G-Em" or "C--D")
      if (text.contains('-') || text.contains('–') || text.contains('—')) {
        final subMatches = RegExp(r'[^\s|–—-]+').allMatches(text);
        if (subMatches.length > 1) {
          for (final sub in subMatches) {
            final subText = sub.group(0)!;
            tokenCount++;
            final subChord = Chord.parse(subText);
            if (subChord != null) {
              found.add(
                ChordLineToken(
                  text: subText,
                  chord: subChord,
                  start: match.start + sub.start,
                  end: match.start + sub.end,
                ),
              );
            }
          }
          continue;
        }
      }

      tokenCount++;
    }

    return ChordLineResult(
      source: line,
      isChordLine: found.isNotEmpty && found.length * 2 > tokenCount,
      tokens: List.unmodifiable(found),
      tokenCount: tokenCount,
    );
  }

  ChordLineResult classify(String line) => detect(line);
}

ChordLineResult detectChordLine(String line) => ChordLineDetector.detect(line);
