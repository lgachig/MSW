import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';
import '../structure/song_structure_editor_page.dart';
import 'arrangement_editor_page.dart';
import 'song_photo_page.dart';

class SongDetailPage extends ConsumerStatefulWidget {
  const SongDetailPage({super.key, required this.song});

  final SongDocument song;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  NoteNotation _notation = NoteNotation.american;
  int _semitones = 0;
  MusicKey? _targetKey;
  List<SongArrangement> _arrangements = const [];
  SongArrangement? _selectedArrangement;
  List<SongStructure> _structures = const [];
  SongStructure? _selectedStructure;

  @override
  void initState() {
    super.initState();
    _loadArrangements();
    _loadStructures();
  }

  Future<void> _loadArrangements() async {
    final id = widget.song.id;
    if (id == null) return;
    final arrangements = await ref
        .read(songRepositoryProvider)
        .readArrangements(id);
    if (!mounted) return;
    setState(() => _arrangements = arrangements);
  }

  Future<void> _loadStructures() async {
    final id = widget.song.id;
    if (id == null) return;
    try {
      final structures = await ref
          .read(songRepositoryProvider)
          .readStructures(id);
      if (!mounted) return;
      setState(() {
        _structures = structures;
        if (_selectedStructure == null && structures.isNotEmpty) {
          _selectedStructure = structures.firstWhere(
            (s) => s.isDefault,
            orElse: () => structures.first,
          );
        }
      });
    } catch (_) {}
  }

  List<SongSection> get _sections =>
      _selectedArrangement?.sections ?? widget.song.sections;

  String get _originalKey => widget.song.originalKey ?? '—';

  Chord? get _sourceChord => Chord.parse(widget.song.originalKey ?? '');

  MusicKey? get _sourceKey {
    final chord = _sourceChord;
    return chord == null ? null : MusicKey(chord.root);
  }

  String get _currentKey {
    final source = _sourceChord;
    if (source == null) return _originalKey;
    return _renderChord(source, _semitones);
  }

  void _setSemitones(int value) {
    setState(() {
      _semitones = (value % 12 + 12) % 12;
      _targetKey = null;
    });
  }

