import '../data/song_repository.dart';
import 'chord_line_detector.dart';
import 'song_structure.dart';

/// The result of analyzing lyrics to propose a musical song structure.
class StructureProposal {
  const StructureProposal({
    required this.items,
    required this.sections,
    required this.explanation,
    required this.hasExplicitHeaders,
    this.confidence = 1.0,
  });

  /// The suggested ordered list of sections with repetitions and colors.
  final List<StructureItem> items;

  /// The normalized song sections with their lyrics and chord placements.
  final List<SongSection> sections;

  /// Human-readable explanation of how the structure was deduced.
  final String explanation;

  /// Whether the lyrics contained explicit tags (e.g. `[Verso 1]`, `Coro:`).
  final bool hasExplicitHeaders;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Converts the proposed items into a new [SongStructure].
  SongStructure toSongStructure({
    int? songId,
    String name = 'Estructura sugerida',
    bool isDefault = false,
  }) {
    return SongStructure(
      songId: songId,
      name: name,
      items: items,
      isDefault: isDefault,
    );
  }
}

/// Analyzes lyrics (plain text or chord-over-lyric) to detect stanzas,
/// repetitions, and structural section roles (Intro, Verso, Pre-coro, Coro, Puente, Final).
class LyricsStructureSuggester {
  const LyricsStructureSuggester._();

  static final RegExp _headerRegex = RegExp(
    r'^(?:##?|\[|\()?\s*(intro(?:ducci[oó]n)?|verso\s*\d*|verse\s*\d*|estrofa\s*\d*|pre-?coro\s*\d*|pre-?chorus\s*\d*|coro\s*\d*|chorus\s*\d*|estribillo\s*\d*|puente\s*\d*|bridge\s*\d*|interludio\s*\d*|interlude\s*\d*|solo|instrumental|final|outro|coda)(?:\s*\]|\)|\:)?\s*$',
    caseSensitive: false,
  );

  /// Proposes a [SongStructure] from raw lyrics or chord-sheet text.
  static StructureProposal suggestFromText(String rawText) {
    final clean = rawText.replaceAll('\r\n', '\n').trim();
    if (clean.isEmpty) {
      return const StructureProposal(
        items: [],
        sections: [],
        explanation: 'El texto está vacío. No se detectaron secciones.',
        hasExplicitHeaders: false,
        confidence: 0.0,
      );
    }

    final rawBlocks = clean.split(RegExp(r'\n\s*\n'));
    final parsedBlocks = <_RawBlock>[];

    for (var i = 0; i < rawBlocks.length; i++) {
      final blockText = rawBlocks[i].trim();
      if (blockText.isEmpty) continue;
      final block = _parseBlock(blockText, i);
      if (block != null) {
        parsedBlocks.add(block);
      }
    }

    if (parsedBlocks.isEmpty) {
      return const StructureProposal(
        items: [],
        sections: [],
        explanation: 'No se encontraron estrofas válidas.',
        hasExplicitHeaders: false,
        confidence: 0.0,
      );
    }

    final hasExplicitHeaders =
        parsedBlocks.where((b) => b.explicitHeader != null).length >=
        (parsedBlocks.length / 2).ceil();

    if (hasExplicitHeaders) {
      return _buildFromExplicitHeaders(parsedBlocks);
    } else {
      return _buildFromRepetitionsAndPosition(parsedBlocks);
    }
  }

  /// Proposes a [SongStructure] from existing song sections.
  static StructureProposal suggestFromSections(List<SongSection> sections) {
    if (sections.isEmpty) {
      return const StructureProposal(
        items: [],
        sections: [],
        explanation: 'La canción no tiene secciones.',
        hasExplicitHeaders: false,
        confidence: 0.0,
      );
    }

    final buffer = StringBuffer();
    for (final sec in sections) {
      buffer.writeln('## ${sec.name}');
      for (final line in sec.lines) {
        if (line.chords.isNotEmpty) {
          final chordRow = StringBuffer();
          for (final c in line.chords) {
            if (chordRow.length < c.position) {
              chordRow.write(' ' * (c.position - chordRow.length));
            }
            chordRow.write(c.chord);
          }
          buffer.writeln(chordRow.toString());
        }
        buffer.writeln(line.content);
      }
      buffer.writeln();
    }

    return suggestFromText(buffer.toString());
  }

