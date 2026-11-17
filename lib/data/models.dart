class Ayah {
  final int surah;
  final int numberInSurah;
  final String text;
  final int juz;
  final int page;
  final int hizbQuarter;
  final int ruku;
  const Ayah({
    required this.surah,
    required this.numberInSurah,
    required this.text,
    required this.juz,
    required this.page,
    required this.hizbQuarter,
    required this.ruku,
  });

  static int _int(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  factory Ayah.fromJson(int surah, Map<String, dynamic> j) => Ayah(
        surah: surah,
        numberInSurah: _int(j, ['numberInSurah', 'n', 'number']),
        text: (j['text'] ?? j['t'] ?? '') as String,
        juz: _int(j, ['juz', 'j']),
        page: _int(j, ['page', 'p']),
        hizbQuarter: _int(j, ['hizbQuarter', 'h']),
        ruku: _int(j, ['ruku', 'r']),
      );
}

class Surah {
  final int number;
  final String name; // الاسم العربي كما في المصدر
  final String englishName;
  final String revelationType;
  final List<Ayah> ayahs;
  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.revelationType,
    required this.ayahs,
  });
  int get ayahCount => ayahs.length;
  int get juz => ayahs.isEmpty ? 1 : ayahs.first.juz;
  factory Surah.fromJson(Map<String, dynamic> j) {
    final number = (j['number'] as num).toInt();
    return Surah(
      number: number,
      name: (j['name'] ?? '') as String,
      englishName: (j['englishName'] ?? '') as String,
      revelationType: (j['revelationType'] ?? '') as String,
      ayahs: [
        for (final a in (j['ayahs'] as List)) Ayah.fromJson(number, a as Map<String, dynamic>),
      ],
    );
  }
}

/// نطاق محفوظ للحفظ/المراجعة.
class SavedRange {
  final int? id;
  final String title;
  final int surah;
  final int fromAyah;
  final int toAyah;
  final String kind; // memorization | review | custom
  const SavedRange({
    this.id,
    required this.title,
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
    this.kind = 'custom',
  });
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'surah': surah,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'kind': kind,
      };
  factory SavedRange.fromMap(Map<String, dynamic> m) => SavedRange(
        id: m['id'] as int?,
        title: m['title'] as String,
        surah: m['surah'] as int,
        fromAyah: m['from_ayah'] as int,
        toAyah: m['to_ayah'] as int,
        kind: (m['kind'] ?? 'custom') as String,
      );
}
