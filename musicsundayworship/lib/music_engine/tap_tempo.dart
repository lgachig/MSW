/// Rastreador de Tap Tempo para calcular BPM a partir de pulsaciones repetidas.
class TapTempoTracker {
  TapTempoTracker({
    this.minBpm = 40,
    this.maxBpm = 220,
    this.timeout = const Duration(milliseconds: 2500),
    this.maxHistory = 6,
  });

  final int minBpm;
  final int maxBpm;
  final Duration timeout;
  final int maxHistory;

  final List<DateTime> _taps = [];

  /// Historial de toques registrados.
  List<DateTime> get taps => List.unmodifiable(_taps);

  /// Registra una pulsación y devuelve el BPM calculado, o null si se requieren más toques.
  int? recordTap({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (_taps.isNotEmpty) {
      final elapsed = currentTime.difference(_taps.last);
      if (elapsed > timeout) {
        _taps.clear();
      } else if (elapsed.inMilliseconds < 140) {
        // Ignorar toques accidentales ultrarrápidos (> 420 BPM)
        return null;
      }
    }

    _taps.add(currentTime);
    if (_taps.length > maxHistory) {
      _taps.removeAt(0);
    }

    if (_taps.length < 2) {
      return null;
    }

    final intervals = <int>[];
    for (int i = 1; i < _taps.length; i++) {
      intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
    }

    final avgIntervalMs = intervals.reduce((a, b) => a + b) / intervals.length;
    if (avgIntervalMs <= 0) return null;

    final bpm = (60000.0 / avgIntervalMs).round();
    return bpm.clamp(minBpm, maxBpm);
  }

  /// Limpia el historial de pulsaciones.
  void reset() {
    _taps.clear();
  }
}