  static _RawBlock? _parseBlock(String blockText, int blockIndex) {
    final lines = blockText.split('\n');
    String? explicitHeader;
    int contentStartIndex = 0;

    final firstLine = lines.first.trim();
    final headerMatch = _headerRegex.firstMatch(firstLine);
    if (headerMatch != null) {
      explicitHeader = headerMatch.group(1)!;
      contentStartIndex = 1;
    } else if (firstLine.startsWith('##')) {
      explicitHeader = firstLine.replaceFirst(RegExp(r'^##\s*'), '').trim();
      contentStartIndex = 1;
    }

    final lyricLines = <String>[];
    final songLines = <SongLine>[];
    final pendingChords = <ChordPlacementData>[];

    for (var j = contentStartIndex; j < lines.length; j++) {
      final line = lines[j];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final chordResult = ChordLineDetector.detect(line);
      if (chordResult.isChordLine) {
        pendingChords
          ..clear()
          ..addAll(
            chordResult.tokens.map(
              (t) => ChordPlacementData(chord: t.text, position: t.start),
            ),
          );
      } else {
        lyricLines.add(trimmed);
        songLines.add(
          SongLine(
            content: line,
            position: songLines.length,
            chords: List.unmodifiable(pendingChords),
          ),
        );
        pendingChords.clear();
      }
    }

    if (lyricLines.isEmpty && songLines.isEmpty) {
      if (explicitHeader != null) {
        return _RawBlock(
          index: blockIndex,
          explicitHeader: explicitHeader,
          lyricLines: const [],
          songLines: const [],
        );
      }
      return null;
    }

    return _RawBlock(
      index: blockIndex,
      explicitHeader: explicitHeader,
      lyricLines: lyricLines,
      songLines: songLines,
    );
  }

  static StructureProposal _buildFromExplicitHeaders(
    List<_RawBlock> blocks,
  ) {
    final items = <StructureItem>[];
    final sections = <SongSection>[];
    final verseCounts = <String, int>{};

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final headerRaw = b.explicitHeader ?? 'Sección ${i + 1}';
      final type = SectionType.fromString(headerRaw);

      String name;
      if (type == SectionType.verso) {
        final count = (verseCounts['verso'] ?? 0) + 1;
        verseCounts['verso'] = count;
        name = headerRaw.toLowerCase().contains('verso') ||
                headerRaw.toLowerCase().contains('verse')
            ? _formatExplicitName(headerRaw, count)
            : 'Verso $count';
      } else {
        name = _formatExplicitName(headerRaw, null);
      }

      items.add(
        StructureItem(
          id: 'sug_${i}_${type.name}',
          type: type,
          name: name,
          repeatCount: 1,
        ),
      );

      sections.add(
        SongSection(
          name: name,
          position: i,
          lines: b.songLines,
        ),
      );
    }

    final explanation =
        'Se detectaron ${items.length} secciones basadas en encabezados explícitos '
        '(${items.map((it) => it.name).join(' → ')}).';

