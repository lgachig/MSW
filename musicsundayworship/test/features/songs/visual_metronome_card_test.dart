import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/features/rehearsal/visual_metronome_card.dart';
import 'package:musicsundayworship/music_engine/song_structure.dart';

class _FakeMetronomeSongRepository implements SongRepository {
  _FakeMetronomeSongRepository({this.onUpdateTempo});

  final void Function(int songId, int? tempo, String? timeSignature)? onUpdateTempo;

  @override
  Future<SongDocument> updateTempoAndSignature(
    int songId, {
    int? tempo,
    String? timeSignature,
  }) async {
    onUpdateTempo?.call(songId, tempo, timeSignature);
    return SongDocument(
      id: songId,
      title: 'Test Song',
      tempo: tempo,
      timeSignature: timeSignature,
    );
  }

  @override
  Future<SongDocument> create(SongDocument song) => throw UnimplementedError();
  @override
  Future<SongDocument?> read(int id) async => null;
  @override
  Future<List<SongDocument>> readAll() async => [];
  @override
  Stream<List<SongDocument>> watchAll() => const Stream.empty();
  @override
  Future<SongDocument> update(SongDocument song) => throw UnimplementedError();
  @override
  Future<void> delete(int id) async {}
  @override
  Future<List<SongArrangement>> readArrangements(int songId) async => [];
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
  Future<SongStructure> createStructure(SongStructure structure) =>
      throw UnimplementedError();
  @override
  Future<List<SongStructure>> readStructures(int songId) async => [];
  @override
  Future<SongStructure> updateStructure(SongStructure structure) =>
      throw UnimplementedError();
  @override
  Future<void> deleteStructure(int id) async {}
  @override
  Future<SongStructure> duplicateStructure(int structureId, {String? newName}) =>
      throw UnimplementedError();
}

