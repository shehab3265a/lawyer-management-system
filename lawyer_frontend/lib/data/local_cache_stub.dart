import 'cache_entry.dart';

/// نسخة الويب: مفيش تخزين محلي، فالتطبيق على Chrome بيشتغل أونلاين بس.
class LocalCache {
  static Future<void> put(String key, String body) async {}

  static Future<CacheEntry?> get(String key) async => null;

  static Future<void> clear() async {}
}