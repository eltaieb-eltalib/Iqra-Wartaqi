import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// معالج الصوت الخلفي: مشغّل واحد فقط (just_audio) داخل audio_service،
/// مع معالجة مقاطعات الصوت (المكالمات وغيرها) عبر audio_session.
///
/// أزرار التخطي/الإيقاف في الإشعار وشاشة القفل تُفوَّض إلى [AudioController]
/// عبر هذه الحقول (تُضبط عند إنشاء المتحكم)، لأن منطق الآيات والتكرار عنده.
class WirdAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  /// تفويض «التالي» من الإشعار (يضبطه AudioController).
  Future<void> Function()? onSkipToNext;

  /// تفويض «السابق» من الإشعار (يضبطه AudioController).
  Future<void> Function()? onSkipToPrevious;

  /// يُستدعى بعد توقّف المشغّل من الإشعار/النظام لمزامنة حالة المتحكم.
  void Function()? onStopRequested;

  WirdAudioHandler() {
    _initSession();
    _subs.add(player.playbackEventStream.listen((_) => _broadcastState()));
    _subs.add(player.processingStateStream.listen((_) => _broadcastState()));
    _subs.add(player.playingStream.listen((_) => _broadcastState()));
  }

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _subs.add(session.interruptionEventStream.listen((event) {
        if (event.begin) {
          // مقاطعة (مكالمة...): إيقاف مؤقت، والاستئناف فقط إذا سمح النظام.
          if (player.playing) player.pause();
        }
      }));
      _subs.add(session.becomingNoisyEventStream.listen((_) {
        if (player.playing) player.pause();
      }));
    } catch (_) {
      // تعذّرت تهيئة جلسة الصوت: التشغيل الأساسي يعمل دون معالجة المقاطعات.
    }
  }

  void _broadcastState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: switch (player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  void setNowPlaying({required String id, required String title, required String album}) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      album: album,
      artist: 'الشيخ الزين محمد أحمد',
      artUri: null,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
    onStopRequested?.call();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final f = onSkipToNext;
    if (f != null) await f();
  }

  @override
  Future<void> skipToPrevious() async {
    final f = onSkipToPrevious;
    if (f != null) await f();
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await player.dispose();
  }
}
