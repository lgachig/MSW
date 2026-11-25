import 'dart:async';

import 'time_signature.dart';

/// Notificación de un pulso del metrónomo visual.
class MetronomeTick {
  const MetronomeTick({
    required this.beat,
    required this.totalBeats,
    required this.isFirstBeat,
    required this.isAccentBeat,
    required this.elapsedMilliseconds,
    this.targetMilliseconds = 0,
  });

  /// Pulso dentro del compás actual (1 a beatsPerBar).
  final int beat;

  /// Contador acumulado de pulsos desde el inicio.
  final int totalBeats;

  /// Verdadero si es el pulso 1 (acento principal).
  final bool isFirstBeat;

  /// Verdadero si tiene acento primario o secundario.
  final bool isAccentBeat;

  /// Tiempo transcurrido en milisegundos desde el inicio.
  final int elapsedMilliseconds;

  /// Tiempo ideal acumulado en milisegundos para este pulso.
  final int targetMilliseconds;

  /// Desviación instantánea en milisegundos respecto al tiempo ideal.
  int get deviationMilliseconds =>
      (elapsedMilliseconds - targetMilliseconds).abs();
}

/// Metrónomo visual de baja latencia y libre de deriva acumulada.
///
/// Utiliza un reloj monotónico de alta resolución ([Stopwatch]) para recalcular
/// en cada pulso el retraso necesario hasta el siguiente tiempo esperado,
/// asegurando que la desviación a lo largo del tiempo se mantenga < 10 ms
/// sin acumular retrasos de ciclos anteriores.
class VisualMetronome {
  VisualMetronome({
    int initialBpm = 120,
    TimeSignature initialTimeSignature = TimeSignature.fourFour,
    Stopwatch Function()? stopwatchFactory,
  })  : _bpm = initialBpm.clamp(minBpm, maxBpm),
        _timeSignature = initialTimeSignature,
        _stopwatchFactory = stopwatchFactory ?? Stopwatch.new;

  static const int minBpm = 40;
  static const int maxBpm = 220;

  final Stopwatch Function() _stopwatchFactory;

  int _bpm;
  TimeSignature _timeSignature;
  bool _isPlaying = false;
  int _currentBeat = 0;
  int _totalBeats = 0;

  Stopwatch? _stopwatch;
  Timer? _timer;

  final StreamController<MetronomeTick> _controller =
      StreamController<MetronomeTick>.broadcast();

  /// BPM actual (40 a 220).
  int get bpm => _bpm;

  /// Compás actual.
  TimeSignature get timeSignature => _timeSignature;

  /// Indica si el metrónomo está en marcha.
  bool get isPlaying => _isPlaying;

  /// Pulso actual dentro del compás (0 si está detenido).
  int get currentBeat => _currentBeat;

  /// Total de pulsos emitidos en la sesión activa.
  int get totalBeats => _totalBeats;

  /// Flujo continuo de pulsos para la animación visual.
  Stream<MetronomeTick> get ticks => _controller.stream;

  /// Duración de cada pulso en microsegundos.
  int get intervalMicroseconds => (60.0 / _bpm * 1000000).round();

  /// Cambia el tempo en BPM.
  void setBpm(int value) {
    final clamped = value.clamp(minBpm, maxBpm);
    if (_bpm == clamped) return;
    _bpm = clamped;
    if (_isPlaying) {
      _reanchorTiming();
    }
  }

  /// Cambia el compás.
  void setTimeSignature(TimeSignature signature) {
    if (_timeSignature == signature) return;
    _timeSignature = signature;
    if (_currentBeat > signature.beatsPerBar) {
      _currentBeat = ((_totalBeats - 1) % signature.beatsPerBar) + 1;
    }
  }

  /// Inicia el pulso visual.
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _totalBeats = 0;
    _currentBeat = 0;
    _stopwatch = _stopwatchFactory()..start();
    _fireBeat();
  }

  /// Detiene el pulso visual.
  void stop() {
    _isPlaying = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _currentBeat = 0;
  }

  /// Alterna entre iniciar y detener.
  void toggle() {
    if (_isPlaying) {
      stop();
    } else {
      start();
    }
  }

  /// Libera recursos.
  void dispose() {
    stop();
    _controller.close();
  }

  void _reanchorTiming() {
    _timer?.cancel();
    _stopwatch?.reset();
    _stopwatch?.start();
    _totalBeats = 0;
    _scheduleNext();
  }

  void _fireBeat() {
    if (!_isPlaying || _stopwatch == null) return;

    _totalBeats++;
    _currentBeat = ((_totalBeats - 1) % _timeSignature.beatsPerBar) + 1;

    final elapsedMs = _stopwatch!.elapsedMilliseconds;
    final targetMs = ((_totalBeats - 1) * intervalMicroseconds / 1000).round();

    final tick = MetronomeTick(
      beat: _currentBeat,
      totalBeats: _totalBeats,
      isFirstBeat: _currentBeat == 1,
      isAccentBeat: _timeSignature.isAccentBeat(_currentBeat),
      elapsedMilliseconds: elapsedMs,
      targetMilliseconds: targetMs,
    );

    if (!_controller.isClosed) {
      _controller.add(tick);
    }

    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_isPlaying || _stopwatch == null) return;

    final nextTargetMicros = _totalBeats * intervalMicroseconds;
    final elapsedMicros = _stopwatch!.elapsedMicroseconds;
    final delayMicros = nextTargetMicros - elapsedMicros;

    if (delayMicros <= 0) {
      Timer.run(_fireBeat);
    } else {
      _timer = Timer(Duration(microseconds: delayMicros), _fireBeat);
    }
  }
}

