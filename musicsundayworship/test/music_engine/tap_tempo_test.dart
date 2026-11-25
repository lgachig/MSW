import 'package:flutter_test/flutter_test.dart';
import 'package:musicsundayworship/music_engine/tap_tempo.dart';

void main() {
  group('TapTempoTracker', () {
    test('requires at least 2 taps to calculate BPM', () {
      final tracker = TapTempoTracker();
      final now = DateTime(2026, 11, 24, 12, 0, 0);

      expect(tracker.recordTap(now: now), isNull);
      expect(tracker.taps.length, 1);
    });

    test('calculates 120 BPM from 500ms intervals', () {
      final tracker = TapTempoTracker();
      var time = DateTime(2026, 11, 24, 12, 0, 0);

      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 500));
      final bpm = tracker.recordTap(now: time);

      expect(bpm, 120);
    });

    test('averages intervals over multiple taps and clamps between 40 and 220', () {
      final tracker = TapTempoTracker();
      var time = DateTime(2026, 11, 24, 12, 0, 0);

      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 600)); // 100 bpm
      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 620));
      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 580));
      final bpm = tracker.recordTap(now: time);

      // Average = (600 + 620 + 580) / 3 = 600ms -> 100 BPM
      expect(bpm, 100);

      // Test upper clamp (very fast taps -> 220 max)
      tracker.reset();
      time = DateTime(2026, 11, 24, 12, 0, 0);
      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 180)); // 333 bpm -> clamped to 220
      final fastBpm = tracker.recordTap(now: time);
      expect(fastBpm, 220);

      // Test lower clamp (very slow taps -> 40 min)
      tracker.reset();
      time = DateTime(2026, 11, 24, 12, 0, 0);
      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 2000)); // 30 bpm -> clamped to 40
      final slowBpm = tracker.recordTap(now: time);
      expect(slowBpm, 40);
    });

    test('resets after timeout duration (e.g. 2.5s pause)', () {
      final tracker = TapTempoTracker(timeout: const Duration(milliseconds: 1000));
      var time = DateTime(2026, 11, 24, 12, 0, 0);

      tracker.recordTap(now: time);
      time = time.add(const Duration(milliseconds: 500));
      expect(tracker.recordTap(now: time), 120);

      // Long pause
      time = time.add(const Duration(milliseconds: 1500));
      // Tapping after timeout should clear previous taps and start a new sequence
      expect(tracker.recordTap(now: time), isNull);
      expect(tracker.taps.length, 1);
    });

    test('ignores rapid debounce taps (< 140ms)', () {
      final tracker = TapTempoTracker();
      var time = DateTime(2026, 11, 24, 12, 0, 0);

      tracker.recordTap(now: time);
      // Double click debounce
      time = time.add(const Duration(milliseconds: 50));
      expect(tracker.recordTap(now: time), isNull);
      expect(tracker.taps.length, 1);
    });
  });
}

