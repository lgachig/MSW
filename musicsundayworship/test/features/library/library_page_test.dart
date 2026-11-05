import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/capture/offline_photo_queue.dart';
import 'package:musicsundayworship/features/capture/remote_digitize_service.dart';
import 'package:musicsundayworship/features/library/library_page.dart';
import 'package:musicsundayworship/features/songs/song_editor_page.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository(this.songs);

  final List<SongDocument> songs;

  @override
  Future<SongDocument> create(SongDocument song) => throw UnimplementedError();
  @override
  Future<void> delete(int id) => throw UnimplementedError();
  @override
  Future<List<SongArrangement>> readArrangements(int songId) =>
      throw UnimplementedError();
  @override
  Future<SongDocument?> read(int id) => throw UnimplementedError();
  @override
  Future<List<SongDocument>> readAll() async => songs;
  @override
  Future<SongDocument> update(SongDocument song) => throw UnimplementedError();
  @override
  Future<SongArrangement> createArrangement(SongArrangement arrangement) =>
      throw UnimplementedError();
  @override
  Future<SongArrangement> updateArrangement(SongArrangement arrangement) =>
      throw UnimplementedError();
  @override
  Future<SongDocument> updatePhotoPath(int songId, String? photoPath) =>
      throw UnimplementedError();
  @override
  Stream<List<SongDocument>> watchAll() => Stream.value(songs);
}

Widget _app(List<SongDocument> songs) => ProviderScope(
  overrides: [
    songRepositoryProvider.overrideWithValue(_FakeSongRepository(songs)),
  ],
  child: const MaterialApp(home: LibraryPage()),
);

