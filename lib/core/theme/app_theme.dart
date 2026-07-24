import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandRed = Color(0xFFE71D24);
  static const Color darkText = Color(0xFF1F232A);

  static ThemeData light() {
    final baseText = ThemeData.light().textTheme.apply(fontFamily: 'Cairo');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandRed,
        primary: brandRed,
        secondary: const Color(0xFF232830),
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: brandRed,
        ),
        actionsIconTheme: IconThemeData(
          color: brandRed,
        ),
      ),
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: darkText,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: const Color(0xFF545C69),
        ),
        
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
