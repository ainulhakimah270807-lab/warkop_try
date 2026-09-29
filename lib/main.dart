import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/app_session.dart';
import 'theme/stitch_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, child) => MaterialApp(
        title: 'POSHub Enterprise',
        debugShowCheckedModeBanner: false,
        theme: StitchTheme.lightTheme,
        home: AppSession.instance.isLoggedIn
            ? const MainNavigationScreen()
            : const LoginScreen(),
      ),
    );
  }
}
