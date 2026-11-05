import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../music_engine/chord.dart';

class DigitizeException implements Exception {
  const DigitizeException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DigitizedChord {
  const DigitizedChord({required this.chord, required this.position});

  final String chord;
  final int position;

  bool get isValid => Chord.parse(chord) != null;

  factory DigitizedChord.fromJson(Map<String, dynamic> json) => DigitizedChord(
    chord: json['chord'] as String,
    position: json['position'] as int,
  );
}

class DigitizedLine {
  const DigitizedLine({required this.text, required this.chords});

  final String text;
  final List<DigitizedChord> chords;

  factory DigitizedLine.fromJson(Map<String, dynamic> json) => DigitizedLine(
    text: json['text'] as String,
    chords: (json['chords'] as List<dynamic>)
        .map((item) => DigitizedChord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}

class DigitizedSection {
  const DigitizedSection({required this.name, required this.lines});

  final String name;
  final List<DigitizedLine> lines;

  factory DigitizedSection.fromJson(Map<String, dynamic> json) =>
      DigitizedSection(
        name: json['name'] as String,
        lines: (json['lines'] as List<dynamic>)
            .map((item) => DigitizedLine.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class DigitizedSong {
  const DigitizedSong({
    required this.title,
    required this.key,
    required this.sections,
  });

  final String? title;
  final String? key;
  final List<DigitizedSection> sections;

  Iterable<DigitizedChord> get chords =>
      sections.expand((section) => section.lines.expand((line) => line.chords));

  int get chordCount => chords.length;

  int get validChordCount => chords.where((chord) => chord.isValid).length;

  double get validChordPercentage =>
      chordCount == 0 ? 0 : validChordCount * 100 / chordCount;

  factory DigitizedSong.fromJson(Map<String, dynamic> json) => DigitizedSong(
    title: json['title'] as String?,
    key: json['key'] as String?,
    sections: (json['sections'] as List<dynamic>)
        .map((item) => DigitizedSection.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  String get chordOverLyricText => sections
      .map(
        (section) => [
          '## ${section.name}',
          for (final line in section.lines) ...[
            if (line.chords.isNotEmpty) _formatChordLine(line.chords),
            line.text,
          ],
        ].join('\n'),
      )
      .join('\n\n');

  static String _formatChordLine(List<DigitizedChord> chords) {
    final sorted = [...chords]
      ..sort((a, b) => a.position.compareTo(b.position));
    final buffer = StringBuffer();
    for (final item in sorted) {
      final position = item.position.clamp(0, 1000);
      if (buffer.length < position) {
        buffer.write(' ' * (position - buffer.length));
      }
      if (buffer.length > position) {
        buffer.write(' ');
      }
      buffer.write(item.chord);
    }
    return buffer.toString();
  }
}

abstract interface class RemoteDigitizeService {
  Future<DigitizedSong> digitize(String imagePath);
}

class HttpRemoteDigitizeService implements RemoteDigitizeService {
  HttpRemoteDigitizeService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<DigitizedSong> digitize(String imagePath) async {
    final configuredUrl = baseUrl.trim();
    if (configuredUrl.isEmpty) {
      throw const DigitizeException(
        'Configura MSW_DIGITIZE_API_URL para habilitar la digitalización con IA.',
      );
    }

    final uri = Uri.tryParse(configuredUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const DigitizeException(
        'La URL del servicio de digitalización no es válida.',
      );
    }

    final request = http.MultipartRequest('POST', uri.resolve('/digitize'));
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw DigitizeException(
          detail is String
              ? detail
              : 'El servicio de digitalización respondió con error.',
        );
      }
      if (body is! Map<String, dynamic>) {
        throw const DigitizeException(
          'El servicio devolvió un resultado inválido.',
        );
      }
      try {
        return DigitizedSong.fromJson(body);
      } on FormatException {
        throw const DigitizeException(
          'El servicio devolvió un resultado incompleto.',
        );
      } on TypeError {
        throw const DigitizeException(
          'El servicio devolvió un resultado incompleto.',
        );
      }
    } on DigitizeException {
      rethrow;
    } on FormatException {
      throw const DigitizeException('El servicio devolvió un JSON inválido.');
    } on Exception {
      throw const DigitizeException(
        'No se pudo conectar con el servicio. Revisa internet e inténtalo de nuevo.',
      );
    }
  }
}

final remoteDigitizeServiceProvider = Provider<RemoteDigitizeService>((ref) {
  const baseUrl = String.fromEnvironment('MSW_DIGITIZE_API_URL');
  return HttpRemoteDigitizeService(baseUrl: baseUrl);
});
