import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/features/capture/device_ocr_service.dart';
import 'package:musicsundayworship/features/capture/ocr_models.dart';

void main() {
  group('FakeDeviceOcrService', () {
    test('delivers lines to chord detector and classifies chord lines', () async {
      final service = FakeDeviceOcrService(
        predefinedLines: [
          const OcrLine(
            text: 'G      D/F#     Em',
            boundingBox: OcrBoundingBox(left: 10, top: 20, width: 250, height: 18),
          ),
          const OcrLine(
            text: 'Cuán grande es Dios',
            boundingBox: OcrBoundingBox(left: 10, top: 40, width: 250, height: 18),
          ),
          const OcrLine(
            text: 'C      D        G',
            boundingBox: OcrBoundingBox(left: 10, top: 60, width: 250, height: 18),
          ),
          const OcrLine(
            text: 'Cantaré, cuán grande es Dios',
            boundingBox: OcrBoundingBox(left: 10, top: 80, width: 250, height: 18),
          ),
        ],
      );

      final doc = await service.processImage('fake_path.jpg');

      expect(doc.lines.length, 4);
      expect(doc.processedLines.length, 4);

      // Line 0 is chord line
      expect(doc.processedLines[0].isChordLine, isTrue);
      expect(doc.processedLines[0].chords.map((c) => c.text), ['G', 'D/F#', 'Em']);

      // Line 1 is lyric line
      expect(doc.processedLines[1].isChordLine, isFalse);
      expect(doc.processedLines[1].chords, isEmpty);

      // Line 2 is chord line
      expect(doc.processedLines[2].isChordLine, isTrue);
      expect(doc.processedLines[2].chords.map((c) => c.text), ['C', 'D', 'G']);

      // Line 3 is lyric line
      expect(doc.processedLines[3].isChordLine, isFalse);

      final structured = doc.toChordOverLyricText();
      expect(structured.contains('Cuán grande es Dios'), isTrue);
    });

    test('extracts blocks and lines with bounding boxes', () async {
      final service = FakeDeviceOcrService(
        predefinedLines: [
          const OcrLine(
            text: 'A      E',
            boundingBox: OcrBoundingBox(left: 15, top: 30, width: 100, height: 15),
          ),
        ],
      );

      final doc = await service.processImage('dummy.jpg');
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first.boundingBox.width, 500);
      expect(doc.lines.first.boundingBox.left, 15);
      expect(doc.rawText, 'A      E');
    });
  });
}