    return StructureProposal(
      items: List.unmodifiable(items),
      sections: List.unmodifiable(sections),
      explanation: explanation,
      hasExplicitHeaders: true,
      confidence: 0.98,
    );
  }

  static StructureProposal _buildFromRepetitionsAndPosition(
    List<_RawBlock> blocks,
  ) {
    // 1. Group blocks by textual similarity to find repeated sections
    final clusters = <int, int>{}; // blockIndex -> clusterId
    var nextClusterId = 0;

    for (var i = 0; i < blocks.length; i++) {
      if (clusters.containsKey(i)) continue;
      clusters[i] = nextClusterId;
      for (var j = i + 1; j < blocks.length; j++) {
        if (!clusters.containsKey(j)) {
          final sim = _similarity(blocks[i].lyricLines, blocks[j].lyricLines);
          if (sim >= 0.55) {
            clusters[j] = nextClusterId;
          }
        }
      }
      nextClusterId++;
    }

    // 2. Count frequency of each cluster
    final clusterFrequencies = <int, int>{};
    for (final c in clusters.values) {
      clusterFrequencies[c] = (clusterFrequencies[c] ?? 0) + 1;
    }

    // 3. Identify Chorus cluster:
    // The most repeated cluster (>= 2 times).
    // If multiple clusters repeat, choose the one with standard chorus position or length.
    int? chorusCluster;
    var maxFreq = 1;
    for (final entry in clusterFrequencies.entries) {
      if (entry.value > maxFreq) {
        maxFreq = entry.value;
        chorusCluster = entry.key;
      }
    }

    // If no cluster repeats >= 2, check if any stanza contains typical chorus keywords
    if (chorusCluster == null) {
      for (var i = 0; i < blocks.length; i++) {
        final text = blocks[i].lyricLines.join(' ').toLowerCase();
        if (text.contains('aleluya') ||
            text.contains('santo') ||
            text.contains('gloria') ||
            text.contains('te alabamos') ||
            text.contains('cuan grande')) {
          if (i > 0) {
            chorusCluster = clusters[i];
            break;
          }
        }
      }
    }

    // 4. Classify each block by role
    final items = <StructureItem>[];
    final sections = <SongSection>[];
    var verseCount = 0;
    var bridgeCount = 0;
    var chorusesSeen = 0;
    var lastChorusIndex = -1;

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final cluster = clusters[i]!;
      SectionType type;
      String name;

      final isChorus = cluster == chorusCluster;
      final nextChorusIndex = chorusCluster != null
          ? blocks.indexWhere(
              (bk) => clusters[bk.index] == chorusCluster,
              i + 1,
            )
          : -1;
      final isNextChorus = nextChorusIndex == i + 1;
      final isShortStanza = b.lyricLines.length <= 3;
      final stanzasInCycle = nextChorusIndex != -1
          ? nextChorusIndex - (lastChorusIndex + 1)
          : 0;

      if (isChorus) {
        // It's the chorus
        type = SectionType.coro;
        name = 'Coro';
        chorusesSeen++;
        lastChorusIndex = i;
      } else if (isNextChorus && isShortStanza && stanzasInCycle >= 2) {
        // Short stanza immediately before a chorus, preceded by a verse, is a Pre-chorus
        type = SectionType.precoro;
        name = 'Pre-coro';
      } else if (chorusesSeen >= 1 && i == blocks.length - 1 && isShortStanza) {
        // Short stanza at the very end is Outro / Final
        type = SectionType.finalSection;
        name = 'Final';
      } else if (chorusesSeen >= 2 &&
          clusterFrequencies[cluster] == 1 &&
          i >= (blocks.length * 0.5).floor()) {
        // Distinct non-repeating stanza after at least 2 choruses is Bridge
        type = SectionType.puente;
        bridgeCount++;
        name = bridgeCount > 1 ? 'Puente $bridgeCount' : 'Puente';
      } else {
        // Verses
        type = SectionType.verso;
        verseCount++;
        name = 'Verso $verseCount';
      }

      items.add(
        StructureItem(
          id: 'sug_${i}_${type.name}',
          type: type,
          name: name,
          repeatCount: 1,
        ),
      );

      sections.add(
        SongSection(
          name: name,
          position: i,
          lines: b.songLines,
        ),
      );
    }

    final chorusInfo = chorusCluster != null
        ? 'Coro detectado por repetición (${maxFreq}x)'
        : 'Estructura lineal';
    final explanation =
        'Estructura inferida por análisis de estrofas ($chorusInfo): '
        '${items.map((it) => it.name).join(' → ')}.';

    return StructureProposal(
      items: List.unmodifiable(items),
      sections: List.unmodifiable(sections),
      explanation: explanation,
      hasExplicitHeaders: false,
      confidence: chorusCluster != null ? 0.90 : 0.75,
    );
  }

  static double _similarity(List<String> linesA, List<String> linesB) {
    if (linesA.isEmpty || linesB.isEmpty) return 0.0;
    final setA = linesA.map(_normalize).where((s) => s.isNotEmpty).toSet();
    final setB = linesB.map(_normalize).where((s) => s.isNotEmpty).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0.0;

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _formatExplicitName(String raw, int? fallbackCount) {
    final clean = raw
        .replaceAll(RegExp(r'[\[\]\(\)\#\:]'), '')
        .trim();
    if (clean.isEmpty) {
      return fallbackCount != null ? 'Verso $fallbackCount' : 'Sección';
    }
    // Capitalize first letter
    return clean[0].toUpperCase() + clean.substring(1);
  }
}

class _RawBlock {
  const _RawBlock({
    required this.index,
    required this.explicitHeader,
    required this.lyricLines,
    required this.songLines,
  });

  final int index;
  final String? explicitHeader;
  final List<String> lyricLines;
  final List<SongLine> songLines;
}