Widget _wrap(Widget child, {SongRepository? repo}) {
  return ProviderScope(
    overrides: [
      if (repo != null) songRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  group('VisualMetronomeCard', () {
    testWidgets('renders card with song tempo and time signature', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Tu Fidelidad',
        tempo: 80,
        timeSignature: '3/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      expect(find.byKey(const Key('visual-metronome-card')), findsOneWidget);
      expect(find.text('80 BPM'), findsWidgets);
      expect(find.text('3/4'), findsWidgets);
      expect(find.text('Pulso en pausa'), findsOneWidget);

      // In 3/4, there should be 3 beat indicators
      expect(find.byKey(const Key('beat-indicator-1')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-2')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-3')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-4')), findsNothing);
    });

    testWidgets('adjusts tempo with stepper buttons and slider', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Test Song',
        tempo: 100,
        timeSignature: '4/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      expect(find.text('100 BPM'), findsWidgets);

      // Increment +1
      await tester.tap(find.byKey(const Key('bpm-increment')));
      await tester.pump();
      expect(find.text('101 BPM'), findsWidgets);

      // Decrement -1
      await tester.tap(find.byKey(const Key('bpm-decrement')));
      await tester.pump();
      expect(find.text('100 BPM'), findsWidgets);

      // Fast increment +5
      await tester.tap(find.byKey(const Key('bpm-increment-fast')));
      await tester.pump();
      expect(find.text('105 BPM'), findsWidgets);

      // Fast decrement -5
      await tester.tap(find.byKey(const Key('bpm-decrement-fast')));
      await tester.pump();
      expect(find.text('100 BPM'), findsWidgets);
    });

    testWidgets('switches time signature to 6/8 and displays 6 beat indicators', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Test Song',
        tempo: 90,
        timeSignature: '4/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      // Tap 6/8 segment
      await tester.tap(find.text('6/8'));
      await tester.pump();

      expect(find.byKey(const Key('beat-indicator-1')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-2')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-3')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-4')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-5')), findsOneWidget);
      expect(find.byKey(const Key('beat-indicator-6')), findsOneWidget);
    });

    testWidgets('starts and stops visual pulse with beat 1 accent', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Test Song',
        tempo: 120,
        timeSignature: '4/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      expect(find.text('Iniciar pulso'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      // Start pulse
      await tester.tap(find.byKey(const Key('play-metronome-button')));
      await tester.pump();

      expect(find.text('Detener'), findsOneWidget);
      // Beat 1 should be active immediately with accent
      expect(find.text('1'), findsWidgets);
      expect(find.text('¡Tiempo 1 (Acento fuerte)!'), findsOneWidget);

      // Stop pulse
      await tester.tap(find.byKey(const Key('play-metronome-button')));
      await tester.pump();

      expect(find.text('Iniciar pulso'), findsOneWidget);
      expect(find.text('Pulso en pausa'), findsOneWidget);
    });

    testWidgets('tap tempo button responds to taps', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Test Song',
        tempo: 100,
        timeSignature: '4/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      // Tap 1
      await tester.tap(find.byKey(const Key('tap-tempo-button')));
      await tester.pump();
      expect(find.text('Toca...'), findsOneWidget);

      // Wait 500ms and tap 2 (120 BPM)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('tap-tempo-button')));
      await tester.pump();

      expect(find.text('120 BPM'), findsWidgets);
    });

    testWidgets('suggests tempo and time signature from AI and requires confirmation', (tester) async {
      const song = SongDocument(
        id: 1,
        title: 'Alabanza Sublime - 130 bpm',
        tempo: 80,
        timeSignature: '4/4',
        sections: [
          SongSection(
            name: 'Verso 1',
            lines: [
              SongLine(
                content: 'Ritmo 6/8 en júbilo',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song)));
      await tester.pump();

      // Click suggest button
      await tester.tap(find.byKey(const Key('suggest-tempo-button')));
      await tester.pumpAndSettle();

      // Dialog is visible
      expect(find.text('Sugerencia de tempo e IA'), findsOneWidget);
      expect(find.text('Tempo sugerido: 130 BPM'), findsOneWidget);
      expect(find.text('Compás sugerido: 6/8'), findsOneWidget);
      expect(find.byKey(const Key('discard-suggestion-button')), findsOneWidget);
      expect(find.byKey(const Key('apply-suggestion-button')), findsOneWidget);

      // Discard first: values should remain unchanged
      await tester.tap(find.byKey(const Key('discard-suggestion-button')));
      await tester.pumpAndSettle();

      expect(find.text('80 BPM'), findsWidgets);

      // Click suggest again and apply
      await tester.tap(find.byKey(const Key('suggest-tempo-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('apply-suggestion-button')));
      await tester.pumpAndSettle();

      // Applied!
      expect(find.text('130 BPM'), findsWidgets);
      expect(find.text('Sugerencia aplicada: 130 BPM, 6/8'), findsOneWidget);
    });

    testWidgets('saves tempo and time signature to song repository', (tester) async {
      int? savedSongId;
      int? savedTempo;
      String? savedSig;

      final repo = _FakeMetronomeSongRepository(
        onUpdateTempo: (id, tempo, sig) {
          savedSongId = id;
          savedTempo = tempo;
          savedSig = sig;
        },
      );

      const song = SongDocument(
        id: 42,
        title: 'Canción con tempo',
        tempo: 95,
        timeSignature: '4/4',
      );

      await tester.pumpWidget(_wrap(const VisualMetronomeCard(song: song), repo: repo));
      await tester.pump();

      // Change tempo to 110
      await tester.tap(find.byKey(const Key('bpm-increment-fast')));
      await tester.tap(find.byKey(const Key('bpm-increment-fast')));
      await tester.pump();

      // Tap save
      await tester.tap(find.byKey(const Key('save-tempo-button')));
      await tester.pumpAndSettle();

      expect(savedSongId, 42);
      expect(savedTempo, 105);
      expect(savedSig, '4/4');
      expect(find.text('Tempo guardado: 105 BPM, 4/4'), findsOneWidget);
    });
  });
}

