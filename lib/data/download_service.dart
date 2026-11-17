import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// تنزيل سور الشيخ الزين محمد أحمد بطلبٍ من المستخدم نفسه
/// (تخزين مؤقت للاستخدام دون اتصال). لا تُضمَّن أي ملفات صوتية في التطبيق.
///
/// سلامة التنزيل: يُكتب إلى ملف مؤقت `.part` ولا يُعتمد ملفًا نهائيًا إلا
/// بعد اكتمال البث ومطابقة الحجم المُعلن (إن وُجد) وتجاوز حدّ أدنى للحجم —
/// فلا يُحسب تنزيل منقطع أو صفحة خطأ على أنه سورة محمّلة أبدًا.
class DownloadService extends ChangeNotifier {
  static String surahUrl(int surah) =>
      'https://cdn.mp3quran.net/audio/zain-ahmad/r1/${surah.toString().padLeft(3, '0')}.mp3';

  /// الحد الأدنى لحجم ملف سورة صالح (أصغر سورة تتجاوزه بمراحل).
  static const int minValidBytes = 10000;

  final Map<int, double> progress = {}; // surah -> 0..1 أثناء التنزيل
  final Set<int> _inFlight = {};
  http.Client? _client;

  http.Client get _http => _client ??= http.Client();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'audio'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(int surah) async {
    final dir = await _dir();
    return File(p.join(dir.path, '${surah.toString().padLeft(3, '0')}.mp3'));
  }

  Future<bool> isDownloaded(int surah) async {
    final f = await fileFor(surah);
    return f.existsSync() && await f.length() > minValidBytes;
  }

  Future<List<int>> downloadedSurahs() async {
    final out = <int>[];
    for (var s = 1; s <= 114; s++) {
      if (await isDownloaded(s)) out.add(s);
    }
    return out;
  }

  Future<int> totalDownloadedBytes() async {
    var total = 0;
    for (final s in await downloadedSurahs()) {
      total += await (await fileFor(s)).length();
    }
    return total;
  }

  /// تنزيل متدفق مع إشعار بالتقدّم. يعيد true عند النجاح الكامل فقط.
  /// استدعاء ثانٍ لنفس السورة أثناء تنزيلها يُرفض فورًا (حماية من الكتابة المزدوجة).
  Future<bool> download(int surah) async {
    if (_inFlight.contains(surah)) return false;
    _inFlight.add(surah);
    progress[surah] = 0; // حجز فوري: تُعطَّل أزرار التنزيل من أول لحظة
    notifyListeners();
    final target = await fileFor(surah);
    final tmp = File('${target.path}.part');
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(surahUrl(surah)));
      final response = await _http.send(request);
      if (response.statusCode != 200) {
        if (await tmp.exists()) await tmp.delete();
        return false;
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      sink = tmp.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        progress[surah] =
            total > 0 ? (received / total).clamp(0.0, 1.0) : -1;
        notifyListeners();
      }
      await sink.close();
      sink = null;
      // اكتمال حقيقي: الحجم المستلم يطابق المُعلن (عند وجوده) ويتجاوز الحد الأدنى.
      final complete =
          (total <= 0 || received == total) && received > minValidBytes;
      if (!complete) {
        if (await tmp.exists()) await tmp.delete();
        return false;
      }
      await tmp.rename(target.path);
      return true;
    } catch (_) {
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      if (await tmp.exists()) await tmp.delete();
      return false;
    } finally {
      _inFlight.remove(surah);
      progress.remove(surah);
      notifyListeners();
    }
  }

  Future<void> delete(int surah) async {
    final f = await fileFor(surah);
    if (await f.exists()) await f.delete();
    notifyListeners();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
