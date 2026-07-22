import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Home's opening lines: what the app is asking, and what it will do.
///
/// A fixed greeting, not a time-of-day one — the design asks a question rather
/// than saying "good morning", which also keeps it correct for a user who
/// opens the app at any hour.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marked as a header so screen-reader users can jump straight to it.
        Semantics(
          header: true,
          child: Text(
            s.homeGreetingTitle,
            style: AppTypography.headlineLarge.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          s.homeGreetingSubtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
            fontWeight: AppTypography.medium,
          ),
        ),
      ],
    );
  }
}
