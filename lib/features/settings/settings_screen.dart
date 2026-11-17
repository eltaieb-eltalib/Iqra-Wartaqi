import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/download_service.dart';
import '../../data/settings_service.dart';
import '../home/home_screen.dart';
import 'about_screen.dart';

/// الإعدادات + إدارة التنزيلات (تنزيل/حذف كل سورة وحجم التخزين المستخدم).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _fmtBytes(int b) {
    if (b < 1024 * 1024) return '${toArabicDigits((b / 1024).toStringAsFixed(0))} كيلوبايت';
    return '${toArabicDigits((b / (1024 * 1024)).toStringAsFixed(1))} ميغابايت';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final downloads = context.watch<DownloadService>();
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('العرض والتشغيل',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          ListTile(
            title: Text('حجم خط المصحف: ${toArabicDigits(settings.fontSize.round())}'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 20,
              max: 44,
              divisions: 12,
              onChanged: settings.setFontSize,
            ),
          ),
          SwitchListTile(
            title: const Text('التمرير التلقائي مع التلاوة',
                style: TextStyle(fontSize: 17)),
            value: settings.autoScroll,
            onChanged: settings.setAutoScroll,
          ),
          SwitchListTile(
            title: const Text(
                'تقديم علامة الوقوف تلقائيًا عند إتقان آية',
                style: TextStyle(fontSize: 17)),
            subtitle: const Text(
                'عند إتقان آية عند موضع وقوفك أو بعده، تنتقل العلامة للآية التالية وحدها'),
            value: settings.autoAdvanceStanding,
            onChanged: settings.setAutoAdvanceStanding,
          ),
          if (settings.standingSurah != null)
            ListTile(
              leading: const Icon(Icons.bookmark,
                  color: WirdColors.deepRose, size: 28),
              title: Text(
                  'موضع وقوفك الحالي: سورة رقم '
                  '${toArabicDigits(settings.standingSurah!)} — الآية '
                  '${toArabicDigits(settings.standingAyah ?? 1)}',
                  style: const TextStyle(fontSize: 16)),
              trailing: IconButton(
                icon: const Icon(Icons.bookmark_remove_outlined),
                tooltip: 'مسح علامة الوقوف',
                onPressed: () =>
                    context.read<AppState>().clearStandingMarker(),
              ),
            ),
          ListTile(
            title: Text(
                'الفاصل الافتراضي بين التكرارات: ${toArabicDigits(settings.defaultGapSeconds)} ثانية'),
            subtitle: Slider(
              value: settings.defaultGapSeconds.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => settings.setGapSeconds(v.round()),
            ),
          ),
          ListTile(
            title: Text(
                'عدد التكرار الافتراضي: ${toArabicDigits(settings.defaultRepeatCount)}'),
            subtitle: Slider(
              value: settings.defaultRepeatCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => settings.setRepeatCount(v.round()),
            ),
          ),
          ListTile(
            title: Text(
                'الهدف اليومي: ${toArabicDigits(settings.dailyTarget)} آية'),
            subtitle: Slider(
              value: settings.dailyTarget.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (v) async {
                await settings.setDailyTarget(v.round());
                await db.setDailyTarget(v.round());
              },
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('القارئ', style: TextStyle(fontSize: 17)),
            subtitle: Text(
              'الشيخ الزين محمد أحمد — رواية حفص عن عاصم، ترتيل. '
              'المصدر: mp3quran.net (بث مباشر، والتنزيل بطلب المستخدم).',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ListTile(
            title: const Text('المصادر والحقوق والتراخيص',
                style: TextStyle(fontSize: 17)),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          const Divider(),
          const Text('إدارة التنزيلات (للاستماع دون إنترنت)',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FutureBuilder<int>(
            future: downloads.totalDownloadedBytes(),
            builder: (context, snap) => Text(
              'حجم التخزين المستخدم: ${_fmtBytes(snap.data ?? 0)}',
              style: const TextStyle(fontSize: 16, color: WirdColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          for (final s in repo.surahs)
            FutureBuilder<bool>(
              future: downloads.isDownloaded(s.number),
              builder: (context, snap) {
                final downloaded = snap.data ?? false;
                final prog = downloads.progress[s.number];
                return ListTile(
                  title: Text(
                    '${toArabicDigits(s.number)}. ${s.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  subtitle: prog != null
                      ? LinearProgressIndicator(value: prog)
                      : Text(downloaded ? 'محمّلة — تعمل دون إنترنت' : 'غير محمّلة'),
                  trailing: downloaded
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'حذف التنزيل',
                          onPressed: () => downloads.delete(s.number),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'تنزيل السورة',
                          onPressed: prog == null
                              ? () async {
                                  final ok = await downloads.download(s.number);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'اكتمل تنزيل ${s.name}'
                                            : 'فشل التنزيل — تحقق من الإنترنت'),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}
