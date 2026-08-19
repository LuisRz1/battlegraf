import 'package:flutter/material.dart';

/// Pixel-fantasy palette shared by the BattleGraph game and landing.
class AppColors {
  static const Color voidBlack = Color(0xFF07030E);
  static const Color deepPurple = Color(0xFF10061F);
  static const Color royalPurple = Color(0xFF24103F);
  static const Color crimsonRed = Color(0xFFB40F35);
  static const Color brightRed = Color(0xFFFF315D);
  static const Color magenta = Color(0xFFFF2BD6);
  static const Color neonPurple = Color(0xFFA855F7);
  static const Color cyan = Color(0xFF38E8F5);
  static const Color gold = Color(0xFFFFC857);
  static const Color offWhite = Color(0xFFFFF4D6);
  static const Color darkCard = Color(0xFF160B27);
  static const Color shadowPurple = Color(0xFF4D1C78);
  static const Color mutedInk = Color(0xFFBCA8CF);

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
        primary: AppColors.brightRed,
        onPrimary: AppColors.offWhite,
        secondary: AppColors.gold,
        onSecondary: AppColors.deepPurple,
        surface: AppColors.darkCard,
        onSurface: AppColors.offWhite,
        error: AppColors.brightRed,
        onError: AppColors.offWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.voidBlack,
        foregroundColor: AppColors.offWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          color: AppColors.offWhite,
          fontSize: 14,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xEE160B27),
        elevation: 12,
        shadowColor: AppColors.voidBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: AppColors.shadowPurple, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brightRed,
          foregroundColor: AppColors.offWhite,
          disabledBackgroundColor: AppColors.shadowPurple,
          disabledForegroundColor: AppColors.mutedInk,
          elevation: 8,
          shadowColor: AppColors.crimsonRed,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: displayFont,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: AppColors.offWhite, width: 2),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brightRed,
        foregroundColor: AppColors.offWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: AppColors.offWhite, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.voidBlack.withAlpha(190),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.neonPurple, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.shadowPurple, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.mutedInk),
        prefixIconColor: AppColors.gold,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: AppColors.neonPurple, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.voidBlack,
        selectedColor: AppColors.crimsonRed,
        side: BorderSide(color: AppColors.shadowPurple, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        labelStyle: TextStyle(fontFamily: bodyFont, color: AppColors.offWhite),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: displayFont,
          color: AppColors.offWhite,
          fontSize: 28,
          height: 1.2,
          shadows: [Shadow(color: AppColors.crimsonRed, offset: Offset(3, 3))],
        ),
        displayMedium: TextStyle(
          fontFamily: displayFont,
          color: AppColors.offWhite,
          fontSize: 20,
          shadows: [
            Shadow(color: AppColors.shadowPurple, offset: Offset(2, 2)),
          ],
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
          color: AppColors.mutedInk,
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
