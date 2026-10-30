import 'package:shared_preferences/shared_preferences.dart';

/// بيانات الجلسة المحفوظة على الجهاز (من غير كلمة المرور أبدًا).
class SavedSession {
  final int lawyerId;
  final String fullName;
  final String email;

  const SavedSession({
    required this.lawyerId,
    required this.fullName,
    required this.email,
  });
}

/// حفظ/قراءة/مسح جلسة "تذكرني".
class SessionService {
  static const String _lawyerIdKey = 'session_lawyer_id';
  static const String _fullNameKey = 'session_full_name';
  static const String _emailKey = 'session_email';

  static Future<void> save({
    required int lawyerId,
    required String fullName,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lawyerIdKey, lawyerId);
      await prefs.setString(_fullNameKey, fullName);
      await prefs.setString(_emailKey, email);
    } catch (_) {
      // لو الحفظ فشل مش هنوقف تسجيل الدخول
    }
  }

  static Future<SavedSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lawyerId = prefs.getInt(_lawyerIdKey);
      final fullName = prefs.getString(_fullNameKey);
      final email = prefs.getString(_emailKey);

      if (lawyerId == null || fullName == null || email == null) return null;

      return SavedSession(
        lawyerId: lawyerId,
        fullName: fullName,
        email: email,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lawyerIdKey);
      await prefs.remove(_fullNameKey);
      await prefs.remove(_emailKey);
    } catch (_) {}
  }
}