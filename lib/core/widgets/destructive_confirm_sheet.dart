import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → `sheetDeleteRem`/`sheetDeleteDoc`/`sheetDeleteAllRem`
// — one shared shape for every destructive confirmation.
const double _sheetRadius = AppRadii.xxl;
const double _sheetPadding = AppSpacing.xl;
const double _titleFontSize = 18;
const double _messageGap = 8;
const double _buttonsGapAbove = 22;
const double _buttonGap = 10;
const double _buttonHeight = 50;
const double _buttonRadius = AppRadii.md;

/// Shows a destructive-action confirmation sheet — the shape
/// `showDeleteReminderSheet` already uses (F09-T12), generalized for the
/// settings' delete-all rows (F11-T11): a title, a message, a red filled
/// confirm button, and a neutral outlined cancel button.
///
/// Returns `true` only if the user tapped the red confirm button; `false` or
/// `null` for every other way out (cancel, tap outside, back gesture) — a
/// permanent delete never fires from an ambiguous dismissal.
Future<bool> showDestructiveConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => _DestructiveConfirmSheetBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return confirmed ?? false;
}

class _DestructiveConfirmSheetBody extends StatelessWidget {
  const _DestructiveConfirmSheetBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

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
            SizedBox(
              height: _buttonHeight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonRadius),
                  ),
                  textStyle: AppTypography.labelLarge,
                ),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: _buttonGap),
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
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
