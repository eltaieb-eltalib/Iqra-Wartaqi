import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../home/home_screen.dart';
import '../range/range_picker_screen.dart';
import '../surah_index/surah_index_screen.dart';

/// وضع الحفظ: متابعة آخر موضع، النطاقات المحفوظة للحفظ، واختيار نطاق جديد.
class MemorizeScreen extends StatelessWidget {
  const MemorizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final app = context.watch<AppState>();
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('وضع الحفظ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'احفظ آيات جديدة بالتكرار المنظّم: اختر النطاق وعدد مرات تكرار كل آية.',
            style: TextStyle(fontSize: 17, color: WirdColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SurahIndexScreen()),
            ),
            icon: const Icon(Icons.add_circle),
            label: const Text('نطاق حفظ جديد — اختر سورة'),
          ),
          if (app.lastSurah != null && repo.isLoaded) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final surah = repo.surah(app.lastSurah!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RangePickerScreen(
                      surah: surah,
                      initialFrom: app.lastAyah ?? 1,
                      sessionMode: 'memorization',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: Text('متابعة من ${app.lastSurahName} — الآية '
                  '${toArabicDigits(app.lastAyah ?? 1)}'),
            ),
          ],
          const SizedBox(height: 20),
          const Text('نطاقات الحفظ المحفوظة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder(
            future: db.savedRanges(),
            builder: (context, snap) {
              final ranges = (snap.data ?? [])
                  .where((r) => r.kind == 'memorization' || r.kind == 'custom')
                  .toList();
              if (ranges.isEmpty) {
                return const Text('لا توجد نطاقات محفوظة بعد.',
                    style: TextStyle(fontSize: 16, color: WirdColors.muted));
              }
              return Column(
                children: [
                  for (final r in ranges)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(r.title,
                                style: const TextStyle(fontSize: 17)),
                            trailing: const Icon(Icons.play_circle, size: 30),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RangePickerScreen(
                                  surah: repo.surah(r.surah),
                                  initialFrom: r.fromAyah,
                                  initialTo: r.toAyah,
                                  sessionMode: 'memorization',
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(start: 8),
                              child: TextButton.icon(
                                onPressed: () async {
                                  await app.setStandingMarker(
                                      r.surah, r.toAyah);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'اتثبّت وقوفك عند آخر آية في النطاق: '
                                          'الآية ${toArabicDigits(r.toAyah)}'),
                                    ));
                                  }
                                },
                                icon: const Icon(Icons.bookmark_add),
                                label: const Text(
                                    'ثبّت وقوفي عند آخر آية في النطاق'),
                              ),
                            ),
                          ),
                        ],
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
