import 'dart:io';

void main(List<String> args) async {
  final scriptDir = File(Platform.script.toFilePath()).parent.parent;
  final flutterDir = Directory('${scriptDir.path}/musicsundayworship');

  final proc = await Process.start(
    'dart',
    ['run', 'tool/evaluate.dart', ...args],
    workingDirectory: flutterDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await proc.exitCode;
}

