import 'dart:io' show Platform;

import 'package:sqflite/sqflite.dart';

import 'cache_entry.dart';

/// تخزين محلي بسيط (SQLite): كل نوع بيانات (clients / cases / appointments)
/// بيتحفظ كنسخة JSON واحدة مع وقت الحفظ.
class LocalCache {
  static Database? _db;

  // SQLite شغال هنا على الأندرويد والآيفون بس
  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getDatabasesPath();

    final db = await openDatabase(
      '$dir/lawyer_cache.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE cache_entries ('
          'cache_key TEXT PRIMARY KEY, '
          'body TEXT NOT NULL, '
          'saved_at INTEGER NOT NULL)',
        );
      },
    );

    _db = db;
    return db;
  }

  static Future<void> put(String key, String body) async {
    if (!_supported) return;

    try {
      final db = await _open();

      await db.insert(
        'cache_entries',
        {
          'cache_key': key,
          'body': body,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // فشل الحفظ المحلي مش لازم يوقف التطبيق
    }
  }

  static Future<CacheEntry?> get(String key) async {
    if (!_supported) return null;

    try {
      final db = await _open();

      final rows = await db.query(
        'cache_entries',
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return CacheEntry(
        body: rows.first['body'] as String,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          rows.first['saved_at'] as int,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// بيمسح كل البيانات المحفوظة (عند تسجيل الدخول/الخروج)
  static Future<void> clear() async {
    if (!_supported) return;

    try {
      final db = await _open();
      await db.delete('cache_entries');
    } catch (_) {}
  }
}