import 'package:flutter/material.dart';

/// Paleta del sistema web (global.css) replicada en el aplicativo móvil.
class AppColors {
  // Fondos piedra (web: --color-piedra-900/950 y paneles)
  static const Color piedra950 = Color(0xFF0D0C14);
  static const Color piedra900 = Color(0xFF131120);
  static const Color piedra800 = Color(0xFF1B1830);
  static const Color piedra700 = Color(0xFF262142);
  static const Color piedra600 = Color(0xFF342D58);
  static const Color fondoPanel = Color(0xFF14100A); // tarjetas oscuras del panel web
  static const Color fondoGame = Color(0xFF09090C); // fondo general web
  static const Color fondoCard = Color(0xFF100D12);

  // Crema (web: --color-crema-*)
  static const Color crema100 = Color(0xFFF7EED6);
  static const Color crema300 = Color(0xFFE9D9AE);
  static const Color crema500 = Color(0xFFCDB888);

  // Oro (web: --color-oro-*)
  static const Color oro300 = Color(0xFFF0CF7A);
  static const Color oro500 = Color(0xFFE6B84D);
  static const Color oro700 = Color(0xFFB5852C);
  static const Color bordeOro = Color(0xFF4A3A1C); // bordes de tarjetas del panel

  // Acentos (web: aliados / imperio / legion)
  static const Color aliados = Color(0xFF4D99FF);
  static const Color imperio = Color(0xFFFF4D4D);
  static const Color legion = Color(0xFF4DCC66);

  // Sangre (rojo UI web) y estados
  static const Color rojoAccion = Color(0xFFB3202C);
  static const Color textoSeco = Color(0xFF9A8870); // small del panel

  // Compatibilidad: nombres antiguos re-mapeados a la paleta web actual
    // (las vistas usan estos nombres; asi TODO el aplicativo adopta el look web)
    static const Color voidBlack = piedra950;
    static const Color deepPurple = piedra800;
    static const Color royalPurple = piedra700;
    static const Color darkCard = fondoCard;
    static const Color panelBackground = fondoPanel;
    static const Color deepBackground = fondoGame;
    static const Color shadowPurple = piedra600;
    static const Color mutedInk = crema500;
    static const Color crimsonRed = oro700; // sombras y bordes dorados
    static const Color brightRed = oro500; // botones y acentos -> ORO (como la web)
    static const Color magenta = oro300;
    static const Color neonPurple = Color(0xFF7C5CD6); // violeta-600 web
    static const Color cyan = aliados;
    static const Color gold = oro500;
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