import 'package:flutter/material.dart';

import '../../../../core/documents/document_category.dart';
import '../../../../core/documents/document_category_style.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';

// From `Waraqti.dc.html` → `isDocuments`, the saved-document row.
const double _cardPadding = 16;
const double _cardGap = 13;
const double _iconBox = 50;
const double _rowGap = 6;

/// One row of the «مستنداتي» list: tinted category icon, title, category
/// chip, the day it was saved, what was kept, and a chevron into the details
/// screen (F08-T08).
///
/// A sibling of Home's recent-strip card rather than a shared widget: this
/// row also carries a save date and a chevron that Home's card does not, so
/// sharing one widget would mean threading flags through it for a difference
/// that is easier to read as two small widgets.
class DocumentListItem extends StatelessWidget {
  const DocumentListItem({required this.document, this.onTap, super.key});

  final RecentDocument document;

  /// Opens the document's details (F08-T08); `null` until that screen exists.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;
    final style = DocumentCategoryStyle.of(document.category);
    final radius = BorderRadius.circular(AppRadii.xl);
    final categoryName = _categoryName(s, document.category);
    final savedOn = formatDayMonth(s, document.savedAt);
    final storage = _storageLabel(s, document.storageMode);

    return Semantics(
      button: onTap != null,
      label: '${document.title}. $categoryName. $savedOn. $storage',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: radius,
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: Row(
                children: [
                  Container(
                    width: _iconBox,
                    height: _iconBox,
                    decoration: BoxDecoration(
                      color: style.tint,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Center(
                      child: StrokeIcon(style.glyph, color: style.foreground),
                    ),
                  ),
                  const SizedBox(width: _cardGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelCard.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: _rowGap,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _CategoryChip(label: categoryName, style: style),
                            Text(
                              savedOn,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: colors.textMuted,
                                fontWeight: AppTypography.semiBold,
                              ),
                            ),
                            Text(
                              '· $storage',
                              style: AppTypography.micro.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StrokeIcon(
                    StrokeGlyph.chevronForward,
                    color: colors.borderStrong,
                    size: 18,
                    strokeWidth: 2.2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.style});

  final String label;
  final DocumentCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Text(
          label,
          style: AppTypography.micro.copyWith(
            fontSize: 11.5,
            color: style.foreground,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}

String _categoryName(AppStrings s, DocumentCategory category) =>
    switch (category) {
      DocumentCategory.appointment => s.documentCategoryAppointment,
      DocumentCategory.invoice => s.documentCategoryInvoice,
      DocumentCategory.government => s.documentCategoryGovernment,
      DocumentCategory.education => s.documentCategoryEducation,
      DocumentCategory.other => s.documentCategoryOther,
    };

String _storageLabel(AppStrings s, DocumentStorageMode mode) => switch (mode) {
  DocumentStorageMode.resultOnly => s.documentStoredResultOnly,
  DocumentStorageMode.withImage => s.documentStoredWithImage,
};
