import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/repetition_engine.dart';
import '../../data/download_service.dart';
import '../../data/quran_repository.dart';
import 'wird_audio_handler.dart';

enum PlaybackKind { idle, listening, repetition }

/// وحدة التحكم المركزية في التشغيل: تمنع أي تداخل، وتقود محرك التكرار.
/// لا يُحتسب أي تكرار مكتملًا إلا عند بلوغ نهاية المقطع فعليًا.
class AudioController extends ChangeNotifier {
  final WirdAudioHandler handler;
  final QuranRepository repo;
  final DownloadService downloads;

  AudioController({required this.handler, required this.repo, required this.downloads});

  AudioPlayer get _player => handler.player;

  PlaybackKind kind = PlaybackKind.idle;
  int? currentSurah;
  int? currentAyah;
  RepeatSegment? currentSegment;
  RepetitionEngine? _engine;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _segmentEnding = false;
  bool _disposed = false;
  String? lastError;

  bool get isPlaying => _player.playing;
  bool get isRepetition => kind == PlaybackKind.repetition;
  Duration get position => _player.position;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<bool> get playingStream => _player.playingStream;

  int? get currentRepeatIndex => currentSegment?.repeatIndex;
  int? get currentRepeatTotal => currentSegment?.repeatTotal;

  Future<String> _sourceFor(int surah) async {
    if (await downloads.isDownloaded(surah)) {
      final f = await downloads.fileFor(surah);
      return 'file://${f.path}';
    }
    return DownloadService.surahUrl(surah);
  }

  /// تشغيل سورة كاملة (وضع الاستماع) ابتداءً من آية اختيارية.
  Future<void> playSurah(int surah, {int fromAyah = 1, String surahName = ''}) async {
    await _stopInternal();
    kind = PlaybackKind.listening;
    currentSurah = surah;
    try {
      final src = await _sourceFor(surah);
      if (src.startsWith('file://')) {
        await _player.setFilePath(src.substring(7));
      } else {
        await _player.setUrl(src);
      }
      final timings = repo.timingsFor(surah);
      final start = timings.where((t) => t.ayah == fromAyah).firstOrNull;
      if (start != null && start.startMs > 0) {
        await _player.seek(Duration(milliseconds: start.startMs));
      }
      currentAyah = fromAyah;
      handler.setNowPlaying(
        id: 'surah-$surah',
        title: surahName.isEmpty ? 'سورة رقم $surah' : surahName,
        album: 'اِقْرَأْ وَارْتَقِ – القرآن الكريم',
      );
      _watchPositionForHighlight(surah);
      await _player.play();
    } catch (e) {
      // فشل التحميل لا يبدأ أي تشغيل ولا يُحتسب تقدمًا.
      lastError = 'تعذّر تحميل التلاوة. تحقق من الاتصال بالإنترنت أو نزّل السورة أولًا.';
      kind = PlaybackKind.idle;
    }
    _safeNotify();
  }

  void _watchPositionForHighlight(int surah) {
    _posSub?.cancel();
    _posSub = _player.positionStream.listen((pos) {
      if (kind != PlaybackKind.listening) return;
      final ayah = repo.ayahAtPosition(surah, pos);
      if (ayah != null && ayah != currentAyah) {
        currentAyah = ayah;
        _safeNotify();
      }
    });
  }

  /// بدء خطة تكرار عبر محرك التكرار.
  Future<void> playRepetition(RepetitionEngine engine, {String surahName = ''}) async {
    await _stopInternal();
    _engine = engine;
    kind = PlaybackKind.repetition;
    currentSurah = engine.surah;
    handler.setNowPlaying(
      id: 'rep-${engine.surah}-${engine.fromAyah}-${engine.toAyah}',
      title: surahName.isEmpty ? 'تكرار – سورة رقم ${engine.surah}' : 'تكرار – $surahName',
      album: 'اِقْرَأْ وَارْتَقِ – الحفظ والمراجعة',
    );
    final first = engine.current;
    if (first != null) await _playSegment(first);
    _safeNotify();
  }

