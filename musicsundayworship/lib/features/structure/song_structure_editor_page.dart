import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';

/// Provides distinct colors and icons for each musical section type.
class SectionStyle {
  const SectionStyle._();

  static Color backgroundColor(SectionType type) => switch (type) {
    SectionType.intro => Colors.teal.shade50,
    SectionType.verso => Colors.blue.shade50,
    SectionType.precoro => Colors.purple.shade50,
    SectionType.coro => Colors.amber.shade50,
    SectionType.puente => Colors.green.shade50,
    SectionType.interludio => Colors.indigo.shade50,
    SectionType.finalSection => Colors.red.shade50,
    SectionType.otro => Colors.grey.shade100,
  };

  static Color borderColor(SectionType type) => switch (type) {
    SectionType.intro => Colors.teal.shade300,
    SectionType.verso => Colors.blue.shade300,
    SectionType.precoro => Colors.purple.shade300,
    SectionType.coro => Colors.amber.shade500,
    SectionType.puente => Colors.green.shade400,
    SectionType.interludio => Colors.indigo.shade300,
    SectionType.finalSection => Colors.red.shade300,
    SectionType.otro => Colors.grey.shade400,
  };

  static Color textColor(SectionType type) => switch (type) {
    SectionType.intro => Colors.teal.shade900,
    SectionType.verso => Colors.blue.shade900,
    SectionType.precoro => Colors.purple.shade900,
    SectionType.coro => Colors.amber.shade900,
    SectionType.puente => Colors.green.shade900,
    SectionType.interludio => Colors.indigo.shade900,
    SectionType.finalSection => Colors.red.shade900,
    SectionType.otro => Colors.grey.shade900,
  };

  static IconData icon(SectionType type) => switch (type) {
    SectionType.intro => Icons.play_circle_outline,
    SectionType.verso => Icons.format_quote,
    SectionType.precoro => Icons.trending_up,
    SectionType.coro => Icons.star_rounded,
    SectionType.puente => Icons.wb_sunny_outlined,
    SectionType.interludio => Icons.music_note,
    SectionType.finalSection => Icons.flag_outlined,
    SectionType.otro => Icons.label_outline,
  };
}

/// Interactive screen to reorder sections with drag & drop and adjust repetitions.
class SongStructureEditorPage extends ConsumerStatefulWidget {
  const SongStructureEditorPage({
    super.key,
    required this.song,
    this.initialStructure,
    this.onStructureSaved,
  });

  final SongDocument song;
  final SongStructure? initialStructure;
  final ValueChanged<SongStructure>? onStructureSaved;

  @override
  ConsumerState<SongStructureEditorPage> createState() =>
      _SongStructureEditorPageState();
}

