import 'package:flutter/material.dart';

import '../../data/song_repository.dart';
import '../../music_engine/chord.dart';

/// A compact, touch-friendly editor for chord placements over lyric lines.
class ChordEditor extends StatefulWidget {
  const ChordEditor({
    super.key,
    required this.lines,
    required this.onChanged,
    this.showHeader = true,
  });

  final List<SongLine> lines;
  final ValueChanged<List<SongLine>> onChanged;
  final bool showHeader;

  @override
  State<ChordEditor> createState() => _ChordEditorState();
}

class _ChordEditorState extends State<ChordEditor> {
  static const _characterWidth = 9.6;
  late List<SongLine> _lines;
  final _undo = <List<SongLine>>[];
  final _redo = <List<SongLine>>[];

  @override
  void initState() {
    super.initState();
    _lines = List.of(widget.lines);
  }

  @override
  void didUpdateWidget(covariant ChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) _lines = List.of(widget.lines);
  }

  List<SongLine> _copyLines() => _lines
      .map(
        (line) => SongLine(
          content: line.content,
          position: line.position,
          chords: List.of(line.chords),
        ),
      )
      .toList();

  void _commit(List<SongLine> next) {
    _undo.add(_copyLines());
    _redo.clear();
    setState(() => _lines = next);
    widget.onChanged(List.unmodifiable(next));
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_copyLines());
    setState(() => _lines = _undo.removeLast());
    widget.onChanged(List.unmodifiable(_lines));
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_copyLines());
    setState(() => _lines = _redo.removeLast());
    widget.onChanged(List.unmodifiable(_lines));
  }

  Future<void> _addAt(int lineIndex, int position) async {
    final value = await _chordDialog(initialPosition: position);
    if (value == null) return;
    final next = _copyLines();
    final chords = [...next[lineIndex].chords, value]
      ..sort((a, b) => a.position.compareTo(b.position));
    next[lineIndex] = SongLine(
      content: next[lineIndex].content,
      position: next[lineIndex].position,
      chords: chords,
    );
    _commit(next);
  }

  Future<void> _editChord(int lineIndex, ChordPlacementData chord) async {
    final value = await _chordDialog(
      initialChord: chord.chord,
      initialPosition: chord.position,
      allowDelete: true,
    );
    if (!mounted || value == null) return;
    final next = _copyLines();
    final chords = next[lineIndex].chords.toList()
      ..removeWhere((item) => item == chord);
    chords.add(value);
    chords.sort((a, b) => a.position.compareTo(b.position));
    next[lineIndex] = SongLine(
      content: next[lineIndex].content,
      position: next[lineIndex].position,
      chords: chords,
    );
    _commit(next);
  }

  Future<ChordPlacementData?> _chordDialog({
    String initialChord = '',
    int initialPosition = 0,
    bool allowDelete = false,
  }) async {
    final chord = TextEditingController(text: initialChord);
    final position = TextEditingController(text: '$initialPosition');
    String? error;
    final result = await showDialog<ChordPlacementData?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(allowDelete ? 'Editar acorde' : 'Agregar acorde'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('chord-input'),
                controller: chord,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Acorde',
                  errorText: error,
                ),
                onChanged: (_) => setDialogState(() => error = null),
              ),
              TextField(
                key: const Key('chord-position-input'),
                controller: position,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Columna'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-chord'),
              onPressed: () {
                final value = chord.text.trim();
                if (Chord.parse(value) == null) {
                  setDialogState(() => error = 'Acorde no válido');
                  return;
                }
                Navigator.pop(
                  context,
                  ChordPlacementData(
                    chord: value,
                    position: int.tryParse(position.text) ?? 0,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  void _moveChord(int fromLine, ChordPlacementData chord, Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalOffset);
    var targetLine = (local.dy / 72).floor().clamp(0, _lines.length - 1);
    final targetColumn = (local.dx / _characterWidth).round().clamp(0, 10000);
    final next = _copyLines();
    next[fromLine] = SongLine(
      content: next[fromLine].content,
      position: next[fromLine].position,
      chords: next[fromLine].chords.where((item) => item != chord).toList(),
    );
    final target = next[targetLine];
    final chords = [
      ...target.chords,
      ChordPlacementData(chord: chord.chord, position: targetColumn),
    ]..sort((a, b) => a.position.compareTo(b.position));
    next[targetLine] = SongLine(
      content: target.content,
      position: target.position,
      chords: chords,
    );
    _commit(next);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showHeader)
        Row(
          children: [
            const Expanded(
              child: Text(
                'Acordes sobre la letra',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              key: const Key('undo-chord-edit'),
              tooltip: 'Deshacer',
              onPressed: _undo.isEmpty ? null : _undoEdit,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              key: const Key('redo-chord-edit'),
              tooltip: 'Rehacer',
              onPressed: _redo.isEmpty ? null : _redoEdit,
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
      if (!widget.showHeader)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              key: const Key('undo-chord-edit'),
              tooltip: 'Deshacer',
              onPressed: _undo.isEmpty ? null : _undoEdit,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              key: const Key('redo-chord-edit'),
              tooltip: 'Rehacer',
              onPressed: _redo.isEmpty ? null : _redoEdit,
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
      ...List.generate(_lines.length, (index) {
        final line = _lines[index];
        return DragTarget<_DraggedChord>(
          onAcceptWithDetails: (details) =>
              _moveChord(details.data.line, details.data.chord, details.offset),
          builder: (context, candidate, rejected) => GestureDetector(
            key: Key('chord-line-$index'),
            onTapUp: (details) => _addAt(
              index,
              (details.localPosition.dx / _characterWidth).round().clamp(
                0,
                line.content.length,
              ),
            ),
            child: SizedBox(
              height: 72,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 28,
                    child: Text(
                      line.content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ),
                  for (final chord in line.chords)
                    Positioned(
                      left: chord.position * _characterWidth,
                      top: 2,
                      child: Dismissible(
                        key: ValueKey(
                          'chord-$index-${chord.chord}-${chord.position}',
                        ),
                        direction: DismissDirection.horizontal,
                        onDismissed: (_) {
                          final next = _copyLines();
                          final chords = next[index].chords.toList()
                            ..remove(chord);
                          next[index] = SongLine(
                            content: line.content,
                            position: line.position,
                            chords: chords,
                          );
                          _commit(next);
                        },
                        child: LongPressDraggable<_DraggedChord>(
                          data: _DraggedChord(index, chord),
                          feedback: Material(
                            color: Colors.transparent,
                            child: Chip(label: Text(chord.chord)),
                          ),
                          child: ActionChip(
                            key: Key('chord-${chord.chord}-${chord.position}'),
                            label: Text(chord.chord),
                            onPressed: () => _editChord(index, chord),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ],
  );
}

class _DraggedChord {
  const _DraggedChord(this.line, this.chord);

  final int line;
  final ChordPlacementData chord;
}
