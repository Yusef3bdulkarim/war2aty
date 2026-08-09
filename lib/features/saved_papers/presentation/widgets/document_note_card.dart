import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → `docDetails` → «ملاحظتي» section.
const double _headingGapAbove = 22;
const double _headingGapBelow = 12;
const double _headingIconSize = 20;
const double _headingGap = 8;
const double _headingFontSize = 17;
const double _cardRadius = 18;
const double _cardPaddingH = 18;
const double _cardPaddingV = 16;
const double _noteFontSize = 15.5;
const double _noteHeight = 1.75;
const double _noteGapBelow = 12;
const double _buttonHeight = 42;
const double _buttonRadius = 12;
const double _buttonFontSize = 14;
const double _buttonGap = 9;
const double _emptyFontSize = 14.5;
const double _emptyGap = 10;
const double _addIconSize = 17;
const double _addGap = 6;
const double _addFontSize = 14.5;

/// The «ملاحظتي» section on the document details screen (F08-T09).
///
/// Two states:
/// - **Has note:** the text in a card with edit / delete buttons.
/// - **No note:** a row with "مافيش ملاحظة مضافة." and an add button.
///
/// Callbacks are optional so the widget can be pumped alone in a test.
class DocumentNoteCard extends StatelessWidget {
  const DocumentNoteCard({
    required this.note,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  /// The user's note, or `null` when none has been written yet.
  final String? note;

  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section heading — icon + «ملاحظتي».
        Padding(
          padding: const EdgeInsets.only(
            top: _headingGapAbove,
            bottom: _headingGapBelow,
            right: 4,
            left: 4,
          ),
          child: Row(
            children: [
              StrokeIcon(
                StrokeGlyph.documentSteps,
                color: colors.ink,
                size: _headingIconSize,
              ),
              const SizedBox(width: _headingGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.documentNoteHeading,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _headingFontSize,
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card: either the note with actions, or the empty state.
        if (note case final text?)
          _FilledCard(text: text, onEdit: onEdit, onDelete: onDelete)
        else
          _EmptyCard(onAdd: onAdd),
      ],
    );
  }
}

/// The note is present — text + edit / delete buttons.
class _FilledCard extends StatelessWidget {
  const _FilledCard({required this.text, this.onEdit, this.onDelete});

  final String text;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F142D2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D142D2D),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cardPaddingH,
          vertical: _cardPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: _noteFontSize,
                height: _noteHeight,
                color: colors.textBody,
              ),
            ),
            const SizedBox(height: _noteGapBelow),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: _buttonHeight,
                    child: TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        backgroundColor: colors.surfaceTeal,
                        foregroundColor: colors.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_buttonRadius),
                        ),
                        textStyle: AppTypography.labelCard.copyWith(
                          fontSize: _buttonFontSize,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      child: Text(strings.documentNoteEdit),
                    ),
                  ),
                ),
                const SizedBox(width: _buttonGap),
                Expanded(
                  child: SizedBox(
                    height: _buttonHeight,
                    child: TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        backgroundColor: colors.errorTint,
                        foregroundColor: colors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_buttonRadius),
                        ),
                        textStyle: AppTypography.labelCard.copyWith(
                          fontSize: _buttonFontSize,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      child: Text(strings.documentNoteDelete),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// No note yet — a single row with a prompt and an add button.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F142D2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cardPaddingH,
          vertical: _cardPaddingV,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: _emptyGap,
          runSpacing: 8,
          children: [
            Text(
              strings.documentNoteEmpty,
              style: AppTypography.bodySmall.copyWith(
                fontSize: _emptyFontSize,
                fontWeight: AppTypography.semiBold,
                color: colors.textMuted,
              ),
            ),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StrokeIcon(
                    StrokeGlyph.plus,
                    color: colors.brandPrimary,
                    size: _addIconSize,
                    strokeWidth: 2.3,
                  ),
                  const SizedBox(width: _addGap),
                  Flexible(
                    child: Text(
                      strings.documentNoteAdd,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _addFontSize,
                        fontWeight: AppTypography.bold,
                        color: colors.brandPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
