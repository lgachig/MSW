import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class SongPhotoPage extends StatefulWidget {
  const SongPhotoPage({
    super.key,
    required this.songTitle,
    this.songId,
    this.onImageCropped,
  });

  final int? songId;
  final String songTitle;
  final ValueChanged<String>? onImageCropped;

  @override
  State<SongPhotoPage> createState() => _SongPhotoPageState();
}

class _SongPhotoPageState extends State<SongPhotoPage> {
  final _picker = ImagePicker();
  String? _croppedPath;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capturar y recortar')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.songTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Toma una foto o elígela de la galería y recorta la sección con letra y acordes. '
              'La imagen se utilizará para extraer el contenido mediante OCR.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_croppedPath != null && File(_croppedPath!).existsSync()) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_croppedPath!),
              key: const Key('song-photo-preview'),
              fit: BoxFit.contain,
              height: 320,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foto recortada con éxito y lista para digitalizar con OCR.',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          key: const Key('pick-from-gallery'),
          onPressed: _loading ? null : () => _select(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Elegir de galería'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('take-photo'),
          onPressed: _loading ? null : () => _select(ImageSource.camera),
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
      if (selected == null) return;

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

      if (!mounted) return;
      setState(() {
        _croppedPath = cropped.path;
        _loading = false;
      });

      widget.onImageCropped?.call(cropped.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto recortada correctamente')),
      );
    } on PlatformException catch (e) {
      if (e.code.toLowerCase().contains('denied') ||
          e.code.toLowerCase().contains('permission')) {
        _showPermissionHelp(source);
      } else {
        _setError('No se pudo abrir la cámara o fotos: ${e.message}');
      }
    } on UnimplementedError {
      _setError('La captura de fotos está disponible en iOS y Android.');
    } on Exception catch (error) {
      _setError('No se pudo obtener la foto: $error');
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
      _loading = false;
      _error = message;
    });
  }
}
