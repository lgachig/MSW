import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/library/library_page.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository(this.songs);

  final List<SongDocument> songs;

  @override
  Future<SongDocument> create(SongDocument song) => throw UnimplementedError();
  @override
  Future<void> delete(int id) => throw UnimplementedError();
  @override
  Future<SongDocument?> read(int id) => throw UnimplementedError();
  @override
  Future<List<SongDocument>> readAll() async => songs;
  @override
  Future<SongDocument> update(SongDocument song) => throw UnimplementedError();
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
}
