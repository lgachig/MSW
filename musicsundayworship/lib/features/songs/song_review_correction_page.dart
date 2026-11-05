import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_key_detector.dart';
import '../capture/offline_photo_queue.dart';
import '../capture/remote_digitize_service.dart';
import 'song_editor_page.dart';
import 'song_photo_page.dart';

enum ReviewViewMode { split, photoOnly, textOnly }

class SongReviewCorrectionPage extends ConsumerStatefulWidget {
  const SongReviewCorrectionPage({
    super.key,
    required this.imagePath,
    required this.digitizedSong,
    this.songId,
    this.initialSongTitle,
    this.initialAuthor,
    this.initialSource,
    this.queueItemId,
    this.onSongSaved,
  });

  final String imagePath;
  final DigitizedSong digitizedSong;
  final int? songId;
  final String? initialSongTitle;
  final String? initialAuthor;
  final String? initialSource;
  final int? queueItemId;
  final ValueChanged<SongDocument>? onSongSaved;

  @override
  ConsumerState<SongReviewCorrectionPage> createState() =>
      _SongReviewCorrectionPageState();
}

class _SongReviewCorrectionPageState
    extends ConsumerState<SongReviewCorrectionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _sourceController;
  late final TextEditingController _keyController;
  late final TextEditingController _lyricsController;

  ReviewViewMode _viewMode = ReviewViewMode.split;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final song = widget.digitizedSong;

    final title = (song.title?.isNotEmpty ?? false)
        ? song.title!
        : (widget.initialSongTitle?.isNotEmpty ?? false)
            ? widget.initialSongTitle!
            : 'Canción sin título';

    final initialChords = song.chords.map((c) => c.chord).toList();
    final detectedKey = MusicKeyDetector.detectKey(initialChords);
    final key = (song.key?.trim().isNotEmpty ?? false)
        ? song.key!.trim()
        : (detectedKey ?? 'G');

    _titleController = TextEditingController(text: title);
    _authorController = TextEditingController(text: widget.initialAuthor ?? '');
    _sourceController =
        TextEditingController(text: widget.initialSource ?? 'Foto digitalizada');
    _keyController = TextEditingController(text: key);
    _lyricsController = TextEditingController(text: song.chordOverLyricText);

    _keyController.addListener(_onKeyOrLyricsChanged);
    _lyricsController.addListener(_onKeyOrLyricsChanged);
  }

  void _onKeyOrLyricsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _keyController.removeListener(_onKeyOrLyricsChanged);
    _lyricsController.removeListener(_onKeyOrLyricsChanged);
    _titleController.dispose();
    _authorController.dispose();
    _sourceController.dispose();
    _keyController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  bool _isLocalFile(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmAndSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('confirm-save-dialog'),
        title: const Text('¿Confirmar y guardar canción?'),
        content: Text(
          '¿Deseas guardar "${_titleController.text.trim()}" en tu biblioteca con las correcciones realizadas?',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-confirm-save'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-save-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repository = ref.read(songRepositoryProvider);
      final sections = SongTextParser.parse(_lyricsController.text);

      final document = SongDocument(
        id: widget.songId,
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        source: _sourceController.text.trim().isEmpty
            ? null
            : _sourceController.text.trim(),
        originalKey: _keyController.text.trim().isEmpty
            ? null
            : _keyController.text.trim(),
        sections: sections,
      );

      final saved = widget.songId != null
          ? await repository.update(document)
          : await repository.create(document);

      if (widget.queueItemId != null) {
        await ref
            .read(photoQueueRepositoryProvider)
            .delete(widget.queueItemId!);
      }

      widget.onSongSaved?.call(saved);

      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Canción "${saved.title}" guardada exitosamente'),
          backgroundColor: Colors.green.shade800,
        ),
      );

      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Error al guardar canción: $e';
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('confirm-discard-dialog'),
        title: const Text('¿Descartar correcciones?'),
        content: const Text(
          'Se descartarán los cambios y no se guardará nada en la biblioteca.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-discard-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            key: const Key('confirm-discard-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isWide = mediaWidth >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión y corrección'),
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildPhotoPanel(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: _buildEditorPanel(),
                  ),
                ],
              )
            : _buildMobileLayout(),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildMobileLayout() {
    Widget content;
    switch (_viewMode) {
      case ReviewViewMode.photoOnly:
        content = Expanded(child: _buildPhotoPanel());
      case ReviewViewMode.textOnly:
        content = Expanded(child: _buildEditorPanel());
      case ReviewViewMode.split:
        content = Expanded(
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: _buildPhotoPanel(),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 6,
                child: _buildEditorPanel(),
              ),
            ],
          ),
        );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ReviewViewMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: ReviewViewMode.split,
                  icon: Icon(Icons.vertical_split, size: 16),
                  label: Text('Lado a lado'),
                ),
                ButtonSegment(
                  value: ReviewViewMode.photoOnly,
                  icon: Icon(Icons.image, size: 16),
                  label: Text('Foto'),
                ),
                ButtonSegment(
                  value: ReviewViewMode.textOnly,
                  icon: Icon(Icons.edit_note, size: 16),
                  label: Text('Texto'),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (set) {
                setState(() => _viewMode = set.first);
              },
            ),
          ),
        ),
        const Divider(height: 1),
        content,
      ],
    );
  }

  Widget _buildPhotoPanel() {
    final exists = _isLocalFile(widget.imagePath);

    return Container(
      color: Colors.black.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Foto original (usa zoom para comparar)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Chip(
                  label: const Text('Foto fuente'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
          ),
          Expanded(
            child: exists
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        File(widget.imagePath),
                        key: const Key('review-original-photo'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Vista previa de foto: ${widget.imagePath}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<String> _extractCurrentChords() {
    final parsed = SongTextParser.parse(_lyricsController.text);
    final chords = <String>[];
    for (final s in parsed) {
      for (final l in s.lines) {
        for (final c in l.chords) {
          chords.add(c.chord);
        }
      }
    }
    if (chords.isEmpty) {
      return widget.digitizedSong.chords.map((c) => c.chord).toList();
    }
    return chords;
  }

  Widget _buildTonalitySection() {
    final chords = _extractCurrentChords();
    final verification = MusicKeyDetector.verifyKey(
      _keyController.text.trim(),
      chords,
    );

    final isMatching = verification.matchesCurrentKey;
    const primaryKeys = [
      'C', 'D', 'E', 'F', 'G', 'A', 'B',
      'Am', 'Em', 'Bm', 'Dm', 'F#m'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Tono *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Chip(
              key: const Key('ai-badge-key'),
              avatar: Icon(
                isMatching ? Icons.check_circle : Icons.auto_awesome,
                size: 14,
                color: isMatching ? Colors.green.shade800 : Colors.blue.shade800,
              ),
              label: Text(
                isMatching ? 'Armonía verificada' : 'IA / Armonía',
                style: TextStyle(
                  color: isMatching ? Colors.green.shade900 : Colors.blue.shade900,
                  fontSize: 12,
                ),
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor:
                  isMatching ? Colors.green.shade100 : Colors.blue.shade100,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                key: const Key('review-key-field'),
                controller: _keyController,
                decoration: const InputDecoration(
                  hintText: 'Ej. G, Am, C#',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.music_note, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa el tono' : null,
              ),
            ),
            if (!isMatching) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: FilledButton.tonalIcon(
                  key: const Key('apply-detected-key-button'),
                  onPressed: () {
                    _keyController.text = verification.detectedKey;
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text('Usar ${verification.detectedKey}'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          key: Key(
            isMatching ? 'tonality-verified-badge' : 'tonality-warning-badge',
          ),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMatching ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isMatching ? Colors.green.shade300 : Colors.amber.shade400,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isMatching ? Icons.check_circle : Icons.warning_amber_rounded,
                color:
                    isMatching ? Colors.green.shade700 : Colors.amber.shade900,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMatching
                          ? 'Tonalidad armónica: ${_keyController.text.trim()}'
                          : 'Tonalidad sugerida: ${verification.detectedKey}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isMatching
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      verification.explanation,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMatching
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Cambiar tonalidad rápidamente:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in primaryKeys) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('quick-key-chip-$k'),
                    label: Text(k),
                    selected: _keyController.text.trim().toUpperCase() ==
                        k.toUpperCase(),
                    onSelected: (selected) {
                      if (selected) {
                        _keyController.text = k;
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorPanel() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de sugerencia IA
          Container(
            key: const Key('ai-suggestion-banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resultado sugerido por IA',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Compara contra la foto, corrige cualquier letra o acorde y confirma para guardar.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Título con etiqueta IA
          Row(
            children: [
              const Text('Título *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Chip(
                key: const Key('ai-badge-title'),
                avatar: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Sugerido por IA'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.blue.shade100,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('review-title-field'),
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Ingresa el título de la canción',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Ingresa el título' : null,
          ),
          const SizedBox(height: 16),

          // Tono y Validación con análisis armónico
          _buildTonalitySection(),
          const SizedBox(height: 16),

          // Autor
          const Text('Autor', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('review-author-field'),
            controller: _authorController,
            decoration: const InputDecoration(
              hintText: 'Ej. Marcos Witt',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Fuente
          const Text('Fuente', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('review-source-field'),
            controller: _sourceController,
            decoration: const InputDecoration(
              hintText: 'Ej. Himnario, Álbum',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Resumen de acordes sugeridos por IA
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Acordes sugeridos por IA',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        key: const Key('ai-chords-badge'),
                        label: Text('${widget.digitizedSong.chordCount} acordes'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.blue.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DigitizedSongChordReview(song: widget.digitizedSong),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Editor de Letra y acordes
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Letra y acordes (editable)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Chip(
                key: const Key('ai-badge-lyrics'),
                avatar: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Texto IA'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.blue.shade100,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('review-lyrics-field'),
            controller: _lyricsController,
            minLines: 12,
            maxLines: 24,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Text(
              _saveError!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            key: const Key('discard-button'),
            onPressed: _saving ? null : _confirmDiscard,
            icon: const Icon(Icons.close),
            label: const Text('Descartar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            key: const Key('save-button'),
            onPressed: _saving ? null : _confirmAndSave,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Guardando...' : 'Aceptar y Guardar'),
          ),
        ],
      ),
    );
  }
}
