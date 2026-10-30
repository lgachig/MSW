import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import 'song_editor_page.dart';

class ArrangementEditorPage extends ConsumerStatefulWidget {
  const ArrangementEditorPage({
    super.key,
    required this.songId,
    required this.initialName,
    required this.sections,
    this.arrangementId,
  });

  final int songId;
  final int? arrangementId;
  final String initialName;
  final List<SongSection> sections;

  @override
  ConsumerState<ArrangementEditorPage> createState() =>
      _ArrangementEditorPageState();
}

class _ArrangementEditorPageState extends ConsumerState<ArrangementEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _content = TextEditingController(
      text: SongTextParser.format(widget.sections),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa un nombre y contenido');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(songRepositoryProvider);
    final value = SongArrangement(
      id: widget.arrangementId,
      songId: widget.songId,
      name: name,
      sections: SongTextParser.parse(_content.text),
    );
    try {
      final saved = widget.arrangementId == null
          ? await repository.createArrangement(value)
          : await repository.updateArrangement(value);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el arreglo: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.arrangementId == null ? 'Nuevo arreglo' : 'Editar arreglo',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre del arreglo'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _content,
          minLines: 16,
          maxLines: 28,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'Letra y acordes',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, key: const Key('arrangement-save-error')),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_saving ? 'Guardando…' : 'Guardar arreglo'),
        ),
      ],
    ),
  );
}
