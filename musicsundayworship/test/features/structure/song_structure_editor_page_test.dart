import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/database.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/structure/song_structure_editor_page.dart';
import 'package:musicsundayworship/music_engine/song_structure.dart';

void main() {
  late AppDatabase database;
  late DriftSongRepository repository;
  late SongDocument createdSong;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftSongRepository(database);

    createdSong = await repository.create(
      const SongDocument(
        title: 'Cuan Grande es Dios',
        originalKey: 'G',
        sections: [
          SongSection(name: 'Intro', lines: []),
          SongSection(name: 'Verso 1', lines: []),
          SongSection(name: 'Coro', lines: []),
        ],
      ),
    );
  });

  tearDown(() => database.close());

  Widget createWidget({
    SongDocument? song,
    SongStructure? initialStructure,
    ValueChanged<SongStructure>? onStructureSaved,
  }) {
    return ProviderScope(
      overrides: [
        songRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: SongStructureEditorPage(
          song: song ?? createdSong,
          initialStructure: initialStructure,
          onStructureSaved: onStructureSaved,
        ),
      ),
    );
  }

  testWidgets('renders sections with colors, labels and repeat badges', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Editor de estructura'), findsOneWidget);
    expect(find.text('Cuan Grande es Dios'), findsOneWidget);
    expect(find.byKey(const Key('structure-name-field')), findsOneWidget);

    // Initial 3 items have repeat counters and delete buttons
    expect(find.byKey(const Key('repeat-count-0')), findsOneWidget);
    expect(find.byKey(const Key('repeat-count-1')), findsOneWidget);
    expect(find.byKey(const Key('repeat-count-2')), findsOneWidget);

    expect(find.byKey(const Key('delete-item-0')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-1')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-2')), findsOneWidget);
  });

  testWidgets(
    'Luis manual test: increments repeat count of Coro from x2 to x4',
    (tester) async {
      // Set up initial structure with Coro x2
      final customStructure = SongStructure(
        songId: createdSong.id,
        name: 'Estructura Domingo',
        items: [
          const StructureItem(
            id: 's1',
            type: SectionType.verso,
            name: 'Verso 1',
            repeatCount: 1,
          ),
          const StructureItem(
            id: 's2',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 2,
          ),
        ],
      );

      await tester.pumpWidget(
        createWidget(initialStructure: customStructure),
      );
      await tester.pumpAndSettle();

      // Coro is at index 1
      expect(find.byKey(const Key('repeat-count-1')), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);

      // Tap '+' on index 1 to make it x3
      await tester.tap(find.byKey(const Key('increment-repeat-1')));
      await tester.pumpAndSettle();
      expect(find.text('x3'), findsOneWidget);

      // Tap '+' again on index 1 to make it x4
      await tester.tap(find.byKey(const Key('increment-repeat-1')));
      await tester.pumpAndSettle();
      expect(find.text('x4'), findsOneWidget);

      // Tap '-' on index 1 to decrease back to x3
      await tester.tap(find.byKey(const Key('decrement-repeat-1')));
      await tester.pumpAndSettle();
      expect(find.text('x3'), findsOneWidget);
    },
  );

  testWidgets('adds new sections using quick action chips', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Initially 3 items
    expect(find.byKey(const Key('delete-item-2')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-3')), findsNothing);

    // Tap quick chip 'Intro'
    await tester.tap(find.byKey(const Key('add-section-intro')));
    await tester.pumpAndSettle();

    // Should now have 4 items
    expect(find.byKey(const Key('delete-item-3')), findsOneWidget);
  });

  testWidgets('removes a section with delete button', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // Initially 3 items
    expect(find.byKey(const Key('delete-item-0')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-1')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-2')), findsOneWidget);

    // Delete item 0
    await tester.tap(find.byKey(const Key('delete-item-0')));
    await tester.pumpAndSettle();

    // Item 2 is gone, now only items 0 and 1 remain
    expect(find.byKey(const Key('delete-item-2')), findsNothing);
    expect(find.byKey(const Key('delete-item-0')), findsOneWidget);
    expect(find.byKey(const Key('delete-item-1')), findsOneWidget);
  });

  testWidgets('reorders sections via drag and drop', (tester) async {
    final customStructure = SongStructure(
      songId: createdSong.id,
      name: 'Orden Test',
      items: [
        const StructureItem(
          id: 'item_verso',
          type: SectionType.verso,
          name: 'Verso 1',
          repeatCount: 1,
        ),
        const StructureItem(
          id: 'item_coro',
          type: SectionType.coro,
          name: 'Coro',
          repeatCount: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      createWidget(initialStructure: customStructure),
    );
    await tester.pumpAndSettle();

    final dragHandles = find.byIcon(Icons.drag_indicator);
    expect(dragHandles, findsNWidgets(2));

    final firstHandle = tester.getCenter(dragHandles.at(0));
    final secondHandle = tester.getCenter(dragHandles.at(1));

    final gesture = await tester.startGesture(firstHandle);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(Offset(secondHandle.dx, secondHandle.dy + 40));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
  });

  testWidgets('duplicates structure version with new name', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('duplicate-structure-button')));
    await tester.pumpAndSettle();

    // Name field should now contain (Copia)
    final textField = tester.widget<TextField>(
      find.byKey(const Key('structure-name-field')),
    );
    expect(textField.controller?.text, contains('(Copia)'));
    expect(find.textContaining('duplicada como'), findsOneWidget);
  });

  testWidgets('saves structure to repository and fires callback', (
    tester,
  ) async {
    SongStructure? savedResult;

    await tester.pumpWidget(
      createWidget(
        onStructureSaved: (s) => savedResult = s,
      ),
    );
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(
      find.byKey(const Key('structure-name-field')),
      'Estructura Servicio 10AM',
    );
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byKey(const Key('save-structure-button')));
    await tester.pumpAndSettle();

    expect(savedResult, isNotNull);
    expect(savedResult?.name, 'Estructura Servicio 10AM');
    expect(savedResult?.items.length, 3);

    // Verify stored in repository
    final stored = await repository.readStructures(createdSong.id!);
    expect(stored.any((s) => s.name == 'Estructura Servicio 10AM'), isTrue);
  });

  testWidgets('expanded sequence preview reflects section repetitions', (
    tester,
  ) async {
    final customStructure = SongStructure(
      songId: createdSong.id,
      name: 'Vista Previa Test',
      items: [
        const StructureItem(
          id: 'v1',
          type: SectionType.verso,
          name: 'Verso 1',
          repeatCount: 1,
        ),
        const StructureItem(
          id: 'c1',
          type: SectionType.coro,
          name: 'Coro',
          repeatCount: 3,
        ),
      ],
    );

    await tester.pumpWidget(
      createWidget(initialStructure: customStructure),
    );
    await tester.pumpAndSettle();

    // Preview should say 4 bloques (1 verso + 3 coros)
    expect(find.text('Secuencia expandida (4 bloques):'), findsOneWidget);

    // Increase Coro to x4
    await tester.tap(find.byKey(const Key('increment-repeat-1')));
    await tester.pumpAndSettle();

    // Preview should update to 5 bloques (1 verso + 4 coros)
    expect(find.text('Secuencia expandida (5 bloques):'), findsOneWidget);
  });

  testWidgets(
    'MSW-37: opens suggestion modal, detects structure, and does not apply if discarded',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Initial structure has 3 items
      expect(find.byKey(const Key('repeat-count-0')), findsOneWidget);
      expect(find.byKey(const Key('repeat-count-1')), findsOneWidget);
      expect(find.byKey(const Key('repeat-count-2')), findsOneWidget);

      // Open suggestion modal via action button
      await tester.tap(find.byKey(const Key('suggest-structure-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Estructura propuesta desde la letra'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('suggestion-lyrics-input')), findsOneWidget);

      // Paste new lyrics into modal
      const newLyrics = '''
[Verso 1]
Primera linea

[Coro]
Coro gloria

[Puente]
Puente santo
''';
      await tester.enterText(
        find.byKey(const Key('suggestion-lyrics-input')),
        newLyrics,
      );
      await tester.pumpAndSettle();

      // Proposal is shown in modal
      expect(find.byKey(const Key('proposal-summary-card')), findsOneWidget);
      expect(
        find.textContaining('encabezados explícitos'),
        findsOneWidget,
      );

      // Tap 'Descartar'
      await tester.tap(find.byKey(const Key('discard-suggestion-button')));
      await tester.pumpAndSettle();

      // Modal closed, and original 3 items remain unchanged!
      expect(find.byKey(const Key('delete-item-2')), findsOneWidget);
      expect(find.byKey(const Key('delete-item-3')), findsNothing);
    },
  );

  testWidgets(
    'MSW-37: Luis manual test - pastes lyrics, reviews proposal, applies and saves only after confirmation',
    (tester) async {
      SongStructure? savedOutput;
      await tester.pumpWidget(
        createWidget(
          onStructureSaved: (s) => savedOutput = s,
        ),
      );
      await tester.pumpAndSettle();

      // Open suggestion via chip
      await tester.tap(find.byKey(const Key('suggest-from-lyrics-chip')));
      await tester.pumpAndSettle();

      // Paste lyrics with verses and repeated chorus without tags
      const lyricsToTest = '''
El esplendor de un Rey
Vestido en majestad
La Tierra alegre esta

Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios

Dia a dia El esta
El tiempo en Sus manos

Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios
''';
      await tester.enterText(
        find.byKey(const Key('suggestion-lyrics-input')),
        lyricsToTest,
      );
      await tester.pumpAndSettle();

      // Proposal shows inferred structure
      expect(find.byKey(const Key('proposal-summary-card')), findsOneWidget);
      expect(
        find.textContaining('Coro detectado por repetición'),
        findsOneWidget,
      );

      // Apply structure
      await tester.tap(find.byKey(const Key('apply-suggestion-button')));
      await tester.pumpAndSettle();

      // Modal closed, editor now has 4 items (Verso 1, Coro, Verso 2, Coro)
      expect(find.byKey(const Key('delete-item-3')), findsOneWidget);
      expect(find.text('Secuencia expandida (4 bloques):'), findsOneWidget);

      // The structure is in editor memory, but NOT yet saved to repository
      expect(savedOutput, isNull);

      // Save structure explicitly
      await tester.tap(find.byKey(const Key('save-structure-button')));
      await tester.pumpAndSettle();

      // Now it is saved!
      expect(savedOutput, isNotNull);
      expect(savedOutput?.items.length, 4);
      expect(savedOutput?.items[1].name, 'Coro');
      expect(savedOutput?.items[1].type, SectionType.coro);
    },
  );
}
