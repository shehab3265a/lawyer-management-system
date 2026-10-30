import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/login_screen.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // لو المحامي كان مفعّل "تذكرني" هندخله الداشبورد مباشرة
  final session = await SessionService.load();

  runApp(LawyerApp(session: session));
}

class LawyerApp extends StatelessWidget {
  final SavedSession? session;

  const LawyerApp({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة مكتب المحاماة',
      theme: AppTheme.light,
      home: session == null
          ? const LoginScreen()
          : DashboardScreen(
              fullName: session!.fullName,
              email: session!.email,
              lawyerId: session!.lawyerId,
            ),
    );
  }
}
