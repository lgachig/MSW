import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/song_structure.dart';

void main() {
  group('SectionType', () {
    test('parses common Spanish and English names to correct enum', () {
      expect(SectionType.fromString('Intro 1'), SectionType.intro);
      expect(SectionType.fromString('Introducción'), SectionType.intro);
      expect(SectionType.fromString('Verso 1'), SectionType.verso);
      expect(SectionType.fromString('Estrofa 2'), SectionType.verso);
      expect(SectionType.fromString('Verse'), SectionType.verso);
      expect(SectionType.fromString('Pre-coro'), SectionType.precoro);
      expect(SectionType.fromString('Precoro'), SectionType.precoro);
      expect(SectionType.fromString('Coro'), SectionType.coro);
      expect(SectionType.fromString('Estribillo'), SectionType.coro);
      expect(SectionType.fromString('Chorus'), SectionType.coro);
      expect(SectionType.fromString('Puente'), SectionType.puente);
      expect(SectionType.fromString('Bridge'), SectionType.puente);
      expect(SectionType.fromString('Interludio'), SectionType.interludio);
      expect(SectionType.fromString('Solo de Guitarra'), SectionType.interludio);
      expect(SectionType.fromString('Instrumental'), SectionType.interludio);
      expect(SectionType.fromString('Final'), SectionType.finalSection);
      expect(SectionType.fromString('Outro'), SectionType.finalSection);
      expect(SectionType.fromString('Coda'), SectionType.finalSection);
      expect(SectionType.fromString('Cualquier cosa'), SectionType.otro);
    });

    test('exposes human-readable display names', () {
      expect(SectionType.intro.displayName, 'Intro');
      expect(SectionType.verso.displayName, 'Verso');
      expect(SectionType.precoro.displayName, 'Pre-coro');
      expect(SectionType.coro.displayName, 'Coro');
      expect(SectionType.puente.displayName, 'Puente');
      expect(SectionType.interludio.displayName, 'Interludio');
      expect(SectionType.finalSection.displayName, 'Final');
    });
  });

  group('StructureItem', () {
    test('formats label with repetition count when greater than 1', () {
      const single = StructureItem(
        id: '1',
        type: SectionType.verso,
        name: 'Verso 1',
        repeatCount: 1,
      );
      expect(single.labelWithRepeats, 'Verso 1');

      const repeated = StructureItem(
        id: '2',
        type: SectionType.coro,
        name: 'Coro',
        repeatCount: 3,
      );
      expect(repeated.labelWithRepeats, 'Coro x3');
    });

    test('serializes and deserializes correctly via JSON', () {
      const item = StructureItem(
        id: 'c1',
        type: SectionType.coro,
        name: 'Coro Principal',
        repeatCount: 2,
        customNote: 'Entrada suave',
      );

      final json = item.toJson();
      final restored = StructureItem.fromJson(json);

      expect(restored, item);
      expect(restored.repeatCount, 2);
      expect(restored.customNote, 'Entrada suave');
    });
  });

  group('SongStructure - Repetitions and Duplication', () {
    test('expands repetitions: Coro x3 se expande a tres coros', () {
      const structure = SongStructure(
        name: 'Estructura Domingo',
        items: [
          StructureItem(
            id: 'coro_1',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 3,
          ),
        ],
      );

      final expanded = structure.expand();

      // Debe haber exactamente 3 coros individuales
      expect(expanded.length, 3);
      for (final item in expanded) {
        expect(item.type, SectionType.coro);
        expect(item.name, 'Coro');
        expect(item.repeatCount, 1);
      }
      expect(expanded[0].id, 'coro_1_rep_1');
      expect(expanded[1].id, 'coro_1_rep_2');
      expect(expanded[2].id, 'coro_1_rep_3');
    });

    test('expands complex structure with multiple sections and repetitions', () {
      const structure = SongStructure(
        name: 'Arreglo Completo',
        items: [
          StructureItem(
            id: 'intro',
            type: SectionType.intro,
            name: 'Intro',
            repeatCount: 1,
          ),
          StructureItem(
            id: 'verso1',
            type: SectionType.verso,
            name: 'Verso 1',
            repeatCount: 2,
          ),
          StructureItem(
            id: 'coro',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 3,
          ),
          StructureItem(
            id: 'puente',
            type: SectionType.puente,
            name: 'Puente',
            repeatCount: 1,
          ),
          StructureItem(
            id: 'final',
            type: SectionType.finalSection,
            name: 'Final',
            repeatCount: 2,
          ),
        ],
      );

      final expanded = structure.expand();

      // Total de secciones expandidas: 1 + 2 + 3 + 1 + 2 = 9
      expect(expanded.length, 9);
      expect(expanded.map((e) => e.name).toList(), [
        'Intro',
        'Verso 1',
        'Verso 1',
        'Coro',
        'Coro',
        'Coro',
        'Puente',
        'Final',
        'Final',
      ]);
    });

    test('duplicar una estructura no cambia la original (inmutabilidad e independencia)', () {
      final original = SongStructure(
        id: 10,
        songId: 100,
        name: 'Versión Original',
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
            repeatCount: 2,
          ),
        ],
      );

      final duplicate = original.duplicate(newName: 'Versión Acústica');

      // 1. La copia debe tener nuevo nombre y sin id asignado aún
      expect(duplicate.name, 'Versión Acústica');
      expect(duplicate.id, isNull);
      expect(duplicate.songId, 100);
      expect(duplicate.items.length, 2);

      // 2. Modificar la copia agregando y cambiando elementos
      final modifiedDuplicate = duplicate.copyWith(
        items: [
          ...duplicate.items,
          const StructureItem(
            id: 'p1',
            type: SectionType.puente,
            name: 'Puente Espontáneo',
            repeatCount: 4,
          ),
        ],
      );

      // 3. Comprobar que la estructura original permanece intacta
      expect(original.items.length, 2);
      expect(original.name, 'Versión Original');
      expect(original.items[1].repeatCount, 2);
      expect(original.expand().length, 3); // 1 verso + 2 coros

      // La copia modificada tiene 3 items y se expande diferente
      expect(modifiedDuplicate.items.length, 3);
      expect(modifiedDuplicate.expand().length, 7); // 1 verso + 2 coros + 4 puentes
    });

    test('supports JSON roundtrip serialization', () {
      const original = SongStructure(
        id: 5,
        songId: 42,
        name: 'Arreglo de Alabanza',
        isDefault: true,
        items: [
          StructureItem(
            id: 'i1',
            type: SectionType.intro,
            name: 'Intro',
            repeatCount: 1,
          ),
          StructureItem(
            id: 'c1',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 3,
            customNote: 'Toda la congregación',
          ),
        ],
      );

      final jsonStr = original.toJsonString();
      final restored = SongStructure.fromJsonString(jsonStr);

      expect(restored.id, 5);
      expect(restored.songId, 42);
      expect(restored.name, 'Arreglo de Alabanza');
      expect(restored.isDefault, isTrue);
      expect(restored.items.length, 2);
      expect(restored.items[1].repeatCount, 3);
      expect(restored.items[1].customNote, 'Toda la congregación');
    });
  });
}
