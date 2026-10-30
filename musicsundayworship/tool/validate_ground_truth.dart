import 'dart:convert';
import 'dart:io';

void main() {
  final repositoryRoot = Directory.current.parent.path;
  final directory =
      Directory('$repositoryRoot/docs/fotos-prueba/respuestas');
  if (!directory.existsSync()) {
    stderr.writeln('Missing directory: ${directory.path}');
    exitCode = 1;
    return;
  }

  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final photos = Directory('$repositoryRoot/docs/fotos-prueba')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.png'))
      .length;

  if (files.length != photos) {
    stderr.writeln('Expected $photos JSON files, found ${files.length}.');
    exitCode = 1;
    return;
  }

  for (final file in files) {
    final label = file.path;
    final dynamic document;
    try {
      document = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      stderr.writeln('$label: invalid JSON: $error');
      exitCode = 1;
      return;
    }

    if (document is! Map<String, dynamic> ||
        document['source'] is! String ||
        document['title'] is! String ||
        document['author'] is! String ||
        document['key'] is! String ||
        document['lines'] is! List) {
      stderr.writeln('$label: missing required fields.');
      exitCode = 1;
      return;
    }

    for (final line in document['lines'] as List) {
      if (line is! Map<String, dynamic> ||
          line['text'] is! String ||
          line['chords'] is! List) {
        stderr.writeln('$label: invalid line.');
        exitCode = 1;
        return;
      }
      final text = line['text'] as String;
      for (final chord in line['chords'] as List) {
        if (chord is! Map<String, dynamic> ||
            chord['name'] is! String ||
            chord['position'] is! int ||
            (chord['position'] as int) < 0 ||
            (chord['position'] as int) > text.length) {
          stderr.writeln('$label: invalid chord position.');
          exitCode = 1;
          return;
        }
      }
    }
  }

  stdout.writeln('Validated ${files.length} ground-truth JSON files.');
}
