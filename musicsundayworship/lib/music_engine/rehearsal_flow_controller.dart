import 'dart:async';

import 'rehearsal_plan.dart';
import 'time_signature.dart';
import 'visual_metronome.dart';

/// Instantánea del estado en tiempo real del ensayo.
class RehearsalState {
  const RehearsalState({
    required this.isPlaying,
    required this.isPaused,
    required this.isFinished,
    required this.sectionIndex,
    required this.currentSection,
    required this.nextSection,
    required this.currentBar,
    required this.totalBarsInSection,
    required this.currentBeat,
    required this.beatsPerBar,
    required this.activeChordIndex,
    required this.activeChord,
    required this.bpm,
    required this.timeSignature,
    required this.songProgress,
    required this.isFirstBeat,
  });

  final bool isPlaying;
  final bool isPaused;
  final bool isFinished;

  /// Índice de la sección actual (0-based).
  final int sectionIndex;

  /// Sección actualmente activa.
  final RehearsalSection? currentSection;

  /// Próxima sección a sonar (para aviso al músico).
  final RehearsalSection? nextSection;

  /// Compás actual dentro de la sección (1-based: 1 .. totalBarsInSection).
  final int currentBar;

  /// Total de compases de la sección actual.
  final int totalBarsInSection;

  /// Pulso actual dentro del compás (1-based: 1 .. beatsPerBar).
  final int currentBeat;

  /// Pulsos por compás.
  final int beatsPerBar;

  /// Índice del acorde activo dentro de los acordes de la sección (-1 si no hay).
  final int activeChordIndex;

  /// Acorde sonando en este momento (ej. "G", "Em").
  final String? activeChord;

  /// BPM actual.
  final int bpm;

  /// Compás actual.
  final TimeSignature timeSignature;

  /// Progreso de 0.0 a 1.0 de toda la canción.
  final double songProgress;

  /// Verdadero si es el tiempo 1 del compás.
  final bool isFirstBeat;
}

/// Controlador de flujo rítmico para el modo de ensayo con avance automático.
class RehearsalFlowController {
  RehearsalFlowController({
    required RehearsalSongPlan plan,
    VisualMetronome? metronome,
  })  : _plan = plan,
        _bpm = plan.bpm,
        _timeSignature = plan.timeSignature {
    _metronome = metronome ??
        VisualMetronome(
          initialBpm: _bpm,
          initialTimeSignature: _timeSignature,
        );
    _tickSub = _metronome.ticks.listen(_onMetronomeTick);
    _resetPositions();
  }

  RehearsalSongPlan _plan;
  late final VisualMetronome _metronome;
  StreamSubscription<MetronomeTick>? _tickSub;

  int _bpm;
  TimeSignature _timeSignature;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isFinished = false;

  int _sectionIndex = 0;
  int _currentBar = 1;
  int _currentBeat = 1;

  final StreamController<RehearsalState> _stateController =
      StreamController<RehearsalState>.broadcast();

  Stream<RehearsalState> get stateStream => _stateController.stream;

  RehearsalSongPlan get plan => _plan;
  int get bpm => _bpm;
  TimeSignature get timeSignature => _timeSignature;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isFinished => _isFinished;
  int get sectionIndex => _sectionIndex;
  int get currentBar => _currentBar;
  int get currentBeat => _currentBeat;

  RehearsalSection? get currentSection =>
      _sectionIndex < _plan.sections.length ? _plan.sections[_sectionIndex] : null;

  RehearsalSection? get nextSection =>
      _sectionIndex + 1 < _plan.sections.length
          ? _plan.sections[_sectionIndex + 1]
          : null;

  RehearsalState get currentState => _buildSnapshot(isFirstBeat: _currentBeat == 1);

  void _resetPositions() {
    _sectionIndex = 0;
    _currentBar = 1;
    _currentBeat = 1;
    _isFinished = false;
  }

  /// Inicia o reanuda el ensayo.
  void play() {
    if (_isPlaying) return;
    if (_isFinished) {
      _resetPositions();
    }
    _isPlaying = true;
    _isPaused = false;
    _metronome.start();
    _emitState(isFirstBeat: _currentBeat == 1);
  }

