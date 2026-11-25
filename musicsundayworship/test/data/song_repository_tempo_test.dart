import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/database.dart';
import 'package:musicsundayworship/data/song_repository.dart';

void main() {
  late AppDatabase database;
  late DriftSongRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftSongRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DriftSongRepository - Tempo and TimeSignature persistence', () {
    test('persists tempo and timeSignature updates to an existing song', () async {
      final created = await repository.create(
        const SongDocument(
          title: 'Canción de Prueba',
          author: 'Compositor',
          originalKey: 'D',
          tempo: 100,
          timeSignature: '4/4',
          sections: [
            SongSection(
              name: 'Verso 1',
              lines: [SongLine(content: 'Línea de prueba')],
            ),
          ],
        ),
      );

      expect(created.id, isNotNull);
      expect(created.tempo, 100);
      expect(created.timeSignature, '4/4');

      // Update tempo and timeSignature
      final updated = await repository.updateTempoAndSignature(
        created.id!,
        tempo: 135,
        timeSignature: '6/8',
      );

      expect(updated.id, created.id);
      expect(updated.tempo, 135);
      expect(updated.timeSignature, '6/8');
      expect(updated.title, 'Canción de Prueba');
      expect(updated.sections.length, 1);
      expect(updated.sections.first.lines.first.content, 'Línea de prueba');

      // Verify read persists the change
      final readBack = await repository.read(created.id!);
      expect(readBack?.tempo, 135);
      expect(readBack?.timeSignature, '6/8');
    });

    test('throws StateError when updating tempo for a non-existent song', () async {
      expect(
        () => repository.updateTempoAndSignature(9999, tempo: 120),
        throwsA(isA<StateError>()),
      );
    });
  });
}

