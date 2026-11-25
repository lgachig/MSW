import '../data/song_repository.dart';
import 'lyrics_structure_suggester.dart';
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

    final rehearsalSections = <RehearsalSection>[];

    if (structure != null && structure.items.isNotEmpty) {
      // Usar la estructura ordenada con repeticiones expandidas
      int sectionCounter = 0;
      for (final item in structure.items) {
        final matchedSongSection = _findMatchingSongSection(item, song.sections);
        final lines = matchedSongSection?.lines.isNotEmpty == true
            ? matchedSongSection!.lines
            : [SongLine(content: '[${item.name} - Instrumental]')];

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
        final type = LyricsStructureSuggester.matchHeader(s.name)?.type ??
            SectionType.fromString(s.name);
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

  /// Empareja de forma flexible e inteligente un [StructureItem] con la sección real
  /// de la canción, soportando nombres con o sin números, etiquetas y tipos de sección.
  static SongSection? _findMatchingSongSection(
    StructureItem item,
    List<SongSection> songSections,
  ) {
    if (songSections.isEmpty) return null;

    final itemClean = item.name.toLowerCase().trim().replaceAll(RegExp(r'[\[\]\(\)]'), '');

    // 1. Coincidencia exacta de nombre limpio
    for (final sec in songSections) {
      final secClean = sec.name.toLowerCase().trim().replaceAll(RegExp(r'[\[\]\(\)]'), '');
      if (secClean == itemClean) return sec;
    }

    // 2. Coincidencia parcial de nombres cruzados (ej: "Verso 1" y "Verso", o "Coro" y "Coro 1")
    for (final sec in songSections) {
      final s = sec.name.toLowerCase().trim();
      final it = itemClean;
      if (s.contains(it) || it.contains(s)) return sec;
    }

    // 3. Coincidencia por tipo de sección (ej: SectionType.coro con sección de coro)
    for (final sec in songSections) {
      final secType = LyricsStructureSuggester.matchHeader(sec.name)?.type ??
          SectionType.fromString(sec.name);
      if (secType == item.type && secType != SectionType.otro) {
        return sec;
      }
    }

    // 4. Búsqueda por posición en id 'sec_X_...'
    final matchPos = RegExp(r'sec_(\d+)').firstMatch(item.id);
    if (matchPos != null) {
      final idx = int.tryParse(matchPos.group(1)!);
      if (idx != null && idx >= 0 && idx < songSections.length) {
        return songSections[idx];
      }
    }

    // 5. Coincidencia por raíz léxica (ej: "estrofa" coincide con "verso")
    final itemAlpha = itemClean.replaceAll(RegExp(r'[^a-záéíóúñ]'), '');
    for (final sec in songSections) {
      final secAlpha = sec.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-záéíóúñ]'), '');
      if (secAlpha.isNotEmpty &&
          (secAlpha.contains(itemAlpha) || itemAlpha.contains(secAlpha))) {
        return sec;
      }
    }

    // 6. Si es Coro y hay al menos una sección que mencione coro
    if (item.type == SectionType.coro) {
      final anyChorus = songSections.cast<SongSection?>().firstWhere(
            (s) =>
                s != null &&
                (s.name.toLowerCase().contains('coro') ||
                    s.name.toLowerCase().contains('chorus')),
            orElse: () => null,
          );
      if (anyChorus != null) return anyChorus;
    }

    // 7. Si es Verso y no encontró específico, usar el primer verso disponible
    if (item.type == SectionType.verso) {
      final anyVerse = songSections.cast<SongSection?>().firstWhere(
            (s) =>
                s != null &&
                (s.name.toLowerCase().contains('verso') ||
                    s.name.toLowerCase().contains('estrofa') ||
                    s.name.toLowerCase().contains('verse')),
            orElse: () => null,
          );
      if (anyVerse != null) return anyVerse;
    }

    return null;
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
      return chordCount.clamp(4, 32);
    }

    // Si no hay acordes pero hay líneas de letra, asumir 2 compases por línea
    final barsFromLines = lines.length * 2;
    return barsFromLines.clamp(4, 32);
  }
}
