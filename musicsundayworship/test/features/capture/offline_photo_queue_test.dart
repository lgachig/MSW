import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/database.dart';
import 'package:musicsundayworship/features/capture/offline_photo_queue.dart';
import 'package:musicsundayworship/features/capture/remote_digitize_service.dart';

class _FakeRemoteDigitizeService implements RemoteDigitizeService {
  bool isOnline = true;
  bool shouldThrowPermanentError = false;

  @override
  Future<DigitizedSong> digitize(String imagePath) async {
    if (!isOnline) {
      throw const SocketException('Failed host lookup: backend.local');
    }
    if (shouldThrowPermanentError) {
      throw const DigitizeException('Imagen corrupta o ilegible');
    }
    return const DigitizedSong(
      title: 'Sublime Gracia',
      key: 'G',
      sections: [
        DigitizedSection(
          name: 'Verso 1',
          lines: [
            DigitizedLine(
              text: 'Sublime gracia del Señor',
              chords: [DigitizedChord(chord: 'G', position: 0)],
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  group('QueueStatus', () {
    test('parses name and spanish labels', () {
      expect(QueueStatus.fromString('pending'), QueueStatus.pending);
      expect(QueueStatus.fromString('pendiente'), QueueStatus.pending);
      expect(QueueStatus.fromString('processing'), QueueStatus.processing);
      expect(QueueStatus.fromString('procesando'), QueueStatus.processing);
      expect(QueueStatus.fromString('ready'), QueueStatus.ready);
      expect(QueueStatus.fromString('listo'), QueueStatus.ready);
      expect(QueueStatus.fromString('error'), QueueStatus.error);
      expect(QueueStatus.fromString('unknown'), QueueStatus.pending);
    });
  });

  group('DriftPhotoQueueRepository', () {
    late AppDatabase database;
    late DriftPhotoQueueRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = DriftPhotoQueueRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('enqueues item with pending status', () async {
      final item = await repository.enqueue(
        filePath: '/tmp/test_image.jpg',
        songTitle: 'Gracia',
      );

      expect(item.id, isPositive);
      expect(item.songTitle, 'Gracia');
      expect(item.status, QueueStatus.pending);

      final all = await repository.getAll();
      expect(all.length, 1);
      expect(all.first.id, item.id);
    });

    test('updates status and errorMessage', () async {
      final item = await repository.enqueue(filePath: '/tmp/test.jpg');
      await repository.updateStatus(
        item.id,
        QueueStatus.error,
        errorMessage: 'Fallo de red',
      );

      final all = await repository.getAll();
      expect(all.first.status, QueueStatus.error);
      expect(all.first.errorMessage, 'Fallo de red');
    });

    test('deletes an item', () async {
      final item = await repository.enqueue(filePath: '/tmp/test.jpg');
      await repository.delete(item.id);

      final all = await repository.getAll();
      expect(all, isEmpty);
    });
  });

  group('InMemoryPhotoQueueRepository', () {
    late InMemoryPhotoQueueRepository repository;

    setUp(() {
      repository = InMemoryPhotoQueueRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('supports enqueue, status update and deletion in memory', () async {
      final item = await repository.enqueue(
        filePath: '/tmp/photo.jpg',
        songTitle: 'Canto nuevo',
      );

      expect(item.status, QueueStatus.pending);
      final processable = await repository.getProcessableItems();
      expect(processable.length, 1);

      await repository.updateStatus(
        item.id,
        QueueStatus.ready,
        resultJson: '{"title":"Canto nuevo","key":"D","sections":[]}',
      );

      final updated = (await repository.getAll()).first;
      expect(updated.status, QueueStatus.ready);
      expect(updated.digitizedSong?.title, 'Canto nuevo');
      expect(updated.digitizedSong?.key, 'D');

      await repository.delete(item.id);
      expect(await repository.getAll(), isEmpty);
    });
  });

  group('PhotoQueueProcessor - Offline and Reconnection simulation', () {
    late InMemoryPhotoQueueRepository repository;
    late _FakeRemoteDigitizeService fakeService;
    late PhotoQueueProcessor processor;

    setUp(() {
      repository = InMemoryPhotoQueueRepository();
      fakeService = _FakeRemoteDigitizeService();
      processor = PhotoQueueProcessor(
        repository: repository,
        digitizeService: fakeService,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'Simulated offline: item stays pending on SocketException and transitions to ready when connection returns',
      () async {
        // 1. Simular modo avión / sin conexión
        fakeService.isOnline = false;

        final item = await repository.enqueue(
          filePath: '/tmp/song_chord.jpg',
          songTitle: 'Sublime Gracia',
        );
        expect(item.status, QueueStatus.pending);

        // 2. Procesar cola sin conexión -> debe mantenerse en pendiente
        final processedCountOffline = await processor.processPendingQueue();
        expect(processedCountOffline, 0);

        final offlineItems = await repository.getAll();
        expect(offlineItems.first.status, QueueStatus.pending);
        expect(
          offlineItems.first.errorMessage,
          contains('Sin conexión a internet'),
        );

        // 3. Simular recuperación de conexión a internet
        fakeService.isOnline = true;

        // 4. Reintentar procesamiento de la cola
        final processedCountOnline = await processor.processPendingQueue();
        expect(processedCountOnline, 1);

        // 5. Verificar que el estado ahora es 'listo' (ready) y contiene el resultado
        final readyItems = await repository.getAll();
        expect(readyItems.first.status, QueueStatus.ready);
        expect(readyItems.first.digitizedSong, isNotNull);
        expect(readyItems.first.digitizedSong!.title, 'Sublime Gracia');
        expect(readyItems.first.digitizedSong!.key, 'G');
      },
    );

    test('Permanent error transitions status to error', () async {
      fakeService.isOnline = true;
      fakeService.shouldThrowPermanentError = true;

      await repository.enqueue(filePath: '/tmp/corrupt.jpg');
      final processedCount = await processor.processPendingQueue();
      expect(processedCount, 0);

      final items = await repository.getAll();
      expect(items.first.status, QueueStatus.error);
      expect(items.first.errorMessage, contains('Imagen corrupta'));
    });

    test('retryItem retries a single item', () async {
      fakeService.isOnline = false;
      final item = await repository.enqueue(filePath: '/tmp/retry.jpg');

      final failed = await processor.retryItem(item);
      expect(failed, isFalse);

      fakeService.isOnline = true;
      final succeeded = await processor.retryItem(item);
      expect(succeeded, isTrue);

      final items = await repository.getAll();
      expect(items.first.status, QueueStatus.ready);
    });
  });
}
