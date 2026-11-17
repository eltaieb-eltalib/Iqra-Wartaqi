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
///
/// حماية من السباقات: كل عملية تحميل تحمل رقم جيل ([_loadToken]) متزايدًا؛
/// أي عملية أقدم تتخلى بصمت بعد كل `await` إن تجاوزها جيل أحدث أو توقّف الكل.
class AudioController extends ChangeNotifier {
  final WirdAudioHandler handler;
  final QuranRepository repo;
  final DownloadService downloads;

  AudioController({required this.handler, required this.repo, required this.downloads}) {
    // أزرار التخطي في الإشعار/شاشة القفل تعمل عبر هذا المتحكم.
    handler.onSkipToNext = () => nextAyah();
    handler.onSkipToPrevious = () => previousAyah();
    handler.onStopRequested = _onHandlerStopped;
  }

  /// مزامنة الحالة عندما يأتي الإيقاف من الإشعار/النظام عبر المعالج:
  /// المشغّل توقّف أصلًا هناك، فلا نعيد إيقافه — نحدّث الحالة فقط.
  void _onHandlerStopped() {
    _loadToken++;
    _posSub?.cancel();
    _posSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    kind = PlaybackKind.idle;
    currentSegment = null;
    _engine = null;
    _safeNotify();
  }

  AudioPlayer get _player => handler.player;

  PlaybackKind kind = PlaybackKind.idle;
  int? currentSurah;

  /// اسم السورة الجاري تشغيلها فعليًا (لا آخر سورة فُتحت).
  String currentSurahName = '';
  int? currentAyah;
  RepeatSegment? currentSegment;
  RepetitionEngine? _engine;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _segmentEnding = false;
  bool _disposed = false;
  String? lastError;
  int _loadToken = 0;

  /// يُستدعى عند تغيّر الآية الجارية أثناء الاستماع (لحفظ آخر موضع).
  void Function(int surah, int ayah)? onPositionChanged;