class _SongStructureEditorPageState
    extends ConsumerState<SongStructureEditorPage> {
  late final TextEditingController _nameController;
  late List<StructureItem> _items;
  List<SongStructure> _availableStructures = const [];
  SongStructure? _selectedStructure;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeStructure(widget.initialStructure);
    _loadAllStructures();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initializeStructure(SongStructure? structure) {
    if (structure != null) {
      _selectedStructure = structure;
      _nameController = TextEditingController(text: structure.name);
      _items = List<StructureItem>.from(structure.items);
    } else {
      // Build default structure from song sections
      final defaultItems = <StructureItem>[];
      if (widget.song.sections.isNotEmpty) {
        for (var i = 0; i < widget.song.sections.length; i++) {
          final sec = widget.song.sections[i];
          defaultItems.add(
            StructureItem(
              id: 'sec_${sec.position}_$i',
              type: SectionType.fromString(sec.name),
              name: sec.name.trim().isEmpty ? 'Sección ${i + 1}' : sec.name,
              repeatCount: 1,
            ),
          );
        }
      } else {
        defaultItems.addAll([
          const StructureItem(
            id: 'init_intro',
            type: SectionType.intro,
            name: 'Intro',
            repeatCount: 1,
          ),
          const StructureItem(
            id: 'init_verso',
            type: SectionType.verso,
            name: 'Verso 1',
            repeatCount: 1,
          ),
          const StructureItem(
            id: 'init_coro',
            type: SectionType.coro,
            name: 'Coro',
            repeatCount: 2,
          ),
        ]);
      }

      _nameController = TextEditingController(text: 'Estructura Estándar');
      _items = defaultItems;
    }
  }

  Future<void> _loadAllStructures() async {
    final songId = widget.song.id;
    if (songId == null) return;
    try {
      final repo = ref.read(songRepositoryProvider);
      final structures = await repo.readStructures(songId);
      if (!mounted) return;
      setState(() {
        _availableStructures = structures;
      });
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _updateRepeatCount(int index, int newCount) {
    if (newCount < 1 || newCount > 99) return;
    setState(() {
      _items[index] = _items[index].copyWith(repeatCount: newCount);
    });
  }

  void _addSection(SectionType type) {
    setState(() {
      final count = _items.where((i) => i.type == type).length + 1;
      final name = type == SectionType.verso || type == SectionType.puente
          ? '${type.displayName} $count'
          : type.displayName;

      _items.add(
        StructureItem(
          id: 'item_${DateTime.now().millisecondsSinceEpoch}',
          type: type,
          name: name,
          repeatCount: 1,
        ),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _duplicateStructure() async {
    final newName = '${_nameController.text.trim()} (Copia)';
    setState(() {
      _selectedStructure = null;
      _nameController.text = newName;
      _items = _items
          .map(
            (i) => i.copyWith(
              id: 'copy_${DateTime.now().microsecondsSinceEpoch}_${i.id}',
            ),
          )
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estructura duplicada como "$newName"'),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  Future<void> _saveStructure() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ingresa un nombre para la estructura');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Agrega al menos una sección');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(songRepositoryProvider);
      final structure = SongStructure(
        id: _selectedStructure?.id,
        songId: widget.song.id,
        name: name,
        items: List<StructureItem>.from(_items),
        isDefault: _selectedStructure?.isDefault ?? false,
      );

      final saved = structure.id != null
          ? await repo.updateStructure(structure)
          : await repo.createStructure(structure);

      widget.onStructureSaved?.call(saved);

      if (!mounted) return;
      setState(() {
        _saving = false;
        _selectedStructure = saved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estructura "${saved.name}" guardada exitosamente'),
          backgroundColor: Colors.green.shade800,
        ),
      );

      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Error al guardar estructura: $e';
      });
    }
  }

  Future<void> _showSuggestStructureDialog() async {
    final buffer = StringBuffer();
    for (final sec in widget.song.sections) {
      buffer.writeln(sec.name);
      for (final line in sec.lines) {
        if (line.chords.isNotEmpty) {
          final chordRow = StringBuffer();
          for (final c in line.chords) {
            if (chordRow.length < c.position) {
              chordRow.write(' ' * (c.position - chordRow.length));
            }
            chordRow.write(c.chord);
          }
          buffer.writeln(chordRow.toString());
        }
        buffer.writeln(line.content);
      }
      buffer.writeln();
    }

    final lyricsController = TextEditingController(
      text: buffer.toString().trim(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final proposal = LyricsStructureSuggester.suggestFromText(
              lyricsController.text,
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Estructura propuesta desde la letra',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('close-suggestion-modal'),
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pega o edita la letra para detectar automáticamente estrofas, coros, pre-coros y puentes.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('suggestion-lyrics-input'),
                      controller: lyricsController,
                      minLines: 4,
                      maxLines: 8,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Letra a analizar',
                        hintText: 'Pega aquí la letra o acordes...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (proposal.items.isNotEmpty) ...[
                      Container(
                        key: const Key('proposal-summary-card'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb,
                                  size: 16,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    proposal.explanation,
                                    key: const Key('proposal-explanation-text'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.deepPurple.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              key: const Key('proposal-preview-chips'),
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final it in proposal.items)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        SectionStyle.backgroundColor(it.type),
                                    side: BorderSide(
                                      color: SectionStyle.borderColor(it.type),
                                    ),
                                    avatar: Icon(
                                      SectionStyle.icon(it.type),
                                      size: 14,
                                      color: SectionStyle.textColor(it.type),
                                    ),
                                    label: Text(
                                      it.name,
                                      style: TextStyle(
                                        color: SectionStyle.textColor(it.type),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          proposal.explanation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: const Key('discard-suggestion-button'),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          child: const Text('Descartar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('apply-suggestion-button'),
                          icon: const Icon(Icons.check),
                          label: const Text('Aplicar estructura'),
                          onPressed: proposal.items.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _items = List<StructureItem>.from(
                                      proposal.items,
                                    );
                                  });
                                  Navigator.pop(bottomSheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Estructura aplicada (${proposal.items.length} secciones). Guarda para persistir.',
                                      ),
                                      backgroundColor:
                                          Colors.deepPurple.shade800,
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStructure = SongStructure(
      name: _nameController.text.trim(),
      items: _items,
    );
    final expandedSections = currentStructure.expand();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de estructura'),
        actions: [
          IconButton(
            key: const Key('suggest-structure-button'),
            tooltip: 'Sugerir estructura desde letra',
            onPressed: _showSuggestStructureDialog,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            key: const Key('duplicate-structure-button'),
            tooltip: 'Duplicar versión',
            onPressed: _duplicateStructure,
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            key: const Key('save-structure-button'),
            tooltip: 'Guardar estructura',
            onPressed: _saving ? null : _saveStructure,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header: Song title, Structure name & version switch
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('structure-name-field'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la versión de estructura',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.folder_special, size: 20),
                        ),
                      ),
                    ),
                    if (_availableStructures.length > 1) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<SongStructure>(
                        tooltip: 'Cambiar de versión',
                        icon: const Icon(Icons.swap_horiz),
                        onSelected: (structure) {
                          setState(() {
                            _selectedStructure = structure;
                            _nameController.text = structure.name;
                            _items = List<StructureItem>.from(structure.items);
                          });
                        },
                        itemBuilder: (context) => [
                          for (final s in _availableStructures)
                            PopupMenuItem(
                              value: s,
                              child: Text(s.name),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          // Live Expanded Sequence Preview Card
          Container(
            key: const Key('expanded-sequence-preview'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.playlist_play, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Secuencia expandida (${expandedSections.length} bloques):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < expandedSections.length; i++) ...[
                        _buildPreviewChip(expandedSections[i]),
                        if (i < expandedSections.length - 1)
                          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Add section quick bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Text('Agregar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          key: const Key('suggest-from-lyrics-chip'),
                          avatar: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.deepPurple,
                          ),
                          label: const Text(
                            'Sugerir de letra',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.deepPurple.shade50,
                          side: BorderSide(color: Colors.deepPurple.shade200),
                          visualDensity: VisualDensity.compact,
                          onPressed: _showSuggestStructureDialog,
                        ),
                        const SizedBox(width: 8),
                        _buildAddButton(SectionType.intro),
                        _buildAddButton(SectionType.verso),
                        _buildAddButton(SectionType.precoro),
                        _buildAddButton(SectionType.coro),
                        _buildAddButton(SectionType.puente),
                        _buildAddButton(SectionType.interludio),
                        _buildAddButton(SectionType.finalSection),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Reorderable list of sections with repeat controls and color coding
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reorder, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No hay secciones en la estructura.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        const Text('Usa los botones de arriba para agregar.'),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    // ignore: deprecated_member_use
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildStructureCard(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewChip(StructureItem item) {
    final bgColor = SectionStyle.backgroundColor(item.type);
    final txtColor = SectionStyle.textColor(item.type);
    final borderColor = SectionStyle.borderColor(item.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        item.name,
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildAddButton(SectionType type) {
    final keyName = type.name.toLowerCase();
    final borderColor = SectionStyle.borderColor(type);
    final bgColor = SectionStyle.backgroundColor(type);
    final textColor = SectionStyle.textColor(type);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        key: Key('add-section-$keyName'),
        avatar: Icon(SectionStyle.icon(type), size: 14, color: textColor),
        label: Text(type.displayName, style: TextStyle(color: textColor, fontSize: 12)),
        backgroundColor: bgColor,
        side: BorderSide(color: borderColor),
        visualDensity: VisualDensity.compact,
        onPressed: () => _addSection(type),
      ),
    );
  }

  Widget _buildStructureCard(StructureItem item, int index) {
    final bgColor = SectionStyle.backgroundColor(item.type);
    final borderColor = SectionStyle.borderColor(item.type);
    final textColor = SectionStyle.textColor(item.type);

    return Card(
      key: ValueKey(item.id),
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Drag handle indicator
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),

            // Section type icon
            Icon(SectionStyle.icon(item.type), color: textColor, size: 20),
            const SizedBox(width: 8),

            // Section name & label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  Text(
                    item.type.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Repetition Controls: [-] [x3] [+]
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('decrement-repeat-$index'),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Reducir repetición',
                    icon: const Icon(Icons.remove),
                    onPressed: item.repeatCount > 1
                        ? () => _updateRepeatCount(index, item.repeatCount - 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'x${item.repeatCount}',
                      key: Key('repeat-count-$index'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('increment-repeat-$index'),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Aumentar repetición',
                    icon: const Icon(Icons.add),
                    onPressed: item.repeatCount < 99
                        ? () => _updateRepeatCount(index, item.repeatCount + 1)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            // Delete item button
            IconButton(
              key: Key('delete-item-$index'),
              iconSize: 20,
              color: Colors.red.shade400,
              tooltip: 'Eliminar sección',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }
}
