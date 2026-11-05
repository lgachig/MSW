import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/features/capture/device_ocr_service.dart';
import 'package:musicsundayworship/features/capture/ocr_models.dart';
import 'package:musicsundayworship/features/songs/song_photo_page.dart';

class _TestOcrService extends FakeDeviceOcrService {
  _TestOcrService()
      : super(
          predefinedLines: [
            const OcrLine(
              text: 'G       C',
              boundingBox: OcrBoundingBox(left: 10, top: 10, width: 100, height: 20),
            ),
            const OcrLine(
              text: 'Tu amor no cambia',
              boundingBox: OcrBoundingBox(left: 10, top: 35, width: 200, height: 20),
            ),
          ],
        );
}

void main() {
  testWidgets('renders capture options and triggers on-device OCR', (tester) async {
    final fakeOcr = _TestOcrService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceOcrServiceProvider.overrideWithValue(fakeOcr),
        ],
        child: const MaterialApp(
          home: SongPhotoPage(songTitle: 'Canción de prueba'),
        ),
      ),
    );

    expect(find.text('Digitalizar desde foto'), findsOneWidget);
    expect(find.text('Canción de prueba'), findsOneWidget);
    expect(find.byKey(const Key('pick-from-gallery')), findsOneWidget);
    expect(find.byKey(const Key('take-photo')), findsOneWidget);
  });
}
