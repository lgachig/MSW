import '../data/song_repository.dart';
import 'song_structure.dart';
import 'time_signature.dart';

/// Sección preparada para el flujo continuo del ensayo.
class RehearsalSection {
  const RehearsalSection({
    required this.id,
    required this.name,
    required this.type,
    required this.bars,
    required this.lines,
    this.iterationIndex = 1,
    this.totalIterations = 1,
  });

  /// Identificador único para esta iteración en el flujo.
  final String id;

  /// Nombre visible (ej. "Verso 1", "Coro").
  final String name;

  /// Tipo de sección para estilos y colores.
  final SectionType type;

  /// Número de compases calculados o configurados para esta sección.
  final int bars;

  /// Líneas de texto y acordes de la sección.
  final List<SongLine> lines;

  /// Número de repetición actual (1, 2, ...).
  final int iterationIndex;

  /// Total de repeticiones de esta sección.
  final int totalIterations;

  /// Lista ordenada de todos los acordes de la sección.
  List<ChordPlacementData> get allChords => [
        for (final line in lines)
          for (final chord in line.chords) chord,
      ];

  /// Etiqueta visible con repetición (ej. "Coro (2/2)").
  String get displayTitle {
    if (totalIterations > 1) {
      return '$name ($iterationIndex/$totalIterations)';
    }
    return name;
  }

  RehearsalSection copyWith({
    String? id,
    String? name,
    SectionType? type,
    int? bars,
    List<SongLine>? lines,
    int? iterationIndex,
    int? totalIterations,
  }) =>
      RehearsalSection(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        bars: bars ?? this.bars,
        lines: lines ?? this.lines,
        iterationIndex: iterationIndex ?? this.iterationIndex,
        totalIterations: totalIterations ?? this.totalIterations,
      );
}

/// Plan completo y secuencial del ensayo para una canción.
class RehearsalSongPlan {
  const RehearsalSongPlan({
    required this.songTitle,
    required this.originalKey,
    required this.bpm,
    required this.timeSignature,
    required this.sections,
  });

  final String songTitle;
  final String? originalKey;
  final int bpm;
  final TimeSignature timeSignature;
  final List<RehearsalSection> sections;

  /// Total de compases de toda la canción en este plan.
  int get totalBars => sections.fold(0, (sum, sec) => sum + sec.bars);

  /// Total de pulsos (beats) de la canción.
  int get totalBeats => totalBars * timeSignature.beatsPerBar;

  /// Construye un plan secuencial a partir de un [SongDocument] y opcionalmente
  /// una estructura ordenada [SongStructure] o mapa de compases personalizados.
  factory RehearsalSongPlan.fromSong({
    required SongDocument song,
    SongStructure? structure,
    Map<String, int>? customBarsBySectionName,
  }) {
    final bpm = (song.tempo ?? 120).clamp(40, 220);
    final timeSignature =
        TimeSignature.tryParse(song.timeSignature) ?? TimeSignature.fourFour;

    // Mapa de secciones de la canción por nombre
    final sectionMap = <String, SongSection>{
      for (final s in song.sections) s.name.trim().toLowerCase(): s,
    };

    final rehearsalSections = <RehearsalSection>[];

    if (structure != null && structure.items.isNotEmpty) {
      // Usar la estructura ordenada con repeticiones expandidas
      int sectionCounter = 0;
      for (final item in structure.items) {
        final key = item.name.trim().toLowerCase();
        final matchedSongSection = sectionMap[key] ??
            song.sections.cast<SongSection?>().firstWhere(
                  (s) => s != null && s.name.toLowerCase().contains(key),
                  orElse: () => null,
                );

        final lines = matchedSongSection?.lines ?? const [];
        final defaultBars = _calculateDefaultBars(lines, item.type);
        final bars = customBarsBySectionName?[item.name] ??
            customBarsBySectionName?[item.id] ??
            defaultBars;

        for (var rep = 1; rep <= item.repeatCount; rep++) {
          sectionCounter++;
          rehearsalSections.add(
            RehearsalSection(
              id: 'sec_${sectionCounter}_${item.id}_rep$rep',
              name: item.name,
              type: item.type,
              bars: bars,
              lines: lines,
              iterationIndex: rep,
              totalIterations: item.repeatCount,
            ),
          );
        }
      }
    } else {
      // Usar las secciones originales de la canción
      int sectionCounter = 0;
      for (final s in song.sections) {
        sectionCounter++;
        final type = SectionType.fromString(s.name);
        final defaultBars = _calculateDefaultBars(s.lines, type);
        final bars = customBarsBySectionName?[s.name] ?? defaultBars;

        rehearsalSections.add(
          RehearsalSection(
            id: 'sec_${sectionCounter}_pos${s.position}',
            name: s.name.isEmpty ? 'Sección $sectionCounter' : s.name,
            type: type,
            bars: bars,
            lines: s.lines,
          ),
        );
      }
    }

    return RehearsalSongPlan(
      songTitle: song.title,
      originalKey: song.originalKey,
      bpm: bpm,
      timeSignature: timeSignature,
      sections: List.unmodifiable(rehearsalSections),
    );
  }

  /// Calcula una estimación musical inteligente de compases para una sección.
  static int _calculateDefaultBars(List<SongLine> lines, SectionType type) {
    if (lines.isEmpty) {
      switch (type) {
        case SectionType.intro:
        case SectionType.interludio:
        case SectionType.finalSection:
          return 4;
        default:
          return 4;
      }
    }

    // Contar acordes totales en la sección
    int chordCount = 0;
    for (final line in lines) {
      chordCount += line.chords.length;
    }

    if (chordCount > 0) {
      // Generalmente cada acorde dura 1 compás (o 2 si son muy pocos).
      // Si hay 4 acordes -> 4 compases; si hay 8 acordes -> 8 compases.
      return chordCount.clamp(4, 32);
    }

    // Si no hay acordes pero hay líneas de letra, asumir 2 compases por línea
    final barsFromLines = lines.length * 2;
    return barsFromLines.clamp(4, 32);
  }
}

