import 'package:flutter/painting.dart';

/// Cairo type scale, sourced from the Waraqti design.
///
/// Cairo (weights 400–800) is bundled as a local asset (see pubspec), so text
/// renders fully offline. Styles here are color-agnostic — color is applied by
/// the theme ([AppTheme]) so the same scale serves light and high-contrast.
abstract final class AppTypography {
  static const String fontFamily = 'Cairo';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: extraBold,
    height: 1.3,
  );

  /// Page heading on the full-bleed first-run pages (onboarding, privacy).
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: extraBold,
    height: 1.4,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: extraBold,
    height: 1.35,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: bold,
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: bold,
    height: 1.45,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: bold,
    height: 1.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: regular,
    height: 1.7,
  );

  /// The default body size in the design.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: regular,
    height: 1.7,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: regular,
    height: 1.6,
  );

  /// Title inside a large primary action card (Home's scan button).
  static const TextStyle titleAction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 21,
    fontWeight: extraBold,
    height: 1.3,
  );

  /// Supporting line under a [titleAction].
  static const TextStyle labelActionSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13.5,
    fontWeight: medium,
    height: 1.4,
  );

  /// Label on a secondary, outlined action row.
  static const TextStyle labelAction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.5,
    fontWeight: bold,
    height: 1.4,
  );

  /// Lead paragraph under a page heading — airier than [bodyLarge].
  static const TextStyle bodyLead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: medium,
    height: 1.85,
  );

  /// Label inside a picture card (the onboarding category grid).
  static const TextStyle labelCard = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15.5,
    fontWeight: bold,
    height: 1.4,
  );

  /// The large full-width primary call to action.
  static const TextStyle labelCta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: bold,
    height: 1.4,
  );

  /// Button / emphasized label.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: bold,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: semiBold,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: medium,
    height: 1.4,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: semiBold,
    height: 1.3,
  );
}
