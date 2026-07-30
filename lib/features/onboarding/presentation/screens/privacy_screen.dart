import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/onboarding_cubit.dart';
import '../widgets/primary_cta.dart';

// From `Waraqti.dc.html` → `privacy`. As on the intro page, the design's 64px
// top padding is measured from the physical screen top and already contains
// the 52px status bar, which [SafeArea] applies for us.
const double _pageTop = 64 - 52;
const double _pageSide = 26;
const double _pageBottom = 26;
const double _shieldBox = 64;
const double _bulletCircle = 26;
const double _bulletGap = 13;

/// The last first-run step: what the app does with the user's paper, in four
/// plain promises. Agreeing here flips the onboarding flag, which opens the
/// router gate to Home.
///
/// This screen is the app's privacy contract in the user's own words, so the
/// copy is the feature — every point maps to a hard rule in CLAUDE.md §7 and
/// the master plan's privacy section.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    final points = [
      s.privacyPointExtractText,
      s.privacyPointTextOnly,
      s.privacyPointImageOptIn,
      s.privacyPointDeleteAnytime,
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _pageSide,
            _pageTop,
            _pageSide,
            _pageBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: _shieldBox,
                        height: _shieldBox,
                        decoration: BoxDecoration(
                          color: colors.surfaceTealAlt,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: Center(
                          child: StrokeIcon(
                            StrokeGlyph.shieldCheck,
                            color: colors.brandPrimary,
                            size: 32,
                            strokeWidth: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        s.privacyTitle,
                        style: AppTypography.displayMedium.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (final (index, point) in points.indexed) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.lg),
                        _PrivacyPoint(text: point),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryCta(
                label: s.privacyAgree,
                onPressed: () => context.read<OnboardingCubit>().complete(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One promise: a ticked circle beside a line of copy.
class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _bulletCircle,
          height: _bulletCircle,
          // Nudged down so the tick optically aligns with the first text line.
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: colors.surfaceTealAlt,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: StrokeIcon(
              StrokeGlyph.check,
              color: colors.brandPrimary,
              size: 15,
              strokeWidth: 2.4,
            ),
          ),
        ),
        const SizedBox(width: _bulletGap),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyLarge.copyWith(
              color: colors.textBody,
              fontWeight: AppTypography.medium,
            ),
          ),
        ),
      ],
    );
  }
}
