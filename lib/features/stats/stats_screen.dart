import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';

/// الإنجاز والإحصائيات من قاعدة البيانات المحلية.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    return Scaffold(
      appBar: AppBar(title: const Text('الإنجاز والإحصائيات')),
      body: FutureBuilder(
        future: Future.wait([
          db.progressCounts(),
          db.sessionSecondsSince(todayStart),
          db.sessionSecondsSince(weekStart),
          db.todayGoal(),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final counts = snap.data![0] as Map<String, int>;
          final todaySec = snap.data![1] as int;
          final weekSec = snap.data![2] as int;
          final goal = snap.data![3] as ({int target, int done});
          final mastered = counts['mastered'] ?? 0;
          final learning = counts['learning'] ?? 0;
          final pct = (mastered / 6236 * 100);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.check_circle,
                title: 'آيات أتقنتها',
                value: '${toArabicDigits(mastered)} آية '
                    '(${toArabicDigits(pct.toStringAsFixed(1))}٪ من القرآن)',
              ),
              _StatCard(
                icon: Icons.school,
                title: 'آيات قيد الحفظ',
                value: '${toArabicDigits(learning)} آية',
              ),
              _StatCard(
                icon: Icons.today,
                title: 'هدف اليوم',
                value: '${toArabicDigits(goal.done)} من '
                    '${toArabicDigits(goal.target)} آية',
              ),
              _StatCard(
                icon: Icons.timer,
                title: 'مدة الجلسات اليوم',
                value: '${toArabicDigits((todaySec / 60).ceil())} دقيقة',
              ),
              _StatCard(
                icon: Icons.date_range,
                title: 'مدة الجلسات هذا الأسبوع',
                value: '${toArabicDigits((weekSec / 60).ceil())} دقيقة',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (mastered / 6236).clamp(0.0, 1.0),
                minHeight: 14,
                color: WirdColors.pink,
                backgroundColor: WirdColors.softSurface,
              ),
              const SizedBox(height: 6),
              const Text(
                'شريط التقدّم يمثّل نسبة الآيات المتقنة من كامل القرآن الكريم (٦٢٣٦ آية).',
                style: TextStyle(color: WirdColors.muted, fontSize: 14),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _StatCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 36, color: WirdColors.deepRose),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        trailing: Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
