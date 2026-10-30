import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _host = String.fromEnvironment('API_HOST');
  static const String _port =
      String.fromEnvironment('API_PORT', defaultValue: '8080');

  static String get baseUrl {
    final host = _host.isNotEmpty ? _host : _defaultHost;
    return 'http://$host:$_port/api';
  }

  static String get _defaultHost {
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }
}