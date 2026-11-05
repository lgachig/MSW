import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/features/capture/ocr_models.dart';
import 'package:musicsundayworship/music_engine/chord_line_detector.dart';

void main() {
  group('OcrBoundingBox', () {
    test('computes right, bottom and centerY correctly', () {
      const box = OcrBoundingBox(left: 10, top: 20, width: 100, height: 40);
      expect(box.right, 110);
      expect(box.bottom, 60);
      expect(box.centerY, 40);
    });
  });

  group('OcrDocument', () {
    test('formats chord lines above lyrics using coordinate alignment', () {
      const chordLine = OcrLine(
        text: 'C       G',
        boundingBox: OcrBoundingBox(left: 10, top: 20, width: 200, height: 20),
        elements: [
          OcrElement(
            text: 'C',
            boundingBox: OcrBoundingBox(left: 10, top: 20, width: 20, height: 20),
          ),
          OcrElement(
            text: 'G',
            boundingBox: OcrBoundingBox(left: 110, top: 20, width: 20, height: 20),
          ),
        ],
      );

      const lyricLine = OcrLine(
        text: 'Tu amor no cambia',
        boundingBox: OcrBoundingBox(left: 10, top: 45, width: 200, height: 20),
        elements: [
          OcrElement(
            text: 'Tu',
            boundingBox: OcrBoundingBox(left: 10, top: 45, width: 30, height: 20),
          ),
          OcrElement(
            text: 'amor',
            boundingBox: OcrBoundingBox(left: 45, top: 45, width: 50, height: 20),
          ),
          OcrElement(
            text: 'no',
            boundingBox: OcrBoundingBox(left: 100, top: 45, width: 30, height: 20),
          ),
          OcrElement(
            text: 'cambia',
            boundingBox: OcrBoundingBox(left: 135, top: 45, width: 60, height: 20),
          ),
        ],
      );

      final processedChord = OcrProcessedLine(
        line: chordLine,
        chordResult: ChordLineDetector.detect(chordLine.text),
      );

      final processedLyric = OcrProcessedLine(
        line: lyricLine,
        chordResult: ChordLineDetector.detect(lyricLine.text),
      );

      expect(processedChord.isChordLine, isTrue);
      expect(processedLyric.isChordLine, isFalse);

      final doc = OcrDocument(
        blocks: const [],
        lines: [chordLine, lyricLine],
        processedLines: [processedChord, processedLyric],
      );

      final formatted = doc.toChordOverLyricText();
      expect(formatted.contains('Tu amor no cambia'), isTrue);
      expect(formatted.contains('C'), isTrue);
      expect(formatted.contains('G'), isTrue);
    });
  });
}
