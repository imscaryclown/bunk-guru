import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color primaryLight = Color(0xFF3525CD);
  static const Color primaryDark = Color(0xFFC3C0FF);
  
  static const Color secondaryLight = Color(0xFFB4136D);
  static const Color secondaryDark = Color(0xFFFDB0CD);

  static const Color primaryContainer = Color(0xFF4F46E5);
  static const Color primaryFixed = Color(0xFFE2DFFF);
  static const Color primaryFixedDim = Color(0xFFC3C0FF);
  
  static const Color secondaryContainer = Color(0xFFFD56A7);
  static const Color secondaryFixed = Color(0xFFFFD9E4);
  static const Color secondaryFixedDim = Color(0xFFFFB0CD);

  static const Color tertiaryContainer = Color(0xFF006A7C);
  static const Color tertiaryFixed = Color(0xACEDFF00); // 0xACEDFF matches Tailwind config

  // Semantic Status colors (Universal)
  static const Color greenBg = Color(0xFF22C55E);
  static const Color greenText = Color(0xFF16A34A);
  
  static const Color yellowBg = Color(0xFFEAB308);
  static const Color yellowText = Color(0xFFF59E0B);
  
  static const Color redBg = Color(0xFFBA1A1A);
  static const Color redText = Color(0xFFFD56A7);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000a);

  // Light Mode Palette
  static const Color bgAppLight = Color(0xFFF7F9FB);
  static const Color bgSurfaceLight = Color(0xFFFFFFFF);
  static const Color bgSurfaceLowLight = Color(0xFFF2F4F6);
  static const Color bgSurfaceContainerLight = Color(0xFFECEEF0);
  static const Color bgSurfaceContainerHighLight = Color(0xFFE6E8EA);
  static const Color bgSurfaceVariantLight = Color(0xFFE0E3E5);
  static const Color textMainLight = Color(0xFF191C1E);
  static const Color textMutedLight = Color(0xFF464555);
  static const Color borderSubtleLight = Color(0x1A4F46E5); // 10% Indigo
  static const Color outlineLight = Color(0xFF777587);
  static const Color outlineVariantLight = Color(0xFFC7C4D8);

  // Dark Mode Palette
  static const Color bgAppDark = Color(0xFF191C1E);
  static const Color bgSurfaceDark = Color(0xFF242729);
  static const Color bgSurfaceLowDark = Color(0xFF1D2022);
  static const Color bgSurfaceContainerDark = Color(0xFF282C2F);
  static const Color bgSurfaceContainerHighDark = Color(0xFF323639);
  static const Color bgSurfaceVariantDark = Color(0xFF2D3133);
  static const Color textMainDark = Color(0xFFEFF1F3);
  static const Color textMutedDark = Color(0xFFC7C4D8);
  static const Color borderSubtleDark = Color(0x1AC3C0FF); // 10% Dim primary
  static const Color outlineDark = Color(0xFF9390A4);
  static const Color outlineVariantDark = Color(0xFF3A3F44);

  // Helpers to get theme-aware colors manually if needed
  static Color bgApp(bool isDark) => isDark ? bgAppDark : bgAppLight;
  static Color bgSurface(bool isDark) => isDark ? bgSurfaceDark : bgSurfaceLight;
  static Color bgSurfaceLow(bool isDark) => isDark ? bgSurfaceLowDark : bgSurfaceLowLight;
  static Color bgSurfaceContainer(bool isDark) => isDark ? bgSurfaceContainerDark : bgSurfaceContainerLight;
  static Color textMain(bool isDark) => isDark ? textMainDark : textMainLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
  static Color borderSubtle(bool isDark) => isDark ? borderSubtleDark : borderSubtleLight;
  static Color outline(bool isDark) => isDark ? outlineDark : outlineLight;
  static Color outlineVariant(bool isDark) => isDark ? outlineVariantDark : outlineVariantLight;
  static Color primary(bool isDark) => isDark ? primaryDark : primaryLight;
  static Color secondary(bool isDark) => isDark ? secondaryDark : secondaryLight;
}
