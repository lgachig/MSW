import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/device_ocr_service.dart';
import '../capture/ocr_models.dart';
import 'song_editor_page.dart';

class SongPhotoPage extends ConsumerStatefulWidget {
  const SongPhotoPage({
    super.key,
    required this.songTitle,
    this.songId,
    this.onImageCropped,
    this.onDocumentExtracted,
  });

  final int? songId;
  final String songTitle;
  final ValueChanged<String>? onImageCropped;
  final ValueChanged<OcrDocument>? onDocumentExtracted;

  @override
  ConsumerState<SongPhotoPage> createState() => _SongPhotoPageState();
}

class _SongPhotoPageState extends ConsumerState<SongPhotoPage> {
  final _picker = ImagePicker();
  String? _croppedPath;
  bool _loading = false;
  bool _ocrProcessing = false;
  String? _error;
  OcrDocument? _ocrDocument;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Digitalizar desde foto')),
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
              'El OCR en el dispositivo procesará la imagen sin conexión a internet.',
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
              height: 260,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
          if (!_ocrProcessing && _ocrDocument == null)
            FilledButton.icon(
              key: const Key('digitize-ocr'),
              onPressed: _loading ? null : _processOcr,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Digitalizar con OCR (en el dispositivo)'),
            ),
          if (_ocrProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Extrayendo texto y acordes sin internet...'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (_ocrDocument != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'OCR completado (${_ocrDocument!.lines.length} líneas detectadas)',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Líneas con acordes: ${_ocrDocument!.processedLines.where((l) => l.isChordLine).length}',
                  style: TextStyle(color: Colors.green.shade900),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _ocrDocument!.toChordOverLyricText(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('open-in-editor'),
                  onPressed: _openInEditor,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Abrir en el editor de canción'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          key: const Key('pick-from-gallery'),
          onPressed: _loading || _ocrProcessing ? null : () => _select(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Elegir de galería'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('take-photo'),
          onPressed: _loading || _ocrProcessing ? null : () => _select(ImageSource.camera),
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
    setState(() {
      _error = null;
      _ocrDocument = null;
    });
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

  Future<void> _processOcr() async {
    final path = _croppedPath;
    if (path == null) return;

    setState(() {
      _ocrProcessing = true;
      _error = null;
    });

    try {
      final ocrService = ref.read(deviceOcrServiceProvider);
      final document = await ocrService.processImage(path);
      if (!mounted) return;

      setState(() {
        _ocrDocument = document;
        _ocrProcessing = false;
      });

      widget.onDocumentExtracted?.call(document);
    } on Exception catch (e) {
      _setError('Error al procesar la imagen con OCR: $e');
    }
  }

  Future<void> _openInEditor() async {
    final doc = _ocrDocument;
    if (doc == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute<dynamic>(
        builder: (_) => SongEditorPage(
          songId: widget.songId,
          initialTitle: widget.songTitle == 'Nueva canción' ? null : widget.songTitle,
          initialLyrics: doc.toChordOverLyricText(),
        ),
      ),
    );

    if (mounted && result != null) {
      Navigator.of(context).pop(result);
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
      _ocrProcessing = false;
      _error = message;
    });
  }
}
