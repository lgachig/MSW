import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/songs/song_detail_page.dart';
import 'package:musicsundayworship/music_engine/song_structure.dart';

const _song = SongDocument(
  title: 'Grande es tu amor',
  author: 'Autor',
  originalKey: 'C',
  sections: [
    SongSection(
      name: 'Sección 1',
      lines: [
        SongLine(
          content: 'Tu amor no cambia',
          chords: [
            ChordPlacementData(chord: 'C', position: 0),
            ChordPlacementData(chord: 'G', position: 8),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('shows song metadata and positioned chords', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    expect(find.text('Tono original: C'), findsOneWidget);
    expect(find.text('Tono actual: C'), findsOneWidget);
    expect(find.text('C       G'), findsOneWidget);
    expect(find.text('Tu amor no cambia'), findsOneWidget);
  });

  testWidgets('transposes chords up and restores the original key', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    await tester.tap(find.byKey(const Key('transpose-up')));
    await tester.pump();
    expect(find.text('Tono actual: C#'), findsOneWidget);
    expect(find.text('C#      G#'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transpose-down')));
    await tester.pump();
    expect(find.text('Tono actual: C'), findsOneWidget);
    expect(find.text('C       G'), findsOneWidget);
  });

  testWidgets('updates the current key after two semitone steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    await tester.tap(find.byKey(const Key('transpose-up')));
    await tester.tap(find.byKey(const Key('transpose-up')));
    await tester.pump();

    expect(find.byKey(const Key('current-key')), findsOneWidget);
    expect(find.text('Tono actual: D'), findsOneWidget);
  });

  testWidgets('switches rendered chords to Latin notation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    await tester.tap(find.text('Latina'));
    await tester.pump();
    expect(find.text('Do      Sol'), findsOneWidget);
  });

  testWidgets('updates minor current keys after transposition', (tester) async {
    const song = SongDocument(
      title: 'Canción en menor',
      originalKey: 'F#m',
      sections: [],
    );
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: song)),
    );

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(const Key('transpose-up')));
    }
    await tester.pump();

    expect(find.text('Tono actual: Bm'), findsOneWidget);
  });

  testWidgets('opens structure editor from action button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    expect(find.byKey(const Key('edit-structure')), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-structure')));
    await tester.pumpAndSettle();

    expect(find.text('Editor de estructura'), findsOneWidget);
  });

  testWidgets('renders sections framed in styled cards with headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    expect(find.byKey(const Key('section-card-0')), findsOneWidget);
    expect(find.text('Sección 1'), findsWidgets);
    expect(find.text('Tu amor no cambia'), findsOneWidget);
  });

  testWidgets('deletes song from detail page with confirmation dialog', (tester) async {
    const song = SongDocument(
      id: 99,
      title: 'Canción a eliminar',
      originalKey: 'D',
      sections: [],
    );
    var deletedId = -1;
    final repo = _FakeDetailSongRepository(onDelete: (id) => deletedId = id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: SongDetailPage(song: song)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-song')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-song')));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar canción?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-delete-song-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-delete-song-button')));
    await tester.pumpAndSettle();

    expect(deletedId, equals(99));
  });
}

class _FakeDetailSongRepository implements SongRepository {
  _FakeDetailSongRepository({this.onDelete});

  final void Function(int id)? onDelete;

  @override
  Future<SongDocument> create(SongDocument song) => throw UnimplementedError();
  @override
  Future<void> delete(int id) async => onDelete?.call(id);
  @override
  Future<List<SongArrangement>> readArrangements(int songId) async => [];
  @override
  Future<SongDocument?> read(int id) async => null;
  @override
  Future<List<SongDocument>> readAll() async => [];
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
  Future<SongStructure> createStructure(SongStructure s) =>
      throw UnimplementedError();
  @override
  Future<List<SongStructure>> readStructures(int songId) async => [];
  @override
  Future<SongStructure> updateStructure(SongStructure s) =>
      throw UnimplementedError();
  @override
  Future<void> deleteStructure(int id) async {}
  @override
  Future<SongStructure> duplicateStructure(int id, {String? newName}) =>
      throw UnimplementedError();
  @override
  Stream<List<SongDocument>> watchAll() => const Stream.empty();
}
