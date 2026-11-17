/// منطق نقي لعلامة «واقف وين؟» — موضع وقوف المستخدم في الحفظ.
/// لا يعتمد على Flutter ولا على المستودع: تُمرَّر أعداد الآيات بدالة.
library;

/// موضع واحد في المصحف: سورة وآية.
class StandingPosition {
  final int surah;
  final int ayah;
  const StandingPosition(this.surah, this.ayah);

  @override
  bool operator ==(Object other) =>
      other is StandingPosition && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => '$surah:$ayah';
}

/// دوال علامة الوقوف: التقدّم لآية تالية، وقرار التقديم التلقائي عند الإتقان.
class StandingMarkerLogic {
  StandingMarkerLogic._();

  /// مقارنة ترتيبية بين موضعين (السورة أولًا ثم الآية).
  static int compare(int s1, int a1, int s2, int a2) {
    if (s1 != s2) return s1.compareTo(s2);
    return a1.compareTo(a2);
  }

  /// الموضع التالي بعد (surah, ayah):
  /// الآية التالية في نفس السورة، فإن انتهت السورة فأول آية في السورة التالية،
  /// ويُثبَّت عند نهاية القرآن (الناس ٦) فلا يتجاوزها.
  /// [ayahCountOf] يعيد عدد آيات السورة المطلوبة.
  static StandingPosition nextPosition(
    int surah,
    int ayah,
    int Function(int surah) ayahCountOf,
  ) {
    final count = ayahCountOf(surah);
    if (ayah < count) return StandingPosition(surah, ayah + 1);
    if (surah < 114) return StandingPosition(surah + 1, 1);
    // آخر آية في القرآن: نبقى مكاننا.
    return StandingPosition(114, ayahCountOf(114));
  }

  /// هل يجب تقديم العلامة تلقائيًا عند إتقان آية؟
  /// نعم إذا لم تكن هناك علامة بعد، أو كانت الآية المتقنة عند العلامة
  /// أو بعدها. لا تتحرك العلامة أبدًا إلى الخلف.
  static bool shouldAutoAdvance({
    required StandingPosition? marker,
    required int masteredSurah,
    required int masteredAyah,
  }) {
    if (marker == null) return true;
    return compare(masteredSurah, masteredAyah, marker.surah, marker.ayah) >= 0;
  }

  /// العلامة الجديدة بعد إتقان آية، أو null إذا لا يجب أن تتحرك.
  /// عند التقديم تصبح العلامة هي الآية التالية للآية المتقنة.
  static StandingPosition? advancedMarker({
    required StandingPosition? marker,
    required int masteredSurah,
    required int masteredAyah,
    required int Function(int surah) ayahCountOf,
  }) {
    if (!shouldAutoAdvance(
      marker: marker,
      masteredSurah: masteredSurah,
      masteredAyah: masteredAyah,
    )) {
      return null;
    }
    final next = nextPosition(masteredSurah, masteredAyah, ayahCountOf);
    if (marker != null && next == marker) return null; // لا تغيير فعلي
    return next;
  }

  /// عدد الأيام الكاملة بين آخر تحديث للعلامة والآن (٠ = اليوم).
  static int daysSince(DateTime? updatedAt, DateTime now) {
    if (updatedAt == null) return 0;
    final a = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
    final b = DateTime(now.year, now.month, now.day);
    final d = b.difference(a).inDays;
    return d < 0 ? 0 : d;
  }
}
