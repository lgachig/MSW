import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';

enum LibrarySort { title, author, key, label }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, this.onAddSong});

  final VoidCallback? onAddSong;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';
  String? _keyFilter;
  String? _labelFilter;
  LibrarySort _sort = LibrarySort.title;

  List<SongDocument> _visible(List<SongDocument> songs) {
    final query = _query.trim().toLowerCase();
    final result = songs.where((song) {
      final matchesQuery =
          query.isEmpty ||
          song.title.toLowerCase().contains(query) ||
          (song.author?.toLowerCase().contains(query) ?? false);
      return matchesQuery &&
          (_keyFilter == null || song.originalKey == _keyFilter) &&
          (_labelFilter == null || song.label == _labelFilter);
    }).toList();
    result.sort((a, b) {
      String value(SongDocument song) => switch (_sort) {
        LibrarySort.title => song.title,
        LibrarySort.author => song.author ?? '',
        LibrarySort.key => song.originalKey ?? '',
        LibrarySort.label => song.label ?? '',
      };
      return value(a).toLowerCase().compareTo(value(b).toLowerCase());
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songRepositoryProvider).watchAll();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          PopupMenuButton<LibrarySort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: LibrarySort.title, child: Text('Título')),
              PopupMenuItem(value: LibrarySort.author, child: Text('Autor')),
              PopupMenuItem(value: LibrarySort.key, child: Text('Tono')),
              PopupMenuItem(value: LibrarySort.label, child: Text('Etiqueta')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<SongDocument>>(
        stream: songs,
        initialData: const [],
        builder: (context, snapshot) {
          final allSongs = snapshot.data ?? const <SongDocument>[];
          final visible = _visible(allSongs);
          final keys =
              allSongs
                  .map((song) => song.originalKey)
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort();
          final labels =
              allSongs
                  .map((song) => song.label)
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por título o autor',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              _Filters(
                keys: keys,
                labels: labels,
                keyFilter: _keyFilter,
                labelFilter: _labelFilter,
                onKeyChanged: (value) => setState(() => _keyFilter = value),
                onLabelChanged: (value) => setState(() => _labelFilter = value),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                        hasSongs: allSongs.isNotEmpty,
                        onAddSong: widget.onAddSong,
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final song = visible[index];
                          return ListTile(
                            title: Text(song.title),
                            subtitle: Text(song.author ?? 'Autor desconocido'),
                            trailing: Text(song.originalKey ?? '—'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onAddSong,
        tooltip: 'Agregar canción',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.keys,
    required this.labels,
    required this.keyFilter,
    required this.labelFilter,
    required this.onKeyChanged,
    required this.onLabelChanged,
  });

  final List<String> keys;
  final List<String> labels;
  final String? keyFilter;
  final String? labelFilter;
  final ValueChanged<String?> onKeyChanged;
  final ValueChanged<String?> onLabelChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        DropdownButton<String>(
          hint: const Text('Tono'),
          value: keyFilter,
          items: [null, ...keys]
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value ?? 'Todos los tonos'),
                ),
              )
              .toList(),
          onChanged: onKeyChanged,
        ),
        const SizedBox(width: 16),
        DropdownButton<String>(
          hint: const Text('Etiqueta'),
          value: labelFilter,
          items: [null, ...labels]
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value ?? 'Todas las etiquetas'),
                ),
              )
              .toList(),
          onChanged: onLabelChanged,
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSongs, this.onAddSong});

  final bool hasSongs;
  final VoidCallback? onAddSong;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hasSongs
              ? 'No hay canciones que coincidan'
              : 'Tu biblioteca está vacía',
        ),
        if (!hasSongs) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddSong,
            icon: const Icon(Icons.add),
            label: const Text('Agregar primera canción'),
          ),
        ],
      ],
    ),
  );
}
