import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../data/settings_service.dart';
import '../audio/audio_controller.dart';
import '../range/range_picker_screen.dart';

const _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

/// شاشة المصحف: نص عثماني، تمييز الآية الجارية، تمرير تلقائي،
/// والنقر على أي آية يفتح قائمة: تشغيل / تكرار / مفضلة / أتقنتها.
class MushafScreen extends StatefulWidget {
  final Surah surah;
  final int initialAyah;
  final bool autoplay;
  const MushafScreen({
    super.key,
    required this.surah,
    this.initialAyah = 1,
    this.autoplay = false,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final ItemScrollController _scroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  final Object _sessionOwner = Object();
  late final AppState _appState;
  late final AudioController _audio;
  late final SettingsService _settingsSvc;
  Set<String> _favorites = {};
  Map<int, String> _progress = {};
  int? _lastHighlighted;

  @override
  void initState() {
    super.initState();
    // نلتقط الخدمات الآن: استخدام context داخل dispose محظور وقد يرمي.
    _appState = context.read<AppState>();
    _audio = context.read<AudioController>();
    _settingsSvc = context.read<SettingsService>();
    _audio.addListener(_onAudioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = context.read<AppDatabase>();
      final app = _appState;
      await app.recordPosition(
          widget.surah.number, widget.initialAyah, cleanSurahName(widget.surah));
      await app.beginSession(widget.surah.number, 'listening',
          owner: _sessionOwner);
      final favs = await db.favoriteKeys();
      final prog = await db.progressForSurah(widget.surah.number);
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _progress = prog;
      });
      if (widget.initialAyah > 1) _jumpTo(widget.initialAyah);
      if (widget.autoplay) {
        await _audio.playSurah(
              widget.surah.number,
              fromAyah: widget.initialAyah,
              surahName: cleanSurahName(widget.surah),
            );
      }
    });
  }

  /// تمرير تلقائي لآية التلاوة الجارية — كردّ فعل على تغيّر الصوت،
  /// لا كأثر جانبي داخل build.
  void _onAudioChanged() {
    if (!mounted) return;
    if (_audio.currentSurah != widget.surah.number) return;
    final highlighted = _audio.currentAyah;
    if (highlighted != null &&
        highlighted != _lastHighlighted &&
        _settingsSvc.autoScroll) {
      _lastHighlighted = highlighted;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpTo(highlighted));
    }
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    // ننهي جلستنا نحن فقط (بمالكنا) وبلا context — dispose متزامن بطبيعته.
    _appState.endSession(owner: _sessionOwner).catchError((_) {});
    super.dispose();
  }

  void _jumpTo(int ayah) {
    if (_scroll.isAttached) {
      _scroll.scrollTo(
        index: ayah - 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
    }
  }

  Future<void> _showAyahMenu(Ayah ayah) async {
    final db = context.read<AppDatabase>();
    final audio = context.read<AudioController>();
    final app = context.read<AppState>();
    final settingsSvc = context.read<SettingsService>();
    final isFav = _favorites.contains('${ayah.surah}:${ayah.numberInSurah}');
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow, size: 30),
              title: const Text('تشغيل من هذه الآية', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat, size: 30),
              title: const Text('تكرار نطاق يبدأ من هنا', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'repeat'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add, size: 30),
              title: const Text('أنا واقف هنا', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'standing'),
            ),
            ListTile(
              leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 30),
              title: Text(isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                  style: const TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'fav'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, size: 30),
              title: const Text('أتقنتُ هذه الآية', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'mastered'),
            ),
            ListTile(
              leading: const Icon(Icons.school, size: 30),
              title: const Text('قيد الحفظ', style: TextStyle(fontSize: 18)),
              onTap: () => Navigator.pop(ctx, 'learning'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'play':
        await app.recordPosition(
            ayah.surah, ayah.numberInSurah, cleanSurahName(widget.surah));
        await audio.playSurah(ayah.surah,
            fromAyah: ayah.numberInSurah,
            surahName: cleanSurahName(widget.surah));
      case 'repeat':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RangePickerScreen(
              surah: widget.surah,
              initialFrom: ayah.numberInSurah,
            ),
          ),
        );
      case 'standing':
        await app.setStandingMarker(ayah.surah, ayah.numberInSurah);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('اتثبّت وقوفك هنا: ${cleanSurahName(widget.surah)} — '
                'الآية ${toArabicDigits(ayah.numberInSurah)}'),
          ));
        }
      case 'fav':
        await db.toggleFavorite(ayah.surah, ayah.numberInSurah);
        final favs = await db.favoriteKeys();
        if (mounted) setState(() => _favorites = favs);
      case 'mastered':
        final alreadyMastered = _progress[ayah.numberInSurah] == 'mastered';
        await db.setAyahStatus(ayah.surah, ayah.numberInSurah, 'mastered');
        if (!alreadyMastered) {
          await db.addDailyDone(1, targetAyahs: settingsSvc.dailyTarget);
        }
        await app.advanceStandingForMastered(
            ayah.surah, ayah.numberInSurah);
        if (mounted) {
          setState(() => _progress[ayah.numberInSurah] = 'mastered');
        }
      case 'learning':
        await db.setAyahStatus(ayah.surah, ayah.numberInSurah, 'learning');
        if (mounted) {
          setState(() => _progress[ayah.numberInSurah] = 'learning');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final audio = context.watch<AudioController>();
    final app = context.watch<AppState>();
    final marker = app.standingMarker;
    final standingHere = marker != null && marker.surah == widget.surah.number;
    final isCurrentSurah = audio.currentSurah == widget.surah.number;
    final highlighted = isCurrentSurah ? audio.currentAyah : null;
    final showBismillah = widget.surah.number != 1 && widget.surah.number != 9;
    return Scaffold(
      appBar: AppBar(
        title: Text(cleanSurahName(widget.surah)),
        actions: [
          IconButton(
            icon: Icon(settings.autoScroll
                ? Icons.swap_vert_circle
                : Icons.swap_vert_circle_outlined),
            tooltip: 'التمرير التلقائي',
            onPressed: () => settings.setAutoScroll(!settings.autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'تكرار نطاق',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RangePickerScreen(surah: widget.surah)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (standingHere)
            Container(
              width: double.infinity,
              color: WirdColors.softSurface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.bookmark,
                      size: 22, color: WirdColors.deepRose),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'موضع وقوفك: الآية ${toArabicDigits(marker.ayah)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: WirdColors.deepRose),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _jumpTo(marker.ayah),
                    child: const Text('الانتقال إلى موضع الوقوف',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          if (showBismillah)
            Container(
              width: double.infinity,
              color: WirdColors.goldSoft,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _bismillah,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: settings.fontSize,
                  color: WirdColors.deepRose,
                ),
              ),
            ),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              itemPositionsListener: _positions,
              itemCount: widget.surah.ayahs.length,
              itemBuilder: (context, i) {
                final ayah = widget.surah.ayahs[i];
                final isCurrent = highlighted == ayah.numberInSurah;
                final isStanding = standingHere &&
                    marker.ayah == ayah.numberInSurah;
                final status = _progress[ayah.numberInSurah];
                return Container(
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? WirdColors.highlight
                        : Colors.transparent,
                    border: isStanding
                        ? Border.all(color: WirdColors.deepRose, width: 2)
                        : null,
                    borderRadius:
                        isStanding ? BorderRadius.circular(14) : null,
                  ),
                  child: InkWell(
                    onTap: () => _showAyahMenu(ayah),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RichText(
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: settings.fontSize,
                                height: 1.9,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(text: ayah.text),
                                TextSpan(
                                  text:
                                      ' ﴿${toArabicDigits(ayah.numberInSurah)}﴾',
                                  style: const TextStyle(
                                    color: WirdColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (isStanding) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: WirdColors.deepRose,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bookmark,
                                          size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('موضع الوقوف',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'الجزء ${toArabicDigits(ayah.juz)} • صفحة '
                                '${toArabicDigits(ayah.page)}',
                                style: const TextStyle(
                                    fontSize: 13, color: WirdColors.muted),
                              ),
                              const Spacer(),
                              if (status == 'mastered')
                                const Icon(Icons.check_circle,
                                    size: 20, color: WirdColors.pink),
                              if (status == 'learning')
                                const Icon(Icons.school,
                                    size: 20, color: WirdColors.gold),
                              if (_favorites
                                  .contains('${ayah.surah}:${ayah.numberInSurah}'))
                                const Icon(Icons.favorite,
                                    size: 20, color: WirdColors.pink),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.format_size),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: 20,
                    max: 44,
                    divisions: 12,
                    label: toArabicDigits(settings.fontSize.round()),
                    onChanged: settings.setFontSize,
                  ),
                ),
                Text('حجم الخط ${toArabicDigits(settings.fontSize.round())}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
