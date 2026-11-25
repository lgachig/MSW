import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';
import '../structure/song_structure_editor_page.dart';

/// Servicio de canal nativo para mantener la pantalla encendida durante el ensayo.
class KeepAwakeService {
  static const _channel = MethodChannel('com.musicsundayworship/keep_awake');

  static Future<bool> setKeepAwake(bool enable) async {
    try {
      final res = await _channel.invokeMethod<bool>(enable ? 'enable' : 'disable');
      return res ?? enable;
    } catch (_) {
      return enable;
    }
  }
}

/// Página de Modo Ensayo con desplazamiento vertical continuo y avance automático al compás.
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

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = [];

  bool _keepAwake = true;
  int _lastScrolledSection = -1;

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

    // Inicializar keys para auto-scroll de cada sección
    for (int i = 0; i < _controller.plan.sections.length; i++) {
      _sectionKeys.add(GlobalKey());
    }

    // Activar pantalla encendida por defecto en ensayo
    KeepAwakeService.setKeepAwake(true);

    _stateSubscription = _controller.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);

      // Desplazamiento automático vertical cuando cambia la sección
      if (state.sectionIndex != _lastScrolledSection) {
        _lastScrolledSection = state.sectionIndex;
        _scrollToSection(state.sectionIndex);
      }
    });

    // Auto-scroll inicial a la primera sección al renderizar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSection(0);
    });
  }

  @override
  void dispose() {
    KeepAwakeService.setKeepAwake(false);
    _stateSubscription?.cancel();
    _scrollController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _scrollToSection(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final keyContext = _sectionKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.12, // Posiciona la sección activa al 12% superior para ver lo que viene abajo
      );
    }
  }

  void _togglePlayPause() {
    _controller.togglePlayPause();
  }

  Future<void> _toggleKeepAwake() async {
    final nextVal = !_keepAwake;
    await KeepAwakeService.setKeepAwake(nextVal);
    if (!mounted) return;
    setState(() => _keepAwake = nextVal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          _keepAwake
              ? 'Pantalla siempre encendida: Activado'
              : 'Pantalla siempre encendida: Desactivado',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _controller.plan.sections;
    final isBeatOne = _state.isFirstBeat && _state.isPlaying;

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
          // Botón descriptivo para mantener la pantalla encendida
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('keep-awake-button'),
                onTap: _toggleKeepAwake,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _keepAwake
                        ? Colors.amber.shade100
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _keepAwake ? Colors.amber.shade800 : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _keepAwake ? Icons.screen_lock_portrait : Icons.stay_current_portrait,
                        size: 16,
                        color: _keepAwake ? Colors.amber.shade900 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _keepAwake ? 'Pantalla encendida' : 'Pantalla normal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _keepAwake ? Colors.amber.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
            // Barra rítmica superior: indicador de compás y pulsos visuales
            _buildBeatBar(theme, isBeatOne),

            // Roadmap horizontal de secciones para salto rápido
            _buildSectionRoadmap(theme),

            // Flujo continuo vertical de la canción completa con auto-desplazamiento
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Text(
                        'Sin secciones para ensayar',
                        style: theme.textTheme.headlineSmall,
                      ),
                    )
                  : ListView.builder(
                      key: const Key('rehearsal-continuous-list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 140),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        final isActive = index == _state.sectionIndex;
                        final isPast = index < _state.sectionIndex;

                        return Container(
                          key: _sectionKeys[index],
                          child: _buildContinuousSectionCard(
                            theme: theme,
                            section: section,
                            index: index,
                            isActive: isActive,
                            isPast: isPast,
                          ),
                        );
                      },
                    ),
            ),

            // Barra de control de transporte inferior (Play/Pause, anterior, siguiente, tempo)
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
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Row(
        children: [
          // Conteo de compás en la sección activa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
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
          const SizedBox(width: 8),
          if (_state.activeChord != null)
            Container(
              key: const Key('active-chord-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade700.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'Acorde: ${_state.activeChord}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          const Spacer(),

          // Fila de pulsos visuales con acento destacado en el tiempo 1
          Row(
            children: List.generate(_state.beatsPerBar, (index) {
              final beatNumber = index + 1;
              final isCurrent = _state.isPlaying && _state.currentBeat == beatNumber;
              final isB1 = beatNumber == 1;

              return Container(
                key: Key('rehearsal-beat-dot-$beatNumber'),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isB1 ? 16 : 12,
                height: isB1 ? 16 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? (isB1 ? beatOneColor : otherBeatColor)
                      : (isB1
                          ? beatOneColor.withValues(alpha: 0.35)
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
                width: isActive ? 2.5 : 1.0,
              ),
              labelStyle: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                color: isActive ? SectionStyle.textColor(sType) : theme.colorScheme.onSurface,
              ),
              onPressed: () {
                _controller.jumpToSection(index);
                _scrollToSection(index);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinuousSectionCard({
    required ThemeData theme,
    required RehearsalSection section,
    required int index,
    required bool isActive,
    required bool isPast,
  }) {
    final type = section.type;
    final sectionColor = SectionStyle.backgroundColor(type);
    final borderColor = SectionStyle.borderColor(type);
    final textColor = SectionStyle.textColor(type);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: isActive ? 1.0 : (isPast ? 0.45 : 0.85),
      child: Container(
        key: isActive ? const Key('current-section-card') : Key('section-card-$index'),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: isActive
              ? sectionColor.withValues(alpha: 0.22)
              : sectionColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? borderColor : borderColor.withValues(alpha: 0.5),
            width: isActive ? 2.5 : 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de la sección
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? sectionColor : sectionColor.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(SectionStyle.icon(type), color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    section.displayTitle,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: textColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'En curso (${section.bars} compases)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${section.bars} compases',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),

            // Contenido de la sección: acordes y letras
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in section.lines) ...[
                    _buildLineWithChords(line, theme, isActive),
                    const SizedBox(height: 12),
                  ],
                  if (section.lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          '[Instrumental - ${section.bars} compases]',
                          style: TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineWithChords(SongLine line, ThemeData theme, bool isSectionActive) {
    final chords = line.chords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chords.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: chords.map((c) {
              final isThisChordActive =
                  isSectionActive && _state.isPlaying && _state.activeChord == c.chord;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isThisChordActive
                      ? Colors.amber.shade700.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isThisChordActive
                      ? Border.all(color: Colors.amber.shade700, width: 1.8)
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

  Widget _buildControlBar(ThemeData theme) {
    return Container(
      key: const Key('rehearsal-control-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón sección anterior
          IconButton(
            key: const Key('prev-section-button'),
            tooltip: 'Sección anterior',
            icon: const Icon(Icons.skip_previous, size: 28),
            onPressed: () {
              _controller.goToPreviousSection();
              _scrollToSection(_controller.sectionIndex);
            },
          ),

          // Botón Play / Pause principal
          FilledButton.icon(
            key: const Key('rehearsal-play-pause-button'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor:
                  _state.isPlaying ? Colors.red.shade700 : theme.colorScheme.primary,
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
            onPressed: () {
              _controller.goToNextSection();
              _scrollToSection(_controller.sectionIndex);
            },
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
