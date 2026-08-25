import 'package:flutter/material.dart';

import 'screens/hires_list_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Rental CMS — Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminAppTheme(),
      home: const _SplashGate(),
    );
  }
}

/// Checks for a stored token before deciding whether to land on the login
/// screen or straight on the hires list — avoids a login-screen flash for
/// an already-authenticated user.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.isLoggedIn.then((value) {
      if (mounted) setState(() => _loggedIn = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _loggedIn! ? const HiresListScreen() : const LoginScreen();
  }
}
