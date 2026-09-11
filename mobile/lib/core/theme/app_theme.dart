import 'package:flutter/material.dart';

/// Paleta del sistema web (global.css) replicada en el aplicativo móvil.
class AppColors {
  // Fondos piedra oscuros con tinte morado (estilo Balatro)
  static const Color piedra950 = Color(0xFF0A0610);
  static const Color piedra900 = Color(0xFF140A20);
  static const Color piedra800 = Color(0xFF1D1030);
  static const Color piedra700 = Color(0xFF2A1745);
  static const Color piedra600 = Color(0xFF3B2160);
  static const Color fondoPanel = Color(0xFF170C26); // tarjetas del panel
  static const Color fondoGame = Color(0xFF08050E); // fondo general
  static const Color fondoCard = Color(0xFF120A1E);

  // Crema lavanda (texto)
  static const Color crema100 = Color(0xFFF6ECFA);
  static const Color crema300 = Color(0xFFDDC8EE);
  static const Color crema500 = Color(0xFFA892C4);

  // Acento principal: rojo -> magenta -> morado (sin dorado)
  static const Color oro300 = Color(0xFFFF6FB0); // magenta claro (highlight)
  static const Color oro500 = Color(0xFFE11D48); // rojo (botones / primario)
  static const Color oro700 = Color(0xFF8E1030); // rojo profundo (bordes/botones)
  static const Color bordeOro = Color(0xFF4A1E52); // borde morado de tarjetas

  // Acentos (bandos y temas)
  static const Color aliados = Color(0xFF8B5CF6); // morado (aliados)
  static const Color imperio = Color(0xFFFF3B5C); // rojo (imperio)
  static const Color legion = Color(0xFFD946EF); // fucsia (legion)
  static const Color violeta400 = Color(0xFFA78BFA);

  // Estados
  static const Color rojoAccion = Color(0xFFE11D48);
  static const Color textoSeco = Color(0xFF8B7BA8);

  // Compatibilidad con nombres antiguos (re-mapeados a la paleta roja/morada)
    static const Color voidBlack = piedra950;
    static const Color deepPurple = piedra800;
    static const Color royalPurple = piedra700;
    static const Color darkCard = fondoCard;
    static const Color panelBackground = fondoPanel;
    static const Color deepBackground = fondoGame;
    static const Color shadowPurple = piedra600;
    static const Color mutedInk = crema500;
    static const Color crimsonRed = oro700;
    static const Color brightRed = Color(0xFFFF3B5C);
    static const Color magenta = Color(0xFFD946EF);
    static const Color neonPurple = Color(0xFFA855F7);
    static const Color cyan = Color(0xFF8B5CF6);
    static const Color gold = oro300;
    static const Color offWhite = crema100;
  }

class AppTheme {
  /// Una sola tipografía en todo el aplicativo, igual que el sistema web.
  static const String displayFont = 'VcrOsdMono';
  static const String bodyFont = 'VcrOsdMono';

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.fondoGame,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.oro500,
        onPrimary: AppColors.piedra950,
        secondary: AppColors.oro300,
        onSecondary: AppColors.piedra950,
        surface: AppColors.fondoPanel,
        onSurface: AppColors.crema100,
        error: AppColors.rojoAccion,
        onError: AppColors.crema100,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.piedra950,
        foregroundColor: AppColors.crema100,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          color: AppColors.oro300,
          fontSize: 16,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.fondoPanel,
        elevation: 4,
        shadowColor: AppColors.piedra950,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.bordeOro, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.oro500,
          foregroundColor: AppColors.piedra950,
          disabledBackgroundColor: AppColors.piedra700,
          disabledForegroundColor: AppColors.crema500,
          elevation: 2,
          shadowColor: AppColors.piedra950,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: displayFont,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.oro700, width: 1.4),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.oro500,
        foregroundColor: AppColors.piedra950,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.oro700, width: 1.4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.piedra900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.bordeOro, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.bordeOro, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.oro500, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.crema500, fontFamily: bodyFont),
        hintStyle: const TextStyle(color: AppColors.crema500, fontFamily: bodyFont),
        prefixIconColor: AppColors.oro500,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.piedra900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.bordeOro, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.piedra900,
        selectedColor: AppColors.oro500,
        side: const BorderSide(color: AppColors.bordeOro, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        labelStyle: TextStyle(fontFamily: bodyFont, color: AppColors.crema100, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.bordeOro, thickness: 1),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: displayFont,
          color: AppColors.crema100,
          fontSize: 26,
          height: 1.2,
          letterSpacing: 1,
        ),
        displayMedium: TextStyle(
          fontFamily: displayFont,
          color: AppColors.crema100,
          fontSize: 20,
          letterSpacing: 1,
        ),
        headlineMedium: TextStyle(
          fontFamily: displayFont,
          color: AppColors.oro300,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.crema100,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.crema500,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.oro300,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}