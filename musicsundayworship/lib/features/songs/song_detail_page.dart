import 'package:flutter/material.dart';

import '../../data/song_repository.dart';
import '../../music_engine/music_engine.dart';

class SongDetailPage extends StatefulWidget {
  const SongDetailPage({super.key, required this.song});

  final SongDocument song;

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  NoteNotation _notation = NoteNotation.american;
  int _semitones = 0;
  MusicKey? _targetKey;

  String get _originalKey => widget.song.originalKey ?? '—';

  MusicKey? get _sourceKey => MusicKey.parse(widget.song.originalKey ?? '');

  String get _currentKey {
    final source = _sourceKey;
    if (source == null) return _originalKey;
    final key = _transposedKey(source, _semitones);
    return _notation == NoteNotation.latin
        ? key.tonic.toLatin().toString()
        : key.toString();
  }

  MusicKey _transposedKey(MusicKey source, int semitones) {
    final chord = Transposer.transpose(Chord(root: source.tonic), semitones);
    return MusicKey(chord.root);
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
    appBar: AppBar(title: Text(widget.song.title)),
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
        ...widget.song.sections.expand(
          (section) => section.lines.map(_buildLine),
        ),
      ],
    ),
  );

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
