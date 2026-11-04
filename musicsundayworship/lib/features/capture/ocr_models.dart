import 'dart:math';
import 'dart:ui';

import '../../music_engine/chord_line_detector.dart';

/// Bounding box with absolute coordinates in image pixels.
class OcrBoundingBox {
  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory OcrBoundingBox.fromRect(Rect rect) => OcrBoundingBox(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
  );

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerY => top + (height / 2);

  Rect toRect() => Rect.fromLTWH(left, top, width, height);

  @override
  String toString() =>
      'OcrBoundingBox(left: $left, top: $top, width: $width, height: $height)';
}

/// A recognized token / word with its bounding box.
class OcrElement {
  const OcrElement({
    required this.text,
    required this.boundingBox,
  });

  final String text;
  final OcrBoundingBox boundingBox;
}

/// A line of recognized text, containing its word elements.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
  });

  final String text;
  final OcrBoundingBox boundingBox;
  final List<OcrElement> elements;
}

/// A block or paragraph of lines detected by OCR.
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.boundingBox,
    this.lines = const [],
  });

  final String text;
  final OcrBoundingBox boundingBox;
  final List<OcrLine> lines;
}

/// A line classified as chords or lyrics by the music engine.
class OcrProcessedLine {
  const OcrProcessedLine({
    required this.line,
    required this.chordResult,
  });

  final OcrLine line;
  final ChordLineResult chordResult;

  String get text => line.text;
  OcrBoundingBox get boundingBox => line.boundingBox;
  bool get isChordLine => chordResult.isChordLine;
  List<ChordLineToken> get chords => chordResult.tokens;
}

/// Result of OCR extraction, ordered and classified.
class OcrDocument {
  const OcrDocument({
    required this.blocks,
    required this.lines,
    required this.processedLines,
  });

  final List<OcrBlock> blocks;
  final List<OcrLine> lines;
  final List<OcrProcessedLine> processedLines;

  /// Returns plain text representation of lines.
  String get rawText => lines.map((l) => l.text).join('\n');

  /// Formats the document as chord-over-lyric text aligned for [SongTextParser].
  String toChordOverLyricText() {
    final buffer = StringBuffer();
    for (var i = 0; i < processedLines.length; i++) {
      final current = processedLines[i];
      if (current.isChordLine && i + 1 < processedLines.length) {
        final next = processedLines[i + 1];
        if (!next.isChordLine) {
          // Align chords above the lyric line using horizontal coordinates
          buffer.writeln(_alignChordsAboveLyric(current, next));
          buffer.writeln(next.text);
          i++; // Skip next since it was paired
          continue;
        }
      }
      buffer.writeln(current.text);
    }
    return buffer.toString().trimRight();
  }

  static String _alignChordsAboveLyric(
    OcrProcessedLine chordLine,
    OcrProcessedLine lyricLine,
  ) {
    if (lyricLine.text.isEmpty || chordLine.chords.isEmpty) {
      return chordLine.text;
    }

    final lyricLeft = lyricLine.boundingBox.left;
    final lyricWidth = lyricLine.boundingBox.width;
    final charWidth = max(1.0, lyricWidth / lyricLine.text.length);

    final lineChars = List<String>.filled(
      max(chordLine.text.length, lyricLine.text.length + 10),
      ' ',
    );

    for (final chord in chordLine.chords) {
      // Find matching element for coordinate or use proportional column
      final elem = chordLine.line.elements.cast<OcrElement?>().firstWhere(
        (e) => e != null && e.text.contains(chord.text),
        orElse: () => null,
      );

      final col = elem != null
          ? ((elem.boundingBox.left - lyricLeft) / charWidth).round().clamp(0, lineChars.length - chord.text.length)
          : chord.column.clamp(0, lineChars.length - chord.text.length);

      for (var j = 0; j < chord.text.length; j++) {
        if (col + j < lineChars.length) {
          lineChars[col + j] = chord.text[j];
        }
      }
    }

    return lineChars.join('').trimRight();
  }
}
