import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../home/home_screen.dart';
import '../mushaf/mushaf_screen.dart';

/// فهرس السور الـ114 مع بحث بالاسم أو الرقم وتصفية اختيارية بالجزء.
class SurahIndexScreen extends StatefulWidget {
  final bool listenMode;
  const SurahIndexScreen({super.key, this.listenMode = false});

  @override
  State<SurahIndexScreen> createState() => _SurahIndexScreenState();
}

class _SurahIndexScreenState extends State<SurahIndexScreen> {
  String _query = '';
  int? _juzFilter;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepositoryProxy>().repo;
    final app = context.watch<AppState>();
    final marker = app.standingMarker;
    var list = repo.searchSurahs(_query);
    if (_juzFilter != null) {
      list = list.where((s) => s.juz == _juzFilter).toList();
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.listenMode ? 'الاستماع – اختر سورة' : 'فهرس السور')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'ابحث باسم السورة أو رقمها…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: const Text('كل الأجزاء'),
                    selected: _juzFilter == null,
                    onSelected: (_) => setState(() => _juzFilter = null),
                  ),
                ),
                for (var j = 1; j <= 30; j++)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text('الجزء ${toArabicDigits(j)}'),
                      selected: _juzFilter == j,
                      onSelected: (_) => setState(() => _juzFilter = j),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final Surah s = list[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: ListTile(
                    minTileHeight: 68,
                    leading: CircleAvatar(
                      backgroundColor: WirdColors.deepRose,
                      foregroundColor: Colors.white,
                      child: Text(toArabicDigits(s.number)),
                    ),
                    title: Text(cleanSurahName(s),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${s.revelationType == 'Meccan' ? 'مكية' : 'مدنية'} — '
                      '${toArabicDigits(s.ayahCount)} آية — الجزء ${toArabicDigits(s.juz)}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (marker != null && marker.surah == s.number)
                          const Icon(Icons.bookmark,
                              size: 26, color: WirdColors.deepRose),
                        const Icon(Icons.chevron_left, size: 28),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MushafScreen(
                          surah: s,
                          autoplay: widget.listenMode,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
