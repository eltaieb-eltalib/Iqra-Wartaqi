/// محرك تكرار الآيات — Dart نقي دون أي اعتماد على مشغّل الصوت.
///
/// يبني قائمة مقاطع مرتبة من توقيتات الآيات، ولا يتقدّم إلا عندما يُبلّغ
/// المشغّل عن اكتمال تشغيل المقطع فعليًا عبر [onSegmentCompleted].
/// فشل التحميل أو التقديم لا يُحتسب تكرارًا مكتملًا أبدًا.
library;

/// توقيت آية واحدة بالملي ثانية داخل ملف السورة.
class AyahTiming {
  final int ayah;
  final int startMs;
  final int endMs;
  const AyahTiming({required this.ayah, required this.startMs, required this.endMs});

  factory AyahTiming.fromJson(Map<String, dynamic> j) => AyahTiming(
        ayah: (j['ayah'] as num).toInt(),
        startMs: (j['start'] as num).toInt(),
        endMs: (j['end'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'ayah': ayah, 'start': startMs, 'end': endMs};
}

/// مرجع آية داخل سورة.
class AyahRef {
  final int surah;
  final int ayah;
  const AyahRef(this.surah, this.ayah);
  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;
  @override
  int get hashCode => Object.hash(surah, ayah);
  @override
  String toString() => '$surah:$ayah';
}

/// نمط التكرار.
enum RepetitionMode {
  /// تكرار كل آية وحدها قبل الانتقال إلى التالية.
  perAyah,

  /// تكرار مجموعة آيات كاملة ثم الانتقال إلى المجموعة التالية.
  perGroup,

  /// تكرار النطاق كاملًا كوحدة واحدة.
  wholeRange,
}

/// مقطع واحد قابل للتشغيل: آيات متصلة داخل سورة واحدة بحدود زمنية.
class RepeatSegment {
  final int surah;
  final int fromAyah;
  final int toAyah;
  final int startMs;
  final int endMs;

  /// رقم التكرار الحالي لهذه الوحدة (يبدأ من 1).
  final int repeatIndex;

  /// العدد الكلي لتكرارات هذه الوحدة (‎-1 = لا نهائي).
  final int repeatTotal;

  /// رقم الوحدة داخل النطاق (يبدأ من 0).
  final int unitIndex;

  const RepeatSegment({
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
    required this.startMs,
    required this.endMs,
    required this.repeatIndex,
    required this.repeatTotal,
    required this.unitIndex,
  });

  @override
  String toString() =>
      'Segment(surah=$surah, $fromAyah-$toAyah, ${startMs}ms-${endMs}ms, rep $repeatIndex/$repeatTotal)';
}

/// إعدادات التكرار.
class RepetitionConfig {
  final RepetitionMode mode;

  /// عدد مرات التكرار: 1..N، أو ‎-1 للتكرار المستمر.
  final int repeatCount;

  /// حجم المجموعة عند اختيار [RepetitionMode.perGroup].
  final int groupSize;

  /// فاصل الصمت بين التكرارات بالثواني (0 = معطّل).
  final int gapSeconds;

  const RepetitionConfig({
    this.mode = RepetitionMode.perAyah,
    this.repeatCount = 3,
    this.groupSize = 5,
    this.gapSeconds = 0,
  });

  bool get isInfinite => repeatCount == -1;
}

/// محرك التكرار: يبني الوحدات ويولّد المقاطع واحدًا تلو الآخر.
class RepetitionEngine {
  final RepetitionConfig config;

  /// توقيتات آيات السورة مرتبة تصاعديًا برقم الآية.
  final List<AyahTiming> _timings;
  final int surah;
  final int fromAyah;
  final int toAyah;

  late final List<(int, int)> _units; // (fromAyah, toAyah) لكل وحدة
  int _unitIndex = 0;
  int _repeatIndex = 1; // 1-based
  bool _finished = false;
  int _completedSegments = 0;

  RepetitionEngine({
    required this.config,
    required List<AyahTiming> timings,
    required this.surah,
    required this.fromAyah,
    required this.toAyah,
  }) : _timings = List.of(timings)..sort((a, b) => a.ayah.compareTo(b.ayah)) {
    if (fromAyah < 1) {
      throw ArgumentError('fromAyah ($fromAyah) must be >= 1');
    }
    if (fromAyah > toAyah) {
      throw ArgumentError('fromAyah ($fromAyah) must be <= toAyah ($toAyah)');
    }
    if (config.repeatCount == 0 || config.repeatCount < -1) {
      throw ArgumentError('repeatCount must be >= 1 or -1 (infinite)');
    }
    if (config.gapSeconds < 0) {
      throw ArgumentError('gapSeconds must be >= 0');
    }
    // كل آية في النطاق يجب أن يكون لها توقيت، وإلا فالمقطع مستحيل التشغيل.
    for (var a = fromAyah; a <= toAyah; a++) {
      if (!_timings.any((t) => t.ayah == a)) {
        throw ArgumentError('No timing found for ayah $a in surah $surah');
      }
    }
    _units = _buildUnits();
  }

  List<(int, int)> _buildUnits() {
    switch (config.mode) {
      case RepetitionMode.perAyah:
        return [for (var a = fromAyah; a <= toAyah; a++) (a, a)];
      case RepetitionMode.wholeRange:
        return [(fromAyah, toAyah)];
      case RepetitionMode.perGroup:
        final size = config.groupSize < 1 ? 1 : config.groupSize;
        final units = <(int, int)>[];
        for (var start = fromAyah; start <= toAyah; start += size) {
          final end = (start + size - 1) > toAyah ? toAyah : start + size - 1;
          units.add((start, end));
        }
        return units;
    }
  }

  AyahTiming _timingFor(int ayah) {
    for (final t in _timings) {
      if (t.ayah == ayah) return t;
    }
    throw StateError('No timing found for ayah $ayah in surah $surah');
  }

  /// عدد الوحدات (آيات / مجموعات / النطاق).
  int get unitCount => _units.length;

  /// هل انتهت كل المقاطع؟ (لا يحدث أبدًا في الوضع اللانهائي).
  bool get isFinished => _finished;

  /// عدد المقاطع التي اكتمل تشغيلها فعليًا.
  int get completedSegments => _completedSegments;

  /// الفاصل الزمني بين التكرارات كما هو مضبوط.
  int get gapSeconds => config.gapSeconds;

  /// المقطع الحالي دون تقدّم، أو null عند الانتهاء.
  RepeatSegment? get current {
    if (_finished) return null;
    final (from, to) = _units[_unitIndex];
    return RepeatSegment(
      surah: surah,
      fromAyah: from,
      toAyah: to,
      startMs: _timingFor(from).startMs,
      endMs: _timingFor(to).endMs,
      repeatIndex: _repeatIndex,
      repeatTotal: config.repeatCount,
      unitIndex: _unitIndex,
    );
  }

  /// يُستدعى فقط عند اكتمال تشغيل المقطع الحالي فعليًا.
  /// يعيد المقطع التالي أو null عند انتهاء الخطة.
  ///
  /// في الوضع اللانهائي (repeatCount = -1) تدور الخطة كاملة بلا نهاية:
  /// كل وحدة تُشغَّل مرة في كل دورة، و[RepeatSegment.repeatIndex] هو رقم
  /// الدورة الحالية (لآية واحدة يعني ذلك تكرارها هي نفسها بلا توقف).
  RepeatSegment? onSegmentCompleted() {
    if (_finished) return null;
    _completedSegments++;
    if (config.isInfinite) {
      if (_unitIndex >= _units.length - 1) {
        _unitIndex = 0;
        _repeatIndex++; // دورة جديدة
      } else {
        _unitIndex++;
      }
      return current;
    }
    if (_repeatIndex >= config.repeatCount) {
      // انتقل إلى الوحدة التالية
      if (_unitIndex >= _units.length - 1) {
        _finished = true;
        return null;
      }
      _unitIndex++;
      _repeatIndex = 1;
    } else {
      _repeatIndex++;
    }
    return current;
  }

  /// تخطٍّ يدوي إلى الوحدة التالية (آية/مجموعة) دون احتساب أي تكرار:
  /// لا يزيد [completedSegments] ولا يستهلك تكرارًا من الوحدة الحالية.
  /// يعيد مقطع الوحدة التالية أو null عند نهاية الخطة.
  RepeatSegment? skipToNextUnit() {
    if (_finished) return null;
    if (config.isInfinite) {
      if (_unitIndex >= _units.length - 1) {
        _unitIndex = 0;
        _repeatIndex++; // دورة جديدة
      } else {
        _unitIndex++;
      }
      return current;
    }
    if (_unitIndex >= _units.length - 1) {
      _finished = true;
      return null;
    }
    _unitIndex++;
    _repeatIndex = 1;
    return current;
  }

  /// معاينة التسلسل الكامل (للوضع المحدود فقط) — مفيدة للاختبارات والعرض.
  /// لا تغيّر حالة المحرك.
  List<RepeatSegment> previewSequence() {
    if (config.isInfinite) {
      throw StateError('Cannot preview an infinite sequence');
    }
    final out = <RepeatSegment>[];
    for (var u = 0; u < _units.length; u++) {
      final (from, to) = _units[u];
      for (var r = 1; r <= config.repeatCount; r++) {
        out.add(RepeatSegment(
          surah: surah,
          fromAyah: from,
          toAyah: to,
          startMs: _timingFor(from).startMs,
          endMs: _timingFor(to).endMs,
          repeatIndex: r,
          repeatTotal: config.repeatCount,
          unitIndex: u,
        ));
      }
    }
    return out;
  }

  /// إعادة المحرك إلى البداية.
  void reset() {
    _unitIndex = 0;
    _repeatIndex = 1;
    _finished = false;
    _completedSegments = 0;
  }
}
