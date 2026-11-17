import 'package:flutter/material.dart';

/// هوية «وِرد»: أناقة نسائية هادئة — بمبي وردي عميق، وردي فاتح،
/// لمسات ذهبية خفيفة، ونص بنّي-خوخي داكن لتباين مريح لكبار السن.
class WirdColors {
  /// الوردي العميق — اللون الأساسي.
  static const deepRose = Color(0xFFAD1457);

  /// الوردي الحيوي — للأزرار والتقدّم والتمييز النشط.
  static const pink = Color(0xFFEC407A);

  /// وردي فاتح — حدود وبطاقات ثانوية.
  static const lightPink = Color(0xFFF8BBD0);

  /// سطح وردي ناعم — بطاقات وتمييز الآية وموضع الوقوف.
  static const softSurface = Color(0xFFFCE4EC);

  /// سطح خوخي-وردي خفيف جدًا.
  static const blushSurface = Color(0xFFFFF0F5);

  /// خلفية التطبيق العامة.
  static const background = Color(0xFFFFFBFC);

  /// ذهبي هادئ — لمسات صغيرة فقط (أرقام الآيات، شريط الإشارة).
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFF7ECD0);

  /// نص داكن خوخي-بنّي.
  static const textDark = Color(0xFF4A2B35);

  /// نص ثانوي خافت.
  static const muted = Color(0xFF8A6D76);

  /// تمييز الآية الجارية أثناء التلاوة — وردي ناعم.
  static const highlight = Color(0xFFFCE4EC);
}

ThemeData buildWirdTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: WirdColors.deepRose,
    primary: WirdColors.deepRose,
    secondary: WirdColors.gold,
    surface: WirdColors.background,
    onSurface: WirdColors.textDark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'IBMPlexSansArabic',
    scaffoldBackgroundColor: WirdColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: WirdColors.deepRose,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: WirdColors.lightPink),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WirdColors.deepRose,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: WirdColors.deepRose,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: WirdColors.softSurface,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    sliderTheme: const SliderThemeData(activeTrackColor: WirdColors.pink),
  );
}

/// أرقام عربية مشرقية (٠١٢٣) لعرض أرقام الآيات والتقدم.
String toArabicDigits(Object value) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var s = value.toString();
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(western[i], arabic[i]);
  }
  return s;
}
