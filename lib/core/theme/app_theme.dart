import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] for the app from the Waraqti design tokens.
///
/// Two themes are exposed: [light] and [highContrast]. Both share the Cairo
/// type scale ([AppTypography]) and differ only in their [AppColors] palette.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData highContrast() => _build(AppColors.highContrast);

  static ThemeData _build(AppColors c) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: c.brandPrimary,
      onPrimary: c.onBrand,
      primaryContainer: c.surfaceTeal,
      onPrimaryContainer: c.brandDeep,
      secondary: c.mint,
      onSecondary: c.onBrand,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.bgBase,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.border,
      outlineVariant: c.borderStrong,
      error: c.error,
      onError: c.onBrand,
      errorContainer: c.errorTint,
      onErrorContainer: c.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.bgBase,
      fontFamily: AppTypography.fontFamily,
      textTheme: _textTheme(c.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgBase,
        foregroundColor: c.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: c.ink),
      ),
      // Every SnackBar floats (F26 #3): clear of the screen's edges and of
      // the nav bar, with rounded corners. Set here so no call site has to.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        elevation: 6,
        backgroundColor: c.ink,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: c.onBrand,
          fontWeight: AppTypography.semiBold,
          height: 1.5,
        ),
        actionTextColor: c.mint,
      ),
      dividerColor: c.border,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brandPrimary,
          foregroundColor: c.onBrand,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color ink) {
    TextStyle c(TextStyle s) => s.copyWith(color: ink);
    return TextTheme(
      displayLarge: c(AppTypography.displayLarge),
      headlineLarge: c(AppTypography.headlineLarge),
      headlineMedium: c(AppTypography.headlineMedium),
      titleLarge: c(AppTypography.titleLarge),
      titleMedium: c(AppTypography.titleMedium),
      bodyLarge: c(AppTypography.bodyLarge),
      bodyMedium: c(AppTypography.bodyMedium),
      bodySmall: c(AppTypography.bodySmall),
      labelLarge: c(AppTypography.labelLarge),
      labelMedium: c(AppTypography.labelMedium),
      labelSmall: c(AppTypography.caption),
    );
  }
}
