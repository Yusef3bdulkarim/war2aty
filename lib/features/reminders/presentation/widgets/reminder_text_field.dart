import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the reminder forms' filled text fields (title,
// note) — one small rounded box, no border, matching `NoteEditorSheet`'s.
const double _fieldRadius = 14;
const double _fieldPaddingH = 16;
const double _fieldPaddingV = 15;
const double _fieldFontSize = 15.5;
const double _fieldHeight = 1.7;
const double _labelFontSize = 14;
const double _labelGapBelow = 8;
const double _sectionGapBelow = 18;

/// A labelled, filled text field — «عنوان التذكير», «ملاحظة» — shared by
/// both reminder forms (F09-T02).
///
/// [minLines]/[maxLines] make the same widget work for a one-line title and
/// a multi-line note.
class ReminderTextField extends StatelessWidget {
  const ReminderTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.required = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int? maxLines;

  /// Marks the label with the design's red asterisk — the manual form's
  /// title and date/time are required, the note never is.
  final bool required;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapBelow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: AppTypography.caption.copyWith(
                fontSize: _labelFontSize,
                fontWeight: AppTypography.bold,
                color: colors.textSecondary,
              ),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: colors.error),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: _labelGapBelow),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            textInputAction: maxLines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: _fieldFontSize,
              height: _fieldHeight,
              color: colors.textBody,
              fontWeight: AppTypography.bold,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyMedium.copyWith(
                fontSize: _fieldFontSize,
                height: _fieldHeight,
                color: colors.textPlaceholder,
                fontWeight: AppTypography.medium,
              ),
              filled: true,
              fillColor: colors.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _fieldPaddingH,
                vertical: _fieldPaddingV,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_fieldRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
