// على الموبايل (Android/iOS) بيستخدم SQLite، وعلى الويب (Chrome) مفيش تخزين محلي.
export 'local_cache_stub.dart' if (dart.library.io) 'local_cache_io.dart';
export 'cache_entry.dart';