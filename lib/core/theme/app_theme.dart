import 'package:flutter/material.dart';

/// Central theme configuration for the premium visual language.
class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF050505);
  static const Color card = Color(0xFF111111);
  static const Color accent = Color(0xFF00E5FF);
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color danger = Color(0xFFFF2D55);
  static const Color glow = Color(0xFF00FFFF);
  static const Color glass = Color(0x14FFFFFF);

  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'SF Pro Display',
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: secondary,
        surface: card,
        surfaceContainerHighest: card,
        onPrimary: background,
        onSurface: Colors.white,
        error: danger,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.w300,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1FFFFFFF)),
    );
  }
}
