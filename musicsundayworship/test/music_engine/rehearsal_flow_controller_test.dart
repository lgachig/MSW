import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/music_engine/music_engine.dart';

void main() {
  group('RehearsalSongPlan', () {
    test('calculates bars per section and expands repetitions from structure', () {
      const song = SongDocument(
        id: 1,
        title: 'Cuan Grande es Dios',
        tempo: 120,
        timeSignature: '4/4',
        sections: [
          SongSection(
            name: 'Verso 1',
            lines: [
              SongLine(
                content: 'El esplendor de un rey',
                chords: [
                  ChordPlacementData(chord: 'G', position: 0),
                  ChordPlacementData(chord: 'Em', position: 10),
                ],
              ),
              SongLine(
                content: 'Vestido en majestad',
                chords: [
                  ChordPlacementData(chord: 'C', position: 0),
                  ChordPlacementData(chord: 'D', position: 10),
                ],
              ),
            ],
          ),
          SongSection(
            name: 'Coro',
            lines: [
              SongLine(
                content: 'Cuan grande es Dios',
                chords: [
                  ChordPlacementData(chord: 'G', position: 0),
                  ChordPlacementData(chord: 'D', position: 8),
                ],
              ),
            ],
          ),
        ],
      );

      final structure = SongStructure(
        name: 'Arreglo domingo',
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

      final plan = RehearsalSongPlan.fromSong(
        song: song,
        structure: structure,
      );

      // Verso 1 (x1) + Coro (x2) = 3 rehearsal sections in linear sequence
      expect(plan.sections.length, 3);
      expect(plan.sections[0].name, 'Verso 1');
      expect(plan.sections[0].bars, 4); // 4 chords -> 4 bars

      expect(plan.sections[1].name, 'Coro');
      expect(plan.sections[1].iterationIndex, 1);
      expect(plan.sections[1].totalIterations, 2);

      expect(plan.sections[2].name, 'Coro');
      expect(plan.sections[2].iterationIndex, 2);
      expect(plan.sections[2].totalIterations, 2);

      expect(plan.totalBars, 4 + 4 + 4);
      expect(plan.totalBeats, 12 * 4);
    });
  });

  group('RehearsalFlowController - Simulación rítmica y verificación', () {
    late RehearsalSongPlan testPlan;

    setUp(() {
      testPlan = const RehearsalSongPlan(
        songTitle: 'Canción Ensayo',
        originalKey: 'G',
        bpm: 120, // 500 ms por beat
        timeSignature: TimeSignature.fourFour, // 4 beats por compás
        sections: [
          RehearsalSection(
            id: 'sec_1',
            name: 'Verso',
            type: SectionType.verso,
            bars: 2, // 2 compases = 8 pulsos
            lines: [
              SongLine(
                content: 'Línea de verso',
                chords: [
                  ChordPlacementData(chord: 'G', position: 0),
                  ChordPlacementData(chord: 'C', position: 8),
                ],
              ),
            ],
          ),
          RehearsalSection(
            id: 'sec_2',
            name: 'Coro',
            type: SectionType.coro,
            bars: 2, // 2 compases = 8 pulsos
            lines: [
              SongLine(
                content: 'Línea de coro',
                chords: [
                  ChordPlacementData(chord: 'D', position: 0),
                ],
              ),
            ],
          ),
        ],
      );
    });

    test('Prueba con reloj simulado: cambia de sección en el compás exacto', () {
      fakeAsync((async) {
        final controller = RehearsalFlowController(plan: testPlan);

        expect(controller.sectionIndex, 0);
        expect(controller.currentSection?.name, 'Verso');
        expect(controller.nextSection?.name, 'Coro');
        expect(controller.currentBar, 1);
        expect(controller.currentBeat, 1);

        controller.play();
        expect(controller.isPlaying, isTrue);

        // Verso tiene 2 compases de 4 pulsos = 8 pulsos.
        // A 120 BPM, cada pulso dura 500 ms.
        // Compás 1: pulsos 1, 2, 3, 4 (0 ms a 1500 ms)
        async.elapse(const Duration(milliseconds: 1500));
        expect(controller.sectionIndex, 0);
        expect(controller.currentBar, 1);

        // Pasamos al compás 2 del Verso (a los 2000 ms)
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.sectionIndex, 0);
        expect(controller.currentBar, 2);

        // Completamos el compás 2: pulsos 2, 3, 4 (de 2500 a 3500 ms)
        async.elapse(const Duration(milliseconds: 1500));
        expect(controller.sectionIndex, 0);
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 4);

        // En el siguiente pulso exacto (4000 ms):
        // Se completa el 2do compás y cambia exactamente al Coro en el compás 1!
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.sectionIndex, 1);
        expect(controller.currentSection?.name, 'Coro');
        expect(controller.currentBar, 1);
        expect(controller.currentBeat, 1);
        expect(controller.nextSection, isNull); // Coro es la última

        controller.dispose();
      });
    });

    test('Pausar y reanudar no pierde el tiempo', () {
      fakeAsync((async) {
        final controller = RehearsalFlowController(plan: testPlan);

        controller.play();
        // Avanzamos 1 compás entero + 2 pulsos = 6 pulsos (3000 ms) -> compás 2, pulso 3
        async.elapse(const Duration(milliseconds: 2500));
        expect(controller.sectionIndex, 0);
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 2);

        // Pausar
        controller.pause();
        expect(controller.isPlaying, isFalse);
        expect(controller.isPaused, isTrue);
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 2);

        // El tiempo en pausa avanza pero la posición no debe perderse
        async.elapse(const Duration(seconds: 10));
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 2);
        expect(controller.sectionIndex, 0);

        // Reanudar
        controller.play();
        expect(controller.isPlaying, isTrue);
        expect(controller.isPaused, isFalse);
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 2);

        // Avanzar 1 pulso más (500 ms)
        async.elapse(const Duration(milliseconds: 500));
        expect(controller.currentBar, 2);
        expect(controller.currentBeat, 3);

        controller.dispose();
      });
    });

    test('Salto manual de sección (jumpToSection, nextSection, previousSection)', () {
      final controller = RehearsalFlowController(plan: testPlan);

      controller.jumpToSection(1);
      expect(controller.sectionIndex, 1);
      expect(controller.currentSection?.name, 'Coro');
      expect(controller.currentBar, 1);
      expect(controller.currentBeat, 1);

      controller.previousSection();
      expect(controller.sectionIndex, 0);
      expect(controller.currentSection?.name, 'Verso');

      controller.nextSection();
      expect(controller.sectionIndex, 1);

      controller.dispose();
    });

    test('Cambio de tempo sobre la marcha', () {
      final controller = RehearsalFlowController(plan: testPlan);

      expect(controller.bpm, 120);
      controller.setBpm(145);
      expect(controller.bpm, 145);

      // Clamps
      controller.setBpm(20);
      expect(controller.bpm, 40);
      controller.setBpm(300);
      expect(controller.bpm, 220);

      controller.dispose();
    });

    test('Resalta acorde activo según compás actual', () {
      final controller = RehearsalFlowController(plan: testPlan);
      // Verso tiene 2 compases y 2 acordes: 'G' y 'C'
      // En compás 1 -> acorde 'G'
      expect(controller.currentState.activeChord, 'G');

      // Si cambiamos compases de sección
      controller.updateSectionBars(0, 4);
      expect(controller.currentSection?.bars, 4);

      controller.dispose();
    });
  });
}

