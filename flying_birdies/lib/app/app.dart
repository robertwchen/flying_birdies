import 'package:flutter/material.dart';
import 'theme.dart';
import '../features/shell/home_shell.dart';

class FlyingBirdiesApp extends StatelessWidget {
  const FlyingBirdiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flying Birdies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(), // Skip onboarding for testing
    );
  }
}
