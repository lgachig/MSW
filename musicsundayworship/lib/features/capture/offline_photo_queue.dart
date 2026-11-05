import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database.dart' as db;
import '../../data/song_repository.dart';
import 'remote_digitize_service.dart';

enum QueueStatus {
  pending('pendiente'),
  processing('procesando'),
  ready('listo'),
  error('error');

  const QueueStatus(this.label);
  final String label;

  static QueueStatus fromString(String value) {
    for (final s in QueueStatus.values) {
      if (s.name == value || s.label == value) return s;
    }
    return QueueStatus.pending;
  }
}

class PhotoQueueItem {
  const PhotoQueueItem({
    required this.id,
    required this.filePath,
    this.songTitle,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
    this.resultJson,
  });

  final int id;
  final String filePath;
  final String? songTitle;
  final QueueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final String? resultJson;

  DigitizedSong? get digitizedSong {
    if (resultJson == null || resultJson!.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(resultJson!) as Map<String, dynamic>;
      return DigitizedSong.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

abstract interface class PhotoQueueRepository {
  Stream<List<PhotoQueueItem>> watchAll();
  Future<List<PhotoQueueItem>> getAll();
  Future<List<PhotoQueueItem>> getProcessableItems();
  Future<PhotoQueueItem> enqueue({
    required String filePath,
    String? songTitle,
  });
  Future<void> updateStatus(
    int id,
    QueueStatus status, {
    String? errorMessage,
    String? resultJson,
  });
  Future<void> delete(int id);
}

class DriftPhotoQueueRepository implements PhotoQueueRepository {
  DriftPhotoQueueRepository(this.database);

  final db.AppDatabase database;

  @override
  Stream<List<PhotoQueueItem>> watchAll() {
    final query = database.select(database.photoQueueItems)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<List<PhotoQueueItem>> getAll() async {
    final query = database.select(database.photoQueueItems)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<PhotoQueueItem>> getProcessableItems() async {
    final query = database.select(database.photoQueueItems)
      ..where((t) => t.status.isIn(['pending', 'error']))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<PhotoQueueItem> enqueue({
    required String filePath,
    String? songTitle,
  }) async {
    // Copy the image file to a persistent queue directory so it survives temp purge
    final persistentPath = await _persistFile(filePath);
    final now = DateTime.now();

    final insertedId = await database.into(database.photoQueueItems).insert(
      db.PhotoQueueItemsCompanion.insert(
        filePath: persistentPath,
        songTitle: Value(songTitle),
        status: QueueStatus.pending.name,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return PhotoQueueItem(
      id: insertedId,
      filePath: persistentPath,
      songTitle: songTitle,
      status: QueueStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateStatus(
    int id,
    QueueStatus status, {
    String? errorMessage,
    String? resultJson,
  }) async {
    final now = DateTime.now();
    await (database.update(database.photoQueueItems)
          ..where((t) => t.id.equals(id)))
        .write(
          db.PhotoQueueItemsCompanion(
            status: Value(status.name),
            updatedAt: Value(now),
            errorMessage: Value(errorMessage),
            resultJson:
                resultJson != null ? Value(resultJson) : const Value.absent(),
          ),
        );
  }

  @override
  Future<void> delete(int id) async {
    await (database.delete(database.photoQueueItems)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  static PhotoQueueItem _fromRow(db.PhotoQueueItem row) => PhotoQueueItem(
    id: row.id,
    filePath: row.filePath,
    songTitle: row.songTitle,
    status: QueueStatus.fromString(row.status),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    errorMessage: row.errorMessage,
    resultJson: row.resultJson,
  );

  static Future<String> _persistFile(String sourcePath) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/offline_queue');
      await dir.create(recursive: true);
      final filename = 'queue_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.split(Platform.pathSeparator).last}';
      final destination = File('${dir.path}/$filename');
      final source = File(sourcePath);
      if (await source.exists()) {
        await source.copy(destination.path);
        return destination.path;
      }
    } catch (_) {
      // If persistence fails (e.g. in test without path_provider), use sourcePath
    }
    return sourcePath;
  }
}

class InMemoryPhotoQueueRepository implements PhotoQueueRepository {
  InMemoryPhotoQueueRepository([List<PhotoQueueItem>? initial]) {
    if (initial != null) {
      _items.addAll(initial);
      _nextId = (_items.map((i) => i.id).fold(0, (max, id) => id > max ? id : max)) + 1;
    }
  }

  final List<PhotoQueueItem> _items = [];
  final _controller = StreamController<List<PhotoQueueItem>>.broadcast();
  int _nextId = 1;

  void _emit() {
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Stream<List<PhotoQueueItem>> watchAll() {
    return Stream.multi((controller) {
      controller.add(List.unmodifiable(_items));
      final sub = _controller.stream.listen(controller.add);
      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<List<PhotoQueueItem>> getAll() async => List.unmodifiable(_items);

  @override
  Future<List<PhotoQueueItem>> getProcessableItems() async => _items
      .where((i) =>
          i.status == QueueStatus.pending || i.status == QueueStatus.error)
      .toList();

  @override
  Future<PhotoQueueItem> enqueue({
    required String filePath,
    String? songTitle,
  }) async {
    final now = DateTime.now();
    final item = PhotoQueueItem(
      id: _nextId++,
      filePath: filePath,
      songTitle: songTitle,
      status: QueueStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    _items.insert(0, item);
    _emit();
    return item;
  }

  @override
  Future<void> updateStatus(
    int id,
    QueueStatus status, {
    String? errorMessage,
    String? resultJson,
  }) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final current = _items[index];
      _items[index] = PhotoQueueItem(
        id: current.id,
        filePath: current.filePath,
        songTitle: current.songTitle,
        status: status,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        errorMessage: errorMessage,
        resultJson: resultJson ?? current.resultJson,
      );
      _emit();
    }
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((i) => i.id == id);
    _emit();
  }

  void dispose() {
    _controller.close();
  }
}

class PhotoQueueProcessor {
  PhotoQueueProcessor({
    required this.repository,
    required this.digitizeService,
  });

  final PhotoQueueRepository repository;
  final RemoteDigitizeService digitizeService;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  static bool isNetworkError(Object e) {
    if (e is SocketException) return true;
    if (e is DigitizeException) {
      final msg = e.message.toLowerCase();
      return msg.contains('conexi') ||
          msg.contains('network') ||
          msg.contains('internet') ||
          msg.contains('failed to connect') ||
          msg.contains('refused') ||
          msg.contains('unreachable') ||
          msg.contains('socket');
    }
    final err = e.toString().toLowerCase();
    return err.contains('socket') ||
        err.contains('network') ||
        err.contains('connection') ||
        err.contains('clientexception') ||
        err.contains('handshake') ||
        err.contains('timeout') ||
        err.contains('timed out') ||
        err.contains('refused') ||
        err.contains('offline');
  }

  Future<int> processPendingQueue() async {
    if (_isProcessing) return 0;
    _isProcessing = true;
    var successCount = 0;
    try {
      final items = await repository.getProcessableItems();

      for (final item in items) {
        await repository.updateStatus(item.id, QueueStatus.processing);
        try {
          final result = await digitizeService.digitize(item.filePath);
          await repository.updateStatus(
            item.id,
            QueueStatus.ready,
            resultJson: jsonEncode(result.toJson()),
          );
          successCount++;
        } catch (e) {
          final isNetwork = isNetworkError(e);
          final errorMsg = e is DigitizeException ? e.message : '$e';
          await repository.updateStatus(
            item.id,
            isNetwork ? QueueStatus.pending : QueueStatus.error,
            errorMessage: isNetwork
                ? 'Sin conexión a internet. Esperando red.'
                : errorMsg,
          );
        }
      }
    } finally {
      _isProcessing = false;
    }
    return successCount;
  }

  Future<bool> retryItem(PhotoQueueItem item) async {
    await repository.updateStatus(item.id, QueueStatus.processing);
    try {
      final result = await digitizeService.digitize(item.filePath);
      await repository.updateStatus(
        item.id,
        QueueStatus.ready,
        resultJson: jsonEncode(result.toJson()),
      );
      return true;
    } catch (e) {
      final isNetwork = isNetworkError(e);
      final errorMsg = e is DigitizeException ? e.message : '$e';
      await repository.updateStatus(
        item.id,
        isNetwork ? QueueStatus.pending : QueueStatus.error,
        errorMessage: isNetwork
            ? 'Sin conexión a internet. Esperando red.'
            : errorMsg,
      );
      return false;
    }
  }
}

final photoQueueRepositoryProvider = Provider<PhotoQueueRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftPhotoQueueRepository(db);
});

final photoQueueProcessorProvider = Provider<PhotoQueueProcessor>((ref) {
  final repo = ref.watch(photoQueueRepositoryProvider);
  final service = ref.watch(remoteDigitizeServiceProvider);
  return PhotoQueueProcessor(repository: repo, digitizeService: service);
});

final photoQueueStreamProvider = StreamProvider<List<PhotoQueueItem>>((ref) {
  final repo = ref.watch(photoQueueRepositoryProvider);
  return repo.watchAll();
});
