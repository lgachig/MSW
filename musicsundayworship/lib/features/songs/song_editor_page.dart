import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/chord.dart';
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
        final placements = _parseChordLine(sourceLine);
        if (placements != null) {
          pending
            ..clear()
            ..addAll(placements);
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

  static List<ChordPlacementData>? _parseChordLine(String sourceLine) {
    final tokenPattern = RegExp(r'[^\s|–—-]+');
    final tokens = tokenPattern
        .allMatches(sourceLine)
        .map((match) => (text: match.group(0)!, start: match.start))
        .toList();
    final chordTokens = tokens
        .map((token) => _splitPunctuation(token.text))
        .whereType<_ChordToken>()
        .toList();
    if (chordTokens.isEmpty || chordTokens.length * 2 <= tokens.length) {
      return null;
    }

    final placements = <ChordPlacementData>[];
    for (final token in tokens) {
      final parsed = _splitPunctuation(token.text);
      if (parsed == null) {
        if (_isStandalonePunctuation(token.text)) {
          placements.add(
            ChordPlacementData(chord: token.text, position: token.start),
          );
        }
        continue;
      }
      if (parsed.prefix.isNotEmpty) {
        placements.add(
          ChordPlacementData(chord: parsed.prefix, position: token.start),
        );
      }
      placements.add(
        ChordPlacementData(
          chord: parsed.chord,
          position: token.start + parsed.prefix.length,
        ),
      );
      if (parsed.suffix.isNotEmpty) {
        placements.add(
          ChordPlacementData(
            chord: parsed.suffix,
            position: token.start + parsed.prefix.length + parsed.chord.length,
          ),
        );
      }
    }
    return placements;
  }

  static _ChordToken? _splitPunctuation(String value) {
    for (var start = 0; start < value.length; start++) {
      for (var end = value.length; end > start; end--) {
        final core = value.substring(start, end);
        if (Chord.parse(core) == null) continue;
        final prefix = value.substring(0, start);
        final suffix = value.substring(end);
        if (_isStandalonePunctuation(prefix) &&
            _isStandalonePunctuation(suffix)) {
          return _ChordToken(prefix: prefix, chord: core, suffix: suffix);
        }
      }
    }
    return null;
  }

  static bool _isStandalonePunctuation(String value) =>
      value.isEmpty || RegExp(r'^[^A-Za-zÁÉÍÓÚáéíóúÑñ0-9]+$').hasMatch(value);

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

class _ChordToken {
  const _ChordToken({
    required this.prefix,
    required this.chord,
    required this.suffix,
  });

  final String prefix;
  final String chord;
  final String suffix;
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
  bool _chordEditorDirty = false;

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
      sections: _chordEditorDirty
          ? (_editorSections ?? SongTextParser.parse(_lyrics.text))
          : SongTextParser.parse(_lyrics.text),
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
                setState(() {
                  _editorSections = parsed;
                  _chordEditorDirty = false;
                });
              },
            ),
            if (_editorSections
                    ?.expand((section) => section.lines)
                    .isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Editar acordes'),
                subtitle: const Text('Agregar, mover o borrar acordes'),
                children: [
                  ChordEditor(
                    showHeader: false,
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
                        _chordEditorDirty = true;
                        _lyrics.text = _sectionsToText(sections);
                      });
                    },
                  ),
                ],
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
