import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/repetition_engine.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/settings_service.dart';
import '../audio/audio_controller.dart';
import '../home/home_screen.dart';

/// اختيار نطاق الآيات داخل سورة واحدة + إعدادات التكرار + بدء التشغيل.
/// تُستخدم للحفظ والمراجعة والاستماع بالتكرار.
class RangePickerScreen extends StatefulWidget {
  final Surah surah;
  final int initialFrom;
  final String sessionMode; // memorization | review | listening
  const RangePickerScreen({
    super.key,
    required this.surah,
    this.initialFrom = 1,
    this.sessionMode = 'memorization',
  });

  @override
  State<RangePickerScreen> createState() => _RangePickerScreenState();
}

class _RangePickerScreenState extends State<RangePickerScreen> {
  late int _from;
  late int _to;
  RepetitionMode _mode = RepetitionMode.perAyah;
  int _repeatCount = 3;
  int _groupSize = 5;
  late int _gap;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.surah.ayahCount;
    _gap = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<SettingsService>();
      setState(() {
        _repeatCount = s.defaultRepeatCount;
        _gap = s.defaultGapSeconds;
      });
    });
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final repo = context.read<QuranRepositoryProxy>().repo;
    final audio = context.read<AudioController>();
    final app = context.read<AppState>();
    final timings = repo.timingsFor(widget.surah.number);
    if (timings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('توقيتات الآيات غير متاحة لهذه السورة')));
      }
      return;
    }
    var count = _repeatCount;
    if (count == -2) {
      // عدد مخصص
      count = int.tryParse(_customCtrl.text.trim()) ?? 0;
      if (count < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أدخل عدد تكرار صحيحًا أكبر من صفر')));
        return;
      }
    }
    final engine = RepetitionEngine(
      config: RepetitionConfig(
        mode: _mode,
        repeatCount: count,
        groupSize: _groupSize,
        gapSeconds: _gap,
      ),
      timings: timings,
      surah: widget.surah.number,
      fromAyah: _from,
      toAyah: _to,
    );
    await app.beginSession(widget.surah.number,
        widget.sessionMode == 'review' ? 'review' : 'memorization');
    await app.recordPosition(
        widget.surah.number, _from, cleanSurahName(widget.surah));
    await audio.playRepetition(engine,
        surahName: cleanSurahName(widget.surah));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveRange() async {
    final db = context.read<AppDatabase>();
    await db.addRange(SavedRange(
      title:
          '${cleanSurahName(widget.surah)}: ${toArabicDigits(_from)} – ${toArabicDigits(_to)}',
      surah: widget.surah.number,
      fromAyah: _from,
      toAyah: _to,
      kind: widget.sessionMode,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ النطاق')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.surah.ayahCount;
    return Scaffold(
      appBar: AppBar(title: Text('نطاق التكرار – ${cleanSurahName(widget.surah)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('من الآية: ${toArabicDigits(_from)}',
              style: const TextStyle(fontSize: 18)),
          Slider(
            value: _from.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max - 1,
            onChanged: (v) => setState(() {
              _from = v.round();
              if (_to < _from) _to = _from;
            }),
          ),
          Text('إلى الآية: ${toArabicDigits(_to)}',
              style: const TextStyle(fontSize: 18)),
          Slider(
            value: _to.toDouble(),
            min: 1,
            max: max.toDouble(),
            divisions: max - 1,
            onChanged: (v) => setState(() {
              _to = v.round();
              if (_from > _to) _from = _to;
            }),
          ),
          const Divider(),
          const Text('نمط التكرار',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('كل آية وحدها'),
                selected: _mode == RepetitionMode.perAyah,
                onSelected: (_) => setState(() => _mode = RepetitionMode.perAyah),
              ),
              ChoiceChip(
                label: const Text('مجموعات آيات'),
                selected: _mode == RepetitionMode.perGroup,
                onSelected: (_) => setState(() => _mode = RepetitionMode.perGroup),
              ),
              ChoiceChip(
                label: const Text('النطاق كاملًا'),
                selected: _mode == RepetitionMode.wholeRange,
                onSelected: (_) =>
                    setState(() => _mode = RepetitionMode.wholeRange),
              ),
            ],
          ),
          if (_mode == RepetitionMode.perGroup) ...[
            const SizedBox(height: 8),
            Text('حجم المجموعة: ${toArabicDigits(_groupSize)} آيات',
                style: const TextStyle(fontSize: 17)),
            Slider(
              value: _groupSize.toDouble(),
              min: 2,
              max: 20,
              divisions: 18,
              onChanged: (v) => setState(() => _groupSize = v.round()),
            ),
          ],
          const SizedBox(height: 12),
          const Text('عدد مرات التكرار',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in [1, 2, 3, 5, 10])
                ChoiceChip(
                  label: Text(toArabicDigits(c)),
                  selected: _repeatCount == c,
                  onSelected: (_) => setState(() => _repeatCount = c),
                ),
              ChoiceChip(
                label: const Text('مستمر'),
                selected: _repeatCount == -1,
                onSelected: (_) => setState(() => _repeatCount = -1),
              ),
              ChoiceChip(
                label: const Text('عدد مخصص'),
                selected: _repeatCount == -2,
                onSelected: (_) => setState(() => _repeatCount = -2),
              ),
            ],
          ),
          if (_repeatCount == -2)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'أدخل عدد التكرار',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('الفاصل بين التكرارات: ${toArabicDigits(_gap)} ثانية (٠ = بدون فاصل)',
              style: const TextStyle(fontSize: 17)),
          Slider(
            value: _gap.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _gap = v.round()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow, size: 28),
            label: const Text('بدء التكرار'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saveRange,
            icon: const Icon(Icons.bookmark_add),
            label: const Text('حفظ هذا النطاق'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context
                      .read<AppState>()
                      .markRangeStatus(widget.surah.number, _from, _to, 'learning'),
                  child: const Text('تعليم: قيد الحفظ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context
                      .read<AppState>()
                      .markRangeStatus(widget.surah.number, _from, _to, 'mastered'),
                  child: const Text('تعليم: أتقنتها'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