void main() {
  testWidgets('filters songs while typing title or author', (tester) async {
    await tester.pumpWidget(
      _app([
        const SongDocument(title: 'Casa de Dios', author: 'Música Uno'),
        const SongDocument(title: 'Santo', author: 'Música Dos'),
      ]),
    );
    await tester.pump();

    expect(find.text('Casa de Dios'), findsOneWidget);
    expect(find.text('Santo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'dos');
    await tester.pump();

    expect(find.text('Casa de Dios'), findsNothing);
    expect(find.text('Santo'), findsOneWidget);
  });

  testWidgets('shows author and source for each song', (tester) async {
    await tester.pumpWidget(
      _app([
        const SongDocument(
          title: 'Canción visible',
          author: 'Autor visible',
          source: 'Fuente visible',
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Autor visible · Fuente visible'), findsOneWidget);
  });

  testWidgets('shows empty state and first-song action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository([])),
        ],
        child: MaterialApp(home: LibraryPage(onAddSong: () => pressed = true)),
      ),
    );
    await tester.pump();

    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    await tester.tap(find.text('Agregar primera canción'));
    expect(pressed, isTrue);
  });

  testWidgets('shows empty state before the repository stream emits', (
    tester,
  ) async {
    final repository = _NeverEmitsSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: LibraryPage()),
      ),
    );

    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('filters by key and sorts by title', (tester) async {
    await tester.pumpWidget(
      _app([
        const SongDocument(title: 'Zeta', originalKey: 'G', label: 'Alabanza'),
        const SongDocument(title: 'Alfa', originalKey: 'C', label: 'Adoración'),
      ]),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Título'));
    await tester.pump();

    final alfa = tester.getTopLeft(find.text('Alfa'));
    final zeta = tester.getTopLeft(find.text('Zeta'));
    expect(alfa.dy, lessThan(zeta.dy));

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('C').last);
    await tester.pump();
    expect(find.text('Alfa'), findsOneWidget);
    expect(find.text('Zeta'), findsNothing);
  });

  testWidgets(
    'displays offline queue section with items in pending, processing, ready and error states',
    (tester) async {
      final now = DateTime.now();
      final items = [
        PhotoQueueItem(
          id: 1,
          filePath: '/tmp/p1.jpg',
          songTitle: 'Foto Uno',
          status: QueueStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        PhotoQueueItem(
          id: 2,
          filePath: '/tmp/p2.jpg',
          songTitle: 'Foto Dos',
          status: QueueStatus.processing,
          createdAt: now,
          updatedAt: now,
        ),
        PhotoQueueItem(
          id: 3,
          filePath: '/tmp/p3.jpg',
          songTitle: 'Foto Tres',
          status: QueueStatus.ready,
          createdAt: now,
          updatedAt: now,
          resultJson: '{"title":"Foto Tres","key":"G","sections":[]}',
        ),
        PhotoQueueItem(
          id: 4,
          filePath: '/tmp/p4.jpg',
          songTitle: 'Foto Cuatro',
          status: QueueStatus.error,
          createdAt: now,
          updatedAt: now,
          errorMessage: 'Timeout de red',
        ),
      ];

      final queueRepo = InMemoryPhotoQueueRepository(items);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songRepositoryProvider.overrideWithValue(_FakeSongRepository([])),
            photoQueueRepositoryProvider.overrideWithValue(queueRepo),
            photoQueueProcessorProvider
                .overrideWithValue(_FakePhotoQueueProcessor(queueRepo)),
          ],
          child: const MaterialApp(home: LibraryPage()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('offline-queue-section')), findsOneWidget);
      expect(find.text('Cola de digitalización (4)'), findsOneWidget);
      expect(find.text('Foto Uno'), findsOneWidget);
      expect(find.text('Estado: pendiente'), findsOneWidget);
      expect(find.byKey(const Key('status-pending-1')), findsOneWidget);

      expect(find.text('Foto Dos'), findsOneWidget);
      expect(find.text('Estado: procesando'), findsOneWidget);
      expect(find.byKey(const Key('status-processing-2')), findsOneWidget);

      expect(find.text('Foto Tres'), findsOneWidget);
      expect(find.text('Estado: listo'), findsOneWidget);
      expect(find.byKey(const Key('status-ready-3')), findsOneWidget);
      expect(find.byKey(const Key('open-queue-item-3')), findsOneWidget);

      expect(find.text('Foto Cuatro'), findsOneWidget);
      expect(find.text('Error: Timeout de red'), findsOneWidget);
      expect(find.byKey(const Key('status-error-4')), findsOneWidget);
    },
  );

  testWidgets('opens ready queue item into SongEditorPage', (tester) async {
    final now = DateTime.now();
    final items = [
      PhotoQueueItem(
        id: 10,
        filePath: '/tmp/ready_song.jpg',
        songTitle: 'Grande y Fuerte',
        status: QueueStatus.ready,
        createdAt: now,
        updatedAt: now,
        resultJson:
            '{"title":"Grande y Fuerte","key":"Am","sections":[{"name":"Verso","lines":[{"text":"Tu amor es grande","chords":[{"chord":"Am","position":0}]}]}]}',
      ),
    ];

    final queueRepo = InMemoryPhotoQueueRepository(items);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository([])),
          photoQueueRepositoryProvider.overrideWithValue(queueRepo),
        ],
        child: const MaterialApp(home: LibraryPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('open-queue-item-10')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-queue-item-10')));
    await tester.pumpAndSettle();

    expect(find.byType(SongEditorPage), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Grande y Fuerte'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Am'), findsOneWidget);
  });
}

class _NeverEmitsSongRepository extends _FakeSongRepository {
  _NeverEmitsSongRepository() : super([]);

  @override
  Stream<List<SongDocument>> watchAll() => const Stream.empty();
}

class _FakePhotoQueueProcessor extends PhotoQueueProcessor {
  _FakePhotoQueueProcessor(PhotoQueueRepository repository)
      : super(
          repository: repository,
          digitizeService: _NoopDigitizeService(),
        );

  @override
  Future<int> processPendingQueue() async => 0;
}

class _NoopDigitizeService implements RemoteDigitizeService {
  @override
  Future<DigitizedSong> digitize(String imagePath) async =>
      const DigitizedSong(title: '', key: '', sections: []);
}
