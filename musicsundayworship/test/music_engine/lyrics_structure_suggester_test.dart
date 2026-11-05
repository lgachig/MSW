import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/data/song_repository.dart';
import 'package:musicsundayworship/music_engine/music_engine.dart';

void main() {
  group('LyricsStructureSuggester - 3 Ejemplos de letra', () {
    test('Ejemplo 1: Letra con encabezados y etiquetas explícitas', () {
      const explicitLyrics = '''
[Verso 1]
Tu amor no se rinde jamas
Tu gracia me basta siempre
G                 D
En la tormenta me sostendras

[Coro]
Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios

[Verso 2]
Dia a dia El esta
El tiempo esta en Sus manos
Principio y fin

[Coro]
Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios

[Puente]
Tu nombre sobre todo es
Eres digno de alabar
Y mi ser cantara cuan grande es Dios

[Final]
Cuan grande es Dios
Por siempre reinaras
''';

      final proposal = LyricsStructureSuggester.suggestFromText(explicitLyrics);

      expect(proposal.hasExplicitHeaders, isTrue);
      expect(proposal.confidence, greaterThanOrEqualTo(0.95));
      expect(proposal.items.length, 6);

      expect(proposal.items[0].type, SectionType.verso);
      expect(proposal.items[0].name, 'Verso 1');

      expect(proposal.items[1].type, SectionType.coro);
      expect(proposal.items[1].name, 'Coro');

      expect(proposal.items[2].type, SectionType.verso);
      expect(proposal.items[2].name, 'Verso 2');

      expect(proposal.items[3].type, SectionType.coro);
      expect(proposal.items[3].name, 'Coro');

      expect(proposal.items[4].type, SectionType.puente);
      expect(proposal.items[4].name, 'Puente');

      expect(proposal.items[5].type, SectionType.finalSection);
      expect(proposal.items[5].name, 'Final');

      expect(proposal.explanation, contains('encabezados explícitos'));
    });

    test(
      'Ejemplo 2: Letra sin etiquetas detecta Coro por repetición textual (Cuan grande es Dios)',
      () {
        const unlabeledLyrics = '''
El esplendor de un Rey
Vestido en majestad
La Tierra alegre esta
La Tierra alegre esta

Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios

Dia a dia El esta
El tiempo en Sus manos
Principio y el fin
Principio y el fin

Cuan grande es Dios
Cantale cuan grande es Dios
Y todos veran cuan grande es Dios
''';

        final proposal = LyricsStructureSuggester.suggestFromText(unlabeledLyrics);

        expect(proposal.hasExplicitHeaders, isFalse);
        expect(proposal.items.length, 4);

        // Estrofa 0: Verso 1
        expect(proposal.items[0].type, SectionType.verso);
        expect(proposal.items[0].name, 'Verso 1');

        // Estrofa 1: Coro (se repite en estrofa 3)
        expect(proposal.items[1].type, SectionType.coro);
        expect(proposal.items[1].name, 'Coro');

        // Estrofa 2: Verso 2
        expect(proposal.items[2].type, SectionType.verso);
        expect(proposal.items[2].name, 'Verso 2');

        // Estrofa 3: Coro
        expect(proposal.items[3].type, SectionType.coro);
        expect(proposal.items[3].name, 'Coro');

        expect(proposal.explanation, contains('Coro detectado por repetición'));
      },
    );

    test(
      'Ejemplo 3: Himno de adoración con Pre-coro, Coro, Puente y Final (La Bondad de Dios)',
      () {
        const worshipAnthem = '''
Te amo Dios, Tu gracia nunca falla
Todos mis dias en Tus manos estan
He vivido en Tu fidelidad

Desde que despierto hasta el anochecer
Cantare de la bondad de Dios

En mi vida has sido bueno
En mi vida has sido fiel
Con cada aliento que me das
Cantare de la bondad de Dios

Amo Tu voz, me has guiado por el fuego
En la oscuridad Tu cerca estas
Te conozco como Padre y como amigo

En mi vida has sido bueno
En mi vida has sido fiel
Con cada aliento que me das
Cantare de la bondad de Dios

Tu fidelidad me sigue a donde voy
Tu fidelidad me sigue a donde voy
Rindo mi vida ante Ti hoy
Tu fidelidad me sigue a donde voy

Cantare de la bondad de Dios
Por siempre
''';

        final proposal = LyricsStructureSuggester.suggestFromText(worshipAnthem);

        expect(proposal.hasExplicitHeaders, isFalse);
        expect(proposal.items.length, 7);

        // Bloque 0: Verso 1
        expect(proposal.items[0].type, SectionType.verso);
        expect(proposal.items[0].name, 'Verso 1');

        // Bloque 1: Estrofa corta de 2 líneas antes del primer coro -> Pre-coro
        expect(proposal.items[1].type, SectionType.precoro);
        expect(proposal.items[1].name, 'Pre-coro');

        // Bloque 2: Coro (repetido)
        expect(proposal.items[2].type, SectionType.coro);
        expect(proposal.items[2].name, 'Coro');

        // Bloque 3: Verso 2
        expect(proposal.items[3].type, SectionType.verso);
        expect(proposal.items[3].name, 'Verso 2');

        // Bloque 4: Coro (repetición)
        expect(proposal.items[4].type, SectionType.coro);
        expect(proposal.items[4].name, 'Coro');

        // Bloque 5: Estrofa no repetida tras el coro en la 2da mitad -> Puente
        expect(proposal.items[5].type, SectionType.puente);
        expect(proposal.items[5].name, 'Puente');

        // Bloque 6: Estrofa final corta -> Final
        expect(proposal.items[6].type, SectionType.finalSection);
        expect(proposal.items[6].name, 'Final');
      },
    );
  });

  group('LyricsStructureSuggester - Casos adicionales y robustez', () {
    test('maneja texto vacío o en blanco sin fallar', () {
      final empty = LyricsStructureSuggester.suggestFromText('');
      expect(empty.items, isEmpty);
      expect(empty.confidence, 0.0);

      final whitespace = LyricsStructureSuggester.suggestFromText('   \n\n   ');
      expect(whitespace.items, isEmpty);
    });

    test('filtra acordes intercalados para analizar letra limpia', () {
      const chordSheet = '''
[Verso 1]
G                 C
Tu amor no cambia senor
Em          D
Siempre fiel

[Coro]
G        D/F#
Aleluya gloria a Dios
Em       C
Aleluya cantamos
''';

      final proposal = LyricsStructureSuggester.suggestFromText(chordSheet);
      expect(proposal.items.length, 2);
      expect(proposal.items[0].type, SectionType.verso);
      expect(proposal.items[1].type, SectionType.coro);

      // Verify that parsed sections retain the chords
      expect(proposal.sections[0].lines.first.chords, isNotEmpty);
    });

    test('toSongStructure genera un SongStructure válido e independiente', () {
      const text = '''
[Verso 1]
Canto hoy

[Coro]
Canto siempre
''';
      final proposal = LyricsStructureSuggester.suggestFromText(text);
      final structure = proposal.toSongStructure(
        songId: 42,
        name: 'Propuesta Personalizada',
      );

      expect(structure.songId, 42);
      expect(structure.name, 'Propuesta Personalizada');
      expect(structure.items.length, 2);
      expect(structure.items[0].type, SectionType.verso);
      expect(structure.items[1].type, SectionType.coro);
    });

    test('detecta secciones incluso si se pegan sin líneas en blanco intermedias', () {
      const tightLyrics = '''
[Verso 1]
Tu amor no cambia
Tu gracia es real
[Coro]
Cuan grande es Dios
Cantale cuan grande es Dios
[Verso 2]
Dia a dia El esta
El tiempo en Sus manos
[Coro]
Cuan grande es Dios
Cantale cuan grande es Dios
''';

      final proposal = LyricsStructureSuggester.suggestFromText(tightLyrics);

      expect(proposal.items.length, 4);
      expect(proposal.items[0].name, 'Verso 1');
      expect(proposal.items[0].type, SectionType.verso);

      expect(proposal.items[1].name, 'Coro');
      expect(proposal.items[1].type, SectionType.coro);

      expect(proposal.items[2].name, 'Verso 2');
      expect(proposal.items[2].type, SectionType.verso);

      expect(proposal.items[3].name, 'Coro');
      expect(proposal.items[3].type, SectionType.coro);
    });

    test('extrae indicadores de repetición como x2, (2x) o Bis en encabezados', () {
      const repeatedHeaders = '''
[Verso 1]
Canto a mi Senor

[Coro] x2
Santo es el Senor
Digno de loor

[Puente] (Bis)
Aleluya al Rey
''';

      final proposal = LyricsStructureSuggester.suggestFromText(repeatedHeaders);

      expect(proposal.items.length, 3);
      expect(proposal.items[0].name, 'Verso 1');
      expect(proposal.items[0].repeatCount, 1);

      expect(proposal.items[1].name, 'Coro');
      expect(proposal.items[1].repeatCount, 2);

      expect(proposal.items[2].name, 'Puente');
      expect(proposal.items[2].repeatCount, 2);
    });

    test('ignora nombres genéricos como Sección 1 y clasifica por la letra y repeticiones', () {
      final genericSections = [
        const SongSection(
          name: 'Sección 1',
          position: 0,
          lines: [
            SongLine(content: 'El esplendor de un Rey vestido en majestad', position: 0),
          ],
        ),
        const SongSection(
          name: 'Sección 2',
          position: 1,
          lines: [
            SongLine(content: 'Cuan grande es Dios, cantale', position: 0),
          ],
        ),
        const SongSection(
          name: 'Sección 3',
          position: 2,
          lines: [
            SongLine(content: 'Dia a dia El esta, el tiempo en Sus manos', position: 0),
          ],
        ),
        const SongSection(
          name: 'Sección 4',
          position: 3,
          lines: [
            SongLine(content: 'Cuan grande es Dios, cantale', position: 0),
          ],
        ),
      ];

      final proposal = LyricsStructureSuggester.suggestFromSections(genericSections);

      // Successfully classified into Verso 1, Coro, Verso 2, Coro!
      expect(proposal.items.length, 4);
      expect(proposal.items[0].name, 'Verso 1');
      expect(proposal.items[0].type, SectionType.verso);

      expect(proposal.items[1].name, 'Coro');
      expect(proposal.items[1].type, SectionType.coro);

      expect(proposal.items[2].name, 'Verso 2');
      expect(proposal.items[2].type, SectionType.verso);

      expect(proposal.items[3].name, 'Coro');
      expect(proposal.items[3].type, SectionType.coro);
    });
  });
}

