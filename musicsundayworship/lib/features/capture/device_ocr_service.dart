import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../music_engine/chord_line_detector.dart';
import 'ocr_models.dart';

/// Contract for on-device OCR without network connectivity.
abstract interface class DeviceOcrService {
  Future<OcrDocument> processImage(String imagePath);
  void dispose();
}

/// On-device OCR using Google ML Kit Text Recognition (Latin script).
class MlKitDeviceOcrService implements DeviceOcrService {
  MlKitDeviceOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ??
            TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<OcrDocument> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final blocks = <OcrBlock>[];
    final allLines = <OcrLine>[];

    for (final mlBlock in recognizedText.blocks) {
      final blockLines = <OcrLine>[];
      for (final mlLine in mlBlock.lines) {
        final elements = mlLine.elements
            .map(
              (e) => OcrElement(
                text: e.text,
                boundingBox: OcrBoundingBox.fromRect(e.boundingBox),
              ),
            )
            .toList()
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

        final line = OcrLine(
          text: mlLine.text,
          boundingBox: OcrBoundingBox.fromRect(mlLine.boundingBox),
          elements: List.unmodifiable(elements),
        );
        blockLines.add(line);
        allLines.add(line);
      }

      blocks.add(
        OcrBlock(
          text: mlBlock.text,
          boundingBox: OcrBoundingBox.fromRect(mlBlock.boundingBox),
          lines: List.unmodifiable(blockLines),
        ),
      );
    }

    // Sort lines from top to bottom based on vertical coordinate
    allLines.sort((a, b) {
      final yDiff = a.boundingBox.top.compareTo(b.boundingBox.top);
      if (yDiff != 0) return yDiff;
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    // Deliver each line to ChordLineDetector
    final processedLines = allLines.map((line) {
      final chordResult = ChordLineDetector.detect(line.text);
      return OcrProcessedLine(line: line, chordResult: chordResult);
    }).toList();

    return OcrDocument(
      blocks: List.unmodifiable(blocks),
      lines: List.unmodifiable(allLines),
      processedLines: List.unmodifiable(processedLines),
    );
  }

  @override
  void dispose() {
    _recognizer.close();
  }
}

/// Simulated OCR service for unit tests and local verification.
class FakeDeviceOcrService implements DeviceOcrService {
  FakeDeviceOcrService({List<OcrLine>? predefinedLines})
      : _lines = predefinedLines ?? const [];

  final List<OcrLine> _lines;

  @override
  Future<OcrDocument> processImage(String imagePath) async {
    final processed = _lines.map((line) {
      final chordResult = ChordLineDetector.detect(line.text);
      return OcrProcessedLine(line: line, chordResult: chordResult);
    }).toList();

    return OcrDocument(
      blocks: [
        OcrBlock(
          text: _lines.map((l) => l.text).join('\n'),
          boundingBox: const OcrBoundingBox(left: 0, top: 0, width: 500, height: 500),
          lines: _lines,
        ),
      ],
      lines: _lines,
      processedLines: processed,
    );
  }

  @override
  void dispose() {}
}

/// Provider for on-device OCR service.
final deviceOcrServiceProvider = Provider<DeviceOcrService>((ref) {
  final service = MlKitDeviceOcrService();
  ref.onDispose(service.dispose);
  return service;
});
