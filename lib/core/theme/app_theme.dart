import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.bgSurfaceLight,
        error: AppColors.redBg,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        outline: AppColors.outlineLight,
        outlineVariant: AppColors.outlineVariantLight,
      ),
      scaffoldBackgroundColor: AppColors.bgAppLight,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primaryLight),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurfaceContainerLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.outlineLight, fontSize: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.secondaryDark,
        surface: AppColors.bgSurfaceDark,
        error: AppColors.redBg,
        errorContainer: Colors.redAccent,
        outline: AppColors.outlineDark,
        outlineVariant: AppColors.outlineVariantDark,
      ),
      scaffoldBackgroundColor: AppColors.bgAppDark,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primaryDark),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurfaceContainerDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.outlineDark, fontSize: 16),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color mainColor = isDark
        ? AppColors.textMainDark
        : AppColors.textMainLight;
    final Color mutedColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;

    return TextTheme(
      // h1 equivalent
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        height: 1.2,
        letterSpacing: -0.64, // -0.02em
        fontWeight: FontWeight.w600,
        color: mainColor,
      ),
      // h2 equivalent
      displayMedium: GoogleFonts.inter(
        fontSize: 24,
        height: 1.3,
        letterSpacing: -0.24,
        fontWeight: FontWeight.w600,
        color: mainColor,
      ),
      // body-lg equivalent
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        height: 1.6,
        fontWeight: FontWeight.normal,
        color: mainColor,
      ),
      // body-md equivalent
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.normal,
        color: mainColor,
      ),
      // label-caps equivalent
      labelLarge: GoogleFonts.inter(
        fontSize: 12,
        height: 1.0,
        letterSpacing: 0.6, // 0.05em
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
      // auxiliary support styles
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.normal,
        color: mutedColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        height: 1.0,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }
}
