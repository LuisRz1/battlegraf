import 'package:flutter/material.dart';

/// Retro Balatro-like color palette for BattleGraf.
class AppColors {
  static const Color deepPurple = Color(0xFF1A0A2E);
  static const Color royalPurple = Color(0xFF2D1B4E);
  static const Color crimsonRed = Color(0xFF8B0000);
  static const Color brightRed = Color(0xFFC41E3A);
  static const Color gold = Color(0xFFC9A84C);
  static const Color offWhite = Color(0xFFF5F0E8);
  static const Color darkCard = Color(0xFF241435);
  static const Color shadowPurple = Color(0xFF3A1F5E);

  // Subject colors for graph nodes
  static const Color math = Color(0xFFE63946);
  static const Color language = Color(0xFFF4A261);
  static const Color science = Color(0xFF2A9D8F);
  static const Color physics = Color(0xFF264653);
  static const Color chemistry = Color(0xFFE76F51);
  static const Color biology = Color(0xFF06A77D);
  static const Color history = Color(0xFF9B5DE5);
  static const Color geography = Color(0xFF00B4D8);
  static const Color english = Color(0xFFF15BB5);
  static const Color art = Color(0xFF8338EC);
  static const Color civics = Color(0xFF3A86FF);
  static const Color physicalEducation = Color(0xFFFB5607);
  static const Color technology = Color(0xFF38B000);
  static const Color philosophy = Color(0xFFFFBE0B);
  static const Color religion = Color(0xFF8AC926);
  static const Color computing = Color(0xFFFF006E);
}

class AppTheme {
  static const String displayFont = 'PressStart2P';
  static const String bodyFont = 'SpaceMono';

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.deepPurple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.crimsonRed,
        onPrimary: AppColors.offWhite,
        secondary: AppColors.gold,
        onSecondary: AppColors.deepPurple,
        surface: AppColors.royalPurple,
        onSurface: AppColors.offWhite,
        error: AppColors.brightRed,
        onError: AppColors.offWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.royalPurple,
        foregroundColor: AppColors.gold,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.gold, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.crimsonRed,
          foregroundColor: AppColors.offWhite,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.gold, width: 1),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.shadowPurple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.offWhite),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: displayFont,
          color: AppColors.gold,
          fontSize: 28,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontFamily: displayFont,
          color: AppColors.gold,
          fontSize: 20,
        ),
        headlineMedium: TextStyle(
          fontFamily: displayFont,
          color: AppColors.offWhite,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.offWhite,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.offWhite,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
