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

class HeaderInfo {
  const HeaderInfo({
    required this.rawName,
    required this.type,
    this.repeatCount = 1,
  });

  final String rawName;
  final SectionType type;
  final int repeatCount;
}

/// Analyzes lyrics (plain text or chord-over-lyric) to detect stanzas,
/// repetitions, and structural section roles (Intro, Verso, Pre-coro, Coro, Puente, Final).
class LyricsStructureSuggester {
  const LyricsStructureSuggester._();

  /// Matches musical section headers in diverse formats:
  /// - Markdown: `## Verso 1`, `# Coro`
  /// - Brackets: `[Verso 1]`, `[Coro]`, `[Puente]`, `[Precoro]`, `[V1]`, `[C]`, `[B]`
  /// - Parentheses / braces: `(Coro)`, `{Puente}`
  /// - Slashes / dashes: `// Coro //`, `-- Verso 2 --`
  /// - Colons: `Verso 1:`, `Coro:`, `Estrofa 1:`
  /// - Standalone names: `Verso 1`, `Coro`, `Puente`, `Intro`, `Final`
  /// - Repetitions: `[Coro] x2`, `Coro (x2)`, `Coro (Bis)`
  static HeaderInfo? matchHeader(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Reject lines that look like lyric sentences (e.g. ending in comma or too long)
    if (trimmed.length > 50 && !trimmed.startsWith('#') && !trimmed.startsWith('[')) {
      return null;
    }

    // 1. Check repetition suffix: x2, (x2), [x2], (2x), (bis), (2 veces)
    var repeatCount = 1;
    final repeatRegex = RegExp(
      r'(?:[\(\[\{]\s*)?(?:x\s*(\d+)|(\d+)\s*x|bis|(\d+)\s*veces)(?:\s*[\)\]\}])?$',
      caseSensitive: false,
    );
    final repeatMatch = repeatRegex.firstMatch(trimmed);
    if (repeatMatch != null) {
      final matchedText = repeatMatch.group(0)!.toLowerCase();
      if (matchedText.contains('bis')) {
        repeatCount = 2;
      } else {
        final numStr = repeatMatch.group(1) ??
            repeatMatch.group(2) ??
            repeatMatch.group(3);
        if (numStr != null) {
          repeatCount = int.tryParse(numStr)?.clamp(1, 99) ?? 1;
        }
      }
    }

    // 2. Clean delimiters: ##, [], (), {}, //, --, :
    var clean = trimmed
        .replaceAll(repeatRegex, '')
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'^[\/|–—\-]+\s*'), '')
        .replaceAll(RegExp(r'\s*[\/|–—\-]+$'), '')
        .replaceAll(RegExp(r'^[\(\[\{]\s*'), '')
        .replaceAll(RegExp(r'\s*[\)\]\}]$'), '')
        .replaceAll(RegExp(r':\s*$'), '')
        .trim();

    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();

    // Reject generic labels like "Sección 1", "Parte 1", "Track 1"
    if (RegExp(r'^(?:secci[oó]n|parte|bloque|section|track)\s*\d*$',
            caseSensitive: false)
        .hasMatch(lower)) {
      return null;
    }

    // Intro
    if (lower.startsWith('intro') ||
        lower == 'introduccion' ||
        lower == 'introducción') {
      return HeaderInfo(
        rawName: 'Intro',
        type: SectionType.intro,
        repeatCount: repeatCount,
      );
    }

    // Pre-coro / Pre-chorus / PC
    if (lower.startsWith('pre') || lower == 'pc' || lower == 'precoro') {
      return HeaderInfo(
        rawName: 'Pre-coro',
        type: SectionType.precoro,
        repeatCount: repeatCount,
      );
    }

    // Coro / Chorus / Estribillo / C
    if (lower.startsWith('coro') ||
        lower.startsWith('chorus') ||
        lower.startsWith('estribillo') ||
        lower == 'c' ||
        lower == 'c1' ||
        lower == 'c2') {
      final num = RegExp(r'\d+').firstMatch(lower)?.group(0);
      final name = num != null ? 'Coro $num' : 'Coro';
      return HeaderInfo(
        rawName: name,
        type: SectionType.coro,
        repeatCount: repeatCount,
      );
    }

    // Verso / Verse / Estrofa / V1 / 1. / 1
    if (lower.startsWith('verso') ||
        lower.startsWith('verse') ||
        lower.startsWith('estrofa') ||
        RegExp(r'^(?:v\s*\.?\s*\d+|\d+\.?)$', caseSensitive: false)
            .hasMatch(lower)) {
      var num = RegExp(r'\d+').firstMatch(lower)?.group(0);
      if (num == null) {
        if (lower.contains(' iv') || lower.endsWith('iv')) {
          num = '4';
        } else if (lower.contains(' iii') || lower.endsWith('iii')) {
          num = '3';
        } else if (lower.contains(' ii') || lower.endsWith('ii')) {
          num = '2';
        } else if (lower.contains(' i') || lower.endsWith('i')) {
          num = '1';
        }
      }
      final name = num != null ? 'Verso $num' : 'Verso';
      return HeaderInfo(
        rawName: name,
        type: SectionType.verso,
        repeatCount: repeatCount,
      );
    }

    // Puente / Bridge / P / B
    if (lower.startsWith('puente') ||
        lower.startsWith('bridge') ||
        lower == 'b' ||
        lower == 'p') {
      final num = RegExp(r'\d+').firstMatch(lower)?.group(0);
      final name = num != null ? 'Puente $num' : 'Puente';
      return HeaderInfo(
        rawName: name,
        type: SectionType.puente,
        repeatCount: repeatCount,
      );
    }

    // Interludio / Solo / Instrumental
    if (lower.startsWith('inter') ||
        lower.startsWith('solo') ||
        lower.startsWith('instrumental')) {
      return HeaderInfo(
        rawName: 'Interludio',
        type: SectionType.interludio,
        repeatCount: repeatCount,
      );
    }

    // Final / Outro / Coda / Fin
    if (lower.startsWith('fin') ||
        lower.startsWith('outro') ||
        lower.startsWith('coda')) {
      return HeaderInfo(
        rawName: 'Final',
        type: SectionType.finalSection,
        repeatCount: repeatCount,
      );
    }

    return null;
  }

  /// Proposes a [SongStructure] from raw lyrics or chord-sheet text.
  static StructureProposal suggestFromText(String rawText) {
    final clean = rawText.replaceAll('\r\n', '\n').trim();
    if (clean.isEmpty) {
      return const StructureProposal(
        items: [],
        sections: [],
        explanation: 'El texto está vacío. Pega la letra para analizarla.',
        hasExplicitHeaders: false,
        confidence: 0.0,
      );
    }

    // Robust multi-line parser that segments by blank lines OR header markers
    final parsedBlocks = _segmentTextIntoBlocks(clean);

    if (parsedBlocks.isEmpty) {
      return const StructureProposal(
        items: [],
        sections: [],
        explanation: 'No se encontraron estrofas reconocibles en el texto.',
        hasExplicitHeaders: false,
        confidence: 0.0,
      );
    }

    final explicitBlocks =
        parsedBlocks.where((b) => b.headerInfo != null).toList();
    final hasExplicitHeaders =
        explicitBlocks.isNotEmpty && explicitBlocks.length >= (parsedBlocks.length * 0.4).ceil();

    if (hasExplicitHeaders) {
      return _buildFromExplicitAndInferred(parsedBlocks);
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
      // If the section already has a known musical header, keep it;
      // if it's generic ("Sección 1"), omit it so the analyzer infers it cleanly from lyrics!
      final header = matchHeader(sec.name);
      if (header != null) {
        buffer.writeln('[${header.rawName}]');
      }

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
      buffer.writeln(); // Blank line between sections
    }

    return suggestFromText(buffer.toString());
  }

  /// Segments text into blocks by blank lines OR by encountering a header line.
  static List<_RawBlock> _segmentTextIntoBlocks(String text) {
    final rawLines = text.split('\n');
    final blocks = <_RawBlock>[];

    HeaderInfo? currentHeader;
    var currentLyricLines = <String>[];
    var currentSongLines = <SongLine>[];
    var pendingChords = <ChordPlacementData>[];

    void flushCurrentBlock() {
      if (currentLyricLines.isNotEmpty ||
          currentSongLines.isNotEmpty ||
          currentHeader != null) {
        blocks.add(
          _RawBlock(
            index: blocks.length,
            headerInfo: currentHeader,
            lyricLines: List.unmodifiable(currentLyricLines),
            songLines: List.unmodifiable(currentSongLines),
          ),
        );
      }
      currentHeader = null;
      currentLyricLines = <String>[];
      currentSongLines = <SongLine>[];
      pendingChords = <ChordPlacementData>[];
    }

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // Blank line ends current block
        if (currentLyricLines.isNotEmpty || currentHeader != null) {
          flushCurrentBlock();
        }
        continue;
      }

      final header = matchHeader(trimmed);
      if (header != null) {
        // Line is a section header! Flush any previous block and start a new one
        flushCurrentBlock();
        currentHeader = header;
        continue;
      }

      // Check if it's a chord line
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
        // It's a lyric line
        currentLyricLines.add(trimmed);
        currentSongLines.add(
          SongLine(
            content: line,
            position: currentSongLines.length,
            chords: List.unmodifiable(pendingChords),
          ),
        );
        pendingChords.clear();
      }
    }

    flushCurrentBlock();

    // If only 1 block was found with many lines, attempt automatic stanza splitting every 4-8 lines
    if (blocks.length == 1 && blocks.first.lyricLines.length >= 8) {
      return _splitLargeUnlabeledBlock(blocks.first);
    }

    return blocks;
  }

  static List<_RawBlock> _splitLargeUnlabeledBlock(_RawBlock large) {
    // If lines contain phrase repetitions, split along repetitions
    final result = <_RawBlock>[];
    final lines = large.lyricLines;
    final songLines = large.songLines;

    // Detect if lines 4..8 repeat later
    const stanzaSize = 4;
    for (var i = 0; i < lines.length; i += stanzaSize) {
      final end = (i + stanzaSize).clamp(0, lines.length);
      final subLyrics = lines.sublist(i, end);
      final subSong = songLines.isNotEmpty
          ? songLines.sublist(i, (i + stanzaSize).clamp(0, songLines.length))
          : <SongLine>[];
      result.add(
        _RawBlock(
          index: result.length,
          headerInfo: null,
          lyricLines: subLyrics,
          songLines: subSong,
        ),
      );
    }
    return result;
  }

  /// Builds structure when some or all blocks have explicit headers.
  static StructureProposal _buildFromExplicitAndInferred(
    List<_RawBlock> blocks,
  ) {
    final items = <StructureItem>[];
    final sections = <SongSection>[];
    final verseCounts = <String, int>{};

    // Find known chorus lyrics from blocks that explicitly had Coro header
    final chorusLyrics = <List<String>>[];
    for (final b in blocks) {
      if (b.headerInfo?.type == SectionType.coro && b.lyricLines.isNotEmpty) {
        chorusLyrics.add(b.lyricLines);
      }
    }

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      SectionType type;
      String name;
      var repeatCount = b.headerInfo?.repeatCount ?? 1;

      if (b.headerInfo != null) {
        type = b.headerInfo!.type;
        if (type == SectionType.verso) {
          final count = (verseCounts['verso'] ?? 0) + 1;
          verseCounts['verso'] = count;
          name = b.headerInfo!.rawName.contains(RegExp(r'\d'))
              ? b.headerInfo!.rawName
              : 'Verso $count';
        } else {
          name = b.headerInfo!.rawName;
        }
      } else {
        // Unlabeled block: check if it matches chorus lyrics
        final matchesChorus = chorusLyrics.any(
          (c) => _similarity(c, b.lyricLines) >= 0.50,
        );
        if (matchesChorus) {
          type = SectionType.coro;
          name = 'Coro';
        } else {
          final count = (verseCounts['verso'] ?? 0) + 1;
          verseCounts['verso'] = count;
          name = 'Verso $count';
          type = SectionType.verso;
        }
      }

      items.add(
        StructureItem(
          id: 'sug_${i}_${type.name}',
          type: type,
          name: name,
          repeatCount: repeatCount,
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
        '(${items.map((it) => it.labelWithRepeats).join(' → ')}).';

    return StructureProposal(
      items: List.unmodifiable(items),
      sections: List.unmodifiable(sections),
      explanation: explanation,
      hasExplicitHeaders: true,
      confidence: 0.98,
    );
  }

  /// Builds structure from textual repetitions and stanza order.
  static StructureProposal _buildFromRepetitionsAndPosition(
    List<_RawBlock> blocks,
  ) {
    // 1. Group blocks by textual similarity to find repeated sections
    final clusters = <int, int>{};
    var nextClusterId = 0;

    for (var i = 0; i < blocks.length; i++) {
      if (clusters.containsKey(i)) continue;
      clusters[i] = nextClusterId;
      for (var j = i + 1; j < blocks.length; j++) {
        if (!clusters.containsKey(j)) {
          final sim = _similarity(blocks[i].lyricLines, blocks[j].lyricLines);
          if (sim >= 0.50) {
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
    int? chorusCluster;
    var maxFreq = 1;
    for (final entry in clusterFrequencies.entries) {
      if (entry.value > maxFreq) {
        maxFreq = entry.value;
        chorusCluster = entry.key;
      }
    }

    // Fallback: check typical praise/chorus keywords if no repetition >= 2
    if (chorusCluster == null) {
      for (var i = 0; i < blocks.length; i++) {
        final text = blocks[i].lyricLines.join(' ').toLowerCase();
        if (text.contains('aleluya') ||
            text.contains('santo') ||
            text.contains('gloria') ||
            text.contains('te alabamos') ||
            text.contains('cuan grande') ||
            text.contains('digno')) {
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
        type = SectionType.coro;
        name = 'Coro';
        chorusesSeen++;
        lastChorusIndex = i;
      } else if (isNextChorus && isShortStanza && stanzasInCycle >= 2) {
        type = SectionType.precoro;
        name = 'Pre-coro';
      } else if (chorusesSeen >= 1 && i == blocks.length - 1 && isShortStanza) {
        type = SectionType.finalSection;
        name = 'Final';
      } else if (chorusesSeen >= 2 &&
          clusterFrequencies[cluster] == 1 &&
          i >= (blocks.length * 0.5).floor()) {
        type = SectionType.puente;
        bridgeCount++;
        name = bridgeCount > 1 ? 'Puente $bridgeCount' : 'Puente';
      } else {
        type = SectionType.verso;
        verseCount++;
        name = 'Verso $verseCount';
      }

      items.add(
        StructureItem(
          id: 'sug_${i}_${type.name}',
          type: type,
          name: name,
          repeatCount: b.headerInfo?.repeatCount ?? 1,
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
        : 'Estructura deducida por orden lírico';
    final explanation =
        'Estructura clasificada ($chorusInfo): '
        '${items.map((it) => it.labelWithRepeats).join(' → ')}.';

    return StructureProposal(
      items: List.unmodifiable(items),
      sections: List.unmodifiable(sections),
      explanation: explanation,
      hasExplicitHeaders: false,
      confidence: chorusCluster != null ? 0.92 : 0.78,
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
}

class _RawBlock {
  const _RawBlock({
    required this.index,
    required this.headerInfo,
    required this.lyricLines,
    required this.songLines,
  });

  final int index;
  final HeaderInfo? headerInfo;
  final List<String> lyricLines;
  final List<SongLine> songLines;
}
