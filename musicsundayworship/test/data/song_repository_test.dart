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

  tearDown(() => database.close());

  test('creates and reads a complete song', () async {
    final created = await repository.create(
      const SongDocument(
        title: 'Santo',
        author: 'Autor',
        sections: [
          SongSection(
            name: 'Verso',
            lines: [
              SongLine(
                content: 'Tu amor no cambia',
                chords: [ChordPlacementData(chord: 'G')],
              ),
            ],
          ),
        ],
      ),
    );

    final loaded = await repository.read(created.id!);
    expect(loaded?.title, 'Santo');
    expect(loaded?.sections.single.lines.single.chords.single.chord, 'G');
  });

  test('persists author, source and song settings', () async {
    final created = await repository.create(
      const SongDocument(
        title: 'Fuente',
        author: 'Autor visible',
        source: 'Libro de cantos',
        originalKey: 'D',
        tempo: 92,
        timeSignature: '4/4',
      ),
    );

    final loaded = await repository.read(created.id!);
    expect(loaded?.author, 'Autor visible');
    expect(loaded?.source, 'Libro de cantos');
    expect(loaded?.originalKey, 'D');
    expect(loaded?.tempo, 92);
    expect(loaded?.timeSignature, '4/4');
  });

  test('watchAll emits the initial library state', () async {
    expect(await repository.watchAll().first, isEmpty);

    await repository.create(const SongDocument(title: 'Nueva canción'));

    expect((await repository.watchAll().first).single.title, 'Nueva canción');
  });

  test('updates content and metadata as one document', () async {
    final created = await repository.create(
      const SongDocument(title: 'Borrador'),
    );
    final updated = await repository.update(
      created.copyWith(sections: const [SongSection(name: 'Coro')]),
    );

    expect(updated.title, 'Borrador');
    expect(updated.sections.single.name, 'Coro');
    expect((await repository.readAll()).single.sections.single.name, 'Coro');
  });

  test('deleting a song removes sections, lines and chords', () async {
    final created = await repository.create(
      const SongDocument(
        title: 'Eliminar',
        sections: [
          SongSection(
            name: 'Verso',
            lines: [
              SongLine(
                content: 'Texto',
                chords: [ChordPlacementData(chord: 'Am')],
              ),
            ],
          ),
        ],
      ),
    );

    await repository.delete(created.id!);

    expect(await repository.read(created.id!), isNull);
    expect(await database.select(database.sections).get(), isEmpty);
    expect(await database.select(database.lines).get(), isEmpty);
    expect(await database.select(database.chordPlacements).get(), isEmpty);
  });
}
