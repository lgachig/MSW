import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/database.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/music_engine/song_structure.dart';

void main() {
  late AppDatabase db;
  late SongRepository repository;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftSongRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates, reads, duplicates and deletes song structures', () async {
    // 1. Create a base song
    final song = await repository.create(
      const SongDocument(
        title: 'Tu Fidelidad',
        originalKey: 'D',
        sections: [
          SongSection(
            name: 'Verso',
            lines: [
              SongLine(
                content: 'Tu fidelidad es grande',
                chords: [ChordPlacementData(chord: 'D', position: 0)],
              ),
            ],
          ),
        ],
      ),
    );

    // 2. Create structure version 1 (Estándar)
    final structure1 = await repository.createStructure(
      SongStructure(
        songId: song.id!,
        name: 'Estructura Estándar',
        isDefault: true,
        items: const [
          StructureItem(
            id: 'v1',
            type: SectionType.verso,
            name: 'Verso',
            repeatCount: 2,
          ),
          StructureItem(
            id: 'c1',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 3,
          ),
        ],
      ),
    );

    expect(structure1.id, isNotNull);

    // 3. Create structure version 2 for the same song (Versión Rápida)
    final structure2 = await repository.createStructure(
      SongStructure(
        songId: song.id!,
        name: 'Versión Servicio Corto',
        items: const [
          StructureItem(
            id: 'v1',
            type: SectionType.verso,
            name: 'Verso',
            repeatCount: 1,
          ),
          StructureItem(
            id: 'c1',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 1,
          ),
        ],
      ),
    );

    // 4. Read all structures for the song (debe haber 2 versiones)
    final structures = await repository.readStructures(song.id!);
    expect(structures.length, 2);
    expect(structures[0].name, 'Estructura Estándar');
    expect(structures[0].items[1].repeatCount, 3);
    expect(structures[0].expand().length, 5); // 2 versos + 3 coros

    expect(structures[1].name, 'Versión Servicio Corto');
    expect(structures[1].expand().length, 2); // 1 verso + 1 coro

    // 5. Duplicate structure 1 (no debe mutar la original)
    final duplicated = await repository.duplicateStructure(
      structure1.id!,
      newName: 'Copia para Concierto',
    );

    expect(duplicated.name, 'Copia para Concierto');
    expect(duplicated.id, isNot(structure1.id));

    // Ahora hay 3 versiones en base de datos
    final updatedList = await repository.readStructures(song.id!);
    expect(updatedList.length, 3);

    // 6. Actualizar la copia y verificar que la original sigue intacta
    final modified = duplicated.copyWith(
      items: [
        ...duplicated.items,
        const StructureItem(
          id: 'fin',
          type: SectionType.finalSection,
          name: 'Final',
          repeatCount: 4,
        ),
      ],
    );
    await repository.updateStructure(modified);

    final refreshedList = await repository.readStructures(song.id!);
    final orig = refreshedList.firstWhere((s) => s.id == structure1.id);
    final mod = refreshedList.firstWhere((s) => s.id == duplicated.id);

    expect(orig.items.length, 2);
    expect(orig.expand().length, 5);
    expect(mod.items.length, 3);
    expect(mod.expand().length, 9); // 2 + 3 + 4

    // 7. Eliminar una estructura
    await repository.deleteStructure(structure2.id!);
    final afterDelete = await repository.readStructures(song.id!);
    expect(afterDelete.length, 2);
  });
}