  /// يُستدعى عند انتهاء خطة التكرار طبيعيًا أو إيقافها (لإنهاء جلستها).
  void Function()? onRepetitionFinished;

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
    final token = ++_loadToken;
    lastError = null;
    await _stopInternal();
    if (token != _loadToken) return; // تجاوزتها عملية أحدث
    kind = PlaybackKind.listening;
    currentSurah = surah;
    currentSurahName = surahName;
    try {
      final src = await _sourceFor(surah);
      if (token != _loadToken) return;
      if (src.startsWith('file://')) {
        await _player.setFilePath(src.substring(7));
      } else {
        await _player.setUrl(src);
      }
      if (token != _loadToken) return;
      final timings = repo.timingsFor(surah);
      final start = timings.where((t) => t.ayah == fromAyah).firstOrNull;
      if (start != null && start.startMs > 0) {
        await _player.seek(Duration(milliseconds: start.startMs));
      }
      if (token != _loadToken) return;
      currentAyah = fromAyah;
      handler.setNowPlaying(
        id: 'surah-$surah',
        title: surahName.isEmpty ? 'سورة رقم $surah' : surahName,
        album: 'اِقْرَأْ وَارْتَقِ – القرآن الكريم',
      );
      _watchPositionForHighlight(surah);
      await _player.play();
    } catch (e) {
      if (token != _loadToken) return;
      // فشل التحميل لا يبدأ أي تشغيل ولا يُحتسب تقدمًا.
      lastError = 'تعذّر تحميل التلاوة. تحقق من الاتصال بالإنترنت أو نزّل السورة أولًا.';
      kind = PlaybackKind.idle;
    }
    _safeNotify();
  }

  void _watchPositionForHighlight(int surah) {
    _posSub?.cancel();
    _posSub = _player.positionStream.listen(
      (pos) {
        if (kind != PlaybackKind.listening) return;
        final ayah = repo.ayahAtPosition(surah, pos);
        if (ayah != null && ayah != currentAyah) {
          currentAyah = ayah;
          onPositionChanged?.call(surah, ayah);
          _safeNotify();
        }
      },
      onError: (Object _) {
        // أخطاء تيار الموضع لا توقف التشغيل ولا تُحتسب تقدمًا.
      },
    );
  }

  /// بدء خطة تكرار عبر محرك التكرار.
  Future<void> playRepetition(RepetitionEngine engine, {String surahName = ''}) async {
    final token = ++_loadToken;
    lastError = null;
    await _stopInternal();
    if (token != _loadToken) return;
    _engine = engine;
    kind = PlaybackKind.repetition;
    currentSurah = engine.surah;
    currentSurahName = surahName;
    handler.setNowPlaying(
      id: 'rep-${engine.surah}-${engine.fromAyah}-${engine.toAyah}',
      title: surahName.isEmpty ? 'تكرار – سورة رقم ${engine.surah}' : 'تكرار – $surahName',
      album: 'اِقْرَأْ وَارْتَقِ – الحفظ والمراجعة',
    );
    RepeatSegment? first;
    try {
      first = engine.current;
    } catch (e) {
      lastError = 'نطاق التكرار غير صالح لهذه السورة.';
      kind = PlaybackKind.idle;
      _safeNotify();
      return;
    }
    if (first != null) await _playSegment(first, token);
    _safeNotify();
  }

  Future<void> _playSegment(RepeatSegment segment, int token) async {
    _segmentEnding = false;
    currentSegment = segment;
    currentAyah = segment.fromAyah;
    lastError = null;
    try {
      final src = await _sourceFor(segment.surah);
      if (token != _loadToken) return;
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
      if (token != _loadToken) return;
      _watchSegmentEnd();
      await _player.play();
    } catch (e) {
      if (token != _loadToken) return;
      // فشل التحميل/التقديم: لا تقدّم في المحرك ولا احتساب للتكرار.
      lastError = 'تعذّر تشغيل المقطع. تحقق من الاتصال أو نزّل السورة.';
      kind = PlaybackKind.idle;
      currentSegment = null;
    }
    _safeNotify();
  }

  void _watchSegmentEnd() {
    _stateSub?.cancel();
    _stateSub = _player.playerStateStream.listen(
      (state) async {
        if (kind != PlaybackKind.repetition || _segmentEnding) return;
        if (state.processingState == ProcessingState.completed) {
          _segmentEnding = true;
          await _advanceAfterCompletion();
        }
      },
      onError: (Object _) {
        // خطأ في تيار المشغّل أثناء مقطع: لا تقدّم في المحرك، نعرض الخطأ ونقف.
        if (kind != PlaybackKind.repetition) return;
        lastError = 'حدث خطأ أثناء التشغيل. أعد المحاولة.';
        kind = PlaybackKind.idle;
        currentSegment = null;
        _safeNotify();
      },
    );
  }

  Future<void> _advanceAfterCompletion() async {
    final engine = _engine;
    if (engine == null) return;
    final token = _loadToken;
    // المقطع اكتمل فعليًا فقط الآن يُحتسب.
    final next = engine.onSegmentCompleted();
    if (next == null) {
      kind = PlaybackKind.idle;
      currentSegment = null;
      onRepetitionFinished?.call();
      _safeNotify();
      return;
    }
    final gap = engine.gapSeconds;
    if (gap > 0) {
      await Future.delayed(Duration(seconds: gap));
      // أُوقف الكل أو بدأت خطة أحدث أثناء الفاصل؟ لا تشغّل مقطع الخطة القديمة.
      if (_disposed ||
          kind != PlaybackKind.repetition ||
          token != _loadToken ||
          !identical(_engine, engine)) {
        return;
      }
    }
    await _playSegment(next, token);
  }

  Future<void> togglePlayPause() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      lastError = 'حدث خطأ أثناء التشغيل. أعد المحاولة.';
    }
    _safeNotify();
  }

  Future<void> nextAyah() async {
    if (currentSurah == null) return;
    if (isRepetition) {
      // تخطٍّ يدوي: لا يُحتسب تكرارًا ولا يستهلك تكرارًا من الآية الحالية؛
      // ننتقل إلى الوحدة التالية مباشرة.
      final engine = _engine;
      if (engine == null) return;
      final token = ++_loadToken;
      final next = engine.skipToNextUnit();
      if (next == null) {
        await stopAll();
      } else {
        await _playSegment(next, token);
      }
      return;
    }
    try {
      final timings = repo.timingsFor(currentSurah!);
      final next = (currentAyah ?? 1) + 1;
      final t = timings.where((e) => e.ayah == next).firstOrNull;
      if (t != null) {
        await _player.seek(Duration(milliseconds: t.startMs));
        currentAyah = next;
        _safeNotify();
      }
    } catch (_) {
      lastError = 'تعذّر الانتقال إلى الآية التالية.';
      _safeNotify();
    }
  }

  Future<void> previousAyah() async {
    if (currentSurah == null) return;
    try {
      final timings = repo.timingsFor(currentSurah!);
      final prev = (currentAyah ?? 1) - 1;
      final t = timings.where((e) => e.ayah == (prev < 1 ? 1 : prev)).firstOrNull;
      if (t != null) {
        if (isRepetition) {
          // في وضع التكرار: إعادة المقطع الحالي من بدايته.
          final seg = currentSegment;
          if (seg != null) await _playSegment(seg, _loadToken);
        } else {
          await _player.seek(Duration(milliseconds: t.startMs));
          currentAyah = t.ayah;
        }
        _safeNotify();
      }
    } catch (_) {
      lastError = 'تعذّر الانتقال إلى الآية السابقة.';
      _safeNotify();
    }
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  /// مستوى الصوت الحالي للمشغّل (لعرضه في شاشة المشغّل).
  double get volume => _player.volume;

  Future<void> stopAll() async {
    _loadToken++; // إبطال أي تحميل أو فاصل قيد الانتظار
    final wasRepetition = kind == PlaybackKind.repetition;
    await _stopInternal();
    if (wasRepetition) onRepetitionFinished?.call();
    kind = PlaybackKind.idle;
    currentSegment = null;
    _engine = null;
    try {
      // إيقاف عبر المعالج أيضًا: يفكّ الخدمة الأمامية ويزيل الإشعار.
      await handler.stop();
    } catch (_) {
      // المشغّل توقّف أصلًا عبر _stopInternal.
    }
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
