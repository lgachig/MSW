import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';

/// Tarjeta de pulso visual y metrónomo de baja latencia sin audio.
class VisualMetronomeCard extends ConsumerStatefulWidget {
  const VisualMetronomeCard({
    super.key,
    required this.song,
    this.onSaved,
  });

  final SongDocument song;
  final void Function(int tempo, String timeSignature)? onSaved;

  @override
  ConsumerState<VisualMetronomeCard> createState() => _VisualMetronomeCardState();
}

class _VisualMetronomeCardState extends ConsumerState<VisualMetronomeCard> {
  late VisualMetronome _metronome;
  late TapTempoTracker _tapTracker;
  StreamSubscription<MetronomeTick>? _tickSubscription;

  late int _bpm;
  late TimeSignature _timeSignature;
  int _activeBeat = 0;
  bool _isFirstBeat = false;
  bool _isFlashing = false;
  bool _isPlaying = false;
  Timer? _flashResetTimer;
  String? _tapFeedback;
  Timer? _tapFeedbackTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bpm = (widget.song.tempo ?? 120).clamp(VisualMetronome.minBpm, VisualMetronome.maxBpm);
    _timeSignature = TimeSignature.tryParse(widget.song.timeSignature) ?? TimeSignature.fourFour;

    _metronome = VisualMetronome(
      initialBpm: _bpm,
      initialTimeSignature: _timeSignature,
    );
    _tapTracker = TapTempoTracker();

