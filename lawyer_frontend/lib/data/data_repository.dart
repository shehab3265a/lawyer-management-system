import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'local_cache.dart';

/// نتيجة تحميل قائمة: البيانات + هل جت من النسخة المحفوظة ولا من السيرفر.
class ListResult {
  final List<Map<String, dynamic>> items;
  final bool fromCache;
  final DateTime? savedAt;

  const ListResult({
    required this.items,
    required this.fromCache,
    this.savedAt,
  });
}

/// الشاشات بتجيب البيانات من هنا بدل ما تكلم السيرفر مباشرة:
/// - لو السيرفر رد: بنعرض البيانات ونحفظ نسخة منها على الجهاز.
/// - لو السيرفر مش متاح: بنعرض آخر نسخة محفوظة (لو موجودة).
class DataRepository {
  static const Duration _timeout = Duration(seconds: 8);

  /// endpoint: clients | cases | appointments
  static Future<ListResult> getList(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/$endpoint'))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = utf8.decode(response.bodyBytes);
      final items = _parse(body);

      await LocalCache.put(endpoint, body);

      return ListResult(items: items, fromCache: false);
    } catch (_) {
      final cached = await LocalCache.get(endpoint);

      if (cached == null) rethrow;

      final items = _tryParse(cached.body);

      if (items == null) rethrow;

      return ListResult(
        items: items,
        fromCache: true,
        savedAt: cached.savedAt,
      );
    }
  }

  static List<Map<String, dynamic>>? _tryParse(String body) {
    try {
      return _parse(body);
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _parse(String body) {
    final data = jsonDecode(body) as List;

    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// أقدم وقت من اتنين (للبانر لما أكتر من قائمة تتحمل مع بعض)
  static DateTime? oldest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }
}