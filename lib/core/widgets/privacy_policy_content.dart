import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → `privacy`.
const double _shieldBox = 64;
const double _bulletCircle = 26;
const double _bulletGap = 13;

/// What the app does with the user's paper, in four plain promises: the
/// app's privacy contract in the user's own words.
///
/// Shared between [PrivacyScreen] (the first-run step, paired with the
/// «موافق، ابدأ» CTA) and the settings screen's «سياسة الخصوصية» row
/// (F11-T12, read back at any time with no CTA) — the copy is identical in
/// both places, so it lives in `core/` rather than being duplicated.
class PrivacyPolicyContent extends StatelessWidget {
  const PrivacyPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = AppColors.of(context);

    final points = [
      s.privacyPointExtractText,
      s.privacyPointTextOnly,
      s.privacyPointImageOptIn,
      s.privacyPointDeleteAnytime,
    ];

    return Column(
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
          style: AppTypography.displayMedium.copyWith(color: colors.ink),
        ),
        const SizedBox(height: 22),
        for (final (index, point) in points.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.lg),
          _PrivacyPoint(text: point),
        ],
      ],
    );
  }
}

/// One promise: a ticked circle beside a line of copy.
class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
