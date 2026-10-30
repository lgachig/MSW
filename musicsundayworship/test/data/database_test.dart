import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('inserts and reads a complete song structure', () async {
    final songId = await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            title: 'Santo',
            author: const Value('Autor'),
            source: const Value('Cancionero'),
            originalKey: const Value('G'),
            tempo: const Value(96),
            timeSignature: const Value('4/4'),
          ),
        );
    final sectionId = await database
        .into(database.sections)
        .insert(
          SectionsCompanion.insert(songId: songId, name: 'Verso', position: 0),
        );
    final lineId = await database
        .into(database.lines)
        .insert(
          LinesCompanion.insert(
            sectionId: sectionId,
            content: 'Tu amor no cambia',
            position: 0,
          ),
        );
    await database
        .into(database.chordPlacements)
        .insert(
          ChordPlacementsCompanion.insert(
            lineId: lineId,
            chord: 'G',
            position: 0,
          ),
        );

    final song = await (database.select(
      database.songs,
    )..where((song) => song.id.equals(songId))).getSingle();
    final sections =
        await (database.select(database.sections)
              ..where((section) => section.songId.equals(songId))
              ..orderBy([(section) => OrderingTerm.asc(section.position)]))
            .get();
    final lines = await (database.select(
      database.lines,
    )..where((line) => line.sectionId.equals(sectionId))).get();
    final chords = await (database.select(
      database.chordPlacements,
    )..where((chord) => chord.lineId.equals(lineId))).get();

    expect(song.title, 'Santo');
    expect(song.tempo, 96);
    expect(sections.single.name, 'Verso');
    expect(lines.single.content, 'Tu amor no cambia');
    expect(chords.single.chord, 'G');
  });
}
