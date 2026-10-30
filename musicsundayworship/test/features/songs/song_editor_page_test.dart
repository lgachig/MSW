import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/songs/song_editor_page.dart';

class _FakeSongRepository implements SongRepository {
  _FakeSongRepository();

  SongDocument? song;

  @override
  Future<SongDocument> create(SongDocument value) async =>
      song = value.copyWith(id: 1);
  @override
  Future<void> delete(int id) async {}
  @override
  Future<SongDocument?> read(int id) async => song;
  @override
  Future<List<SongDocument>> readAll() async => song == null ? [] : [song!];
  @override
  Stream<List<SongDocument>> watchAll() =>
      Stream.value(song == null ? <SongDocument>[] : [song!]);
  @override
  Future<SongDocument> update(SongDocument value) async => song = value;
}

class _FailingSongRepository extends _FakeSongRepository {
  _FailingSongRepository() : super();

  @override
  Future<SongDocument> create(SongDocument value) =>
      Future<SongDocument>.error(StateError('storage unavailable'));
}

class _EditorHost extends StatelessWidget {
  const _EditorHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ElevatedButton(
          key: const Key('create-song'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SongEditorPage()),
          ),
          child: const Text('Crear'),
        ),
        ElevatedButton(
          key: const Key('edit-song'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SongEditorPage(songId: 1),
            ),
          ),
          child: const Text('Editar'),
        ),
      ],
    ),
  );
}

void main() {
  test('parses chord lines into placements above lyric lines', () {
    final sections = SongTextParser.parse('G       C\nTu amor no cambia');

    expect(sections.single.lines.single.content, 'Tu amor no cambia');
    expect(sections.single.lines.single.chords.map((chord) => chord.chord), [
      'G',
      'C',
    ]);
  });

  test('formats chord placements with their original columns', () {
    final sections = SongTextParser.parse('A       E/G#       F#m\nLetra');

    expect(SongTextParser.format(sections), 'A       E/G#       F#m\nLetra');
  });

  test('preserves punctuation between chord placements', () {
    final sections = SongTextParser.parse('A       .       E\nLetra');

    expect(SongTextParser.format(sections), 'A       .       E\nLetra');
  });

  test('preserves punctuation attached to chords and remaining spacing', () {
    final withPunctuation = SongTextParser.parse('.A       E.\nLetra');
    final withoutPunctuation = SongTextParser.parse('A       E\nLetra');

    expect(SongTextParser.format(withPunctuation), '.A       E.\nLetra');
    expect(SongTextParser.format(withoutPunctuation), 'A       E\nLetra');
  });

  test('keeps the exact spacing from the reported chord line', () {
    const input = 'A.          F#m\nLetra';
    final sections = SongTextParser.parse(input);

    expect(SongTextParser.format(sections), input);
    expect(
      sections.single.lines.single.chords
          .map((chord) => (chord.chord, chord.position))
          .toList(),
      [('A', 0), ('.', 1), ('F#m', 12)],
    );
  });

  testWidgets('uses a monospaced font for pasted chord text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(_FakeSongRepository()),
        ],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );

    final lyricsField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );

    expect(lyricsField.style?.fontFamily, 'monospace');
  });

  testWidgets('requires title and key before saving', (tester) async {
    final repository = _FakeSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );

    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await tester.pump();
    expect(find.text('Ingresa el título'), findsOneWidget);
    expect(find.text('Ingresa el tono'), findsOneWidget);
    expect(repository.song, isNull);
  });

  testWidgets('saves metadata and pasted content', (tester) async {
    final repository = _FakeSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nueva');
    await tester.enterText(fields.at(1), 'Autor');
    await tester.enterText(fields.at(2), 'Fuente');
    await tester.enterText(fields.at(3), 'G');
    await tester.enterText(fields.at(6), 'G\nLetra');
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.song?.author, 'Autor');
    expect(repository.song?.source, 'Fuente');
    expect(repository.song?.sections.single.lines.single.content, 'Letra');
  });

  testWidgets('saves the pasted chord columns without rebuilding the text', (
    tester,
  ) async {
    final repository = _FakeSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nueva');
    await tester.enterText(fields.at(3), 'G');
    await tester.enterText(fields.at(6), 'A.          F#m\nLetra');
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      SongTextParser.format(repository.song!.sections),
      'A.          F#m\nLetra',
    );
  });

  testWidgets('saves pasted spacing without punctuation', (tester) async {
    final repository = _FakeSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nueva');
    await tester.enterText(fields.at(3), 'G');
    await tester.enterText(fields.at(6), 'A          F#m\nLetra');
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      SongTextParser.format(repository.song!.sections),
      'A          F#m\nLetra',
    );
  });

  testWidgets('creates and edits an existing song', (tester) async {
    final repository = _FakeSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: _EditorHost()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-song')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Original');
    await tester.enterText(fields.at(3), 'G');
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.song?.id, 1);
    expect(repository.song?.title, 'Original');

    await tester.tap(find.byKey(const Key('edit-song')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Editada');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.song?.id, 1);
    expect(repository.song?.title, 'Editada');
  });

  testWidgets('shows persistence errors in the UI', (tester) async {
    final repository = _FailingSongRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SongEditorPage()),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nueva');
    await tester.enterText(fields.at(3), 'G');
    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('song-save-error')), findsOneWidget);
    expect(find.textContaining('No se pudo guardar'), findsOneWidget);
  });
}
