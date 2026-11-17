import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// معالج الصوت الخلفي: مشغّل واحد فقط (just_audio) داخل audio_service،
/// مع معالجة مقاطعات الصوت (المكالمات وغيرها) عبر audio_session.
class WirdAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();
  StreamSubscription<PlaybackEvent>? _eventSub;

  WirdAudioHandler() {
    _initSession();
    _eventSub = player.playbackEventStream.listen((_) => _broadcastState());
    player.processingStateStream.listen((_) => _broadcastState());
    player.playingStream.listen((_) => _broadcastState());
  }

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // مقاطعة (مكالمة...): إيقاف مؤقت، والاستئناف فقط إذا سمح النظام.
        if (player.playing) player.pause();
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      if (player.playing) player.pause();
    });
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
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  Future<void> dispose() async {
    await _eventSub?.cancel();
    await player.dispose();
  }
}
