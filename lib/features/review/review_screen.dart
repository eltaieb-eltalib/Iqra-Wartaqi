import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../home/home_screen.dart';
import '../range/range_picker_screen.dart';

/// وضع المراجعة: الآيات قيد التعلّم مجمّعة بحسب السورة، ونطاقات المراجعة المحفوظة.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('وضع المراجعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'راجِع ما بدأت حفظه. الآيات التالية ما زالت «قيد الحفظ»:',
            style: TextStyle(fontSize: 17, color: WirdColors.muted),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.learningAyahs(),
            builder: (context, snap) {
              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'لا توجد آيات قيد الحفظ حاليًا. علّم آياتًا أثناء الحفظ لتظهر هنا.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }
              // تجميع بحسب السورة مع نطاق من أول آية لآخر آية قيد التعلم.
              final bySurah = <int, List<int>>{};
              for (final r in rows) {
                bySurah.putIfAbsent(r['surah'] as int, () => []).add(r['ayah'] as int);
              }
              return Column(
                children: [
                  for (final entry in bySurah.entries)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.replay_circle_filled,
                            size: 34, color: WirdColors.pink),
                        title: Text(
                          '${cleanSurahName(repo.surah(entry.key))} — '
                          '${toArabicDigits(entry.value.length)} آية قيد الحفظ',
                          style: const TextStyle(fontSize: 17),
                        ),
                        subtitle: Text(
                          'من الآية ${toArabicDigits(entry.value.first)} إلى '
                          '${toArabicDigits(entry.value.last)}',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RangePickerScreen(
                              surah: repo.surah(entry.key),
                              initialFrom: entry.value.first,
                              sessionMode: 'review',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('نطاقات مراجعة محفوظة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder(
            future: db.savedRanges(),
            builder: (context, snap) {
              final ranges =
                  (snap.data ?? []).where((r) => r.kind == 'review').toList();
              if (ranges.isEmpty) {
                return const Text('لا توجد نطاقات مراجعة محفوظة.',
                    style: TextStyle(fontSize: 16, color: WirdColors.muted));
              }
              return Column(
                children: [
                  for (final r in ranges)
                    Card(
                      child: ListTile(
                        title: Text(r.title, style: const TextStyle(fontSize: 17)),
                        trailing: const Icon(Icons.play_circle, size: 30),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RangePickerScreen(
                              surah: repo.surah(r.surah),
                              initialFrom: r.fromAyah,
                              sessionMode: 'review',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
