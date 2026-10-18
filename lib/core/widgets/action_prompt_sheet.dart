import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// The geometry is `showDestructiveConfirmSheet`'s, unchanged — same radius,
// padding, type sizes and button height. Only the primary button's colour
// differs: brand teal rather than error red, because nothing here destroys
// anything. `Waraqti.dc.html` ships no comp for a non-destructive prompt
// sheet, so this deliberately invents no new shape; see the F30 doc's note,
// which is flagged for the owner.
const double _sheetRadius = AppRadii.xxl;
const double _sheetPadding = AppSpacing.xl;
const double _titleFontSize = 18;
const double _messageGap = 8;
const double _buttonsGapAbove = 22;
const double _buttonGap = 10;
const double _buttonHeight = 50;
const double _buttonRadius = AppRadii.md;

/// Tells the user something they have to act on elsewhere, and offers the way
/// there (F30-T07).
///
/// Unlike `showDestructiveConfirmSheet` this confirms nothing — [actionLabel]
/// sends the user somewhere, so there is no "are you sure".
///
/// [actionLabel] is optional: pass `null` when there is nowhere to send them
/// on this platform, and the sheet shows the message with only a way to
/// close it, rather than a button that does nothing.
///
/// Answers `true` only when the action button was tapped. Dismissing — the
/// button, a tap outside, the back gesture — all answer `false`.
Future<bool> showActionPromptSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String dismissLabel,
  String? actionLabel,
}) async {
  final acted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => _ActionPromptSheetBody(
      title: title,
      message: message,
      dismissLabel: dismissLabel,
      actionLabel: actionLabel,
    ),
  );
  return acted ?? false;
}

class _ActionPromptSheetBody extends StatelessWidget {
  const _ActionPromptSheetBody({
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String dismissLabel;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sheetPadding,
          _sheetPadding + 4,
          _sheetPadding,
          _sheetPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontSize: _titleFontSize,
                fontWeight: AppTypography.extraBold,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: _messageGap),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: _buttonsGapAbove),
            if (actionLabel case final label?) ...[
              SizedBox(
                height: _buttonHeight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brandPrimary,
                    foregroundColor: colors.onBrand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_buttonRadius),
                    ),
                    textStyle: AppTypography.labelLarge,
                  ),
                  child: Text(label),
                ),
              ),
              const SizedBox(height: _buttonGap),
            ],
            SizedBox(
              height: _buttonHeight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonRadius),
                  ),
                  textStyle: AppTypography.labelLarge,
                ),
                child: Text(dismissLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
