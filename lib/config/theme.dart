import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - ألوان مطابقة للوجو (فيروزي من Canva)
  static const Color primaryColor = Color(0xFF33A1AC); // فيروزي من Canva (لون اللوجو الرئيسي)
  static const Color secondaryColor = Color(0xFF4DB8C4); // فيروزي أفتح
  static const Color backgroundColor = Color(0xFFFFFFFF); // أبيض
  static const Color surfaceColor = Color(0xFFFFFFFF); // أبيض
  static const Color textPrimary = Color(0xFF1A1A1A); // أسود فاتح
  static const Color textSecondary = Color(0xFF6B7280); // رمادي متوسط
  static const Color borderColor = Color(0xFFE5E7EB); // رمادي فاتح
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  
  // ألوان إضافية
  static const Color accentColor = Color(0xFF26C6DA); // فيروزي فاتح
  static const Color lightPrimary = Color(0xFFE0F7FA); // فيروزي فاتح جداً
  static const Color darkPrimary = Color(0xFF1A7A85); // فيروزي داكن
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );
  
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryColor, accentColor],
  );
  
  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryColor.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 25,
      offset: const Offset(0, 12),
      spreadRadius: 0,
    ),
  ];

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor, // أبيض
    fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
    textTheme: GoogleFonts.notoKufiArabicTextTheme().copyWith(
      displayLarge: GoogleFonts.notoKufiArabic(
        color: textPrimary,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.notoKufiArabic(
        color: textPrimary,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
      headlineLarge: GoogleFonts.notoKufiArabic(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: GoogleFonts.notoKufiArabic(
        color: textPrimary,
        letterSpacing: 0.1,
      ),
      bodyMedium: GoogleFonts.notoKufiArabic(
        color: textSecondary,
        letterSpacing: 0.1,
      ),
      labelLarge: GoogleFonts.notoKufiArabic(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: surfaceColor,
      background: backgroundColor,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: textPrimary,
      iconTheme: IconThemeData(color: textPrimary),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: surfaceColor,
      shadowColor: primaryColor.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: primaryColor.withOpacity(0.3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorColor),
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
    textTheme: GoogleFonts.notoKufiArabicTextTheme(),
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.black87,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey[800],
    ),
  );
}


