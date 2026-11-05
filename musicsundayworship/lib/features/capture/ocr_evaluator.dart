/// Evaluates OCR extraction quality against ground-truth references.
class OcrEvaluator {
  const OcrEvaluator._();

  /// Compares [extractedText] with [expectedText] and returns word accuracy [0.0 - 1.0].
  static double calculateWordAccuracy(String extractedText, String expectedText) {
    final expectedWords = _tokenize(expectedText);
    if (expectedWords.isEmpty) return 1.0;

    final extractedWords = _tokenize(extractedText);
    if (extractedWords.isEmpty) return 0.0;

    var matched = 0;
    final remaining = List<String>.from(extractedWords);

    for (final exp in expectedWords) {
      final index = remaining.indexWhere((ext) => _isFuzzyMatch(ext, exp));
      if (index != -1) {
        matched++;
        remaining.removeAt(index);
      }
    }

    return matched / expectedWords.length;
  }

  static List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\sáéíóúñÁÉÍÓÚÑ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  static bool _isFuzzyMatch(String a, String b) {
    if (a == b) return true;
    if (a.length > 3 && b.length > 3) {
      final distance = _levenshtein(a, b);
      return distance <= 1;
    }
    return false;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.filled(t.length + 1, 0);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }
}