  Future<void> _playSegment(RepeatSegment segment) async {
    _segmentEnding = false;
    currentSegment = segment;
    currentAyah = segment.fromAyah;
    try {
      final src = await _sourceFor(segment.surah);
      // تشغيل مقطع دقيق بقصّ المصدر بين بداية الآية ونهايتها.
      final clip = ClippingAudioSource(
        child: src.startsWith('file://')
            ? AudioSource.file(src.substring(7))
            : AudioSource.uri(Uri.parse(src)),
        start: Duration(milliseconds: segment.startMs),
        end: Duration(milliseconds: segment.endMs),
        tag: 'seg-${segment.surah}-${segment.fromAyah}-${segment.repeatIndex}',
      );
      await _player.setAudioSource(clip);
      _watchSegmentEnd();
      await _player.play();
    } catch (e) {
      // فشل التحميل/التقديم: لا تقدّم في المحرك ولا احتساب للتكرار.
      lastError = 'تعذّر تشغيل المقطع. تحقق من الاتصال أو نزّل السورة.';
      kind = PlaybackKind.idle;
      currentSegment = null;
    }
    _safeNotify();
  }

  void _watchSegmentEnd() {
    _stateSub?.cancel();
    _stateSub = _player.playerStateStream.listen((state) async {
      if (kind != PlaybackKind.repetition || _segmentEnding) return;
      if (state.processingState == ProcessingState.completed) {
        _segmentEnding = true;
        await _advanceAfterCompletion();
      }
    });
  }

  Future<void> _advanceAfterCompletion() async {
    final engine = _engine;
    if (engine == null) return;
    // المقطع اكتمل فعليًا فقط الآن يُحتسب.
    final next = engine.onSegmentCompleted();
    if (next == null) {
      kind = PlaybackKind.idle;
      currentSegment = null;
      _safeNotify();
      return;
    }
    final gap = engine.gapSeconds;
    if (gap > 0) {
      await Future.delayed(Duration(seconds: gap));
      if (_disposed || kind != PlaybackKind.repetition) return;
    }
    await _playSegment(next);
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _safeNotify();
  }

  Future<void> nextAyah() async {
    if (currentSurah == null) return;
    if (isRepetition) {
      // تخطٍّ يدوي: لا يُحتسب تكرارًا؛ ننتقل للمقطع التالي في الخطة إن وجد.
      final engine = _engine;
      if (engine == null) return;
      final next = engine.onSegmentCompleted();
      if (next == null) {
        await stopAll();
      } else {
        await _playSegment(next);
      }
      return;
    }
    final timings = repo.timingsFor(currentSurah!);
    final next = (currentAyah ?? 1) + 1;
    final t = timings.where((e) => e.ayah == next).firstOrNull;
    if (t != null) {
      await _player.seek(Duration(milliseconds: t.startMs));
      currentAyah = next;
      _safeNotify();
    }
  }

  Future<void> previousAyah() async {
    if (currentSurah == null) return;
    final timings = repo.timingsFor(currentSurah!);
    final prev = (currentAyah ?? 1) - 1;
    final t = timings.where((e) => e.ayah == (prev < 1 ? 1 : prev)).firstOrNull;
    if (t != null) {
      if (isRepetition) {
        // في وضع التكرار: إعادة المقطع الحالي من بدايته.
        final seg = currentSegment;
        if (seg != null) await _playSegment(seg);
      } else {
        await _player.seek(Duration(milliseconds: t.startMs));
        currentAyah = t.ayah;
      }
      _safeNotify();
    }
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  Future<void> stopAll() async {
    await _stopInternal();
    kind = PlaybackKind.idle;
    currentSegment = null;
    _engine = null;
    _safeNotify();
  }

  Future<void> _stopInternal() async {
    _posSub?.cancel();
    _posSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    try {
      await _player.stop();
    } catch (_) {
      // تجاهل: إيقاف مشغّل خامل.
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _posSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
