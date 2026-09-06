import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → `sheetDeleteRem`.
const double _sheetRadius = AppRadii.xxl;
const double _sheetPadding = AppSpacing.xl;
const double _titleFontSize = 18;
const double _messageGap = 8;
const double _buttonsGapAbove = 22;
const double _buttonGap = 10;
const double _buttonHeight = 50;
const double _buttonRadius = AppRadii.md;

/// Shows the «حذف التذكير؟» confirmation sheet (F09-T12, `sheetDeleteRem`).
///
/// Returns `true` only if the user tapped the red «حذف» button; `false` or
/// `null` for every other way out (cancel, tap outside, back gesture) — a
/// permanent delete never fires from an ambiguous dismissal.
Future<bool> showDeleteReminderSheet(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => const _DeleteReminderSheetBody(),
  );
  return confirmed ?? false;
}

class _DeleteReminderSheetBody extends StatelessWidget {
  const _DeleteReminderSheetBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

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
              strings.reminderDeleteSheetTitle,
              style: AppTypography.titleMedium.copyWith(
                fontSize: _titleFontSize,
                fontWeight: AppTypography.extraBold,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: _messageGap),
            Text(
              strings.reminderDeleteSheetMessage,
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
                child: Text(strings.reminderDeleteSheetConfirm),
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
                child: Text(strings.reminderDeleteSheetCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
