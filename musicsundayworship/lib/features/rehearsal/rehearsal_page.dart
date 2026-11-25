import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';

/// Página de pantalla completa para el Modo Ensayo con avance automático.
class RehearsalPage extends StatefulWidget {
  const RehearsalPage({
    super.key,
    required this.song,
    this.structure,
    this.controller,
  });

  final SongDocument song;
  final SongStructure? structure;
  final RehearsalFlowController? controller;

  @override
  State<RehearsalPage> createState() => _RehearsalPageState();
}

class _RehearsalPageState extends State<RehearsalPage> {
  late final RehearsalFlowController _controller;
  late final bool _ownsController;
  StreamSubscription<RehearsalState>? _stateSubscription;
  late RehearsalState _state;

  bool _keepAwake = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final plan = RehearsalSongPlan.fromSong(
        song: widget.song,
        structure: widget.structure,
      );
      _controller = RehearsalFlowController(plan: plan);
      _ownsController = true;
    }

    _state = _controller.currentState;
    _stateSubscription = _controller.stateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    _controller.togglePlayPause();
  }

  void _toggleKeepAwake() {
    setState(() => _keepAwake = !_keepAwake);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          _keepAwake
              ? 'Pantalla encendida activa durante el ensayo'
              : 'Pantalla encendida desactivada',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSection = _state.currentSection;
    final nextSection = _state.nextSection;
    final isBeatOne = _state.isFirstBeat && _state.isPlaying;

    final type = currentSection?.type ?? SectionType.otro;
    final sectionColor = SectionStyle.backgroundColor(type);
    final borderColor = SectionStyle.borderColor(type);
    final textColor = SectionStyle.textColor(type);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.song.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Tono: ${widget.song.originalKey ?? "—"} • ${_state.bpm} BPM • ${_state.timeSignature.label}',
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('keep-awake-button'),
            tooltip: _keepAwake ? 'Mantener pantalla encendida (Activo)' : 'Pantalla encendida (Inactivo)',
            icon: Icon(
              _keepAwake ? Icons.light_mode : Icons.light_mode_outlined,
              color: _keepAwake ? Colors.amber : null,
            ),
            onPressed: _toggleKeepAwake,
          ),
          IconButton(
            key: const Key('close-rehearsal-button'),
            tooltip: 'Salir del ensayo',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            key: const Key('song-progress-bar'),
            value: _state.songProgress,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra rítmica superior: indicador de compás y pulso visual
            _buildBeatBar(theme, isBeatOne),

            // Roadmap horizontal de secciones para salto rápido
            _buildSectionRoadmap(theme),

            // Sección actual destacada en grande
            Expanded(
              child: _buildCurrentSectionCard(
                theme: theme,
                currentSection: currentSection,
                sectionColor: sectionColor,
                borderColor: borderColor,
                textColor: textColor,
              ),
            ),

            // Vista previa de la siguiente sección
            _buildNextSectionPreview(theme, nextSection),

            // Barra de control de transporte (Play/Pause, anterior, siguiente, tempo)
            _buildControlBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBeatBar(ThemeData theme, bool isBeatOne) {
    final beatOneColor = Colors.amber.shade700;
    final otherBeatColor = theme.colorScheme.primary;

    return Container(
      key: const Key('rehearsal-beat-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          // Conteo de compás
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Compás ${_state.currentBar} de ${_state.totalBarsInSection}',
              key: const Key('bar-counter-text'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const Spacer(),

          // Fila de pulsos visuales con acento en el tiempo 1
          Row(
            children: List.generate(_state.beatsPerBar, (index) {
              final beatNumber = index + 1;
              final isCurrent = _state.isPlaying && _state.currentBeat == beatNumber;
              final isB1 = beatNumber == 1;

              return Container(
                key: Key('rehearsal-beat-dot-$beatNumber'),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isB1 ? 16 : 12,
                height: isB1 ? 16 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? (isB1 ? beatOneColor : otherBeatColor)
                      : (isB1
                          ? beatOneColor.withValues(alpha: 0.3)
                          : theme.disabledColor.withValues(alpha: 0.3)),
                  boxShadow: isCurrent && isB1
                      ? [
                          BoxShadow(
                            color: beatOneColor.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionRoadmap(ThemeData theme) {
    final sections = _controller.plan.sections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        key: const Key('section-roadmap-list'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final s = sections[index];
          final isActive = index == _state.sectionIndex;
          final sType = s.type;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: Key('roadmap-chip-$index'),
              visualDensity: VisualDensity.compact,
              label: Text(s.displayTitle),
              backgroundColor: isActive
                  ? SectionStyle.backgroundColor(sType)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              side: BorderSide(
                color: isActive
                    ? SectionStyle.borderColor(sType)
                    : theme.dividerColor.withValues(alpha: 0.4),
                width: isActive ? 2.0 : 1.0,
              ),
              labelStyle: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                color: isActive ? SectionStyle.textColor(sType) : theme.colorScheme.onSurface,
              ),
              onPressed: () => _controller.jumpToSection(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentSectionCard({
    required ThemeData theme,
    required RehearsalSection? currentSection,
    required Color sectionColor,
    required Color borderColor,
    required Color textColor,
  }) {
    if (currentSection == null) {
      return Center(
        child: Text(
          _state.isFinished ? '¡Canción finalizada!' : 'Sin secciones',
          style: theme.textTheme.headlineSmall,
        ),
      );
    }

    return Container(
      key: const Key('current-section-card'),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera de la sección
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(SectionStyle.icon(currentSection.type), color: textColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  currentSection.displayTitle,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (_state.activeChord != null)
                  Container(
                    key: const Key('active-chord-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.shade700.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      'Acorde: ${_state.activeChord}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Letra y acordes de la sección
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in currentSection.lines) ...[
                    _buildLineWithChords(line, theme),
                    const SizedBox(height: 12),
                  ],
                  if (currentSection.lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '[Instrumental]',
                          style: TextStyle(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineWithChords(SongLine line, ThemeData theme) {
    final chords = line.chords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chords.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: chords.map((c) {
              final isThisChordActive = _state.isPlaying && _state.activeChord == c.chord;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isThisChordActive
                      ? Colors.amber.shade700.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isThisChordActive
                      ? Border.all(color: Colors.amber.shade700, width: 1.5)
                      : null,
                ),
                child: Text(
                  c.chord,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isThisChordActive
                        ? Colors.amber.shade800
                        : theme.colorScheme.primary,
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 2),
        Text(
          line.content,
          style: const TextStyle(fontSize: 16, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildNextSectionPreview(ThemeData theme, RehearsalSection? nextSection) {
    if (nextSection == null) {
      return Container(
        key: const Key('next-section-preview'),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Final de la canción',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final nextColor = SectionStyle.backgroundColor(nextSection.type);
    final nextTextColor = SectionStyle.textColor(nextSection.type);

    return Container(
      key: const Key('next-section-preview'),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: nextColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: SectionStyle.borderColor(nextSection.type).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.skip_next, size: 18),
          const SizedBox(width: 6),
          Text(
            'Siguiente: ',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          Text(
            nextSection.displayTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: nextTextColor,
            ),
          ),
          const Spacer(),
          Text(
            '(${nextSection.bars} compases)',
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(ThemeData theme) {
    return Container(
      key: const Key('rehearsal-control-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón sección anterior
          IconButton(
            key: const Key('prev-section-button'),
            tooltip: 'Sección anterior',
            icon: const Icon(Icons.skip_previous, size: 28),
            onPressed: _controller.previousSection,
          ),

          // Botón Play / Pause principal
          FilledButton.icon(
            key: const Key('rehearsal-play-pause-button'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: _state.isPlaying ? Colors.red.shade700 : theme.colorScheme.primary,
            ),
            onPressed: _togglePlayPause,
            icon: Icon(_state.isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(
              _state.isPlaying ? 'Pausar' : (_state.isPaused ? 'Reanudar' : 'Iniciar ensayo'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),

          // Botón siguiente sección
          IconButton(
            key: const Key('next-section-button'),
            tooltip: 'Siguiente sección',
            icon: const Icon(Icons.skip_next, size: 28),
            onPressed: _controller.nextSection,
          ),

          // Ajustador de BPM
          Row(
            children: [
              IconButton(
                key: const Key('rehearsal-bpm-dec'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => _controller.setBpm(_state.bpm - 2),
              ),
              Text(
                '${_state.bpm}',
                key: const Key('rehearsal-bpm-text'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                key: const Key('rehearsal-bpm-inc'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _controller.setBpm(_state.bpm + 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

