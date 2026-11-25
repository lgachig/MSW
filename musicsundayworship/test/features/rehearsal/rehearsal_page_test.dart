import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/rehearsal/rehearsal_page.dart';
import 'package:musicsundayworship/music_engine/music_engine.dart';

void main() {
  const testSong = SongDocument(
    id: 1,
    title: 'Gracia Sublime Es',
    originalKey: 'G',
    tempo: 100,
    timeSignature: '4/4',
    sections: [
      SongSection(
        name: 'Verso 1',
        lines: [
          SongLine(
            content: 'Quién rompe el poder del pecado',
            chords: [
              ChordPlacementData(chord: 'G', position: 0),
              ChordPlacementData(chord: 'C', position: 10),
            ],
          ),
        ],
      ),
      SongSection(
        name: 'Coro',
        lines: [
          SongLine(
            content: 'Gracia sublime es',
            chords: [
              ChordPlacementData(chord: 'G', position: 0),
              ChordPlacementData(chord: 'D', position: 8),
            ],
          ),
        ],
      ),
    ],
  );

  final testStructure = SongStructure(
    name: 'Estructura Domingo',
    items: const [
      StructureItem(
        id: 'item_1',
        type: SectionType.verso,
        name: 'Verso 1',
        repeatCount: 1,
      ),
      StructureItem(
        id: 'item_2',
        type: SectionType.coro,
        name: 'Coro',
        repeatCount: 2,
      ),
    ],
  );

  Widget createRehearsalApp({
    SongDocument song = testSong,
    SongStructure? structure,
    RehearsalFlowController? controller,
  }) {
    return MaterialApp(
      home: RehearsalPage(
        song: song,
        structure: structure,
        controller: controller,
      ),
    );
  }

  group('RehearsalPage UI & Interaction', () {
    testWidgets('renders continuous vertical flow with active section and upcoming sections', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.text('Gracia Sublime Es'), findsOneWidget);
      expect(find.textContaining('100 BPM'), findsWidgets);
      expect(find.textContaining('Tono: G'), findsOneWidget);

      // Continuous vertical list
      expect(find.byKey(const Key('rehearsal-continuous-list')), findsOneWidget);

      // Active section card
      expect(find.byKey(const Key('current-section-card')), findsOneWidget);
      expect(find.text('Verso 1'), findsWidgets);
      expect(find.text('Quién rompe el poder del pecado'), findsOneWidget);

      // Upcoming sections are present in the list
      expect(find.text('Coro (1/2)'), findsWidgets);
      expect(find.text('Coro (2/2)'), findsWidgets);

      // Roadmap chips
      expect(find.byKey(const Key('section-roadmap-list')), findsOneWidget);
      expect(find.byKey(const Key('roadmap-chip-0')), findsOneWidget);
      expect(find.byKey(const Key('roadmap-chip-1')), findsOneWidget);
      expect(find.byKey(const Key('roadmap-chip-2')), findsOneWidget);

      // Bar counter
      expect(find.byKey(const Key('bar-counter-text')), findsOneWidget);
      expect(find.textContaining('Compás 1'), findsOneWidget);
    });

    testWidgets('Play and Pause toggles playback and button text', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.text('Iniciar ensayo'), findsOneWidget);

      // Tap Play
      await tester.tap(find.byKey(const Key('rehearsal-play-pause-button')));
      await tester.pump();

      expect(find.text('Pausar'), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byKey(const Key('rehearsal-play-pause-button')));
      await tester.pump();

      expect(find.text('Reanudar'), findsOneWidget);
    });

    testWidgets('navigation buttons jump to next and previous section', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.text('Verso 1'), findsWidgets);

      // Tap Next section
      await tester.tap(find.byKey(const Key('next-section-button')));
      await tester.pump();

      expect(find.text('Coro (1/2)'), findsWidgets);

      // Tap Next section again
      await tester.tap(find.byKey(const Key('next-section-button')));
      await tester.pump();

      expect(find.text('Coro (2/2)'), findsWidgets);

      // Tap Previous section
      await tester.tap(find.byKey(const Key('prev-section-button')));
      await tester.pump();

      expect(find.text('Coro (1/2)'), findsWidgets);
    });

    testWidgets('tapping a roadmap chip jumps directly to that section', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      // Tap chip 2 (Coro 2/2)
      await tester.tap(find.byKey(const Key('roadmap-chip-2')));
      await tester.pump();

      expect(find.text('Coro (2/2)'), findsWidgets);
    });

    testWidgets('BPM stepper buttons adjust tempo', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.byKey(const Key('rehearsal-bpm-text')), findsOneWidget);
      expect(find.text('100'), findsOneWidget);

      // Increment +2 BPM
      await tester.tap(find.byKey(const Key('rehearsal-bpm-inc')));
      await tester.pump();

      expect(find.text('102'), findsOneWidget);

      // Decrement -2 BPM
      await tester.tap(find.byKey(const Key('rehearsal-bpm-dec')));
      await tester.pump();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('keep awake button toggles state and shows snackbar', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.byKey(const Key('keep-awake-button')), findsOneWidget);
      expect(find.text('Pantalla encendida'), findsOneWidget);

      // Toggle off
      await tester.tap(find.byKey(const Key('keep-awake-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pantalla normal'), findsOneWidget);
      expect(find.text('Pantalla siempre encendida: Desactivado'), findsOneWidget);

      // Toggle back on
      await tester.tap(find.byKey(const Key('keep-awake-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pantalla encendida'), findsOneWidget);
      expect(find.text('Pantalla siempre encendida: Activado'), findsOneWidget);
    });

    testWidgets('active chord badge displays current sounding chord', (tester) async {
      await tester.pumpWidget(
        createRehearsalApp(structure: testStructure),
      );
      await tester.pump();

      expect(find.byKey(const Key('active-chord-badge')), findsOneWidget);
      expect(find.text('Acorde: G'), findsOneWidget);
    });
  });
}
