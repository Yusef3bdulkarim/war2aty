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
    required this.textBody,
    required this.textBodySoft,
    required this.textSecondary,
    required this.textMuted,
    required this.bgBase,
    required this.surface,
    required this.surfaceAlt,
    required this.card,
    required this.surfaceNeutral,
    required this.surfaceTeal,
    required this.surfaceTealAlt,
    required this.borderSoft,
    required this.borderCool,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.successTint,
    required this.mint,
    required this.warning,
    required this.warningInk,
    required this.warningTint,
    required this.iconMuted,
    required this.iconSubtle,
    required this.iconInfo,
    required this.textCaption,
    required this.accentBlue,
    required this.accentBlueTint,
    required this.error,
    required this.errorTint,
  });

  final Color brandPrimary;
  final Color brandDeep;
  final Color onBrand;

  final Color ink;

  /// Body copy — the design's dominant paragraph ink, one step lighter than
  /// [ink] so long text reads comfortably.
  final Color textBody;

  /// A softer body ink the design uses for lead paragraphs.
  final Color textBodySoft;

  final Color textSecondary;
  final Color textMuted;

  final Color bgBase;
  final Color surface;
  final Color surfaceAlt;

  /// Raised cards and sheets — pure white throughout the design, so it reads
  /// as lifted against the warm off-white [surface].
  final Color card;

  /// Muted informational chip background (Home's usage counter).
  final Color surfaceNeutral;

  final Color surfaceTeal;
  final Color surfaceTealAlt;

  /// Hairline separators — the nav bar's top edge and card dividers.
  final Color borderSoft;

  /// Cool-toned outline for teal-tinted controls (the pick-image button).
  final Color borderCool;

  final Color border;
  final Color borderStrong;

  /// Inactive bottom-nav icons and labels.
  final Color iconMuted;

  /// Small supporting icons beside caption text.
  final Color iconSubtle;

  /// Icon inside an informational chip.
  final Color iconInfo;

  /// Caption / reassurance copy sitting under a control.
  final Color textCaption;

  final Color success;
  final Color successTint;
  final Color mint;

  final Color warning;
  final Color warningInk;
  final Color warningTint;

  /// Fourth category accent (government papers), alongside teal, amber and
  /// green. Used for icon tints and category chips.
  final Color accentBlue;
  final Color accentBlueTint;

  final Color error;
  final Color errorTint;

  /// Default light theme — the exact Waraqti hex values.
  static const AppColors light = AppColors(
    brandPrimary: Color(0xFF0E7C86),
    brandDeep: Color(0xFF0A5C64),
    onBrand: Color(0xFFFFFFFF),
    ink: Color(0xFF1D2B30),
    textBody: Color(0xFF3A474C),
    textBodySoft: Color(0xFF4A585E),
    textSecondary: Color(0xFF5A686E),
    textMuted: Color(0xFF8A969B),
    bgBase: Color(0xFFE9E6DF),
    surface: Color(0xFFF5F4EF),
    surfaceAlt: Color(0xFFF2EFE8),
    card: Color(0xFFFFFFFF),
    surfaceNeutral: Color(0xFFEFF3F0),
    surfaceTeal: Color(0xFFEEF4F5),
    surfaceTealAlt: Color(0xFFE4F1F2),
    borderSoft: Color(0xFFE7E4DC),
    borderCool: Color(0xFFDCE6E7),
    border: Color(0xFFE0DCD3),
    borderStrong: Color(0xFFC7C2B7),
    iconMuted: Color(0xFF9AA6AB),
    iconSubtle: Color(0xFF7A868B),
    iconInfo: Color(0xFF5A7A80),
    textCaption: Color(0xFF6B777C),
    success: Color(0xFF2E9E63),
    successTint: Color(0xFFE1F2E9),
    mint: Color(0xFF34D0B4),
    warning: Color(0xFFC77B12),
    warningInk: Color(0xFF8A5A0E),
    warningTint: Color(0xFFFBEFD8),
    accentBlue: Color(0xFF2C63B6),
    accentBlueTint: Color(0xFFE6EEF9),
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
    textBody: Color(0xFF172226),
    textBodySoft: Color(0xFF1F2C31),
    textSecondary: Color(0xFF2E3A3F),
    textMuted: Color(0xFF465257),
    bgBase: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F4EF),
    surfaceAlt: Color(0xFFECE9E1),
    card: Color(0xFFFFFFFF),
    surfaceNeutral: Color(0xFFE3EAE5),
    surfaceTeal: Color(0xFFE4F1F2),
    surfaceTealAlt: Color(0xFFD7E9EB),
    borderSoft: Color(0xFFB6BFC3),
    borderCool: Color(0xFFA9BCBF),
    border: Color(0xFF8A969B),
    borderStrong: Color(0xFF5A686E),
    iconMuted: Color(0xFF465257),
    iconSubtle: Color(0xFF3A474C),
    iconInfo: Color(0xFF2E4A50),
    textCaption: Color(0xFF2E3A3F),
    success: Color(0xFF1E7A48),
    successTint: Color(0xFFDCEEE4),
    mint: Color(0xFF12A98C),
    warning: Color(0xFF8A5A0E),
    warningInk: Color(0xFF5E3D08),
    warningTint: Color(0xFFF8E6C6),
    accentBlue: Color(0xFF1B4489),
    accentBlueTint: Color(0xFFD8E3F5),
    error: Color(0xFFA82217),
    errorTint: Color(0xFFF8E1DE),
  );
}
