import 'package:flutter/material.dart';

import 'app_typography.dart';

class AppTheme {
  static const Color _lightPrimary = Color(0xFF558B80);
  static const Color _lightBackground = Color(0xFFF6F5F0);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF1A1C1A);

  static const Color _darkPrimary = Color(0xFF86BCB1);
  static const Color _darkBackground = Color(0xFF191C1B);
  static const Color _darkSurface = Color(0xFF1E2120);
  static const Color _darkText = Color(0xFFE1E3E1);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _lightPrimary,
    brightness: Brightness.light,
  ).copyWith(
    primary: _lightPrimary,
    background: _lightBackground,
    surface: _lightSurface,
    onBackground: _lightText,
    onSurface: _lightText,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _darkPrimary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _darkPrimary,
    background: _darkBackground,
    surface: _darkSurface,
    onBackground: _darkText,
    onSurface: _darkText,
  );

  static ThemeData get lightTheme => _themeFromScheme(_lightScheme);
  static ThemeData get darkTheme => _themeFromScheme(_darkScheme);

  static ThemeData _themeFromScheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.background,
        foregroundColor: scheme.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onBackground),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: scheme.surface,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      textTheme: AppTypography.textTheme(scheme),
    );
  }
}
