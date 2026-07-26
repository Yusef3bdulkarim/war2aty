import 'package:flutter/painting.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import 'document_category.dart';

/// How a [DocumentCategory] is drawn: its icon and its two tints.
///
/// One table, so a category looks the same everywhere it appears — Home's
/// recent strip, the documents list (F08) and the result header (F07). Adding
/// a category is a compile error here until it is given a look.
final class DocumentCategoryStyle {
  const DocumentCategoryStyle({
    required this.glyph,
    required this.foreground,
    required this.tint,
  });

  final StrokeGlyph glyph;

  /// Icon and chip-label colour.
  final Color foreground;

  /// Icon-tile and chip background.
  final Color tint;

  /// The look for [category] in the light palette.
  static DocumentCategoryStyle of(DocumentCategory category) {
    const colors = AppColors.light;
    return switch (category) {
      DocumentCategory.appointment => DocumentCategoryStyle(
        glyph: StrokeGlyph.appointment,
        foreground: colors.brandPrimary,
        tint: colors.surfaceTealAlt,
      ),
      DocumentCategory.invoice => DocumentCategoryStyle(
        glyph: StrokeGlyph.invoice,
        foreground: colors.warning,
        tint: colors.warningTint,
      ),
      DocumentCategory.government => DocumentCategoryStyle(
        glyph: StrokeGlyph.government,
        foreground: colors.accentBlue,
        tint: colors.accentBlueTint,
      ),
      DocumentCategory.education => DocumentCategoryStyle(
        glyph: StrokeGlyph.education,
        foreground: colors.success,
        tint: colors.successTint,
      ),
      // The design ships no comp for an unclassified paper; a neutral grey
      // keeps it legible and visibly *not* one of the four known kinds.
      DocumentCategory.other => DocumentCategoryStyle(
        glyph: StrokeGlyph.appointment,
        foreground: colors.textSecondary,
        tint: colors.surfaceAlt,
      ),
    };
  }
}
