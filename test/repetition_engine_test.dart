import 'package:flutter_test/flutter_test.dart';
import 'package:wird_quran/core/repetition_engine.dart';

List<AyahTiming> fakeTimings(int count, {int stepMs = 1000}) => [
      for (var a = 1; a <= count; a++)
        AyahTiming(ayah: a, startMs: (a - 1) * stepMs, endMs: a * stepMs),
    ];

void main() {
  group('RepetitionEngine — spec example', () {
    test('Baqarah 1-5, perAyah, x3 => 1,1,1,2,2,2,3,3,3,4,4,4,5,5,5', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: 3),
        timings: fakeTimings(286),
        surah: 2,
        fromAyah: 1,
        toAyah: 5,
      );
      final seq = engine.previewSequence();
      expect(seq.map((s) => s.fromAyah).toList(),
          [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5]);
      expect(seq.every((s) => s.fromAyah == s.toAyah), isTrue);
      expect(seq.map((s) => s.repeatIndex).toList(),
          [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]);
    });

    test('segment times come from timings', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: 1),
        timings: fakeTimings(10, stepMs: 2000),
        surah: 1,
        fromAyah: 3,
        toAyah: 3,
      );
      final seg = engine.current!;
      expect(seg.startMs, 4000);
      expect(seg.endMs, 6000);
    });
  });

  group('modes', () {
    test('perGroup: groups of 2 over 1-5 repeat whole group', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(
            mode: RepetitionMode.perGroup, repeatCount: 2, groupSize: 2),
        timings: fakeTimings(10),
        surah: 36,
        fromAyah: 1,
        toAyah: 5,
      );
      final seq = engine.previewSequence();
      expect(
        seq.map((s) => '${s.fromAyah}-${s.toAyah}').toList(),
        ['1-2', '1-2', '3-4', '3-4', '5-5', '5-5'],
      );
      // group segment spans first ayah start to last ayah end
      expect(seq.first.startMs, 0);
      expect(seq.first.endMs, 2000);
    });

    test('wholeRange: entire range is one unit', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.wholeRange, repeatCount: 2),
        timings: fakeTimings(10),
        surah: 112,
        fromAyah: 1,
        toAyah: 4,
      );
      final seq = engine.previewSequence();
      expect(seq.length, 2);
      expect(seq.first.fromAyah, 1);
      expect(seq.first.toAyah, 4);
      expect(seq.first.endMs, 4000);
    });

    test('custom repeat count 7', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: 7),
        timings: fakeTimings(10),
        surah: 114,
        fromAyah: 6,
        toAyah: 6,
      );
      expect(engine.previewSequence().length, 7);
    });
  });

  group('completion-only advancing', () {
    test('current does not change until onSegmentCompleted is called', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: 2),
        timings: fakeTimings(10),
        surah: 1,
        fromAyah: 1,
        toAyah: 2,
      );
      expect(engine.current!.fromAyah, 1);
      expect(engine.current!.repeatIndex, 1);
      // Reading current repeatedly never advances (failed load/seek safe).
      expect(engine.current!.fromAyah, 1);
      expect(engine.completedSegments, 0);
      final next = engine.onSegmentCompleted();
      expect(next!.fromAyah, 1);
      expect(next.repeatIndex, 2);
      expect(engine.completedSegments, 1);
      final third = engine.onSegmentCompleted();
      expect(third!.fromAyah, 2);
      expect(third.repeatIndex, 1);
      final fourth = engine.onSegmentCompleted();
      expect(fourth!.fromAyah, 2);
      expect(fourth.repeatIndex, 2);
      expect(engine.onSegmentCompleted(), isNull);
      expect(engine.isFinished, isTrue);
      expect(engine.current, isNull);
      expect(engine.onSegmentCompleted(), isNull);
    });

    test('edge: first and last ayah of a surah', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: 1),
        timings: fakeTimings(6),
        surah: 114,
        fromAyah: 1,
        toAyah: 6,
      );
      var seg = engine.current;
      var count = 0;
      while (seg != null) {
        count++;
        seg = engine.onSegmentCompleted();
      }
      expect(count, 6);
      expect(engine.completedSegments, 6);
    });
  });

  group('infinite mode', () {
    test('single ayah repeats itself endlessly', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: -1),
        timings: fakeTimings(10),
        surah: 1,
        fromAyah: 1,
        toAyah: 1,
      );
      final seen = <int>[];
      for (var i = 0; i < 5; i++) {
        seen.add(engine.current!.fromAyah);
        engine.onSegmentCompleted();
      }
      expect(seen, [1, 1, 1, 1, 1]);
      expect(engine.isFinished, isFalse);
    });

    test('range cycles forever: 1,2,1,2... and never finishes', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.perAyah, repeatCount: -1),
        timings: fakeTimings(10),
        surah: 1,
        fromAyah: 1,
        toAyah: 2,
      );
      final seen = <int>[];
      for (var i = 0; i < 6; i++) {
        seen.add(engine.current!.fromAyah);
        engine.onSegmentCompleted();
      }
      expect(seen, [1, 2, 1, 2, 1, 2]);
      expect(engine.isFinished, isFalse);
      expect(engine.completedSegments, 6);
    });

    test('wholeRange infinite cycles the range', () {
      final engine = RepetitionEngine(
        config: const RepetitionConfig(mode: RepetitionMode.wholeRange, repeatCount: -1),
        timings: fakeTimings(10),
        surah: 1,
        fromAyah: 1,
        toAyah: 3,
      );
      for (var i = 0; i < 5; i++) {
        expect(engine.current!.repeatIndex, i + 1);
        engine.onSegmentCompleted();
      }
      expect(engine.isFinished, isFalse);
    });
  });

  test('gap seconds are carried in config', () {
    final engine = RepetitionEngine(
      config: const RepetitionConfig(
          mode: RepetitionMode.perAyah, repeatCount: 1, gapSeconds: 4),
      timings: fakeTimings(3),
      surah: 1,
      fromAyah: 1,
      toAyah: 1,
    );
    expect(engine.gapSeconds, 4);
  });
}
