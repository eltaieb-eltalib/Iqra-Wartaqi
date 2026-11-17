import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../home/home_screen.dart';
import '../mushaf/mushaf_screen.dart';
import '../range/range_picker_screen.dart';

/// المفضلة: آيات مفضلة + نطاقات محفوظة، والنقر يفتح أو يشغّل.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة والمحفوظات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('الآيات المفضلة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.favorites(),
            builder: (context, snap) {
              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return const Text('لا توجد آيات مفضلة بعد.',
                    style: TextStyle(fontSize: 16, color: WirdColors.muted));
              }
              return Column(
                children: [
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.favorite, color: WirdColors.pink),
                        title: Text(
                          '${cleanSurahName(repo.surah(r['surah'] as int))} — '
                          'الآية ${toArabicDigits(r['ayah'] as int)}',
                          style: const TextStyle(fontSize: 17),
                        ),
                        subtitle: Text(
                          repo.ayah(r['surah'] as int, r['ayah'] as int).text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'AmiriQuran'),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MushafScreen(
                              surah: repo.surah(r['surah'] as int),
                              initialAyah: r['ayah'] as int,
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
          const Text('النطاقات المحفوظة والورد اليومي',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder(
            future: db.savedRanges(),
            builder: (context, snap) {
              final ranges = snap.data ?? [];
              if (ranges.isEmpty) {
                return const Text('لا توجد نطاقات محفوظة بعد.',
                    style: TextStyle(fontSize: 16, color: WirdColors.muted));
              }
              return Column(
                children: [
                  for (final r in ranges)
                    Card(
                      child: ListTile(
                        title: Text(r.title, style: const TextStyle(fontSize: 17)),
                        subtitle: Text(switch (r.kind) {
                          'memorization' => 'نطاق حفظ',
                          'review' => 'نطاق مراجعة',
                          _ => 'قائمة مخصصة / ورد يومي',
                        }),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'حذف النطاق',
                          onPressed: () async {
                            await db.deleteRange(r.id!);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حذف النطاق')));
                            }
                          },
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RangePickerScreen(
                              surah: repo.surah(r.surah),
                              initialFrom: r.fromAyah,
                              sessionMode: r.kind,
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
