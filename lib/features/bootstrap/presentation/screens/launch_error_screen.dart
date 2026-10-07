import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shown instead of the splash when a critical launch step fails, with a retry.
///
/// Extracted unchanged in F28-T02 from the screen that drew both this and the
/// splash. The two share a slot in the launch, not a design: this one is a
/// normal screen on the app's light surface, it carries text, and it waits for
/// the user. Keeping it in the splash's file meant the splash could not be
/// replaced without reading past it.
class LaunchErrorScreen extends StatelessWidget {
  const LaunchErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).surfaceTealAlt,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 46,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        s.bootstrapErrorTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: AppTypography.extraBold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        s.bootstrapErrorMessage,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: AppTypography.medium,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                30,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(s.actionRetry),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
