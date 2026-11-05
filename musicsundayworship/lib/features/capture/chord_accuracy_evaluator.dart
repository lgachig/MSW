import 'dart:convert';
import 'dart:io';

import '../../music_engine/chord.dart';

/// Single chord match detail between expected and detected.
class ChordComparison {
  const ChordComparison({
    required this.expectedChord,
    required this.detectedChord,
    required this.expectedPosition,
    required this.detectedPosition,
    required this.isMatched,
    required this.lineText,
  });

  final String expectedChord;
  final String? detectedChord;
  final int expectedPosition;
  final int? detectedPosition;
  final bool isMatched;
  final String lineText;
}

/// Evaluation result for a single photo.
class PhotoEvaluationResult {
  const PhotoEvaluationResult({
    required this.id,
    required this.sourcePhoto,
    required this.expectedTitle,
    required this.detectedTitle,
    required this.expectedKey,
    required this.detectedKey,
    required this.keyMatches,
    required this.expectedChordsCount,
    required this.detectedChordsCount,
    required this.matchedChordsCount,
    required this.accuracy,
    required this.comparisons,
  });

  final String id;
  final String sourcePhoto;
  final String expectedTitle;
  final String? detectedTitle;
  final String expectedKey;
  final String? detectedKey;
  final bool keyMatches;
  final int expectedChordsCount;
  final int detectedChordsCount;
  final int matchedChordsCount;
  final double accuracy;
  final List<ChordComparison> comparisons;
}

/// Overall report compiling all evaluated photos.
class EvaluationReport {
  const EvaluationReport({
    required this.photoResults,
    required this.totalExpectedChords,
    required this.totalDetectedChords,
    required this.totalMatchedChords,
    required this.overallAccuracy,
    required this.keysMatchedCount,
    required this.keyAccuracy,
    required this.targetAccuracy,
  });

  final List<PhotoEvaluationResult> photoResults;
  final int totalExpectedChords;
  final int totalDetectedChords;
  final int totalMatchedChords;
  final double overallAccuracy;
  final int keysMatchedCount;
  final double keyAccuracy;
  final double targetAccuracy;

  bool get meetsTarget => overallAccuracy >= targetAccuracy;

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Reporte de Precisión de Digitalización contra Fotos de Prueba');
    buffer.writeln();
    buffer.writeln('**Fecha de evaluación:** ${DateTime.now().toIso8601String().split('T').first}');
    buffer.writeln('**Meta de precisión requerida:** ${(targetAccuracy * 100).toStringAsFixed(0)}% de acordes correctos');
    buffer.writeln('**Resultado global:** ${(overallAccuracy * 100).toStringAsFixed(1)}% '
        '(${meetsTarget ? '✅ CUMPLE LA META' : '❌ NO CUMPLE LA META'})');
    buffer.writeln();

    buffer.writeln('## Resumen General');
    buffer.writeln();
    buffer.writeln('| Métrica | Valor |');
    buffer.writeln('|---|---|');
    buffer.writeln('| Fotos evaluadas | ${photoResults.length} |');
    buffer.writeln('| Acordes esperados (Ground Truth) | $totalExpectedChords |');
    buffer.writeln('| Acordes detectados | $totalDetectedChords |');
    buffer.writeln('| Acordes correctos (aciertos) | $totalMatchedChords |');
    buffer.writeln('| **Precisión total de acordes** | **${(overallAccuracy * 100).toStringAsFixed(1)}%** |');
    buffer.writeln('| Tonalidades correctas | $keysMatchedCount / ${photoResults.length} (${(keyAccuracy * 100).toStringAsFixed(1)}%) |');
    buffer.writeln('| Estado final | **${meetsTarget ? 'APROBADO' : 'REQUIERE AJUSTE'}** |');
    buffer.writeln();

    buffer.writeln('## Detalle por Foto');
    buffer.writeln();
    buffer.writeln('| # | Foto Fuente | Título Esperado | Tono Esp. | Tono Det. | Tono OK | Acordes Esp. | Acordes Det. | Aciertos | Precisión |');
    buffer.writeln('|---|---|---|---|---|:---:|:---:|:---:|:---:|:---:|');

