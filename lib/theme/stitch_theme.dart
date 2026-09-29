import 'package:flutter/material.dart';

class StitchTheme {
  static const Color primaryGreen = Color(0xFF08B887);
  static const Color backgroundLight = Color(0xFFF4F7F8);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF202829);
  static const Color textMuted = Color(0xFF687577);
  static const Color accentWarning = Color(0xFFC77819);
  static const Color borderSubtle = Color(0xFFE3E9E9);
  static const Color sidebar = Color(0xFF252B2D);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryGreen,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
    );
  }
}
