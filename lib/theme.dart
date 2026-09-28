import 'package:flutter/material.dart';

/// Paleta MOBLAR (BRAND.md del proyecto): azul petróleo, salvia y ámbar.
class MoblarColors {
  MoblarColors._();

  static const primary = Color(0xFF407080); // moblar-500
  static const primaryDark = Color(0xFF2C4E59); // moblar-700
  static const primarySoft = Color(0xFFEFF3F4); // moblar-50
  static const primaryTint = Color(0xFFD4DFE3); // moblar-100
  static const sage = Color(0xFFA0B0A0); // sage-500
  static const sageSoft = Color(0xFFEAEDEA); // sage-100
  static const amber = Color(0xFFF59E0B); // acento
  static const amberSoft = Color(0xFFFEF3C7);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
}

ThemeData moblarTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MoblarColors.primary,
    primary: MoblarColors.primary,
    secondary: MoblarColors.sage,
    tertiary: MoblarColors.amber,
    surface: MoblarColors.surface,
    error: MoblarColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MoblarColors.surfaceSubtle,
    appBarTheme: const AppBarTheme(
      backgroundColor: MoblarColors.surface,
      foregroundColor: MoblarColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: MoblarColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MoblarColors.border),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: MoblarColors.surface,
      indicatorColor: MoblarColors.primaryTint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MoblarColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
