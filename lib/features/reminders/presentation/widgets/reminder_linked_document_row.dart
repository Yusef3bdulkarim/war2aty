import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → «ربط بمستند محفوظ» on the create-from-document
// form — read-only there, since the link is how the reminder got made.
const double _rowRadius = 14;
const double _rowPaddingH = 15;
const double _rowPaddingV = 14;
const double _iconSize = 20;
const double _rowGap = 11;
const double _captionFontSize = 12.5;
const double _valueFontSize = 15;
const double _labelFontSize = 14;
const double _labelGapBelow = 9;
const double _sectionGapBelow = 8;

/// «ربط بمستند محفوظ» — which saved document a reminder is tied to.
///
/// Read-only: a reminder created from a document's date (F09-T03) is always
/// linked, and there is nothing to change here — this only tells the user
/// so, the same way the design draws it.
class ReminderLinkedDocumentRow extends StatelessWidget {
  const ReminderLinkedDocumentRow({required this.documentTitle, super.key});

  final String documentTitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapBelow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.reminderLinkedDocumentSectionLabel,
            style: AppTypography.caption.copyWith(
              fontSize: _labelFontSize,
              fontWeight: AppTypography.bold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: _labelGapBelow),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceTeal,
              borderRadius: BorderRadius.circular(_rowRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _rowPaddingH,
                vertical: _rowPaddingV,
              ),
              child: Row(
                children: [
                  StrokeIcon(
                    StrokeGlyph.documentCheck,
                    color: colors.brandPrimary,
                    size: _iconSize,
                  ),
                  const SizedBox(width: _rowGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.reminderLinkedDocumentValueLabel,
                          style: AppTypography.caption.copyWith(
                            fontSize: _captionFontSize,
                            fontWeight: AppTypography.semiBold,
                            color: colors.brandDeep,
                          ),
                        ),
                        Text(
                          documentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelCard.copyWith(
                            fontSize: _valueFontSize,
                            fontWeight: AppTypography.bold,
                            color: colors.brandDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
