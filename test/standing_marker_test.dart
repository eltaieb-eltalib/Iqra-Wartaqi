import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wird_quran/core/standing_marker.dart';
import 'package:wird_quran/data/settings_service.dart';

/// أعداد آيات عيّنة حقيقية من المصحف للاختبارات.
int testCount(int surah) {
  const counts = {1: 7, 2: 286, 3: 200, 36: 83, 113: 5, 114: 6};
  return counts[surah] ?? 10;
}

void main() {
  group('nextPosition', () {
    test('next ayah inside the same surah', () {
      final p = StandingMarkerLogic.nextPosition(2, 254, testCount);
      expect(p, const StandingPosition(2, 255));
    });

    test('surah boundary moves to ayah 1 of next surah', () {
      expect(StandingMarkerLogic.nextPosition(1, 7, testCount),
          const StandingPosition(2, 1));
      expect(StandingMarkerLogic.nextPosition(2, 286, testCount),
          const StandingPosition(3, 1));
      expect(StandingMarkerLogic.nextPosition(113, 5, testCount),
          const StandingPosition(114, 1));
    });

    test('reaching last ayah of the Quran', () {
      expect(StandingMarkerLogic.nextPosition(114, 5, testCount),
          const StandingPosition(114, 6));
    });

    test('clamps at end of Quran 114:6 and never goes beyond', () {
      final p = StandingMarkerLogic.nextPosition(114, 6, testCount);
      expect(p, const StandingPosition(114, 6));
    });
  });

  group('shouldAutoAdvance', () {
    test('no marker yet -> advances', () {
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: null, masteredSurah: 2, masteredAyah: 10),
        isTrue,
      );
    });

    test('mastered exactly at the marker -> advances', () {
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: const StandingPosition(2, 10),
            masteredSurah: 2,
            masteredAyah: 10),
        isTrue,
      );
    });

    test('mastered after the marker -> advances', () {
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: const StandingPosition(2, 10),
            masteredSurah: 2,
            masteredAyah: 25),
        isTrue,
      );
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: const StandingPosition(2, 286),
            masteredSurah: 3,
            masteredAyah: 1),
        isTrue,
      );
    });

    test('mastered before the marker -> does NOT move it backwards', () {
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: const StandingPosition(2, 10),
            masteredSurah: 2,
            masteredAyah: 5),
        isFalse,
      );
      expect(
        StandingMarkerLogic.shouldAutoAdvance(
            marker: const StandingPosition(3, 1),
            masteredSurah: 2,
            masteredAyah: 286),
        isFalse,
      );
    });
  });

  group('advancedMarker', () {
    test('moves to the ayah after the mastered one', () {
      final p = StandingMarkerLogic.advancedMarker(
        marker: const StandingPosition(2, 10),
        masteredSurah: 2,
        masteredAyah: 10,
        ayahCountOf: testCount,
      );
      expect(p, const StandingPosition(2, 11));
    });

    test('crosses surah boundary', () {
      final p = StandingMarkerLogic.advancedMarker(
        marker: const StandingPosition(1, 7),
        masteredSurah: 1,
        masteredAyah: 7,
        ayahCountOf: testCount,
      );
      expect(p, const StandingPosition(2, 1));
    });

    test('returns null when mastered is before marker', () {
      final p = StandingMarkerLogic.advancedMarker(
        marker: const StandingPosition(2, 10),
        masteredSurah: 2,
        masteredAyah: 3,
        ayahCountOf: testCount,
      );
      expect(p, isNull);
    });

    test('returns null at end of Quran (already clamped)', () {
      final p = StandingMarkerLogic.advancedMarker(
        marker: const StandingPosition(114, 6),
        masteredSurah: 114,
        masteredAyah: 6,
        ayahCountOf: testCount,
      );
      expect(p, isNull);
    });
  });

  group('daysSince', () {
    test('same day = 0, yesterday = 1, five days = 5', () {
      final now = DateTime(2026, 11, 17, 15, 30);
      expect(StandingMarkerLogic.daysSince(DateTime(2026, 11, 17, 8), now), 0);
      expect(StandingMarkerLogic.daysSince(DateTime(2026, 11, 16, 23), now), 1);
      expect(StandingMarkerLogic.daysSince(DateTime(2026, 11, 12, 1), now), 5);
      expect(StandingMarkerLogic.daysSince(null, now), 0);
    });
  });

  group('persistence via SettingsService (SharedPreferences)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('standing marker round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final s1 = SettingsService();
      await s1.load();
      expect(s1.standingSurah, isNull);
      expect(s1.autoAdvanceStanding, isTrue); // default ON

      await s1.setStandingMarker(2, 255);
      expect(s1.standingSurah, 2);
      expect(s1.standingAyah, 255);
      expect(s1.standingUpdatedAt, isNotNull);

      // Fresh instance reads the persisted values back.
      final s2 = SettingsService();
      await s2.load();
      expect(s2.standingSurah, 2);
      expect(s2.standingAyah, 255);
      expect(s2.standingUpdatedAt, isNotNull);

      await s2.setAutoAdvanceStanding(false);
      final s3 = SettingsService();
      await s3.load();
      expect(s3.autoAdvanceStanding, isFalse);

      await s3.clearStandingMarker();
      final s4 = SettingsService();
      await s4.load();
      expect(s4.standingSurah, isNull);
      expect(s4.standingAyah, isNull);
    });
  });
}
