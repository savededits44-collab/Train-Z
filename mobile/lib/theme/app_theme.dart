import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Trainuspro Theme - Premium Monochrome & Corporate Luxury Design System
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Outfit';

  // Primary Palette - Deep Absolute Monochrome
  static const Color pureBlack = Color(0xFF000000);
  static const Color obsidianBlack = Color(0xFF080808);
  static const Color surfaceBlack = Color(0xFF101010);
  static const Color elevatedSurface = Color(0xFF161616);
  static const Color cardSurface = Color(0xFF1A1A1A);

  // Border & Dividers
  static const Color borderDark = Color(0xFF242424);
  static const Color borderSubtle = Color(0xFF333333);
  static const Color borderLight = Color(0xFF4A4A4A);

  // Platinum & White Accents
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color platinum = Color(0xFFF0F0F0);
  static const Color mutedWhite = Color(0xFFD4D4D4);
  static const Color slateGrey = Color(0xFF8E8E93);
  static const Color darkGrey = Color(0xFF48484A);

  // Glassmorphism overlays
  static const Color glassWhite10 = Color(0x1AFFFFFF);
  static const Color glassWhite05 = Color(0x0DFFFFFF);
  static const Color glassWhite20 = Color(0x33FFFFFF);

  /// Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: pureBlack,
      primaryColor: pureWhite,
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        onPrimary: pureBlack,
        secondary: mutedWhite,
        onSecondary: pureBlack,
        surface: surfaceBlack,
        onSurface: pureWhite,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: pureWhite,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: pureWhite,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: pureWhite,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: pureWhite,
          letterSpacing: -0.2,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pureWhite,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: pureWhite,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: pureWhite,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: pureWhite,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: mutedWhite,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: mutedWhite,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: slateGrey,
          letterSpacing: 0.15,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: slateGrey,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: pureWhite,
          letterSpacing: 0.2,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: pureWhite,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: slateGrey,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pureWhite,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
      ),
    );
  }
}
