import 'package:flutter/painting.dart';

/// Semantic color palette, sourced exactly from the Waraqti design
/// (`Waraqti.dc.html`). Two variants are provided: [light] and
/// [highContrast]. Never rely on color alone to convey state (CLAUDE.md) —
/// always pair with text/icon.
final class AppColors {
  const AppColors({
    required this.brandPrimary,
    required this.brandDeep,
    required this.onBrand,
    required this.ink,
    required this.textSecondary,
    required this.textMuted,
    required this.bgBase,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceTeal,
    required this.surfaceTealAlt,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.successTint,
    required this.mint,
    required this.warning,
    required this.warningInk,
    required this.warningTint,
    required this.error,
    required this.errorTint,
  });

  final Color brandPrimary;
  final Color brandDeep;
  final Color onBrand;

  final Color ink;
  final Color textSecondary;
  final Color textMuted;

  final Color bgBase;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceTeal;
  final Color surfaceTealAlt;

  final Color border;
  final Color borderStrong;

  final Color success;
  final Color successTint;
  final Color mint;

  final Color warning;
  final Color warningInk;
  final Color warningTint;

  final Color error;
  final Color errorTint;

  /// Default light theme — the exact Waraqti hex values.
  static const AppColors light = AppColors(
    brandPrimary: Color(0xFF0E7C86),
    brandDeep: Color(0xFF0A5C64),
    onBrand: Color(0xFFFFFFFF),
    ink: Color(0xFF1D2B30),
    textSecondary: Color(0xFF5A686E),
    textMuted: Color(0xFF8A969B),
    bgBase: Color(0xFFE9E6DF),
    surface: Color(0xFFF5F4EF),
    surfaceAlt: Color(0xFFF2EFE8),
    surfaceTeal: Color(0xFFEEF4F5),
    surfaceTealAlt: Color(0xFFE4F1F2),
    border: Color(0xFFE0DCD3),
    borderStrong: Color(0xFFC7C2B7),
    success: Color(0xFF2E9E63),
    successTint: Color(0xFFE1F2E9),
    mint: Color(0xFF34D0B4),
    warning: Color(0xFFC77B12),
    warningInk: Color(0xFF8A5A0E),
    warningTint: Color(0xFFFBEFD8),
    error: Color(0xFFC4362A),
    errorTint: Color(0xFFFBECEA),
  );

  /// High-contrast variant — darker text, stronger borders, deeper brand and
  /// semantic colors for readability (WCAG-AA). Derived from the palette; the
  /// design does not ship a dedicated high-contrast comp.
  static const AppColors highContrast = AppColors(
    brandPrimary: Color(0xFF0A5C64),
    brandDeep: Color(0xFF063E44),
    onBrand: Color(0xFFFFFFFF),
    ink: Color(0xFF0B1417),
    textSecondary: Color(0xFF2E3A3F),
    textMuted: Color(0xFF465257),
    bgBase: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F4EF),
    surfaceAlt: Color(0xFFECE9E1),
    surfaceTeal: Color(0xFFE4F1F2),
    surfaceTealAlt: Color(0xFFD7E9EB),
    border: Color(0xFF8A969B),
    borderStrong: Color(0xFF5A686E),
    success: Color(0xFF1E7A48),
    successTint: Color(0xFFDCEEE4),
    mint: Color(0xFF12A98C),
    warning: Color(0xFF8A5A0E),
    warningInk: Color(0xFF5E3D08),
    warningTint: Color(0xFFF8E6C6),
    error: Color(0xFFA82217),
    errorTint: Color(0xFFF8E1DE),
  );
}
