import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF20243A);
  static const purple = Color(0xFF6354D9);
  static const background = Color(0xFFF5F6FB);
  static const groupColors = <String, Color>{
    'amarillo': Color(0xFFE7AF14),
    'verde': Color(0xFF2C9B68),
    'rojo': Color(0xFFE15865),
    'celeste': Color(0xFF269ED0),
  };

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: purple),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8EAF2)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -1,
      ),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
      bodyMedium: TextStyle(color: ink, height: 1.5),
    ),
  );
}
