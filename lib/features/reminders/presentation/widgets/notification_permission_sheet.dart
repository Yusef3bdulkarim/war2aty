import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the `notifPerm` sheet.
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 24;
const double _sheetPaddingBottom = 34;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 22;
const double _iconBox = 64;
const double _iconRadius = 19;
const double _iconGapBelow = 18;
const double _titleFontSize = 20;
const double _titleGapBelow = 8;
const double _messageGapBelow = 22;
const double _primaryHeight = 54;
const double _secondaryHeight = 52;
const double _buttonRadius = 15;
const double _buttonGap = 8;

/// «اسمح بالتنبيهات» — asked once, right before the first reminder that
/// would need an OS notification is saved (F09-T09).
///
/// Two ways forward, both of which save the reminder (`ReminderFormCubit`
/// persists either way) — declining only means no OS notification, never a
/// blocked save.
Future<void> showNotificationPermissionSheet(
  BuildContext context, {
  required VoidCallback onAllow,
  required VoidCallback onSaveWithout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.of(context).card,
    // Scroll-controlled so the sheet sizes to its content instead of the
    // default half-screen, which clips the icon/title/message/two buttons
    // on a short viewport or under Large Text.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _NotificationPermissionSheet(
      onAllow: onAllow,
      onSaveWithout: onSaveWithout,
    ),
  );
}

class _NotificationPermissionSheet extends StatelessWidget {
  const _NotificationPermissionSheet({
    required this.onAllow,
    required this.onSaveWithout,
  });

  final VoidCallback onAllow;
  final VoidCallback onSaveWithout;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                margin: const EdgeInsets.only(bottom: _grabberGapBelow),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Container(
              width: _iconBox,
              height: _iconBox,
              decoration: BoxDecoration(
                color: colors.surfaceTealAlt,
                borderRadius: BorderRadius.circular(_iconRadius),
              ),
              child: Center(
                child: StrokeIcon(
                  StrokeGlyph.navReminders,
                  color: colors.brandPrimary,
                  size: 32,
                  strokeWidth: 1.7,
                ),
              ),
            ),
            const SizedBox(height: _iconGapBelow),
            Semantics(
              header: true,
              child: Text(
                strings.reminderNotifPermTitle,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            Text(
              strings.reminderNotifPermMessage,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.medium,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: _messageGapBelow),
            SizedBox(
              width: double.infinity,
              height: _primaryHeight,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAllow();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brandPrimary,
                  foregroundColor: colors.onBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonRadius),
                  ),
                  textStyle: AppTypography.labelMedium.copyWith(
                    fontSize: 17,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                child: Text(strings.reminderNotifPermAllow),
              ),
            ),
            const SizedBox(height: _buttonGap),
            SizedBox(
              width: double.infinity,
              height: _secondaryHeight,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onSaveWithout();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.surfaceTeal,
                  foregroundColor: colors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonRadius),
                  ),
                  textStyle: AppTypography.labelMedium.copyWith(
                    fontSize: 16,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                child: Text(strings.reminderNotifPermSaveWithout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
