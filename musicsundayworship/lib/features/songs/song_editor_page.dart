import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/chord_line_detector.dart';
import 'chord_editor.dart';

/// Converts pasted chord-over-lyric text into the ordered song model.
class SongTextParser {
  const SongTextParser._();

  static List<SongSection> parse(String text) {
    final sections = <SongSection>[];
    final blocks = text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    for (var sectionIndex = 0; sectionIndex < blocks.length; sectionIndex++) {
      final lines = <SongLine>[];
      final pending = <ChordPlacementData>[];
      final sourceLines = blocks[sectionIndex].split('\n');
      for (final sourceLine in sourceLines) {
        final result = ChordLineDetector.detect(sourceLine);
        if (result.isChordLine) {
          pending
            ..clear()
            ..addAll(_placementsForChordLine(sourceLine, result));
        } else if (sourceLine.trim().isNotEmpty || pending.isNotEmpty) {
          lines.add(
            SongLine(
              content: sourceLine,
              position: lines.length,
              chords: List.unmodifiable(pending),
            ),
          );
          pending.clear();
        }
      }
      if (pending.isNotEmpty) {
        lines.add(
          SongLine(
            content: '',
            position: lines.length,
            chords: List.unmodifiable(pending),
          ),
        );
      }
      if (lines.isNotEmpty) {
        sections.add(
          SongSection(
            name: 'Sección ${sections.length + 1}',
            position: sections.length,
            lines: List.unmodifiable(lines),
          ),
        );
      }
    }
    return List.unmodifiable(sections);
  }

  static List<ChordPlacementData> _placementsForChordLine(
    String sourceLine,
    ChordLineResult result,
  ) {
    final validPositions = {for (final token in result.tokens) token.start};
    final placements = <ChordPlacementData>[];
    final tokenPattern = RegExp(r'[^\s|–—-]+');
    for (final match in tokenPattern.allMatches(sourceLine)) {
      final text = match.group(0)!;
      final position = match.start;
      if (validPositions.contains(position) || _isStandalonePunctuation(text)) {
        placements.add(ChordPlacementData(chord: text, position: position));
      }
    }
    return placements;
  }

  static bool _isStandalonePunctuation(String value) =>
      RegExp(r'^[^A-Za-zÁÉÍÓÚáéíóúÑñ0-9]+$').hasMatch(value);

  static String format(List<SongSection> sections) => sections
      .expand(
        (section) => section.lines.expand(
          (line) => [
            if (line.chords.isNotEmpty) _formatChordLine(line.chords),
            line.content,
          ],
        ),
      )
      .join('\n');

  static String _formatChordLine(List<ChordPlacementData> chords) {
    final buffer = StringBuffer();
    for (final chord in chords) {
      final position = chord.position.clamp(0, 100000);
      if (buffer.length < position) {
        buffer.write(' ' * (position - buffer.length));
      }
      if (buffer.length > position) {
        buffer.write(' ');
      }
      buffer.write(chord.chord);
    }
    return buffer.toString();
  }
}

class SongEditorPage extends ConsumerStatefulWidget {
  const SongEditorPage({super.key, this.songId});

  final int? songId;

  @override
  ConsumerState<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends ConsumerState<SongEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _source = TextEditingController();
  final _key = TextEditingController();
  final _tempo = TextEditingController();
  final _timeSignature = TextEditingController();
  final _lyrics = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  String? _saveError;
  SongDocument? _song;
  List<SongSection>? _editorSections;

  bool get editing => widget.songId != null;

  @override
  void initState() {
    super.initState();
    if (widget.songId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final song = await ref.read(songRepositoryProvider).read(widget.songId!);
    if (!mounted) return;
    if (song != null) {
      _song = song;
      _title.text = song.title;
      _author.text = song.author ?? '';
      _source.text = song.source ?? '';
      _key.text = song.originalKey ?? '';
      _tempo.text = song.tempo?.toString() ?? '';
      _timeSignature.text = song.timeSignature ?? '';
      _lyrics.text = _toText(song);
      _editorSections = song.sections;
    }
    setState(() => _loading = false);
  }

  String _toText(SongDocument song) => SongTextParser.format(song.sections);

  String _sectionsToText(List<SongSection> sections) =>
      SongTextParser.format(sections);

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Ingresa $label' : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final song = SongDocument(
      id: _song?.id,
      title: _title.text.trim(),
      author: _optional(_author.text),
      source: _optional(_source.text),
      originalKey: _key.text.trim(),
      tempo: int.tryParse(_tempo.text.trim()),
      timeSignature: _optional(_timeSignature.text),
      sections: _editorSections ?? SongTextParser.parse(_lyrics.text),
    );
    final repository = ref.read(songRepositoryProvider);
    try {
      final saved = editing
          ? await repository.update(song)
          : await repository.create(song);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'No se pudo guardar la canción: $error';
      });
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _author,
      _source,
      _key,
      _tempo,
      _timeSignature,
      _lyrics,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar canción')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar canción' : 'Nueva canción')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (value) => _required(value, 'el título'),
            ),
            TextFormField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Autor'),
            ),
            TextFormField(
              controller: _source,
              decoration: const InputDecoration(labelText: 'Fuente'),
            ),
            TextFormField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Tono *'),
              validator: (value) => _required(value, 'el tono'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tempo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tempo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _timeSignature,
                    decoration: const InputDecoration(labelText: 'Compás'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lyrics,
              minLines: 12,
              maxLines: 20,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Letra y acordes (importar)',
                hintText: 'G        C\nTu amor no cambia',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = SongTextParser.parse(value);
                setState(() => _editorSections = parsed);
              },
            ),
            if (_editorSections
                    ?.expand((section) => section.lines)
                    .isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              ChordEditor(
                lines: _editorSections!
                    .expand((section) => section.lines)
                    .toList(),
                onChanged: (lines) {
                  final sections = [
                    SongSection(
                      name: 'Sección 1',
                      position: 0,
                      lines: lines
                          .asMap()
                          .entries
                          .map(
                            (entry) => SongLine(
                              content: entry.value.content,
                              position: entry.key,
                              chords: entry.value.chords,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ];
                  setState(() {
                    _editorSections = sections;
                    _lyrics.text = _sectionsToText(sections);
                  });
                },
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Guardando…' : 'Guardar canción'),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                key: const Key('song-save-error'),
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
