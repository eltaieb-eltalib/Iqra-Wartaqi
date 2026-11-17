import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wird_quran/app_state.dart';
import 'package:wird_quran/core/theme.dart';
import 'package:wird_quran/data/app_database.dart';
import 'package:wird_quran/data/quran_repository.dart';
import 'package:wird_quran/features/home/home_screen.dart';

void main() {
  testWidgets('Home smoke test renders shortcuts in Arabic RTL',
      (tester) async {
    final repo = QuranRepository()
      ..loadFromStrings(
        '{"surahs":[{"number":1,"name":"سورة الفاتحة","englishName":"Al-Fatiha",'
        '"revelationType":"Meccan","ayahs":['
        '{"numberInSurah":1,"text":"بِسْمِ ٱللَّهِ","juz":1,"page":1,"hizbQuarter":1,"ruku":1}'
        ']}]}',
        '{"1":[{"ayah":1,"start":0,"end":1000}]}',
      );
    final db = AppDatabase();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: QuranRepositoryProxy(repo)),
          Provider.value(value: db),
          ChangeNotifierProvider.value(value: AppState(db)),
        ],
        child: MaterialApp(
          theme: buildWirdTheme(),
          locale: const Locale('ar'),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('بدء الحفظ'), findsOneWidget);
    expect(find.text('بدء المراجعة'), findsOneWidget);
    expect(find.text('تصفّح المصحف'), findsOneWidget);
    expect(find.text('الاستماع'), findsOneWidget);
  });
}
