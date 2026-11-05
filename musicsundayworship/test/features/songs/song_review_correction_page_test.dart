import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/capture/offline_photo_queue.dart';
import 'package:musicsundayworship/features/capture/remote_digitize_service.dart';
import 'package:musicsundayworship/features/songs/song_review_correction_page.dart';

class _MockSongRepository implements SongRepository {
  SongDocument? createdSong;
  SongDocument? updatedSong;

  @override
  Future<SongDocument> create(SongDocument song) async {
    createdSong = song;
    return song.copyWith(id: 123);
  }

  @override
  Future<SongDocument> update(SongDocument song) async {
    updatedSong = song;
    return song;
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<List<SongDocument>> readAll() async => [];

  @override
  Future<SongDocument?> read(int id) async => null;

  @override
  Future<SongArrangement> createArrangement(SongArrangement a) =>
      throw UnimplementedError();

  @override
  Future<List<SongArrangement>> readArrangements(int songId) =>
      throw UnimplementedError();

  @override
  Future<SongArrangement> updateArrangement(SongArrangement a) =>
      throw UnimplementedError();

  @override
  Future<SongDocument> updatePhotoPath(int songId, String? photoPath) =>
      throw UnimplementedError();

  @override
  Stream<List<SongDocument>> watchAll() => Stream.value([]);
}

const _testDigitizedSong = DigitizedSong(
  title: 'Canto de Gracia',
  key: 'E',
  sections: [
    DigitizedSection(
      name: 'Verso',
      lines: [
        DigitizedLine(
          text: 'Sublime gracia que me salvó',
          chords: [DigitizedChord(chord: 'E', position: 0)],
        ),
      ],
    ),
  ],
);

Widget _buildTestApp({
  required SongRepository songRepo,
  PhotoQueueRepository? queueRepo,
  DigitizedSong song = _testDigitizedSong,
  int? queueItemId,
}) {
  return ProviderScope(
    overrides: [
      songRepositoryProvider.overrideWithValue(songRepo),
      if (queueRepo != null)
        photoQueueRepositoryProvider.overrideWithValue(queueRepo),
    ],
    child: MaterialApp(
      home: SongReviewCorrectionPage(
        imagePath: '/virtual/cropped_song.jpg',
        digitizedSong: song,
        queueItemId: queueItemId,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders side by side view and marks AI suggestions with badges',
    (tester) async {
      final mockRepo = _MockSongRepository();

      await tester.pumpWidget(_buildTestApp(songRepo: mockRepo));
      await tester.pump();

      // 1. Verifica elementos lado a lado / paneles
      expect(find.byType(SongReviewCorrectionPage), findsOneWidget);
      expect(find.text('Revisión y corrección'), findsOneWidget);
      expect(find.byKey(const Key('ai-suggestion-banner')), findsOneWidget);

      // 2. Verifica marcas y badges de lo sugerido por IA
      expect(find.byKey(const Key('ai-badge-title')), findsOneWidget);
      expect(find.byKey(const Key('ai-badge-key')), findsOneWidget);

      // 3. Verifica campos precargados
      expect(
        find.widgetWithText(TextFormField, 'Canto de Gracia'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'E'), findsOneWidget);
      expect(find.byKey(const Key('review-author-field')), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const Key('review-source-field')),
        find.byType(ListView),
        const Offset(0, -50),
      );
      expect(find.byKey(const Key('review-source-field')), findsOneWidget);

      // 4. Scroll para verificar badges y editor de acordes
      await tester.dragUntilVisible(
        find.byKey(const Key('ai-chords-badge')),
        find.byType(ListView),
        const Offset(0, -100),
      );
      expect(find.byKey(const Key('ai-chords-badge')), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const Key('ai-badge-lyrics')),
        find.byType(ListView),
        const Offset(0, -100),
      );
      expect(find.byKey(const Key('ai-badge-lyrics')), findsOneWidget);

      expect(find.byKey(const Key('save-button')), findsOneWidget);
      expect(find.byKey(const Key('discard-button')), findsOneWidget);
    },
  );

  testWidgets(
    'requires confirmation before saving (nothing is saved without confirmation)',
    (tester) async {
      final mockRepo = _MockSongRepository();

      await tester.pumpWidget(_buildTestApp(songRepo: mockRepo));
      await tester.pump();

      // Pulsar guardar
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      // Debe aparecer el diálogo de confirmación explícito
      expect(find.byKey(const Key('confirm-save-dialog')), findsOneWidget);
      expect(
        find.text('¿Confirmar y guardar canción?'),
        findsOneWidget,
      );

      // Cancelar confirmación
      await tester.tap(find.byKey(const Key('cancel-confirm-save')));
      await tester.pumpAndSettle();

      // NO se guardó nada en el repositorio
      expect(mockRepo.createdSong, isNull);
      expect(find.byKey(const Key('confirm-save-dialog')), findsNothing);

      // Pulsar guardar de nuevo y ahora confirmar
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-save-button')));
      await tester.pumpAndSettle();

      // Ahora sí se guardó en el repositorio
      expect(mockRepo.createdSong, isNotNull);
      expect(mockRepo.createdSong!.title, 'Canto de Gracia');
      expect(mockRepo.createdSong!.originalKey, 'E');
    },
  );

  testWidgets('allows editing author and source before saving', (tester) async {
    final mockRepo = _MockSongRepository();
    final queueRepo = InMemoryPhotoQueueRepository([
      PhotoQueueItem(
        id: 77,
        filePath: '/virtual/cropped_song.jpg',
        songTitle: 'Canto de Gracia',
        status: QueueStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      _buildTestApp(
        songRepo: mockRepo,
        queueRepo: queueRepo,
        queueItemId: 77,
      ),
    );
    await tester.pump();

    // Editar autor y fuente
    await tester.enterText(
      find.byKey(const Key('review-author-field')),
      'John Newton',
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('review-source-field')),
      find.byType(ListView),
      const Offset(0, -50),
    );
    await tester.enterText(
      find.byKey(const Key('review-source-field')),
      'Himnario Cristiano',
    );
    await tester.pump();

    // Guardar y confirmar
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-save-button')));
    await tester.pumpAndSettle();

    // Verificar que se guardó con autor y fuente
    expect(mockRepo.createdSong, isNotNull);
    expect(mockRepo.createdSong!.author, 'John Newton');
    expect(mockRepo.createdSong!.source, 'Himnario Cristiano');

    // Verificar que se eliminó el item de la cola
    final remainingQueue = await queueRepo.getAll();
    expect(remainingQueue, isEmpty);
  });

  testWidgets('discard button prompts confirmation and pops without saving', (
    tester,
  ) async {
    final mockRepo = _MockSongRepository();

    await tester.pumpWidget(_buildTestApp(songRepo: mockRepo));
    await tester.pump();

    await tester.tap(find.byKey(const Key('discard-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm-discard-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-discard-button')));
    await tester.pumpAndSettle();

    expect(mockRepo.createdSong, isNull);
  });
}
