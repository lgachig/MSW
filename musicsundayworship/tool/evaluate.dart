import 'dart:io';

import 'package:musicsundayworship/features/capture/chord_accuracy_evaluator.dart';

void main(List<String> args) {
  final current = Directory.current;
  final repoRoot = current.path.endsWith('musicsundayworship')
      ? current.parent.path
      : current.path;

  final groundTruthDir = Directory('$repoRoot/docs/fotos-prueba/respuestas');
  final resultsDir = Directory('$repoRoot/docs/evaluacion/resultados');
  final outputReportDir = Directory('$repoRoot/docs/evaluacion');

  if (!groundTruthDir.existsSync()) {
    stderr.writeln('Error: No se encontró la carpeta de respuestas: ${groundTruthDir.path}');
    exitCode = 1;
    return;
  }

  if (!resultsDir.existsSync()) {
    stderr.writeln('Error: No se encontró la carpeta de resultados: ${resultsDir.path}');
    exitCode = 1;
    return;
  }

  outputReportDir.createSync(recursive: true);

  stdout.writeln('=== Evaluación de Precisión de Acordes (MSW-34) ===');
  stdout.writeln('Ground Truth: ${groundTruthDir.path}');
  stdout.writeln('Resultados:   ${resultsDir.path}');
  stdout.writeln();

  const evaluator = ChordAccuracyEvaluator(targetAccuracy: 0.90);
  final report = evaluator.evaluateDirectories(
    groundTruthDir: groundTruthDir,
    resultsDir: resultsDir,
  );

  final markdown = report.toMarkdown();
  final reportFile = File('${outputReportDir.path}/reporte_precision.md');
  reportFile.writeAsStringSync(markdown);

  stdout.writeln('-----------------------------------------------------------------------------------');
  stdout.writeln('| #  | Foto Fuente             | Título               | Tono | Acordes (Esp/Det/OK) | Precisión |');
  stdout.writeln('-----------------------------------------------------------------------------------');

  for (final p in report.photoResults) {
    final idStr = p.id.padRight(2);
    final photoStr = p.sourcePhoto.length > 23
        ? '${p.sourcePhoto.substring(0, 20)}...'
        : p.sourcePhoto.padRight(23);
    final titleStr = p.expectedTitle.length > 20
        ? '${p.expectedTitle.substring(0, 17)}...'
        : p.expectedTitle.padRight(20);
    final keyStr = '${p.expectedKey}/${p.detectedKey ?? '-'}'.padRight(4);
    final chordsStr = '${p.expectedChordsCount}/${p.detectedChordsCount}/${p.matchedChordsCount}'.padRight(20);
    final accStr = '${(p.accuracy * 100).toStringAsFixed(1)}%'.padLeft(9);

    stdout.writeln('| $idStr | $photoStr | $titleStr | $keyStr | $chordsStr | $accStr |');
  }

  stdout.writeln('-----------------------------------------------------------------------------------');
  stdout.writeln();

  final overallAcc = (report.overallAccuracy * 100).toStringAsFixed(1);
  final targetAcc = (report.targetAccuracy * 100).toStringAsFixed(0);

  stdout.writeln('Fotos evaluadas:      ${report.photoResults.length}');
  stdout.writeln('Acordes esperados:    ${report.totalExpectedChords}');
  stdout.writeln('Acordes detectados:   ${report.totalDetectedChords}');
  stdout.writeln('Acordes correctos:    ${report.totalMatchedChords}');
  stdout.writeln('Precisión de acordes: $overallAcc% (Meta requerida: >= $targetAcc%)');
  stdout.writeln('Tonalidades correctas:${report.keysMatchedCount}/${report.photoResults.length} (${(report.keyAccuracy * 100).toStringAsFixed(1)}%)');
  stdout.writeln('Reporte guardado en:  ${reportFile.path}');
  stdout.writeln();

  if (report.meetsTarget) {
    stdout.writeln('RESULTADO: APROBADO ($overallAcc% >= $targetAcc%)');
    exitCode = 0;
  } else {
    stderr.writeln('RESULTADO: REPROBADO ($overallAcc% < $targetAcc%)');
    exitCode = 1;
  }
}

