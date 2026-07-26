import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/home_state.dart';

// From `Waraqti.dc.html` → `home`.
const double _chipRadiusOverride = 14;
const double _chipPaddingV = 12;
const double _chipPaddingH = 14;
const double _chipIcon = 18;
const double _chipGap = 9;
const double _chipGapAbove = 16;

/// "You have N analyses left today."
///
/// Shown only once the user has actually spent part of the quota and some of
/// it remains — a full quota needs no explanation, and an exhausted one is
/// handled by the limit screen rather than a chip. That rule comes from the
/// design, which hides this block in both of those cases.
class UsageIndicator extends StatelessWidget {
  const UsageIndicator({required this.section, super.key});

  final UsageSection section;

  /// Whether this section renders anything at all.
  static bool isVisible(UsageSection section) =>
      _remainingToShow(section) != null;

  /// The count to display, or `null` when the chip stays hidden.
  ///
  /// Returning the number rather than a bool means the build below cannot
  /// reach a state where it has to cast or force-unwrap.
  static int? _remainingToShow(UsageSection section) => switch (section) {
    UsageLoading() || UsageUnavailable() => null,
    UsageAvailable(usage: null) => null,
    UsageAvailable(:final usage?) =>
      usage.usedCount > 0 && usage.hasQuotaLeft ? usage.remainingCount : null,
  };

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingToShow(section);
    if (remaining == null) return const SizedBox.shrink();

    final s = context.strings;
    const colors = AppColors.light;

    return Padding(
      // Its own spacing, so the screen above does not have to know whether
      // this section is showing.
      padding: const EdgeInsets.only(top: _chipGapAbove),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceNeutral,
          borderRadius: BorderRadius.circular(_chipRadiusOverride),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _chipPaddingV,
            horizontal: _chipPaddingH,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: StrokeIcon(
                  StrokeGlyph.clock,
                  color: colors.iconInfo,
                  size: _chipIcon,
                  strokeWidth: 1.9,
                ),
              ),
              const SizedBox(width: _chipGap),
              Expanded(
                child: Text(
                  s.homeUsageRemaining(remaining),
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.textBodySoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
