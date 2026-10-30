import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Metadata and ordered content of a song, independent of the database.
class SongDocument {
  const SongDocument({
    this.id,
    required this.title,
    this.author,
    this.source,
    this.originalKey,
    this.label,
    this.tempo,
    this.timeSignature,
    this.sections = const [],
  });

  final int? id;
  final String title;
  final String? author;
  final String? source;
  final String? originalKey;
  final String? label;
  final int? tempo;
  final String? timeSignature;
  final List<SongSection> sections;

  SongDocument copyWith({int? id, List<SongSection>? sections}) => SongDocument(
    id: id ?? this.id,
    title: title,
    author: author,
    source: source,
    originalKey: originalKey,
    label: label,
    tempo: tempo,
    timeSignature: timeSignature,
    sections: sections ?? this.sections,
  );
}

class SongArrangement {
  const SongArrangement({
    this.id,
    required this.songId,
    required this.name,
    this.sections = const [],
  });

  final int? id;
  final int songId;
  final String name;
  final List<SongSection> sections;
}

class SongSection {
  const SongSection({
    required this.name,
    this.position = 0,
    this.lines = const [],
  });

  final String name;
  final int position;
  final List<SongLine> lines;
}

class SongLine {
  const SongLine({
    required this.content,
    this.position = 0,
    this.chords = const [],
  });

  final String content;
  final int position;
  final List<ChordPlacementData> chords;
}

class ChordPlacementData {
  const ChordPlacementData({required this.chord, this.position = 0});

  final String chord;
  final int position;
}

abstract interface class SongRepository {
  Future<SongDocument> create(SongDocument song);
  Future<SongDocument?> read(int id);
  Future<List<SongDocument>> readAll();
  Stream<List<SongDocument>> watchAll();
  Future<SongDocument> update(SongDocument song);
  Future<void> delete(int id);
  Future<List<SongArrangement>> readArrangements(int songId);
  Future<SongArrangement> createArrangement(SongArrangement arrangement);
  Future<SongArrangement> updateArrangement(SongArrangement arrangement);
}

class DriftSongRepository implements SongRepository {
  DriftSongRepository(this.database);

  final AppDatabase database;

  @override
  Future<SongDocument> create(SongDocument song) async {
    final id = await database.transaction(() async {
      final songId = await database
          .into(database.songs)
          .insert(
            SongsCompanion.insert(
              title: song.title,
              author: Value(song.author),
              source: Value(song.source),
              originalKey: Value(song.originalKey),
              label: Value(song.label),
              tempo: Value(song.tempo),
              timeSignature: Value(song.timeSignature),
            ),
          );
      await _insertSections(songId, song.sections);
      return songId;
    });
    return song.copyWith(id: id);
  }