  void _setTargetKey(MusicKey? key) {
    final source = _sourceKey;
    if (source == null || key == null) return;
    setState(() {
      _targetKey = key;
      _semitones = source.semitonesTo(key);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.song.title),
      actions: [
        IconButton(
          key: const Key('edit-structure'),
          tooltip: 'Estructura y repeticiones',
          onPressed: _openStructureEditor,
          icon: const Icon(Icons.reorder),
        ),
        IconButton(
          key: const Key('new-arrangement'),
          tooltip: 'Crear arreglo',
          onPressed: () => _createArrangement(_selectedArrangement),
          icon: const Icon(Icons.copy),
        ),
        IconButton(
          key: const Key('song-photo'),
          tooltip: 'Capturar foto para digitalizar',
          onPressed: _editPhoto,
          icon: const Icon(Icons.photo_camera),
        ),
        if (widget.song.id != null)
          IconButton(
            key: const Key('delete-song'),
            tooltip: 'Eliminar canción',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDeleteSong,
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.song.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (widget.song.author != null)
          Text(
            widget.song.author!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('Tono original: $_originalKey'),
                    Text(
                      'Tono actual: $_currentKey',
                      key: const Key('current-key'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      key: const Key('transpose-down'),
                      tooltip: 'Bajar semitono',
                      onPressed: () => _setSemitones(_semitones - 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    Expanded(
                      child: Text(
                        '$_semitones semitonos',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      key: const Key('transpose-up'),
                      tooltip: 'Subir semitono',
                      onPressed: () => _setSemitones(_semitones + 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
                DropdownButton<MusicKey>(
                  key: const Key('target-key'),
                  isExpanded: true,
                  value: _targetKey,
                  hint: const Text('Elegir tono destino'),
                  items: _targetKeys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(key.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: _setTargetKey,
                ),
                SegmentedButton<NoteNotation>(
                  key: const Key('notation-toggle'),
                  segments: const [
                    ButtonSegment(
                      value: NoteNotation.american,
                      label: Text('Americana'),
                    ),
                    ButtonSegment(
                      value: NoteNotation.latin,
                      label: Text('Latina'),
                    ),
                  ],
                  selected: {_notation},
                  onSelectionChanged: (value) =>
                      setState(() => _notation = value.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_arrangements.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<SongArrangement?>(
                      key: const Key('arrangement-selector'),
                      isExpanded: true,
                      value: _selectedArrangement,
                      hint: const Text('Versión original'),
                      items: [
                        const DropdownMenuItem<SongArrangement?>(
                          child: Text('Versión original'),
                        ),
                        ..._arrangements.map(
                          (arrangement) => DropdownMenuItem<SongArrangement?>(
                            value: arrangement,
                            child: Text(arrangement.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedArrangement = value),
                    ),
                  ),
                  if (_selectedArrangement != null)
                    IconButton(
                      key: const Key('edit-arrangement'),
                      tooltip: 'Editar arreglo',
                      onPressed: () => _editArrangement(_selectedArrangement!),
                      icon: const Icon(Icons.edit),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (_selectedStructure != null) ...[
          Card(
            key: const Key('song-structure-card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reorder, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _structures.length > 1
                            ? DropdownButton<SongStructure>(
                                isExpanded: true,
                                value: _selectedStructure,
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final s in _structures)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        'Estructura: ${s.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _selectedStructure = value;
                                }),
                              )
                            : Text(
                                'Estructura: ${_selectedStructure!.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      IconButton(
                        key: const Key('edit-current-structure'),
                        tooltip: 'Editar estructura',
                        iconSize: 18,
                        onPressed: _openStructureEditor,
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final item in _selectedStructure!.items)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: SectionStyle.backgroundColor(item.type),
                          side: BorderSide(color: SectionStyle.borderColor(item.type)),
                          label: Text(
                            item.repeatCount > 1
                                ? '${item.name} (${item.repeatCount}x)'
                                : item.name,
                            style: TextStyle(
                              color: SectionStyle.textColor(item.type),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final section in _sections)
          _buildSectionCard(section),
      ],
    ),
  );

  Future<void> _openStructureEditor() async {
    final saved = await Navigator.of(context).push<SongStructure>(
      MaterialPageRoute(
        builder: (_) => SongStructureEditorPage(
          song: widget.song,
          initialStructure: _selectedStructure,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    await _loadStructures();
    setState(() {
      _selectedStructure = saved;
    });
  }

  Future<void> _createArrangement(SongArrangement? source) async {
    final id = widget.song.id;
    if (id == null) return;
    final saved = await Navigator.of(context).push<SongArrangement>(
      MaterialPageRoute(
        builder: (_) => ArrangementEditorPage(
          songId: id,
          initialName: 'Arreglo ${_arrangements.length + 1}',
          sections: source?.sections ?? widget.song.sections,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    setState(() {
      _arrangements = [..._arrangements, saved];
      _selectedArrangement = saved;
    });
  }

  Future<void> _editPhoto() async {
    final id = widget.song.id;
    if (id == null) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SongPhotoPage(
          songId: id,
          songTitle: widget.song.title,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSong() async {
    final id = widget.song.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar canción?'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${widget.song.title}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-delete-song-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-delete-song-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(songRepositoryProvider).delete(id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canción "${widget.song.title}" eliminada'),
          ),
        );
      }
    }
  }

  Future<void> _editArrangement(SongArrangement arrangement) async {
    final saved = await Navigator.of(context).push<SongArrangement>(
      MaterialPageRoute(
        builder: (_) => ArrangementEditorPage(
          songId: arrangement.songId,
          arrangementId: arrangement.id,
          initialName: arrangement.name,
          sections: arrangement.sections,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    setState(() {
      _arrangements = [
        for (final item in _arrangements)
          if (item.id == saved.id) saved else item,
      ];
      _selectedArrangement = saved;
    });
  }

  Widget _buildSectionCard(SongSection section) {
    final headerInfo = LyricsStructureSuggester.matchHeader(section.name);
    final displayName = headerInfo?.rawName ??
        (section.name.trim().isEmpty ? 'Sección' : section.name);
    final type = headerInfo?.type ?? SectionType.fromString(section.name);
    final borderColor = SectionStyle.borderColor(type);
    final bgColor = SectionStyle.backgroundColor(type);
    final textColor = SectionStyle.textColor(type);

    return Container(
      key: Key('section-card-${section.position}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(SectionStyle.icon(type), size: 16, color: textColor),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: section.lines.map(_buildLine).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(SongLine line) {
    final chordLine = _formatChords(line.chords);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chordLine.isNotEmpty)
            Text(
              chordLine,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(line.content, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  String _formatChords(List<ChordPlacementData> chords) {
    final buffer = StringBuffer();
    for (final placement in chords) {
      final chord = Chord.parse(placement.chord);
      final rendered = chord == null
          ? placement.chord
          : _renderChord(chord, _semitones);
      final position = placement.position;
      if (buffer.length < position) {
        buffer.write(' ' * (position - buffer.length));
      }
      if (buffer.length > position) buffer.write(' ');
      buffer.write(rendered);
    }
    return buffer.toString();
  }

  String _renderChord(Chord chord, int semitones) {
    final transposed = Transposer.transpose(
      chord,
      semitones,
      targetKey: _targetKey,
    );
    final rendered = _notation == NoteNotation.latin
        ? transposed.toLatin()
        : transposed.toAmerican();
    return rendered.toString();
  }
}

const _targetKeys = [
  MusicKey(NoteName('C')),
  MusicKey(NoteName('D', accidental: 'b')),
  MusicKey(NoteName('D')),
  MusicKey(NoteName('E', accidental: 'b')),
  MusicKey(NoteName('E')),
  MusicKey(NoteName('F')),
  MusicKey(NoteName('G', accidental: 'b')),
  MusicKey(NoteName('G')),
  MusicKey(NoteName('A', accidental: 'b')),
  MusicKey(NoteName('A')),
  MusicKey(NoteName('B', accidental: 'b')),
  MusicKey(NoteName('B')),
];
