import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData build() {
    const canvas = Color(0xFFF7F3EA);
    const ink = Color(0xFF1B1F23);
    const accent = Color(0xFFB45309);
    const accentSoft = Color(0xFFFBBF24);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: canvas,
      onSurface: ink,
      primary: accent,
      secondary: accentSoft,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: canvas,
        foregroundColor: ink,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
