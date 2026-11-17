import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// تنزيل سور الشيخ الزين محمد أحمد بطلبٍ من المستخدم نفسه
/// (تخزين مؤقت للاستخدام دون اتصال). لا تُضمَّن أي ملفات صوتية في التطبيق.
class DownloadService extends ChangeNotifier {
  static String surahUrl(int surah) =>
      'https://cdn.mp3quran.net/audio/zain-ahmad/r1/${surah.toString().padLeft(3, '0')}.mp3';

  final Map<int, double> progress = {}; // surah -> 0..1 أثناء التنزيل

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
    return f.existsSync() && await f.length() > 10000;
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

  /// تنزيل متدفق مع إشعار بالتقدّم. يعيد true عند النجاح.
  Future<bool> download(int surah) async {
    final target = await fileFor(surah);
    final tmp = File('${target.path}.part');
    try {
      final request = http.Request('GET', Uri.parse(surahUrl(surah)));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) return false;
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress[surah] = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      await tmp.rename(target.path);
      progress.remove(surah);
      notifyListeners();
      return true;
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      progress.remove(surah);
      notifyListeners();
      return false;
    }
  }

  Future<void> delete(int surah) async {
    final f = await fileFor(surah);
    if (await f.exists()) await f.delete();
    notifyListeners();
  }
}
