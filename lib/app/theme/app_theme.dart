import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

abstract final class AppTheme {
  // Accent color that adapts to brightness
  static Color accentColor(Brightness brightness) {
    return brightness == Brightness.dark ? AppColors.green : AppColors.coral;
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.forest,
      secondary: AppColors.green,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    );

    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.cream);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
      primary: AppColors.mint,
      secondary: AppColors.green,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
    );

    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.darkBg);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NunitoSans',
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLg.copyWith(color: scheme.onSurface),
        displayMedium: AppTypography.displayMd.copyWith(
          color: scheme.onSurface,
        ),
        titleLarge: AppTypography.titleLg.copyWith(color: scheme.onSurface),
        titleMedium: AppTypography.titleMd.copyWith(color: scheme.onSurface),
        bodyLarge: AppTypography.bodyLg.copyWith(color: scheme.onSurface),
        bodyMedium: AppTypography.bodyMd.copyWith(color: scheme.onSurface),
        labelSmall: AppTypography.labelSm.copyWith(color: scheme.onSurface),
        bodySmall: AppTypography.caption.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: AppTypography.titleMd,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLg.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
