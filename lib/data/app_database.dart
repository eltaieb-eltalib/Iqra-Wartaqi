import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// قاعدة البيانات المحلية: تقدّم الحفظ، المفضلة، النطاقات المحفوظة،
/// الجلسات، والأهداف اليومية. كل شيء محلي دون حساب أو إنترنت.
class AppDatabase {
  Future<Database>? _dbFuture;

  /// نحفظ الـ Future نفسه لا نتيجته: استدعاءان متزامنان أول مرة
  /// يتشاركان فتحًا واحدًا بدل فتح قاعدة البيانات مرتين.
  Future<Database> get db => _dbFuture ??= _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'wird.db'),
      version: 1,
      onUpgrade: (db, oldVersion, newVersion) async {
        // نقطة الترحيل الرسمية: أي تغيير مستقبلي في المخطط يُنفَّذ هنا
        // بزيادات متسلسلة (oldVersion < 2، < 3، ...) دون فقدان بيانات.
        // الإصدار الحالي 1 هو الأساس، فلا خطوات بعد.
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE ayah_progress(
            surah INTEGER NOT NULL,
            ayah INTEGER NOT NULL,
            status TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY(surah, ayah)
          )''');
        await db.execute('''
          CREATE TABLE favorites(
            surah INTEGER NOT NULL,
            ayah INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY(surah, ayah)
          )''');
        await db.execute('''
          CREATE TABLE saved_ranges(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            surah INTEGER NOT NULL,
            from_ayah INTEGER NOT NULL,
            to_ayah INTEGER NOT NULL,
            kind TEXT NOT NULL DEFAULT 'custom'
          )''');
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            surah INTEGER,
            mode TEXT NOT NULL DEFAULT 'listening'
          )''');
        await db.execute('''
          CREATE TABLE daily_goals(
            day TEXT PRIMARY KEY,
            target_ayahs INTEGER NOT NULL DEFAULT 10,
            done_ayahs INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE kv(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      },
    );
  }

  // ---------- تقدّم الآيات ----------
  Future<void> setAyahStatus(int surah, int ayah, String status) async {
    final d = await db;
    await d.insert(
      'ayah_progress',
      {
        'surah': surah,
        'ayah': ayah,
        'status': status,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// تعليم نطاق كامل دفعة واحدة (معاملة + دفعة)، ويعيد عدد الآيات التي
  /// تغيّرت حالتها فعليًا — حتى لا يتضخّم عدّاد الهدف اليومي بإعادة التعليم.
  Future<int> setRangeStatus(
      int surah, int fromAyah, int toAyah, String status) async {
    final d = await db;
    var changed = 0;
    await d.transaction((txn) async {
      final rows = await txn.query('ayah_progress',
          where: 'surah = ?', whereArgs: [surah]);
      final prev = {for (final r in rows) r['ayah'] as int: r['status'] as String};
      final batch = txn.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var a = fromAyah; a <= toAyah; a++) {
        if (prev[a] == status) continue;
        changed++;
        batch.insert(
          'ayah_progress',
          {'surah': surah, 'ayah': a, 'status': status, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    return changed;
  }

  Future<Map<String, int>> progressCounts() async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT status, COUNT(*) AS c FROM ayah_progress GROUP BY status',
    );
    return {for (final r in rows) r['status'] as String: (r['c'] as num).toInt()};
  }

  Future<Map<int, String>> progressForSurah(int surah) async {
    final d = await db;
    final rows = await d.query('ayah_progress', where: 'surah = ?', whereArgs: [surah]);
    return {for (final r in rows) r['ayah'] as int: r['status'] as String};
  }

  /// آيات قيد التعلّم (للمراجعة).
  Future<List<Map<String, dynamic>>> learningAyahs() async {
    final d = await db;
    return d.query('ayah_progress',
        where: 'status = ?', whereArgs: ['learning'], orderBy: 'surah, ayah');
  }

  // ---------- المفضلة ----------
  Future<void> toggleFavorite(int surah, int ayah) async {
    final d = await db;
    // داخل معاملة واحدة: نقرتان سريعتان لا تُحدثان تعارض مفتاح أساسي.
    await d.transaction((txn) async {
      final existing = await txn.query('favorites',
          where: 'surah = ? AND ayah = ?', whereArgs: [surah, ayah]);
      if (existing.isEmpty) {
        await txn.insert(
          'favorites',
          {
            'surah': surah,
            'ayah': ayah,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } else {
        await txn.delete('favorites',
            where: 'surah = ? AND ayah = ?', whereArgs: [surah, ayah]);
      }
    });
  }

  Future<Set<String>> favoriteKeys() async {
    final d = await db;
    final rows = await d.query('favorites');
    return {for (final r in rows) '${r['surah']}:${r['ayah']}'};
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final d = await db;
    return d.query('favorites', orderBy: 'created_at DESC');
  }

  // ---------- النطاقات المحفوظة ----------
  Future<int> addRange(SavedRange range) async {
    final d = await db;
    return d.insert('saved_ranges', range.toMap());
  }

  Future<List<SavedRange>> savedRanges() async {
    final d = await db;
    final rows = await d.query('saved_ranges', orderBy: 'id DESC');
    return [for (final r in rows) SavedRange.fromMap(r)];
  }

  Future<void> deleteRange(int id) async {
    final d = await db;
    await d.delete('saved_ranges', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- الجلسات ----------
  Future<int> startSession(int? surah, String mode) async {
    final d = await db;
    return d.insert('sessions', {
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'duration_seconds': 0,
      'surah': surah,
      'mode': mode,
    });
  }

  Future<void> endSession(int id, int durationSeconds) async {
    final d = await db;
    await d.update('sessions', {'duration_seconds': durationSeconds},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> sessionSecondsSince(DateTime since) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COALESCE(SUM(duration_seconds),0) AS s FROM sessions WHERE started_at >= ?',
      [since.millisecondsSinceEpoch],
    );
    return (rows.first['s'] as num).toInt();
  }

  // ---------- الهدف اليومي وآخر موضع ----------
  static String _dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<void> setDailyTarget(int ayahs) async {
    final d = await db;
    await d.insert(
      'daily_goals',
      {'day': _dayKey(DateTime.now()), 'target_ayahs': ayahs, 'done_ayahs': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await d.update('daily_goals', {'target_ayahs': ayahs},
        where: 'day = ?', whereArgs: [_dayKey(DateTime.now())]);
  }

  Future<void> addDailyDone(int ayahs, {int? targetAyahs}) async {
    final d = await db;
    final key = _dayKey(DateTime.now());
    await d.insert(
      'daily_goals',
      {'day': key, 'target_ayahs': targetAyahs ?? 10, 'done_ayahs': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await d.rawUpdate(
      'UPDATE daily_goals SET done_ayahs = done_ayahs + ? WHERE day = ?',
      [ayahs, key],
    );
  }

  Future<({int target, int done})> todayGoal() async {
    final d = await db;
    final rows = await d.query('daily_goals',
        where: 'day = ?', whereArgs: [_dayKey(DateTime.now())]);
    if (rows.isEmpty) return (target: 10, done: 0);
    return (
      target: (rows.first['target_ayahs'] as num).toInt(),
      done: (rows.first['done_ayahs'] as num).toInt(),
    );
  }

  Future<void> saveKv(String key, String value) async {
    final d = await db;
    await d.insert('kv', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readKv(String key) async {
    final d = await db;
    final rows = await d.query('kv', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }
}
