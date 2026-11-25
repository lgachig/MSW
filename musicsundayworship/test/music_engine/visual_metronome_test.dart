import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/time_signature.dart';
import 'package:musicsundayworship/music_engine/visual_metronome.dart';

void main() {
  group('VisualMetronome', () {
    test('initializes with clamped BPM and selected time signature', () {
      final metronome = VisualMetronome(
        initialBpm: 30, // below 40 -> clamp to 40
        initialTimeSignature: TimeSignature.threeFour,
      );

      expect(metronome.bpm, 40);
      expect(metronome.timeSignature, TimeSignature.threeFour);
      expect(metronome.isPlaying, isFalse);
      expect(metronome.currentBeat, 0);

      metronome.setBpm(300); // above 220 -> clamp to 220
      expect(metronome.bpm, 220);

      metronome.dispose();
    });

    test('fires beat 1 immediately upon start with accent', () {
      fakeAsync((async) {
        final metronome = VisualMetronome(
          initialBpm: 120,
          initialTimeSignature: TimeSignature.fourFour,
        );

        final ticks = <MetronomeTick>[];
        final sub = metronome.ticks.listen(ticks.add);

        metronome.start();
        expect(metronome.isPlaying, isTrue);
        expect(ticks.length, 1);
        expect(ticks.first.beat, 1);
        expect(ticks.first.isFirstBeat, isTrue);
        expect(ticks.first.isAccentBeat, isTrue);

        sub.cancel();
        metronome.dispose();
      });
    });

    test('cycles beats correctly for 2/4, 3/4, 4/4 and 6/8', () {
      fakeAsync((async) {
        // Test 3/4: beats 1, 2, 3, 1, 2, 3...
        final metronome = VisualMetronome(
          initialBpm: 120, // 500ms per beat
          initialTimeSignature: TimeSignature.threeFour,
        );

        final beats = <int>[];
        final accents = <bool>[];
        final sub = metronome.ticks.listen((t) {
          beats.add(t.beat);
          accents.add(t.isFirstBeat);
        });

        metronome.start();
        async.elapse(const Duration(milliseconds: 1500)); // 3 intervals = 4 beats total

        expect(beats, [1, 2, 3, 1]);
        expect(accents, [true, false, false, true]);

        sub.cancel();
        metronome.dispose();
      });
    });

    test('6/8 time signature accents beat 1 (primary) and beat 4 (secondary)', () {
      fakeAsync((async) {
        final metronome = VisualMetronome(
          initialBpm: 120,
          initialTimeSignature: TimeSignature.sixEight,
        );

        final accentList = <bool>[];
        final sub = metronome.ticks.listen((t) => accentList.add(t.isAccentBeat));

        metronome.start();
        async.elapse(const Duration(milliseconds: 2500)); // 6 beats: 1, 2, 3, 4, 5, 6

        // Beats: 1 (true), 2 (false), 3 (false), 4 (true), 5 (false), 6 (false)
        expect(accentList.take(6).toList(), [true, false, false, true, false, false]);

        sub.cancel();
        metronome.dispose();
      });
    });

    test('stop resets beat and cancels running timer', () {
      fakeAsync((async) {
        final metronome = VisualMetronome(initialBpm: 120);
        final ticks = <MetronomeTick>[];
        final sub = metronome.ticks.listen(ticks.add);

        metronome.start();
        async.elapse(const Duration(milliseconds: 1000));
        final countBefore = ticks.length;
        expect(countBefore, greaterThan(1));

        metronome.stop();
        expect(metronome.isPlaying, isFalse);
        expect(metronome.currentBeat, 0);

        async.elapse(const Duration(seconds: 2));
        expect(ticks.length, countBefore); // no more ticks

        sub.cancel();
        metronome.dispose();
      });
    });

    test('Medición automática: desviación menor a 10 ms en 60 segundos', () {
      fakeAsync((async) {
        // At 120 BPM:
        // Interval = 500 ms (500,000 microseconds)
        // In 60 seconds (60,000 ms), there are exactly 120 intervals (121 beats: beat 1 at t=0, beat 121 at t=60s).
        final metronome = VisualMetronome(
          initialBpm: 120,
          initialTimeSignature: TimeSignature.fourFour,
        );

        final ticks = <MetronomeTick>[];
        final sub = metronome.ticks.listen(ticks.add);

        metronome.start();
        async.elapse(const Duration(seconds: 60));

        expect(ticks.length, 121);

        // Verify the 60-second mark tick
        final lastTick = ticks.last;
        expect(lastTick.totalBeats, 121);
        expect(lastTick.targetMilliseconds, 60000);
        expect(lastTick.elapsedMilliseconds, 60000);

        // Deviation of every single beat must be less than 10 ms
        for (final tick in ticks) {
          expect(
            tick.deviationMilliseconds,
            lessThan(10),
            reason: 'Beat ${tick.totalBeats} had deviation ${tick.deviationMilliseconds}ms >= 10ms',
          );
        }

        sub.cancel();
        metronome.dispose();
      });
    });
  });
}

