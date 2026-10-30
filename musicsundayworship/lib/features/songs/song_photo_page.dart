import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/song_repository.dart';

class SongPhotoPage extends ConsumerStatefulWidget {
  const SongPhotoPage({
    super.key,
    required this.songId,
    required this.songTitle,
    this.currentPath,
  });

  final int songId;
  final String songTitle;
  final String? currentPath;

  @override
  ConsumerState<SongPhotoPage> createState() => _SongPhotoPageState();
}

class _SongPhotoPageState extends ConsumerState<SongPhotoPage> {
  final _picker = ImagePicker();
  String? _path;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = widget.currentPath;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Foto de la canción')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.songTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_path != null)
          Image.file(
            File(_path!),
            key: const Key('song-photo-preview'),
            fit: BoxFit.contain,
            height: 360,
            errorBuilder: (_, _, _) => const Text('No se pudo mostrar la foto'),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Todavía no hay una foto guardada.'),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('pick-from-gallery'),
          onPressed: _saving ? null : () => _select(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Elegir de galería'),
        ),
        FilledButton.icon(
          key: const Key('take-photo'),
          onPressed: _saving ? null : () => _select(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Tomar foto'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
      ],
    ),
  );

  Future<void> _select(ImageSource source) async {
    setState(() => _error = null);
    try {
      final selected = await _picker.pickImage(source: source);
      if (selected == null) {
        _showPermissionHelp(source);
        return;
      }
      final cropped = await ImageCropper().cropImage(
        sourcePath: selected.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar canción',
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Recortar canción'),
        ],
      );
      if (cropped == null) return;
      await _save(cropped.path);
    } on UnimplementedError {
      _setError('La captura de fotos está disponible en iOS y Android.');
    } on Exception catch (error) {
      _setError('No se pudo obtener la foto: $error');
    }
  }

  Future<void> _save(String sourcePath) async {
    setState(() => _saving = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photos = Directory('${directory.path}/song_photos');
      await photos.create(recursive: true);
      final destination = File('${photos.path}/song_${widget.songId}.jpg');
      await File(sourcePath).copy(destination.path);
      await ref
          .read(songRepositoryProvider)
          .updatePhotoPath(widget.songId, destination.path);
      if (!mounted) return;
      setState(() {
        _path = destination.path;
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto guardada')));
    } on Exception catch (error) {
      _setError('No se pudo guardar la foto: $error');
    }
  }

  void _showPermissionHelp(ImageSource source) {
    final permission = source == ImageSource.camera ? 'cámara' : 'fotos';
    _setError(
      'No se concedió permiso para $permission. Puedes permitirlo en Ajustes '
      'o elegir la otra opción.',
    );
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }
}