  @override
  Future<SongDocument?> read(int id) async {
    final song = await (database.select(
      database.songs,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (song == null) return null;
    return _assemble(song);
  }

  @override
  Future<List<SongDocument>> readAll() async {
    final songs = await (database.select(
      database.songs,
    )..orderBy([(table) => OrderingTerm.asc(table.title)])).get();
    return Future.wait(songs.map(_assemble));
  }

  @override
  Stream<List<SongDocument>> watchAll() async* {
    await for (final songs in (database.select(
      database.songs,
    )..orderBy([(table) => OrderingTerm.asc(table.title)])).watch()) {
      yield await Future.wait(songs.map(_assemble));
    }
  }

  @override
  Future<SongDocument> update(SongDocument song) async {
    final id = song.id;
    if (id == null) {
      throw ArgumentError.value(song, 'song', 'An id is required to update');
    }
    final updated = await database.transaction(() async {
      final exists = await (database.select(
        database.songs,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      if (exists == null) throw StateError('Song $id does not exist');
      await (database.update(
        database.songs,
      )..where((table) => table.id.equals(id))).write(
        SongsCompanion(
          title: Value(song.title),
          author: Value(song.author),
          source: Value(song.source),
          originalKey: Value(song.originalKey),
          label: Value(song.label),
          tempo: Value(song.tempo),
          timeSignature: Value(song.timeSignature),
        ),
      );
      await _deleteSections(id);
      await _insertSections(id, song.sections);
      return id;
    });
    return (await read(updated))!;
  }

  @override
  Future<void> delete(int id) async {
    await database.transaction(() async {
      await _deleteSections(id);
      await (database.delete(
        database.songs,
      )..where((table) => table.id.equals(id))).go();
    });
  }

  @override
  Future<List<SongArrangement>> readArrangements(int songId) async {
    final rows =
        await (database.select(database.arrangements)
              ..where((table) => table.songId.equals(songId))
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows
        .map(
          (row) => SongArrangement(
            id: row.id,
            songId: row.songId,
            name: row.name,
            sections: _sectionsFromJson(row.content),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SongArrangement> createArrangement(SongArrangement arrangement) async {
    final song = await read(arrangement.songId);
    if (song == null) {
      throw StateError('Song ${arrangement.songId} does not exist');
    }
    final id = await database
        .into(database.arrangements)
        .insert(
          ArrangementsCompanion.insert(
            songId: arrangement.songId,
            name: arrangement.name,
            content: _sectionsToJson(arrangement.sections),
          ),
        );
    return SongArrangement(
      id: id,
      songId: arrangement.songId,
      name: arrangement.name,
      sections: arrangement.sections,
    );
  }

  @override
  Future<SongArrangement> updateArrangement(SongArrangement arrangement) async {
    final id = arrangement.id;
    if (id == null) {
      throw ArgumentError.value(
        arrangement,
        'arrangement',
        'An id is required to update',
      );
    }
    final updated =
        await (database.update(
          database.arrangements,
        )..where((table) => table.id.equals(id))).write(
          ArrangementsCompanion(
            name: Value(arrangement.name),
            content: Value(_sectionsToJson(arrangement.sections)),
          ),
        );
    if (updated == 0) {
      throw StateError('Arrangement $id does not exist');
    }
    return arrangement;
  }

  Future<void> _insertSections(int songId, List<SongSection> sections) async {
    for (final section in sections) {
      final sectionId = await database
          .into(database.sections)
          .insert(
            SectionsCompanion.insert(
              songId: songId,
              name: section.name,
              position: section.position,
            ),
          );
      for (final line in section.lines) {
        final lineId = await database
            .into(database.lines)
            .insert(
              LinesCompanion.insert(
                sectionId: sectionId,
                content: line.content,
                position: line.position,
              ),
            );
        for (final chord in line.chords) {
          await database
              .into(database.chordPlacements)
              .insert(
                ChordPlacementsCompanion.insert(
                  lineId: lineId,
                  chord: chord.chord,
                  position: chord.position,
                ),
              );
        }
      }
    }
  }

  Future<void> _deleteSections(int songId) async {
    final sections = await (database.select(
      database.sections,
    )..where((table) => table.songId.equals(songId))).get();
    for (final section in sections) {
      final lines = await (database.select(
        database.lines,
      )..where((table) => table.sectionId.equals(section.id))).get();
      for (final line in lines) {
        await (database.delete(
          database.chordPlacements,
        )..where((table) => table.lineId.equals(line.id))).go();
      }
      await (database.delete(
        database.lines,
      )..where((table) => table.sectionId.equals(section.id))).go();
    }
    await (database.delete(
      database.sections,
    )..where((table) => table.songId.equals(songId))).go();
  }

  Future<SongDocument> _assemble(Song song) async {
    final sections =
        await (database.select(database.sections)
              ..where((table) => table.songId.equals(song.id))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final result = <SongSection>[];
    for (final section in sections) {
      final lines =
          await (database.select(database.lines)
                ..where((table) => table.sectionId.equals(section.id))
                ..orderBy([(table) => OrderingTerm.asc(table.position)]))
              .get();
      final lineData = <SongLine>[];
      for (final line in lines) {
        final chords =
            await (database.select(database.chordPlacements)
                  ..where((table) => table.lineId.equals(line.id))
                  ..orderBy([(table) => OrderingTerm.asc(table.position)]))
                .get();
        lineData.add(
          SongLine(
            content: line.content,
            position: line.position,
            chords: chords
                .map(
                  (chord) => ChordPlacementData(
                    chord: chord.chord,
                    position: chord.position,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
      result.add(
        SongSection(
          name: section.name,
          position: section.position,
          lines: List.unmodifiable(lineData),
        ),
      );
    }
    return SongDocument(
      id: song.id,
      title: song.title,
      author: song.author,
      source: song.source,
      originalKey: song.originalKey,
      label: song.label,
      tempo: song.tempo,
      timeSignature: song.timeSignature,
      sections: List.unmodifiable(result),
    );
  }

  String _sectionsToJson(List<SongSection> sections) => jsonEncode(
    sections
        .map(
          (section) => {
            'name': section.name,
            'position': section.position,
            'lines': section.lines
                .map(
                  (line) => {
                    'content': line.content,
                    'position': line.position,
                    'chords': line.chords
                        .map(
                          (chord) => {
                            'chord': chord.chord,
                            'position': chord.position,
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
          },
        )
        .toList(),
  );

  List<SongSection> _sectionsFromJson(String content) {
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map(
          (section) => SongSection(
            name: section['name'] as String,
            position: section['position'] as int,
            lines: (section['lines'] as List<dynamic>)
                .map(
                  (line) => SongLine(
                    content: line['content'] as String,
                    position: line['position'] as int,
                    chords: (line['chords'] as List<dynamic>)
                        .map(
                          (chord) => ChordPlacementData(
                            chord: chord['chord'] as String,
                            position: chord['position'] as int,
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return DriftSongRepository(ref.watch(appDatabaseProvider));
});
