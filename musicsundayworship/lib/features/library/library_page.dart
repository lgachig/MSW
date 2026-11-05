import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../capture/offline_photo_queue.dart';
import '../songs/song_detail_page.dart';
import '../songs/song_editor_page.dart';
import '../songs/song_photo_page.dart';
import '../songs/song_review_correction_page.dart';

enum LibrarySort { title, author, key, label }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, this.onAddSong});

  final VoidCallback? onAddSong;

  void _addSong(BuildContext context) {
    if (onAddSong != null) {
      onAddSong!();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SongEditorPage()));
    }
  }

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with WidgetsBindingObserver {
  String _query = '';
  String? _keyFilter;
  String? _labelFilter;
  LibrarySort _sort = LibrarySort.title;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(photoQueueProcessorProvider).processPendingQueue();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(photoQueueProcessorProvider).processPendingQueue();
    }
  }

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
    final queueAsync = ref.watch(photoQueueStreamProvider);
    final queueItems = queueAsync.value ?? const <PhotoQueueItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          IconButton(
            key: const Key('library-camera-button'),
            tooltip: 'Digitalizar desde foto',
            icon: const Icon(Icons.document_scanner),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SongPhotoPage(songTitle: 'Nueva canción'),
              ),
            ),
          ),
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
              if (queueItems.isNotEmpty)
                _OfflineQueueSection(items: queueItems),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(
                        hasSongs: allSongs.isNotEmpty,
                        onAddSong: () => widget._addSong(context),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final song = visible[index];
                          return ListTile(
                            title: Text(song.title),
                            subtitle: Text(
                              [
                                song.author ?? 'Autor desconocido',
                                if (song.source != null) song.source!,
                              ].join(' · '),
                            ),
                            trailing: Text(song.originalKey ?? '—'),
                            onTap: song.id == null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          SongDetailPage(song: song),
                                    ),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget._addSong(context),
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
    child: SingleChildScrollView(
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
    ),
  );
}

class _OfflineQueueSection extends ConsumerWidget {
  const _OfflineQueueSection({required this.items});

  final List<PhotoQueueItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('offline-queue-section'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cola de digitalización (${items.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  key: const Key('sync-queue-button'),
                  tooltip: 'Sincronizar cola',
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    ref.read(photoQueueProcessorProvider).processPendingQueue();
                  },
                ),
              ],
            ),
            const Divider(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items
                      .map((item) => _QueueItemTile(item: item))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueItemTile extends ConsumerWidget {
  const _QueueItemTile({required this.item});

  final PhotoQueueItem item;

  Color _statusColor() => switch (item.status) {
    QueueStatus.pending => Colors.amber.shade800,
    QueueStatus.processing => Colors.blue.shade700,
    QueueStatus.ready => Colors.green.shade700,
    QueueStatus.error => Colors.red.shade700,
  };

  Widget _statusIcon() => switch (item.status) {
    QueueStatus.pending => Icon(
      Icons.hourglass_empty,
      color: _statusColor(),
      size: 20,
      key: Key('status-pending-${item.id}'),
    ),
    QueueStatus.processing => SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(_statusColor()),
        key: Key('status-processing-${item.id}'),
      ),
    ),
    QueueStatus.ready => Icon(
      Icons.check_circle,
      color: _statusColor(),
      size: 20,
      key: Key('status-ready-${item.id}'),
    ),
    QueueStatus.error => Icon(
      Icons.error_outline,
      color: _statusColor(),
      size: 20,
      key: Key('status-error-${item.id}'),
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = item.songTitle?.isNotEmpty == true
        ? item.songTitle!
        : 'Foto #${item.id}';

    return Container(
      key: Key('queue-item-${item.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _statusColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _statusIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  item.status == QueueStatus.error && item.errorMessage != null
                      ? 'Error: ${item.errorMessage}'
                      : 'Estado: ${item.status.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(),
                  ),
                ),
              ],
            ),
          ),
          if (item.status == QueueStatus.ready)
            FilledButton.tonal(
              key: Key('open-queue-item-${item.id}'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _openReadyItem(context, ref, item),
              child: const Text('Revisar'),
            ),
          if (item.status == QueueStatus.pending || item.status == QueueStatus.error)
            IconButton(
              key: Key('retry-queue-item-${item.id}'),
              icon: const Icon(Icons.replay, size: 20),
              tooltip: 'Reintentar',
              onPressed: () => ref.read(photoQueueProcessorProvider).retryItem(item),
            ),
          IconButton(
            key: Key('delete-queue-item-${item.id}'),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Eliminar de la cola',
            onPressed: () => ref.read(photoQueueRepositoryProvider).delete(item.id),
          ),
        ],
      ),
    );
  }

  Future<void> _openReadyItem(
    BuildContext context,
    WidgetRef ref,
    PhotoQueueItem item,
  ) async {
    final digitized = item.digitizedSong;
    if (digitized == null) return;

    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => SongReviewCorrectionPage(
          imagePath: item.filePath,
          digitizedSong: digitized,
          initialSongTitle: item.songTitle,
          queueItemId: item.id,
        ),
      ),
    );
  }
}
