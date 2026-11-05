import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/features/capture/device_ocr_service.dart';
import 'package:musicsundayworship/features/capture/ocr_models.dart';
import 'package:musicsundayworship/features/capture/offline_photo_queue.dart';
import 'package:musicsundayworship/features/capture/remote_digitize_service.dart';
import 'package:musicsundayworship/features/songs/song_photo_page.dart';

class _TestOcrService extends FakeDeviceOcrService {
  _TestOcrService()
    : super(
        predefinedLines: [
          const OcrLine(
            text: 'G       C',
            boundingBox: OcrBoundingBox(
              left: 10,
              top: 10,
              width: 100,
              height: 20,
            ),
          ),
          const OcrLine(
            text: 'Tu amor no cambia',
            boundingBox: OcrBoundingBox(
              left: 10,
              top: 35,
              width: 200,
              height: 20,
            ),
          ),
        ],
      );
}

void main() {
  testWidgets('renders capture options and triggers on-device OCR', (
    tester,
  ) async {
    final fakeOcr = _TestOcrService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceOcrServiceProvider.overrideWithValue(fakeOcr)],
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

  testWidgets('highlights invalid chords and displays their validity rate', (
    tester,
  ) async {
    const song = DigitizedSong(
      title: 'Canto de prueba',
      key: 'G',
      sections: [
        DigitizedSection(
          name: 'Verso',
          lines: [
            DigitizedLine(
              text: 'Tu amor permanece',
              chords: [
                DigitizedChord(chord: 'G', position: 0),
                DigitizedChord(chord: 'Hx', position: 5),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DigitizedSongChordReview(song: song)),
      ),
    );

    expect(find.text('Acordes válidos: 1/2 (50%)'), findsOneWidget);
    expect(find.text('Hx · revisar'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final invalidChip = tester.widget<Chip>(
      find.byKey(const Key('chord-review-1')),
    );
    expect(invalidChip.backgroundColor, Colors.red.shade100);
  });

  testWidgets('enqueues photo manually when offline enqueue button is tapped', (
    tester,
  ) async {
    final queueRepo = InMemoryPhotoQueueRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoQueueRepositoryProvider.overrideWithValue(queueRepo),
        ],
        child: const MaterialApp(
          home: SongPhotoPage(
            songTitle: 'Canción Offline',
            initialCroppedPath: '/virtual/cropped_test.jpg',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('enqueue-offline')), findsOneWidget);
    await tester.tap(find.byKey(const Key('enqueue-offline')));
    await tester.pump();

    final queued = await queueRepo.getAll();
    expect(queued.length, 1);
    expect(queued.first.songTitle, 'Canción Offline');
    expect(queued.first.status, QueueStatus.pending);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Foto guardada en la cola sin conexión. Se procesará al reconectar.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'automatically enqueues photo when digitize-ai fails due to network outage',
    (tester) async {
      final queueRepo = InMemoryPhotoQueueRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoQueueRepositoryProvider.overrideWithValue(queueRepo),
            remoteDigitizeServiceProvider.overrideWithValue(
              _OfflineFailingDigitizeService(),
            ),
          ],
          child: const MaterialApp(
            home: SongPhotoPage(
              songTitle: 'Modo Avión Canto',
              initialCroppedPath: '/virtual/cropped_offline.jpg',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('digitize-ai')), findsOneWidget);
      await tester.tap(find.byKey(const Key('digitize-ai')));
      await tester.pump();

      final queued = await queueRepo.getAll();
      expect(queued.length, 1);
      expect(queued.first.songTitle, 'Modo Avión Canto');
      expect(queued.first.status, QueueStatus.pending);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
    },
  );
}

class _OfflineFailingDigitizeService implements RemoteDigitizeService {
  @override
  Future<DigitizedSong> digitize(String imagePath) async {
    throw const SocketException('Network is unreachable');
  }
}
