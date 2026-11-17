import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wird_quran/data/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranRepository repo;

  setUpAll(() {
    // Load the REAL bundled asset files directly from disk.
    final quranJson = File('assets/data/quran.json').readAsStringSync();
    final timingsJson = File('assets/data/timings.json').readAsStringSync();
    repo = QuranRepository()..loadFromStrings(quranJson, timingsJson);
  });

  group('Quran data integrity (real Tanzil data)', () {
    test('114 surahs and 6236 ayahs', () {
      expect(repo.surahs.length, 114);
      expect(repo.totalAyahs, 6236);
    });

    test('first ayah of Al-Fatiha starts with Basmala text, no BOM', () {
      final first = repo.ayah(1, 1);
      expect(first.text.contains('﻿'), isFalse,
          reason: 'BOM must be stripped');
      expect(first.text.startsWith('بِسْمِ'), isTrue);
    });

    test('last surah An-Nas has 6 ayahs', () {
      expect(repo.surah(114).ayahCount, 6);
      expect(repo.ayah(114, 6).text, isNotEmpty);
    });

    test('per-surah counts sample: 2->286, 36->83, 114->6, 1->7, 9->129', () {
      expect(repo.surah(2).ayahCount, 286);
      expect(repo.surah(36).ayahCount, 83);
      expect(repo.surah(114).ayahCount, 6);
      expect(repo.surah(1).ayahCount, 7);
      expect(repo.surah(9).ayahCount, 129);
    });

    test('ayah metadata present (juz/page/hizb)', () {
      final a = repo.ayah(2, 255);
      expect(a.juz, inInclusiveRange(1, 30));
      expect(a.page, inInclusiveRange(1, 604));
      expect(a.hizbQuarter, inInclusiveRange(1, 240));
    });

    test('timings count matches ayah count for sampled surahs', () {
      for (final s in [1, 2, 9, 36, 55, 114]) {
        expect(repo.timingsFor(s).length, repo.surah(s).ayahCount,
            reason: 'surah $s timings must equal ayah count');
      }
    });

    test('timings are ordered and non-overlapping for surah 36', () {
      final t = repo.timingsFor(36);
      for (var i = 1; i < t.length; i++) {
        expect(t[i].startMs, greaterThanOrEqualTo(t[i - 1].startMs));
        expect(t[i].ayah, t[i - 1].ayah + 1);
      }
      expect(t.first.startMs, greaterThanOrEqualTo(0));
      expect(t.last.endMs, greaterThan(t.last.startMs));
    });

    test('ayahAtPosition resolves highlight ayah', () {
      final t = repo.timingsFor(1);
      final mid = (t[2].startMs + t[2].endMs) ~/ 2;
      expect(repo.ayahAtPosition(1, Duration(milliseconds: mid)), 3);
    });

    test('timings.json raw structure parses for all 114 surahs', () {
      final raw = jsonDecode(File('assets/data/timings.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(raw.length, 114);
    });
  });
}
