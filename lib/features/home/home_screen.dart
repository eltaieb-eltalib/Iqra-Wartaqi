import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/standing_marker.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/quran_repository.dart';
import '../favorites/favorites_screen.dart';
import '../memorize/memorize_screen.dart';
import '../mushaf/mushaf_screen.dart';
import '../range/range_picker_screen.dart';
import '../review/review_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../surah_index/surah_index_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final app = context.watch<AppState>();
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('اِقْرَأْ وَارْتَقِ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'المصادر والحقوق',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'بسم الله الرحمن الرحيم',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 26,
              color: WirdColors.deepRose,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'تلاوة الشيخ الزين محمد أحمد — حفظٌ ومراجعةٌ بتكرارٍ دقيق للآيات',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: WirdColors.muted),
          ),
          const SizedBox(height: 16),
          if (repo.isLoaded) _StandingCard(app: app, repo: repo),
          const SizedBox(height: 12),
          FutureBuilder<({int target, int done})>(
            future: db.todayGoal(),
            builder: (context, snap) {
              final goal = snap.data ?? (target: 10, done: 0);
              final pct = goal.target == 0
                  ? 0.0
                  : (goal.done / goal.target).clamp(0.0, 1.0);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 8,
                              color: WirdColors.pink,
                              backgroundColor: WirdColors.softSurface,
                            ),
                            Text('${toArabicDigits((pct * 100).round())}٪',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'هدف اليوم: ${toArabicDigits(goal.done)} من '
                          '${toArabicDigits(goal.target)} آية',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (app.lastSurah != null && repo.isLoaded) ...[
            const SizedBox(height: 8),
            Card(
              color: WirdColors.softSurface,
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill,
                    size: 40, color: WirdColors.deepRose),
                title: Text(
                  'متابعة آخر جلسة: ${app.lastSurahName} — الآية '
                  '${toArabicDigits(app.lastAyah ?? 1)}',
                  style: const TextStyle(fontSize: 17),
                ),
                onTap: () {
                  final surah = repo.surah(app.lastSurah!);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MushafScreen(
                        surah: surah,
                        initialAyah: app.lastAyah ?? 1,
                        autoplay: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          _ShortcutGrid(),
        ],
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Widget)>[
      (Icons.school, 'بدء الحفظ', const MemorizeScreen()),
      (Icons.replay_circle_filled, 'بدء المراجعة', const ReviewScreen()),
      (Icons.menu_book, 'تصفّح المصحف', const SurahIndexScreen()),
      (Icons.headphones, 'الاستماع', const SurahIndexScreen(listenMode: true)),
      (Icons.bar_chart, 'الإنجاز والإحصائيات', const StatsScreen()),
      (Icons.favorite, 'المفضلة', const FavoritesScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (final (icon, label, screen) in items)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => screen)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 42, color: WirdColors.deepRose),
                  const SizedBox(height: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// بطاقة «واقف وين؟» — علامة الوقوف في الحفظ، بأزرار متابعة حقيقية.
class _StandingCard extends StatelessWidget {
  final AppState app;
  final QuranRepository repo;
  const _StandingCard({required this.app, required this.repo});

  String _dayLabel(DateTime? t) {
    final d = StandingMarkerLogic.daysSince(t, DateTime.now());
    if (d == 0) return 'ثبّتّها اليوم';
    if (d == 1) return 'من أمس';
    if (d == 2) return 'منذ يومين';
    if (d <= 10) return 'منذ ${toArabicDigits(d)} أيام';
    return 'منذ ${toArabicDigits(d)} يومًا';
  }

  @override
  Widget build(BuildContext context) {
    final marker = app.standingMarker;
    if (marker != null && (marker.surah < 1 || marker.surah > 114)) {
      // علامة خارج النطاق (بيانات تالفة): تجاهلها بدل إسقاط الشاشة.
      return const SizedBox.shrink();
    }
    if (marker == null) {
      return Card(
        color: WirdColors.blushSurface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.bookmark_border,
                      size: 28, color: WirdColors.deepRose),
                  SizedBox(width: 8),
                  Text('واقف وين؟',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: WirdColors.deepRose)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'ثبّت علامة عند آخر آية حفظتها، عشان ما تنسى وقفت وين — '
                'وكمّل منها في أي وقت.',
                style: TextStyle(fontSize: 16, color: WirdColors.textDark),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SurahIndexScreen()),
                ),
                icon: const Icon(Icons.bookmark_add),
                label: const Text('حدّد موضع وقوفك'),
              ),
            ],
          ),
        ),
      );
    }
    final surah = repo.surah(marker.surah);
    final surahName = cleanSurahName(surah);
    Widget btn(String label, IconData icon, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: WirdColors.deepRose,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WirdColors.deepRose, WirdColors.pink],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33AD1457), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.bookmark, size: 28, color: Colors.white),
              SizedBox(width: 8),
              Text('واقف وين؟',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$surahName — الآية ${toArabicDigits(marker.ayah)}',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'آخر تحديث: ${_dayLabel(app.standingUpdatedAt)}',
            style: const TextStyle(fontSize: 15, color: WirdColors.lightPink),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              btn('كمّل من هنا', Icons.menu_book, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MushafScreen(
                        surah: surah, initialAyah: marker.ayah),
                  ),
                );
              }),
              btn('اسمع من هنا', Icons.headphones, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MushafScreen(
                        surah: surah,
                        initialAyah: marker.ayah,
                        autoplay: true),
                  ),
                );
              }),
              btn('كرّر من هنا', Icons.repeat, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RangePickerScreen(
                        surah: surah, initialFrom: marker.ayah),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

/// وكيل بسيط لحمل المستودع داخل شجرة Provider دون جعله ChangeNotifier.
class QuranRepositoryProxy {
  final QuranRepository repo;
  const QuranRepositoryProxy(this.repo);
}
