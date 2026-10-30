import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get originalKey => text().nullable()();
  IntColumn get tempo => integer().nullable()();
  TextColumn get timeSignature => text().nullable()();
}

class Sections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get position => integer()();
}

class Lines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sectionId =>
      integer().references(Sections, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  IntColumn get position => integer()();
}

class ChordPlacements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lineId =>
      integer().references(Lines, #id, onDelete: KeyAction.cascade)();
  TextColumn get chord => text()();
  IntColumn get position => integer()();
}

@DriftDatabase(tables: [Songs, Sections, Lines, ChordPlacements])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {},
  );
}

QueryExecutor _openConnection() {
  final dbFile = File('${Directory.current.path}/musicsundayworship.sqlite');
  return NativeDatabase.createInBackground(dbFile);
}
