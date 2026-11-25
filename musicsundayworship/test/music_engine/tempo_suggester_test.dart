import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/tempo_suggester.dart';
import 'package:musicsundayworship/music_engine/time_signature.dart';

void main() {
  group('TempoSuggester', () {
    test('detects explicit BPM and time signature in text header', () {
      const text = '''
Título: Cuan Grande es Dios
BPM: 75
Compás: 4/4
Tono: G

[Verso 1]
G                 Em
El esplendor de un rey
''';
      final suggestion = TempoSuggester.suggest(text: text);

      expect(suggestion.tempo, 75);
      expect(suggestion.timeSignature, TimeSignature.fourFour);
      expect(suggestion.confidence, greaterThanOrEqualTo(0.8));
      expect(suggestion.confidenceLabel, 'Alta');
      expect(suggestion.reason, contains('75 BPM'));
      expect(suggestion.reason, contains('4/4'));
    });

    test('detects varied BPM formats (120 bpm, t=130, ♩=90)', () {
      final s1 = TempoSuggester.suggest(text: 'Gracia Sublime - 128 bpm');
      expect(s1.tempo, 128);

      final s2 = TempoSuggester.suggest(text: 'Tempo = 85 | Métrica: 3/4');
      expect(s2.tempo, 85);
      expect(s2.timeSignature, TimeSignature.threeFour);

      final s3 = TempoSuggester.suggest(text: '♩=96 compas: 6/8');
      expect(s3.tempo, 96);
      expect(s3.timeSignature, TimeSignature.sixEight);

      final s4 = TempoSuggester.suggest(text: 'T: 72 2/4');
      expect(s4.tempo, 72);
      expect(s4.timeSignature, TimeSignature.twoFour);
    });

    test('deduces 3/4 and 6/8 from genre terms when not explicit', () {
      final sVals = TempoSuggester.suggest(text: 'Hermoso vals de adoración');
      expect(sVals.timeSignature, TimeSignature.threeFour);

      final sHuapango = TempoSuggester.suggest(text: 'Huapango cristiano');
      expect(sHuapango.timeSignature, TimeSignature.sixEight);

      final sMarcha = TempoSuggester.suggest(text: 'Marcha celestial');
      expect(sMarcha.timeSignature, TimeSignature.twoFour);
    });

    test('estimates tempo from descriptive worship terms', () {
      final sBalada = TempoSuggester.suggest(text: 'Balada suave de comunión');
      expect(sBalada.tempo, 72);

      final sAlabanza = TempoSuggester.suggest(text: 'Alabanza alegre y gozo');
      expect(sAlabanza.tempo, 125);

      final sJubilo = TempoSuggester.suggest(text: 'Júbilo rápido');
      expect(sJubilo.tempo, 145);
    });

    test('provides standard defaults for empty text with low confidence', () {
      final sEmpty = TempoSuggester.suggest(text: '');
      expect(sEmpty.tempo, 100);
      expect(sEmpty.timeSignature, TimeSignature.fourFour);
      expect(sEmpty.confidenceLabel, 'Baja');
    });
  });
}

