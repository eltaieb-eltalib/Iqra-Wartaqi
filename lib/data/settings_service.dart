import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات التطبيق المحلية (حجم الخط، التمرير التلقائي، الفاصل الافتراضي...).
class SettingsService extends ChangeNotifier {
  SharedPreferences? _prefs;

  double fontSize = 26;
  bool autoScroll = true;
  int defaultGapSeconds = 1;
  int defaultRepeatCount = 3;
  int dailyTarget = 10;

  // --- علامة الوقوف «واقف وين؟» ---
  int? standingSurah;
  int? standingAyah;
  DateTime? standingUpdatedAt;

  /// تقديم علامة الوقوف تلقائيًا عند إتقان آية (افتراضيًا: يعمل).
  bool autoAdvanceStanding = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    fontSize = _prefs!.getDouble('fontSize') ?? 26;
    autoScroll = _prefs!.getBool('autoScroll') ?? true;
    defaultGapSeconds = _prefs!.getInt('gapSeconds') ?? 1;
    defaultRepeatCount = _prefs!.getInt('repeatCount') ?? 3;
    dailyTarget = _prefs!.getInt('dailyTarget') ?? 10;
    standingSurah = _prefs!.getInt('standing_surah');
    standingAyah = _prefs!.getInt('standing_ayah');
    if (standingSurah == null || standingAyah == null) {
      standingSurah = null;
      standingAyah = null;
    }
    final ms = _prefs!.getInt('standing_updated_at');
    standingUpdatedAt =
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    autoAdvanceStanding = _prefs!.getBool('auto_advance_standing') ?? true;
    notifyListeners();
  }

  /// تثبيت علامة الوقوف عند (سورة، آية) مع طابع زمني لليوم الحالي.
  Future<void> setStandingMarker(int surah, int ayah) async {
    standingSurah = surah;
    standingAyah = ayah;
    standingUpdatedAt = DateTime.now();
    await _prefs?.setInt('standing_surah', surah);
    await _prefs?.setInt('standing_ayah', ayah);
    await _prefs?.setInt(
        'standing_updated_at', standingUpdatedAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> clearStandingMarker() async {
    standingSurah = null;
    standingAyah = null;
    standingUpdatedAt = null;
    await _prefs?.remove('standing_surah');
    await _prefs?.remove('standing_ayah');
    await _prefs?.remove('standing_updated_at');
    notifyListeners();
  }

  Future<void> setAutoAdvanceStanding(bool v) async {
    autoAdvanceStanding = v;
    await _prefs?.setBool('auto_advance_standing', v);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _prefs?.setDouble('fontSize', v);
    notifyListeners();
  }

  Future<void> setAutoScroll(bool v) async {
    autoScroll = v;
    await _prefs?.setBool('autoScroll', v);
    notifyListeners();
  }

  Future<void> setGapSeconds(int v) async {
    defaultGapSeconds = v;
    await _prefs?.setInt('gapSeconds', v);
    notifyListeners();
  }

  Future<void> setRepeatCount(int v) async {
    defaultRepeatCount = v;
    await _prefs?.setInt('repeatCount', v);
    notifyListeners();
  }

  Future<void> setDailyTarget(int v) async {
    dailyTarget = v;
    await _prefs?.setInt('dailyTarget', v);
    notifyListeners();
  }
}
