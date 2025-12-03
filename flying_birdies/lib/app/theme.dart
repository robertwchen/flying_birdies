import 'package:flutter/material.dart';

class AppTheme {
  // Brand / seed
  static const seed = Color(0xFF6D28D9);

  // Dark surfaces
  static const bgDark = Color(0xFF050816); // deep navy/near-black
  static const surfaceDark = Color(0xFF111827);

  // Light surfaces
  static const bgLight = Color(0xFFF5F5FF); // soft off-white
  static const surfaceLight = Color(0xFFFFFFFF);

  // Gradients
  static const heroCornersDark = [bgDark, Color(0xFF312E81), bgDark];
  static const heroCornersLight = [
    Color(0xFFF5F5FF),
    Color(0xFFE5E7FF),
    Color(0xFFF5F5FF),
  ];

  static const titleGradient = [Color(0xFFFF6FD8), Color(0xFF9B6EFF)];
  static const gPink = [Color(0xFF5C2C7C), Color(0xFFBA2FA2)];
  static const gBlue = [Color(0xFF1E426E), Color(0xFF1B98C0)];
  static const gTeal = [Color(0xFF173B48), Color(0xFF13A0A0)];
  static const gCTA = [Color(0xFFFA60D1), Color(0xFF7B7BFF)];
  static const gQA = [Color(0xFF0FAE96), Color(0xFF1F6FEB)];

  // ---------------- DARK THEME ----------------
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: seed,
    );

    final scheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: seed,
      surface: surfaceDark,
      onSurface: Colors.white.withValues(alpha: .90),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bgDark,
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: Colors.white.withValues(alpha: .88),
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // NOTE: CardThemeData instead of CardTheme
      cardTheme: const CardThemeData(
        color: Color(0x171F2937), // translucent on dark
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x141C2540),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: .5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .35)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: seed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: .25)),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: seed.withValues(alpha: 0.25),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.w600,
            color: sel
                ? const Color.fromARGB(255, 255, 215, 0)
                : const Color.fromARGB(230, 255, 255, 255),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: sel
                ? const Color.fromARGB(255, 255, 215, 0)
                : const Color.fromARGB(200, 255, 255, 255),
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x22FFFFFF),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ---------------- LIGHT THEME ----------------
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: seed,
    );

    final scheme = base.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: seed,
      surface: surfaceLight,
      onSurface: const Color(0xFF111827),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bgLight,
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: const Color(0xFF111827),
        displayColor: const Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF111827)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      // NOTE: CardThemeData instead of CardTheme
      cardTheme: const CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0x14000000)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed.withValues(alpha: .8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: seed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          foregroundColor: const Color(0xFF111827),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: seed.withValues(alpha: .12),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.w600,
            color: sel ? seed : const Color(0xFF6B7280),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: sel ? seed : const Color(0xFF9CA3AF),
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