  /// Pausa el ensayo sin perder el tiempo ni la posición actual.
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _isPaused = true;
    _metronome.stop();
    _emitState(isFirstBeat: false);
  }

  /// Alterna entre reproducir y pausar.
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Detiene y reinicia al principio de la canción.
  void stop() {
    _isPlaying = false;
    _isPaused = false;
    _metronome.stop();
    _resetPositions();
    _emitState(isFirstBeat: false);
  }

  /// Salta a una sección específica por índice.
  void jumpToSection(int index) {
    if (_plan.sections.isEmpty) return;
    final clamped = index.clamp(0, _plan.sections.length - 1);
    _sectionIndex = clamped;
    _currentBar = 1;
    _currentBeat = 1;
    _isFinished = false;
    _emitState(isFirstBeat: true);
  }

  /// Avanza a la siguiente sección inmediatamente.
  void nextSection() {
    if (_sectionIndex + 1 < _plan.sections.length) {
      jumpToSection(_sectionIndex + 1);
    }
  }

  /// Retrocede a la sección previa (o al inicio del compás si está a mitad).
  void previousSection() {
    if (_currentBar > 1) {
      _currentBar = 1;
      _currentBeat = 1;
      _emitState(isFirstBeat: true);
    } else if (_sectionIndex > 0) {
      jumpToSection(_sectionIndex - 1);
    }
  }

  /// Cambia el tempo (40 a 220 BPM) sobre la marcha.
  void setBpm(int newBpm) {
    final clamped = newBpm.clamp(VisualMetronome.minBpm, VisualMetronome.maxBpm);
    _bpm = clamped;
    _metronome.setBpm(clamped);
    _emitState(isFirstBeat: _currentBeat == 1);
  }

  /// Actualiza los compases de una sección específica.
  void updateSectionBars(int index, int bars) {
    if (index < 0 || index >= _plan.sections.length) return;
    final updatedList = List<RehearsalSection>.from(_plan.sections);
    updatedList[index] = updatedList[index].copyWith(bars: bars.clamp(1, 64));
    _plan = RehearsalSongPlan(
      songTitle: _plan.songTitle,
      originalKey: _plan.originalKey,
      bpm: _plan.bpm,
      timeSignature: _plan.timeSignature,
      sections: List.unmodifiable(updatedList),
    );
    _emitState(isFirstBeat: _currentBeat == 1);
  }

  /// Procesa cada pulso emitido por el metrónomo.
  void _onMetronomeTick(MetronomeTick tick) {
    if (!_isPlaying) return;

    final beatsPerBar = _timeSignature.beatsPerBar;
    final section = currentSection;

    if (section == null) {
      _finishSong();
      return;
    }

    // El primer tick tras play() se corresponde con la posición actual
    if (tick.totalBeats == 1) {
      _emitState(isFirstBeat: _currentBeat == 1);
      return;
    }

    // Avanzar pulso
    if (_currentBeat >= beatsPerBar) {
      // Compás completado
      if (_currentBar >= section.bars) {
        // Sección completada: avanzar exactamente en el compás
        if (_sectionIndex + 1 < _plan.sections.length) {
          _sectionIndex++;
          _currentBar = 1;
          _currentBeat = 1;
        } else {
          // Última sección completada
          _finishSong();
          return;
        }
      } else {
        _currentBar++;
        _currentBeat = 1;
      }
    } else {
      _currentBeat++;
    }

    _emitState(isFirstBeat: _currentBeat == 1);
  }

  /// Avanza manualmente un pulso (útil para pruebas unitarias deterministas sin temporizadores).
  void advanceBeatForTesting() {
    if (!_isPlaying) return;
    _onMetronomeTick(MetronomeTick(
      beat: _currentBeat,
      totalBeats: 2, // mayor a 1 para avanzar
      isFirstBeat: _currentBeat == 1,
      isAccentBeat: _timeSignature.isAccentBeat(_currentBeat),
      elapsedMilliseconds: 0,
    ));
  }

  void _finishSong() {
    _isPlaying = false;
    _isPaused = false;
    _isFinished = true;
    _metronome.stop();
    _emitState(isFirstBeat: false);
  }

  void _emitState({required bool isFirstBeat}) {
    if (!_stateController.isClosed) {
      _stateController.add(_buildSnapshot(isFirstBeat: isFirstBeat));
    }
  }

  RehearsalState _buildSnapshot({required bool isFirstBeat}) {
    final section = currentSection;
    final totalBars = section?.bars ?? 1;

    // Calcular acorde activo de la sección
    int activeChordIdx = -1;
    String? activeChordStr;

    if (section != null) {
      final chords = section.allChords;
      if (chords.isNotEmpty) {
        final chordIdx =
            ((_currentBar - 1) * chords.length ~/ totalBars).clamp(0, chords.length - 1);
        activeChordIdx = chordIdx;
        activeChordStr = chords[chordIdx].chord;
      }
    }

    // Calcular progreso total de la canción
    double progress = 0.0;
    final planTotalBars = _plan.totalBars;
    if (planTotalBars > 0) {
      int barsElapsed = 0;
      for (int i = 0; i < _sectionIndex && i < _plan.sections.length; i++) {
        barsElapsed += _plan.sections[i].bars;
      }
      barsElapsed += (_currentBar - 1);
      final beatsInCurrentBar = _currentBeat - 1;
      final totalBeatsElapsed =
          barsElapsed * _timeSignature.beatsPerBar + beatsInCurrentBar;
      progress = (totalBeatsElapsed / _plan.totalBeats).clamp(0.0, 1.0);
    }

    return RehearsalState(
      isPlaying: _isPlaying,
      isPaused: _isPaused,
      isFinished: _isFinished,
      sectionIndex: _sectionIndex,
      currentSection: section,
      nextSection: nextSection,
      currentBar: _currentBar,
      totalBarsInSection: totalBars,
      currentBeat: _currentBeat,
      beatsPerBar: _timeSignature.beatsPerBar,
      activeChordIndex: activeChordIdx,
      activeChord: activeChordStr,
      bpm: _bpm,
      timeSignature: _timeSignature,
      songProgress: progress,
      isFirstBeat: isFirstBeat,
    );
  }

  void dispose() {
    _tickSub?.cancel();
    _metronome.dispose();
    _stateController.close();
  }
}

