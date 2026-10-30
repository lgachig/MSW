import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/songs/chord_editor.dart';

void main() {
  SongLine line([List<ChordPlacementData> chords = const []]) =>
      SongLine(content: 'Tu amor', chords: chords);

  testWidgets('agrega un acorde en la columna tocada y valida el texto', (
    tester,
  ) async {
    List<SongLine> result = [line()];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordEditor(
            lines: result,
            onChanged: (value) => result = value,
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('chord-line-0'))) +
          const Offset(48, 30),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chord-input')), 'not-a-chord');
    await tester.tap(find.byKey(const Key('confirm-chord')));
    await tester.pump();
    expect(find.text('Acorde no válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chord-input')), 'G');
    await tester.tap(find.byKey(const Key('confirm-chord')));
    await tester.pumpAndSettle();
    expect(result.single.chords.single.chord, 'G');
    expect(result.single.chords.single.position, 5);
  });

  testWidgets('deshacer y rehacer restauran el acorde', (tester) async {
    List<SongLine> result = [line()];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordEditor(
            lines: result,
            onChanged: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('chord-line-0'))) +
          const Offset(10, 30),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chord-input')), 'C');
    await tester.tap(find.byKey(const Key('confirm-chord')));
    await tester.pumpAndSettle();
    expect(result.single.chords, isNotEmpty);

    await tester.tap(find.byKey(const Key('undo-chord-edit')));
    await tester.pump();
    expect(result.single.chords, isEmpty);
    await tester.tap(find.byKey(const Key('redo-chord-edit')));
    await tester.pump();
    expect(result.single.chords.single.chord, 'C');
  });

  testWidgets('deslizar un acorde lo elimina', (tester) async {
    List<SongLine> result = [
      line([const ChordPlacementData(chord: 'G', position: 0)]),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChordEditor(
            lines: result,
            onChanged: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('chord-G-0')), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(result.single.chords, isEmpty);
  });
}