    _tickSubscription = _metronome.ticks.listen(_onTick);
  }

  @override
  void didUpdateWidget(covariant VisualMetronomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.song.id != oldWidget.song.id) {
      final newBpm = (widget.song.tempo ?? 120).clamp(VisualMetronome.minBpm, VisualMetronome.maxBpm);
      final newSig = TimeSignature.tryParse(widget.song.timeSignature) ?? TimeSignature.fourFour;
      setState(() {
        _bpm = newBpm;
        _timeSignature = newSig;
      });
      _metronome.setBpm(newBpm);
      _metronome.setTimeSignature(newSig);
    }
  }

  @override
  void dispose() {
    _flashResetTimer?.cancel();
    _tapFeedbackTimer?.cancel();
    _tickSubscription?.cancel();
    _metronome.dispose();
    super.dispose();
  }

  void _onTick(MetronomeTick tick) {
    if (!mounted) return;

    _flashResetTimer?.cancel();

    final flashMs = (_metronome.intervalMicroseconds ~/ 2500).clamp(70, 180);

    setState(() {
      _activeBeat = tick.beat;
      _isFirstBeat = tick.isFirstBeat;
      _isFlashing = true;
    });

    _flashResetTimer = Timer(Duration(milliseconds: flashMs), () {
      if (mounted) {
        setState(() {
          _isFlashing = false;
        });
      }
    });
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _metronome.stop();
        _isPlaying = false;
        _activeBeat = 0;
        _isFlashing = false;
      } else {
        _metronome.start();
        _isPlaying = true;
      }
    });
  }

  void _onTapTempo() {
    final computedBpm = _tapTracker.recordTap();
    if (computedBpm != null) {
      _setBpm(computedBpm);
      setState(() {
        _tapFeedback = '$computedBpm BPM';
      });
    } else {
      setState(() {
        _tapFeedback = 'Toca...';
      });
    }

    _tapFeedbackTimer?.cancel();
    _tapFeedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _tapFeedback = null);
      }
    });
  }

  void _setBpm(int value) {
    final clamped = value.clamp(VisualMetronome.minBpm, VisualMetronome.maxBpm);
    setState(() {
      _bpm = clamped;
    });
    _metronome.setBpm(clamped);
  }

  void _setTimeSignature(TimeSignature signature) {
    setState(() {
      _timeSignature = signature;
      if (_activeBeat > signature.beatsPerBar) {
        _activeBeat = signature.beatsPerBar;
      }
    });
    _metronome.setTimeSignature(signature);
  }

  Future<void> _suggestFromAi() async {
    // Extraer todo el texto de la canción (título, secciones, acordes)
    final buffer = StringBuffer();
    for (final sec in widget.song.sections) {
      buffer.writeln(sec.name);
      for (final line in sec.lines) {
        if (line.chords.isNotEmpty) {
          buffer.writeln(line.chords.map((c) => c.chord).join(' '));
        }
        buffer.writeln(line.content);
      }
    }

    final suggestion = TempoSuggester.suggest(
      title: widget.song.title,
      text: buffer.toString(),
    );

    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Sugerencia de tempo e IA'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempo sugerido: ${suggestion.tempo ?? _bpm} BPM',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Compás sugerido: ${suggestion.timeSignature?.label ?? _timeSignature.label}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Confianza: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(suggestion.confidenceLabel),
                  backgroundColor: suggestion.confidence >= 0.8
                      ? Colors.green.shade100
                      : (suggestion.confidence >= 0.5 ? Colors.amber.shade100 : Colors.grey.shade200),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Motivo: ${suggestion.reason}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Deseas aplicar estos valores al pulso visual?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('discard-suggestion-button'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Descartar'),
          ),
          FilledButton(
            key: const Key('apply-suggestion-button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Aplicar sugerencia'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      if (suggestion.tempo != null) {
        _setBpm(suggestion.tempo!);
      }
      if (suggestion.timeSignature != null) {
        _setTimeSignature(suggestion.timeSignature!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sugerencia aplicada: $_bpm BPM, ${_timeSignature.label}',
          ),
        ),
      );
    }
  }

  Future<void> _saveToSong() async {
    final songId = widget.song.id;
    if (songId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(songRepositoryProvider).updateTempoAndSignature(
        songId,
        tempo: _bpm,
        timeSignature: _timeSignature.label,
      );
      widget.onSaved?.call(_bpm, _timeSignature.label);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tempo guardado: $_bpm BPM, ${_timeSignature.label}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar tempo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBeatOneActive = _isPlaying && _isFlashing && _isFirstBeat;
    final isSecondaryActive = _isPlaying && _isFlashing && !_isFirstBeat;

    // Colores para el acento del primer tiempo vs los tiempos siguientes
    final beatOneColor = Colors.amber.shade700;
    final otherBeatColor = theme.colorScheme.primary;

    return Card(
      key: const Key('visual-metronome-card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con título, sugerencia IA y botón guardar
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pulso visual y compás',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '$_bpm BPM • ${_timeSignature.label}',
                        key: const Key('metronome-status-summary'),
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('suggest-tempo-button'),
                  tooltip: 'Detectar / sugerir con IA',
                  icon: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                  onPressed: _suggestFromAi,
                ),
                if (widget.song.id != null)
                  IconButton(
                    key: const Key('save-tempo-button'),
                    tooltip: 'Guardar tempo en la canción',
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    onPressed: _isSaving ? null : _saveToSong,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Área central de visualización del pulso y acento visual
            Container(
              key: const Key('visual-pulse-display'),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isBeatOneActive
                    ? beatOneColor.withValues(alpha: 0.18)
                    : (isSecondaryActive
                        ? otherBeatColor.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBeatOneActive
                      ? beatOneColor
                      : (isSecondaryActive
                          ? otherBeatColor.withValues(alpha: 0.7)
                          : theme.dividerColor.withValues(alpha: 0.4)),
                  width: isBeatOneActive ? 2.5 : 1.2,
                ),
                boxShadow: isBeatOneActive
                    ? [
                        BoxShadow(
                          color: beatOneColor.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ]
                    : (isSecondaryActive
                        ? [
                            BoxShadow(
                              color: otherBeatColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null),
              ),
              child: Column(
                children: [
                  // Número de tiempo activo destacado
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 70),
                    style: TextStyle(
                      fontSize: isBeatOneActive ? 46 : (isSecondaryActive ? 38 : 32),
                      fontWeight: FontWeight.bold,
                      color: isBeatOneActive
                          ? beatOneColor
                          : (isSecondaryActive ? otherBeatColor : theme.disabledColor),
                    ),
                    child: Text(
                      _isPlaying ? '$_activeBeat' : '—',
                      key: const Key('active-beat-text'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPlaying
                        ? (_isFirstBeat ? '¡Tiempo 1 (Acento fuerte)!' : 'Tiempo $_activeBeat')
                        : 'Pulso en pausa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isBeatOneActive ? FontWeight.bold : FontWeight.normal,
                      color: isBeatOneActive
                          ? beatOneColor
                          : (_isPlaying ? otherBeatColor : theme.hintColor),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fila de círculos indicadores para cada pulso del compás
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_timeSignature.beatsPerBar, (index) {
                      final beatNumber = index + 1;
                      final isCurrent = _isPlaying && _isFlashing && _activeBeat == beatNumber;
                      final isBeat1 = beatNumber == 1;

                      return Container(
                        key: Key('beat-indicator-$beatNumber'),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: isBeat1 ? (isCurrent ? 28 : 22) : (isCurrent ? 24 : 18),
                        height: isBeat1 ? (isCurrent ? 28 : 22) : (isCurrent ? 24 : 18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? (isBeat1 ? beatOneColor : otherBeatColor)
                              : (isBeat1
                                  ? beatOneColor.withValues(alpha: 0.25)
                                  : theme.disabledColor.withValues(alpha: 0.25)),
                          border: Border.all(
                            color: isBeat1
                                ? beatOneColor
                                : (isCurrent ? otherBeatColor : theme.disabledColor),
                            width: isBeat1 ? 2.0 : 1.2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: (isBeat1 ? beatOneColor : otherBeatColor)
                                        .withValues(alpha: 0.6),
                                    blurRadius: isBeat1 ? 12 : 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$beatNumber',
                            style: TextStyle(
                              fontSize: isBeat1 ? 12 : 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : (isBeat1 ? beatOneColor : theme.hintColor),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fila de Controles: Iniciar/Detener y Tap Tempo
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    key: const Key('play-metronome-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isPlaying ? Colors.red.shade700 : theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _togglePlay,
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    label: Text(_isPlaying ? 'Detener' : 'Iniciar pulso'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    key: const Key('tap-tempo-button'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onTapTempo,
                    icon: const Icon(Icons.touch_app, size: 18),
                    label: Text(_tapFeedback ?? 'Tap Tempo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Controles de ajuste manual de Tempo (BPM)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const Key('bpm-decrement-fast'),
                  tooltip: '-5 BPM',
                  visualDensity: VisualDensity.compact,
                  onPressed: _bpm > VisualMetronome.minBpm ? () => _setBpm(_bpm - 5) : null,
                  icon: const Icon(Icons.fast_rewind, size: 18),
                ),
                IconButton.filledTonal(
                  key: const Key('bpm-decrement'),
                  tooltip: '-1 BPM',
                  visualDensity: VisualDensity.compact,
                  onPressed: _bpm > VisualMetronome.minBpm ? () => _setBpm(_bpm - 1) : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_bpm BPM',
                    key: const Key('bpm-value'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('bpm-increment'),
                  tooltip: '+1 BPM',
                  visualDensity: VisualDensity.compact,
                  onPressed: _bpm < VisualMetronome.maxBpm ? () => _setBpm(_bpm + 1) : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
                IconButton.filledTonal(
                  key: const Key('bpm-increment-fast'),
                  tooltip: '+5 BPM',
                  visualDensity: VisualDensity.compact,
                  onPressed: _bpm < VisualMetronome.maxBpm ? () => _setBpm(_bpm + 5) : null,
                  icon: const Icon(Icons.fast_forward, size: 18),
                ),
              ],
            ),
            Slider(
              key: const Key('bpm-slider'),
              min: VisualMetronome.minBpm.toDouble(),
              max: VisualMetronome.maxBpm.toDouble(),
              divisions: VisualMetronome.maxBpm - VisualMetronome.minBpm,
              value: _bpm.toDouble(),
              label: '$_bpm BPM',
              onChanged: (val) => _setBpm(val.round()),
            ),
            const SizedBox(height: 8),

            // Selector de Compás (2/4, 3/4, 4/4, 6/8)
            const Text(
              'Compás:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            SegmentedButton<TimeSignature>(
              key: const Key('time-signature-selector'),
              segments: [
                for (final sig in TimeSignature.commonSignatures)
                  ButtonSegment<TimeSignature>(
                    value: sig,
                    label: Text(sig.label),
                  ),
              ],
              selected: {_timeSignature},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  _setTimeSignature(selected.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

