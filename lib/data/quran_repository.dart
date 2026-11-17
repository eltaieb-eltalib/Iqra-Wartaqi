import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/repetition_engine.dart';
import 'models.dart';

/// يقرأ نص القرآن الكريم (تنزيل — الرسم العثماني) وتوقيتات الآيات
/// من الأصول المضمّنة في التطبيق. لا توجد أي نصوص مكتوبة يدويًا.
class QuranRepository {
  List<Surah> _surahs = const [];
  Map<int, List<AyahTiming>> _timings = const {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<Surah> get surahs => _surahs;
  int get totalAyahs => _surahs.fold(0, (sum, s) => sum + s.ayahCount);

  Future<void> load() async {
    if (_loaded) return;
    final quranRaw = await rootBundle.loadString('assets/data/quran.json');
    final timingsRaw = await rootBundle.loadString('assets/data/timings.json');
    loadFromStrings(quranRaw, timingsRaw);
  }

  /// قابلة للاختبار دون بيئة Flutter.
  void loadFromStrings(String quranJson, String timingsJson) {
    final q = jsonDecode(quranJson) as Map<String, dynamic>;
    final surahList = (q['surahs'] ?? q['data'] ?? []) as List;
    _surahs = [
      for (final s in surahList) Surah.fromJson(s as Map<String, dynamic>),
    ]..sort((a, b) => a.number.compareTo(b.number));

    final t = jsonDecode(timingsJson) as Map<String, dynamic>;
    final map = <int, List<AyahTiming>>{};
    t.forEach((key, value) {
      final surahNo = int.tryParse(key);
      if (surahNo == null || value is! List) return;
      map[surahNo] = [
        for (final e in value) AyahTiming.fromJson(e as Map<String, dynamic>),
      ]..sort((a, b) => a.ayah.compareTo(b.ayah));
    });
    _timings = map;
    _loaded = true;
  }

  Surah surah(int number) => _surahs.firstWhere(
        (s) => s.number == number,
        orElse: () => throw ArgumentError('Surah $number not found'),
      );

  Ayah ayah(int surah, int ayah) => this.surah(surah).ayahs.firstWhere(
        (a) => a.numberInSurah == ayah,
        orElse: () => throw ArgumentError('Ayah $surah:$ayah not found'),
      );

  List<AyahTiming> timingsFor(int surah) => _timings[surah] ?? const [];

  /// بحث بالاسم العربي/الإنجليزي أو برقم السورة.
  List<Surah> searchSurahs(String query) {
    final q = query.trim();
    if (q.isEmpty) return _surahs;
    final asNumber = int.tryParse(q);
    return _surahs.where((s) {
      if (asNumber != null && s.number == asNumber) return true;
      return s.name.contains(q) ||
          s.englishName.toLowerCase().contains(q.toLowerCase());
    }).toList();
  }

  /// الآية الحالية من موضع التشغيل وتوقيتات السورة (لمزامنة التمييز).
  int? ayahAtPosition(int surah, Duration position) {
    final timings = timingsFor(surah);
    final ms = position.inMilliseconds;
    int? current;
    for (final t in timings) {
      if (ms >= t.startMs && ms < t.endMs) return t.ayah;
      if (ms >= t.startMs) current = t.ayah;
    }
    return current;
  }
}
