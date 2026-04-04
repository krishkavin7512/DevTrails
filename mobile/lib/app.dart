import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

class RainCheckApp extends StatelessWidget {
  const RainCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RainCheck',
      debugShowCheckedModeBanner: false,
      theme: RainCheckTheme.light(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
