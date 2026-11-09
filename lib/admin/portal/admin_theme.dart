import 'package:flutter/material.dart';

/// Shared portal styling, adapted from the supplied Figma admin frames.
abstract final class AdminTheme {
  static const background = Color(0xFFFCF9F8);
  static const rose = Color(0xFFC77B7B);
  static const ink = Color(0xFF202B35);
  static const muted = Color(0xFF78808A);
  static const border = Color(0xFFEAE6E5);

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: rose,
      primary: rose,
      surface: Colors.white,
      onSurface: ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDADBDD)),
      ),
      labelStyle: const TextStyle(color: muted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: rose,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, space: 1),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: ink),
      bodySmall: TextStyle(fontSize: 12, color: muted),
      titleLarge: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
  );
}
