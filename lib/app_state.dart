import 'package:flutter/foundation.dart';

import 'core/standing_marker.dart';
import 'data/app_database.dart';
import 'data/models.dart';
import 'data/settings_service.dart';

/// حالة التطبيق: آخر موضع، جلسة الاستماع الحالية، وعدّادات التقدّم.
class AppState extends ChangeNotifier {
  final AppDatabase db;
  final SettingsService? settings;
  AppState(this.db, {this.settings});

  /// دالة عدد آيات سورة (تُضبط من main من المستودع) لمنطق علامة الوقوف.
  int Function(int surah)? ayahCountResolver;

  // ---------- علامة الوقوف «واقف وين؟» ----------
  StandingPosition? get standingMarker {
    final s = settings?.standingSurah;
    final a = settings?.standingAyah;
    if (s == null || a == null) return null;
    return StandingPosition(s, a);
  }

  DateTime? get standingUpdatedAt => settings?.standingUpdatedAt;

  Future<void> setStandingMarker(int surah, int ayah) async {
    await settings?.setStandingMarker(surah, ayah);
    notifyListeners();
  }

  Future<void> clearStandingMarker() async {
    await settings?.clearStandingMarker();
    notifyListeners();
  }

  /// عند إتقان آية: قدّم علامة الوقوف تلقائيًا إلى الآية التالية
  /// إن كانت الآية المتقنة عند العلامة أو بعدها وكان الخيار مفعّلًا.
  Future<void> advanceStandingForMastered(int surah, int ayah) async {
    final st = settings;
    final resolver = ayahCountResolver;
    if (st == null || resolver == null || !st.autoAdvanceStanding) return;
    final next = StandingMarkerLogic.advancedMarker(
      marker: standingMarker,
      masteredSurah: surah,
      masteredAyah: ayah,
      ayahCountOf: resolver,
    );
    if (next != null) {
      await st.setStandingMarker(next.surah, next.ayah);
      notifyListeners();
    }
  }

  int? lastSurah;
  int? lastAyah;
  String lastSurahName = '';

  /// رمز مالك جلسات التكرار (تشاركه شاشة النطاق وربط main عند انتهاء الخطة).
  static final Object repetitionSessionOwner = Object();

  int? _sessionId;
  DateTime? _sessionStart;
  Object? _sessionOwner;

  Future<void> loadLastPosition() async {
    final s = await db.readKv('last_surah');
    final a = await db.readKv('last_ayah');
    lastSurah = s == null ? null : int.tryParse(s);
    lastAyah = a == null ? null : int.tryParse(a);
    lastSurahName = await db.readKv('last_surah_name') ?? '';
    notifyListeners();
  }

  Future<void> recordPosition(int surah, int ayah, String surahName) async {
    lastSurah = surah;
    lastAyah = ayah;
    lastSurahName = surahName;
    await db.saveKv('last_surah', '$surah');
    await db.saveKv('last_ayah', '$ayah');
    await db.saveKv('last_surah_name', surahName);
    notifyListeners();
  }

  /// بدء جلسة جديدة لمالك معيّن. أي جلسة مفتوحة سابقة تُنهى أولًا بمدتها
  /// الحقيقية (لا تبقى يتيمة بمدة صفر، ولا تنهي شاشةٌ جلسةَ غيرها).
  Future<void> beginSession(int? surah, String mode, {Object? owner}) async {
    if (_sessionId != null) await endSession();
    _sessionStart = DateTime.now();
    _sessionOwner = owner;
    _sessionId = await db.startSession(surah, mode);
  }

  /// إنهاء الجلسة المفتوحة. عند تمرير [owner] لا تُنهى إلا جلسة ذلك المالك.
  Future<void> endSession({Object? owner}) async {
    if (owner != null && _sessionOwner != null && _sessionOwner != owner) {
      return; // الجلسة المفتوحة ليست لهذا المالك
    }
    if (_sessionId != null && _sessionStart != null) {
      final seconds = DateTime.now().difference(_sessionStart!).inSeconds;
      if (seconds > 0) await db.endSession(_sessionId!, seconds);
    }
    _sessionId = null;
    _sessionStart = null;
    _sessionOwner = null;
  }

  Future<void> markRangeStatus(
      int surah, int fromAyah, int toAyah, String status) async {
    final changed = await db.setRangeStatus(surah, fromAyah, toAyah, status);
    if (changed > 0) {
      await db.addDailyDone(changed, targetAyahs: settings?.dailyTarget);
    }
    if (status == 'mastered') {
      await advanceStandingForMastered(surah, toAyah);
    }
    notifyListeners();
  }
}

/// تسمية عربية نظيفة لاسم السورة (المصدر يتضمن بادئة «سورة »).
String cleanSurahName(Surah s) {
  var n = s.name.trim();
  if (n.startsWith('سورة ')) n = n.substring(5);
  return 'سورة $n';
}
