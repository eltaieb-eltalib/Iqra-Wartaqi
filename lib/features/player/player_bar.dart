import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../audio/audio_controller.dart';
import 'player_screen.dart';

/// شريط المشغّل المصغّر الدائم أسفل الشاشات.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioController>();
    if (audio.kind == PlaybackKind.idle || audio.currentSurah == null) {
      return const SizedBox.shrink();
    }
    final title = audio.currentSurahName.isNotEmpty
        ? audio.currentSurahName
        : 'سورة رقم ${toArabicDigits(audio.currentSurah!)}';
    final repeatInfo = audio.isRepetition && audio.currentSegment != null
        ? ' — التكرار ${toArabicDigits(audio.currentRepeatIndex ?? 1)}'
            '${(audio.currentRepeatTotal ?? 0) > 0 ? ' من ${toArabicDigits(audio.currentRepeatTotal!)}' : ''}'
        : '';
    return Material(
      color: WirdColors.deepRose,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlayerScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                iconSize: 34,
                color: Colors.white,
                icon: Icon(audio.isPlaying ? Icons.pause_circle : Icons.play_circle),
                onPressed: audio.togglePlayPause,
              ),
              Expanded(
                child: Text(
                  '$title — الآية ${toArabicDigits(audio.currentAyah ?? 1)}$repeatInfo',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.skip_next, size: 30),
                tooltip: 'الآية التالية',
                onPressed: audio.nextAyah,
              ),
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.stop_circle_outlined, size: 30),
                tooltip: 'إيقاف',
                onPressed: audio.stopAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
