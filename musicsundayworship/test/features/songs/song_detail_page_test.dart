import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/songs/song_detail_page.dart';

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

  testWidgets('switches rendered chords to Latin notation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SongDetailPage(song: _song)),
    );

    await tester.tap(find.text('Latina'));
    await tester.pump();
    expect(find.text('Do      Sol'), findsOneWidget);
  });
}
