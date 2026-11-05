import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musicsundayworship/features/capture/remote_digitize_service.dart';

void main() {
  test('uploads image and maps structured song response', () async {
    final directory = await Directory.systemTemp.createTemp('msw-digitize-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/song.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    http.BaseRequest? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response(
        jsonEncode({
          'title': 'Canto',
          'key': 'G',
          'sections': [
            {
              'name': 'Coro',
              'lines': [
                {
                  'text': 'Tu amor permanece',
                  'chords': [
                    {'chord': 'G', 'position': 0},
                    {'chord': 'C', 'position': 5},
                  ],
                },
              ],
            },
          ],
        }),
        200,
      );
    });
    final service = HttpRemoteDigitizeService(
      baseUrl: 'https://api.example.com',
      client: client,
    );

    final result = await service.digitize(image.path);

    expect(sentRequest?.url.path, '/digitize');
    expect(sentRequest?.method, 'POST');
    expect(result.title, 'Canto');
    expect(result.key, 'G');
    expect(result.chordOverLyricText, '## Coro\nG    C\nTu amor permanece');
    client.close();
  });

  test('reports missing service URL without sending a request', () async {
    final directory = await Directory.systemTemp.createTemp('msw-digitize-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/song.jpg')..writeAsBytesSync([1]);
    final service = HttpRemoteDigitizeService(baseUrl: '');

    await expectLater(
      service.digitize(image.path),
      throwsA(isA<DigitizeException>()),
    );
  });

  test('turns invalid response JSON into a user-safe error', () async {
    final directory = await Directory.systemTemp.createTemp('msw-digitize-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/song.jpg')..writeAsBytesSync([1]);
    final client = MockClient(
      (_) async => http.Response('{"title": "missing sections"}', 200),
    );
    final service = HttpRemoteDigitizeService(
      baseUrl: 'https://api.example.com',
      client: client,
    );

    await expectLater(
      service.digitize(image.path),
      throwsA(isA<DigitizeException>()),
    );
    client.close();
  });
}
