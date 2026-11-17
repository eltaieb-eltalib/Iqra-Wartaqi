import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../audio/audio_controller.dart';

/// شاشة المشغّل الكاملة: تشغيل/إيقاف، تنقّل بين الآيات، تقدّم التكرار، الصوت.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _volume = context.read<AudioController>().volume;
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioController>();
    final app = context.read<AppState>();
    final seg = audio.currentSegment;
    return Scaffold(
      appBar: AppBar(title: const Text('المشغّل')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headphones, size: 84, color: WirdColors.pink),
            const SizedBox(height: 16),
            Text(
              audio.currentSurahName.isNotEmpty
                  ? audio.currentSurahName
                  : 'سورة رقم ${toArabicDigits(audio.currentSurah ?? 1)}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'الآية ${toArabicDigits(audio.currentAyah ?? 1)}',
              style: const TextStyle(fontSize: 20, color: WirdColors.muted),
            ),
            if (audio.isRepetition && seg != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: WirdColors.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  seg.fromAyah == seg.toAyah
                      ? 'الآية ${toArabicDigits(seg.fromAyah)} — التكرار '
                          '${toArabicDigits(seg.repeatIndex)}'
                          '${seg.repeatTotal > 0 ? ' من ${toArabicDigits(seg.repeatTotal)}' : ' (مستمر)'}'
                      : 'الآيات ${toArabicDigits(seg.fromAyah)} – ${toArabicDigits(seg.toAyah)} — التكرار '
                          '${toArabicDigits(seg.repeatIndex)}'
                          '${seg.repeatTotal > 0 ? ' من ${toArabicDigits(seg.repeatTotal)}' : ' (مستمر)'}',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (audio.lastError != null) ...[
              const SizedBox(height: 12),
              Text(audio.lastError!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 44,
                  icon: const Icon(Icons.skip_previous),
                  tooltip: 'السابق',
                  onPressed: audio.previousAyah,
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 76,
                  color: WirdColors.deepRose,
                  icon: Icon(audio.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled),
                  onPressed: audio.togglePlayPause,
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 44,
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'التالي',
                  onPressed: audio.nextAyah,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await audio.stopAll();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop),
              label: const Text('إيقاف التشغيل'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final s = audio.currentSurah ?? app.lastSurah;
                final a = audio.currentSurah != null
                    ? (audio.currentAyah ?? 1)
                    : (app.lastAyah ?? 1);
                if (s == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('شغّل سورة أولًا ثم ثبّت موضع وقوفك')));
                  return;
                }
                await app.setStandingMarker(s, a);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('اتثبّت وقوفك هنا: الآية ${toArabicDigits(a)}'),
                  ));
                }
              },
              icon: const Icon(Icons.bookmark_add),
              label: const Text('أنا واقف هنا'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      audio.setVolume(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),
            const Text('مستوى الصوت', style: TextStyle(color: WirdColors.muted)),
          ],
        ),
      ),
    );
  }
}
