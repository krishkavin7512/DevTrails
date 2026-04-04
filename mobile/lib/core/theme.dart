import 'package:flutter/material.dart';

class RainCheckTheme {
  // Mid-dark blue glass palette
  static const Color primary        = Color(0xFF5B8DEF);   // bright blue accent
  static const Color secondary      = Color(0xFF56CCF2);   // sky cyan
  static const Color background     = Color(0xFF141E33);   // deep navy base
  static const Color surface        = Color(0xFF1E2D4A);   // mid-dark blue card
  static const Color surfaceVariant = Color(0xFF2A3F63);   // border blue
  static const Color success        = Color(0xFF43C59E);   // teal green
  static const Color warning        = Color(0xFFF5A623);   // warm amber
  static const Color error          = Color(0xFFE05C5C);   // soft red
  static const Color textPrimary    = Color(0xFFEAF0FF);   // near-white with blue tint
  static const Color textSecondary  = Color(0xFF7B94BC);   // muted steel blue

  // Glass card helper — use anywhere a glass effect is needed
  static BoxDecoration glassCard({
    Color? borderColor,
    double radius = 20,
    Color? bgColor,
  }) =>
      BoxDecoration(
        color: (bgColor ?? surface).withAlpha(230),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? surfaceVariant,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withAlpha(18),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'SF Pro Display',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: surfaceVariant, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceVariant, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
        ),
      ),
    );
  }

  // Keep dark() as alias so nothing breaks
  static ThemeData dark() => light();
}
