import 'time_signature.dart';

/// Resultado de una sugerencia heurística o basada en IA de tempo y compás.
class TempoSuggestion {
  const TempoSuggestion({
    this.tempo,
    this.timeSignature,
    required this.reason,
    required this.confidence,
  });

  /// Tempo sugerido en pulsos por minuto (BPM, entre 40 y 220).
  final int? tempo;

  /// Compás sugerido (ej. 2/4, 3/4, 4/4, 6/8).
  final TimeSignature? timeSignature;

  /// Explicación clara de por qué se generó la sugerencia.
  final String reason;

  /// Confianza de la sugerencia (0.0 a 1.0).
  final double confidence;

  /// Nivel cualitativo de confianza en español.
  String get confidenceLabel {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }
}

/// Analizador heurístico/IA para detectar o sugerir tempo y compás a partir de
/// texto de canciones, notas, acordes o metadatos.
class TempoSuggester {
  static const int minBpm = 40;
  static const int maxBpm = 220;

  /// Analiza un texto completo (o combinación de título, acordes y letra)
  /// y sugiere tempo y compás.
  static TempoSuggestion suggest({
    String? text,
    String? title,
    List<String>? chordLines,
  }) {
    final combined = StringBuffer();
    if (title != null && title.trim().isNotEmpty) {
      combined.writeln(title);
    }
    if (text != null && text.trim().isNotEmpty) {
      combined.writeln(text);
    }
    if (chordLines != null && chordLines.isNotEmpty) {
      combined.writeln(chordLines.join('\n'));
    }

    final raw = combined.toString();
    if (raw.trim().isEmpty) {
      return const TempoSuggestion(
        tempo: 100,
        timeSignature: TimeSignature.fourFour,
        reason: 'Valores estándar para música congregacional (4/4, 100 BPM)',
        confidence: 0.3,
      );
    }

    int? detectedTempo;
    TimeSignature? detectedSignature;
    final reasons = <String>[];
    double confidenceSum = 0.0;
    int detections = 0;

    // 1. Detección explícita de BPM
    final bpmRegexes = [
      RegExp(r'(?:bpm|tempo|velocidad|t)\s*[:=]?\s*(\d{2,3})', caseSensitive: false),
      RegExp(r'(\d{2,3})\s*(?:bpm|ppm)', caseSensitive: false),
      RegExp(r'[♩q]\s*[:=]?\s*(\d{2,3})', caseSensitive: false),
    ];

    for (final reg in bpmRegexes) {
      final match = reg.firstMatch(raw);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed >= minBpm && parsed <= maxBpm) {
          detectedTempo = parsed;
          reasons.add('Tempo detectado en el texto: "${match.group(0)}" ($parsed BPM)');
          confidenceSum += 0.95;
          detections++;
          break;
        }
      }
    }

    // 2. Detección explícita de Compás
    final sigPrefixRegex = RegExp(
      r'(?:comp[aá]s|m[eé]trica|time\s*signature|ritmo|medida)\s*[:=]?\s*(2/4|3/4|4/4|6/8)',
      caseSensitive: false,
    );
    final prefixMatch = sigPrefixRegex.firstMatch(raw);
    if (prefixMatch != null) {
      final parsed = TimeSignature.tryParse(prefixMatch.group(1));
      if (parsed != null) {
        detectedSignature = parsed;
        reasons.add('Compás detectado en el texto: "${prefixMatch.group(0)}" ($parsed)');
        confidenceSum += 0.95;
        detections++;
      }
    } else {
      // Búsqueda aislada de patrón de compás común
      final standaloneSigRegex = RegExp(r'\b(2/4|3/4|4/4|6/8)\b');
      final match = standaloneSigRegex.firstMatch(raw);
      if (match != null) {
        final parsed = TimeSignature.tryParse(match.group(1));
        if (parsed != null) {
          detectedSignature = parsed;
          reasons.add('Compás identificado en el contenido: "$parsed"');
          confidenceSum += 0.8;
          detections++;
        }
      }
    }

    // 3. Palabras clave musicales y de género si no se detectaron explícitamente
    final lower = raw.toLowerCase();

    if (detectedSignature == null) {
      if (lower.contains('vals') || lower.contains('valse')) {
        detectedSignature = TimeSignature.threeFour;
        reasons.add('Compás 3/4 deducido por ritmo de vals');
        confidenceSum += 0.75;
        detections++;
      } else if (lower.contains('6/8') || lower.contains('huapango') || lower.contains('seis octavos')) {
        detectedSignature = TimeSignature.sixEight;
        reasons.add('Compás 6/8 deducido por término o estilo rítmico');
        confidenceSum += 0.75;
        detections++;
      } else if (lower.contains('marcha')) {
        detectedSignature = TimeSignature.twoFour;
        reasons.add('Compás 2/4 deducido por estilo de marcha');
        confidenceSum += 0.7;
        detections++;
      }
    }

    if (detectedTempo == null) {
      if (lower.contains('muy lento') || lower.contains('balada lenta') || lower.contains('largo')) {
        detectedTempo = 60;
        reasons.add('Tempo 60 BPM estimado por indicación "lento"');
        confidenceSum += 0.6;
        detections++;
      } else if (lower.contains('balada') || lower.contains('suave') || lower.contains('adoración lenta') || lower.contains('adoracion lenta')) {
        detectedTempo = 72;
        reasons.add('Tempo 72 BPM estimado por estilo de balada/adoración suave');
        confidenceSum += 0.65;
        detections++;
      } else if (lower.contains('adoración') || lower.contains('adoracion') || lower.contains('andante')) {
        detectedTempo = 80;
        reasons.add('Tempo 80 BPM estimado por estilo de adoración');
        confidenceSum += 0.6;
        detections++;
      } else if (lower.contains('moderato') || lower.contains('medio')) {
        detectedTempo = 100;
        reasons.add('Tempo 100 BPM estimado por estilo moderado');
        confidenceSum += 0.6;
        detections++;
      } else if (lower.contains('alabanza') || lower.contains('alegre') || lower.contains('allegro') || lower.contains('gozo')) {
        detectedTempo = 125;
        reasons.add('Tempo 125 BPM estimado por estilo de alabanza y júbilo');
        confidenceSum += 0.65;
        detections++;
      } else if (lower.contains('júbilo') || lower.contains('jubilo') || lower.contains('rápido') || lower.contains('rapido') || lower.contains('presto')) {
        detectedTempo = 145;
        reasons.add('Tempo 145 BPM estimado por indicación de tempo rápido/júbilo');
        confidenceSum += 0.6;
        detections++;
      }
    }

    // 4. Valores por defecto si falta alguno
    if (detectedTempo == null) {
      detectedTempo = 110;
      reasons.add('Tempo predeterminado congregacional (110 BPM)');
      confidenceSum += 0.4;
      detections++;
    }

    if (detectedSignature == null) {
      detectedSignature = TimeSignature.fourFour;
      reasons.add('Compás estándar congregacional (4/4)');
      confidenceSum += 0.4;
      detections++;
    }

    final finalConfidence = detections > 0 ? (confidenceSum / detections).clamp(0.1, 1.0) : 0.4;

    return TempoSuggestion(
      tempo: detectedTempo,
      timeSignature: detectedSignature,
      reason: reasons.join(' • '),
      confidence: finalConfidence,
    );
  }
}

