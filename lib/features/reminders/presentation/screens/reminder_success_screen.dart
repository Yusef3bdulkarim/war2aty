import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/alert_time_label.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';

// From `Waraqti.dc.html` → `reminderSuccess`.
const double _padding = 36;
const double _iconOuterSize = 96;
const double _iconInnerSize = 64;
const double _iconGapBelow = 24;
const double _titleFontSize = 22;
const double _titleGapBelow = 20;
const double _cardMaxWidth = 320;
const double _cardPadding = 18;
const double _cardRadius = 18;
const double _cardBorderWidth = 4;
const double _cardTitleFontSize = 16.5;
const double _cardSubtitleFontSize = 13.5;
const double _cardSubtitleGapAbove = 5;
const double _cardGapBelow = 26;
const double _primaryButtonHeight = 52;
const double _primaryButtonRadius = 15;
const double _primaryButtonFontSize = 16;
const double _primaryButtonGapBelow = 9;
const double _secondaryButtonHeight = 50;

/// «تم إنشاء التذكير بنجاح» — the confirmation after F09-T03/T04 saves a
/// reminder, with a way to open it and a way back to wherever the flow
/// started.
class ReminderSuccessScreen extends StatelessWidget {
  const ReminderSuccessScreen({
    required this.reminder,
    this.onViewReminder,
    this.onClose,
    super.key,
  });

  final Reminder reminder;
  final VoidCallback? onViewReminder;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final firstAlert = reminder.alerts.isEmpty ? null : reminder.alerts.first;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _iconOuterSize,
                  height: _iconOuterSize,
                  decoration: BoxDecoration(
                    color: colors.successTint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: _iconInnerSize,
                      height: _iconInnerSize,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: StrokeIcon(
                          StrokeGlyph.check,
                          color: colors.onBrand,
                          size: 36,
                          strokeWidth: 2.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _iconGapBelow),
                Text(
                  strings.reminderSuccessTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: _titleFontSize,
                    fontWeight: AppTypography.extraBold,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: _titleGapBelow),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      boxShadow: AppShadows.card,
                      // Directional so it lands on the right in RTL, the left
                      // in LTR — matching every other role-accent border in
                      // the design.
                      border: BorderDirectional(
                        start: BorderSide(
                          color: colors.brandPrimary,
                          width: _cardBorderWidth,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(_cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.title,
                            style: AppTypography.labelCard.copyWith(
                              fontSize: _cardTitleFontSize,
                              fontWeight: AppTypography.extraBold,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: _cardSubtitleGapAbove),
                          Text(
                            firstAlert == null
                                ? formatDayMonth(strings, reminder.eventDate)
                                : '${formatDayMonth(strings, reminder.eventDate)}'
                                      ' — ${alertTimeLabel(strings, firstAlert.scheduledAt, offset: null)}',
                            style: AppTypography.caption.copyWith(
                              fontSize: _cardSubtitleFontSize,
                              fontWeight: AppTypography.semiBold,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _cardGapBelow),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: SizedBox(
                    width: double.infinity,
                    height: _primaryButtonHeight,
                    child: FilledButton(
                      onPressed: onViewReminder,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.brandPrimary,
                        foregroundColor: colors.onBrand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _primaryButtonRadius,
                          ),
                        ),
                        textStyle: AppTypography.labelMedium.copyWith(
                          fontSize: _primaryButtonFontSize,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      child: Text(strings.reminderSuccessViewAction),
                    ),
                  ),
                ),
                const SizedBox(height: _primaryButtonGapBelow),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: SizedBox(
                    width: double.infinity,
                    height: _secondaryButtonHeight,
                    child: FilledButton(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.surfaceTeal,
                        foregroundColor: colors.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _primaryButtonRadius,
                          ),
                        ),
                        textStyle: AppTypography.labelMedium.copyWith(
                          fontSize: _primaryButtonFontSize,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                      child: Text(strings.actionBack),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