    for (final p in photoResults) {
      final keyIcon = p.keyMatches ? '✅' : '⚠️';
      final accStr = '${(p.accuracy * 100).toStringAsFixed(1)}%';
      buffer.writeln('| ${p.id} | `${p.sourcePhoto}` | ${p.expectedTitle} | ${p.expectedKey} | ${p.detectedKey ?? '-'} | $keyIcon | ${p.expectedChordsCount} | ${p.detectedChordsCount} | ${p.matchedChordsCount} | **$accStr** |');
    }
    buffer.writeln();

    buffer.writeln('## Detalle de Aciertos y Discrepancias por Foto');
    buffer.writeln();
    for (final p in photoResults) {
      buffer.writeln('### Foto ${p.id}: ${p.expectedTitle}');
      buffer.writeln('- **Archivo:** `${p.sourcePhoto}`');
      buffer.writeln('- **Tonalidad:** esperada `${p.expectedKey}`, detectada `${p.detectedKey ?? '-'}` (${p.keyMatches ? 'Coincide' : 'Difiere'})');
      buffer.writeln('- **Precisión de acordes:** ${p.matchedChordsCount}/${p.expectedChordsCount} (${(p.accuracy * 100).toStringAsFixed(1)}%)');
      buffer.writeln();
      buffer.writeln('| Línea de Letra | Acorde Esperado | Pos. Esp. | Acorde Detectado | Pos. Det. | Coincidencia |');
      buffer.writeln('|---|---|:---:|---|:---:|:---:|');
      for (final c in p.comparisons) {
        final icon = c.isMatched ? '✅ Correcto' : '❌ Discrepancia';
        buffer.writeln('| ${c.lineText.replaceAll('|', '/')} | `${c.expectedChord}` | ${c.expectedPosition} | `${c.detectedChord ?? '-'}` | ${c.detectedPosition ?? '-'} | $icon |');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Compares digitization results against ground truth JSON responses.
class ChordAccuracyEvaluator {
  const ChordAccuracyEvaluator({this.targetAccuracy = 0.90});

  final double targetAccuracy;

  /// Evaluates a single photo given its [groundTruthJson] and [digitizedResultJson].
  PhotoEvaluationResult evaluateSingle({
    required String id,
    required Map<String, dynamic> groundTruthJson,
    required Map<String, dynamic> digitizedResultJson,
  }) {
    final expectedTitle = groundTruthJson['title'] as String? ?? '';
    final detectedTitle = digitizedResultJson['title'] as String?;
    final sourcePhoto = groundTruthJson['source'] as String? ?? 'foto_$id.png';

    final expectedKey = (groundTruthJson['key'] as String? ?? '').trim();
    final detectedKey = (digitizedResultJson['key'] as String?)?.trim();
    final keyMatches = _areKeysEquivalent(expectedKey, detectedKey);

    final expectedLines = (groundTruthJson['lines'] as List<dynamic>? ?? [])
        .map((item) => _GroundTruthLine.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    final detectedLines = _extractDetectedLines(digitizedResultJson);

    final comparisons = <ChordComparison>[];
    var matchedChordsCount = 0;
    var totalExpectedChords = 0;

    for (final expLine in expectedLines) {
      final bestDetLine = _findBestMatchingLine(expLine.text, detectedLines);
      final candidateDetectedChords = bestDetLine != null
          ? List<_DetectedChordPlacement>.from(bestDetLine.chords)
          : <_DetectedChordPlacement>[];

      for (final expChord in expLine.chords) {
        totalExpectedChords++;
        final matchIndex = _findBestChordMatch(
          expChord,
          candidateDetectedChords,
        );

        if (matchIndex != -1) {
          final matchedDetChord = candidateDetectedChords.removeAt(matchIndex);
          matchedChordsCount++;
          comparisons.add(
            ChordComparison(
              expectedChord: expChord.name,
              detectedChord: matchedDetChord.chord,
              expectedPosition: expChord.position,
              detectedPosition: matchedDetChord.position,
              isMatched: true,
              lineText: expLine.text,
            ),
          );
        } else {
          comparisons.add(
            ChordComparison(
              expectedChord: expChord.name,
              detectedChord: null,
              expectedPosition: expChord.position,
              detectedPosition: null,
              isMatched: false,
              lineText: expLine.text,
            ),
          );
        }
      }
    }

    final totalDetectedChords = detectedLines.fold<int>(
      0,
      (sum, line) => sum + line.chords.length,
    );

    final accuracy = totalExpectedChords > 0
        ? matchedChordsCount / totalExpectedChords
        : 1.0;

    return PhotoEvaluationResult(
      id: id,
      sourcePhoto: sourcePhoto,
      expectedTitle: expectedTitle,
      detectedTitle: detectedTitle,
      expectedKey: expectedKey,
      detectedKey: detectedKey,
      keyMatches: keyMatches,
      expectedChordsCount: totalExpectedChords,
      detectedChordsCount: totalDetectedChords,
      matchedChordsCount: matchedChordsCount,
      accuracy: accuracy,
      comparisons: comparisons,
    );
  }

  /// Evaluates all files in [groundTruthDir] against results in [resultsDir].
  EvaluationReport evaluateDirectories({
    required Directory groundTruthDir,
    required Directory resultsDir,
  }) {
    final gtFiles = groundTruthDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final photoResults = <PhotoEvaluationResult>[];

    for (final gtFile in gtFiles) {
      final fileName = gtFile.uri.pathSegments.last;
      final id = fileName.replaceAll('.json', '');
      final resFile = File('${resultsDir.path}/$fileName');

      if (!resFile.existsSync()) {
        continue;
      }

      final gtJson = jsonDecode(gtFile.readAsStringSync()) as Map<String, dynamic>;
      final resJson = jsonDecode(resFile.readAsStringSync()) as Map<String, dynamic>;

      photoResults.add(
        evaluateSingle(
          id: id,
          groundTruthJson: gtJson,
          digitizedResultJson: resJson,
        ),
      );
    }

    final totalExpected = photoResults.fold<int>(
      0,
      (sum, p) => sum + p.expectedChordsCount,
    );
    final totalDetected = photoResults.fold<int>(
      0,
      (sum, p) => sum + p.detectedChordsCount,
    );
    final totalMatched = photoResults.fold<int>(
      0,
      (sum, p) => sum + p.matchedChordsCount,
    );
    final keysMatched = photoResults.where((p) => p.keyMatches).length;

    final overallAccuracy = totalExpected > 0 ? totalMatched / totalExpected : 0.0;
    final keyAccuracy = photoResults.isNotEmpty ? keysMatched / photoResults.length : 0.0;

    return EvaluationReport(
      photoResults: photoResults,
      totalExpectedChords: totalExpected,
      totalDetectedChords: totalDetected,
      totalMatchedChords: totalMatched,
      overallAccuracy: overallAccuracy,
      keysMatchedCount: keysMatched,
      keyAccuracy: keyAccuracy,
      targetAccuracy: targetAccuracy,
    );
  }

  static bool _areKeysEquivalent(String? a, String? b) {
    if (a == null || b == null) return false;
    final trimA = a.trim();
    final trimB = b.trim();
    if (trimA.toLowerCase() == trimB.toLowerCase()) return true;

    final cA = Chord.parse(trimA);
    final cB = Chord.parse(trimB);
    if (cA != null && cB != null) {
      final aIsMinor = cA.quality.startsWith('m') && !cA.quality.startsWith('maj');
      final bIsMinor = cB.quality.startsWith('m') && !cB.quality.startsWith('maj');
      return cA.root.semitone == cB.root.semitone && aIsMinor == bIsMinor;
    }
    return false;
  }

  static int _findBestChordMatch(
    _GroundTruthChord expected,
    List<_DetectedChordPlacement> candidates,
  ) {
    if (candidates.isEmpty) return -1;

    // 1. First priority: Exact or semantically identical chord closest in position
    int bestIndex = -1;
    int minPosDiff = 9999;

    for (var i = 0; i < candidates.length; i++) {
      final cand = candidates[i];
      if (_areChordsMatching(expected.name, cand.chord)) {
        final diff = (expected.position - cand.position).abs();
        if (diff < minPosDiff) {
          minPosDiff = diff;
          bestIndex = i;
        }
      }
    }

    if (bestIndex != -1) return bestIndex;

    // 2. Second priority: Harmonic root & quality equivalence (e.g. F#m vs F#m7(9), G9 vs G)
    for (var i = 0; i < candidates.length; i++) {
      final cand = candidates[i];
      if (_areChordsHarmonicallyCompatible(expected.name, cand.chord)) {
        return i;
      }
    }

    return -1;
  }

  static bool _areChordsMatching(String a, String b) {
    final cleanA = a.trim();
    final cleanB = b.trim();
    if (cleanA.toLowerCase() == cleanB.toLowerCase()) return true;

    final cA = Chord.parse(cleanA);
    final cB = Chord.parse(cleanB);
    if (cA != null && cB != null) {
      return cA.root.semitone == cB.root.semitone &&
          cA.quality == cB.quality &&
          cA.bass?.semitone == cB.bass?.semitone;
    }
    return false;
  }

  static bool _areChordsHarmonicallyCompatible(String a, String b) {
    final cA = Chord.parse(a.trim());
    final cB = Chord.parse(b.trim());
    if (cA != null && cB != null) {
      final aIsMinor = cA.quality.startsWith('m') && !cA.quality.startsWith('maj');
      final bIsMinor = cB.quality.startsWith('m') && !cB.quality.startsWith('maj');
      return cA.root.semitone == cB.root.semitone && aIsMinor == bIsMinor;
    }
    return false;
  }

  static _DetectedLine? _findBestMatchingLine(
    String expectedText,
    List<_DetectedLine> detectedLines,
  ) {
    if (detectedLines.isEmpty) return null;

    final normExpected = _normalizeWords(expectedText);
    if (normExpected.isEmpty) return detectedLines.first;

    _DetectedLine? bestLine;
    double maxScore = 0.0;

    for (final detLine in detectedLines) {
      final normDetected = _normalizeWords(detLine.text);
      if (normDetected.isEmpty) continue;

      final intersection = normExpected.intersection(normDetected).length;
      final union = normExpected.union(normDetected).length;
      final jaccard = union > 0 ? intersection / union : 0.0;

      if (jaccard > maxScore) {
        maxScore = jaccard;
        bestLine = detLine;
      }
    }

    return maxScore >= 0.20 ? bestLine : null;
  }

  static Set<String> _normalizeWords(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\sáéíóúñÁÉÍÓÚÑ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();

  static List<_DetectedLine> _extractDetectedLines(Map<String, dynamic> json) {
    final lines = <_DetectedLine>[];

    // If result is in sections structure
    if (json.containsKey('sections') && json['sections'] is List) {
      for (final sec in json['sections'] as List<dynamic>) {
        if (sec is Map<String, dynamic> && sec['lines'] is List) {
          for (final line in sec['lines'] as List<dynamic>) {
            if (line is Map<String, dynamic>) {
              lines.add(_DetectedLine.fromJson(line));
            }
          }
        }
      }
    } else if (json.containsKey('lines') && json['lines'] is List) {
      for (final line in json['lines'] as List<dynamic>) {
        if (line is Map<String, dynamic>) {
          lines.add(_DetectedLine.fromJson(line));
        }
      }
    }

    return lines;
  }
}

class _GroundTruthLine {
  const _GroundTruthLine({required this.text, required this.chords});

  final String text;
  final List<_GroundTruthChord> chords;

  factory _GroundTruthLine.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    final chords = (json['chords'] as List<dynamic>? ?? [])
        .map((item) => _GroundTruthChord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return _GroundTruthLine(text: text, chords: chords);
  }
}

class _GroundTruthChord {
  const _GroundTruthChord({required this.name, required this.position});

  final String name;
  final int position;

  factory _GroundTruthChord.fromJson(Map<String, dynamic> json) =>
      _GroundTruthChord(
        name: (json['name'] as String? ?? '').trim(),
        position: json['position'] as int? ?? 0,
      );
}

class _DetectedLine {
  const _DetectedLine({required this.text, required this.chords});

  final String text;
  final List<_DetectedChordPlacement> chords;

  factory _DetectedLine.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    final chords = (json['chords'] as List<dynamic>? ?? [])
        .map(
          (item) =>
              _DetectedChordPlacement.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
    return _DetectedLine(text: text, chords: chords);
  }
}

class _DetectedChordPlacement {
  const _DetectedChordPlacement({required this.chord, required this.position});

  final String chord;
  final int position;

  factory _DetectedChordPlacement.fromJson(Map<String, dynamic> json) =>
      _DetectedChordPlacement(
        chord: ((json['chord'] ?? json['name']) as String? ?? '').trim(),
        position: json['position'] as int? ?? 0,
      );
}
