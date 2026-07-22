import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Height and radius of the first-run pages' primary button, per the design.
const double _ctaHeight = 56;
const double _ctaRadius = 16;

/// The full-width teal call to action at the bottom of each first-run page.
///
/// The design gives it a soft brand-tinted glow. That is drawn as a [BoxShadow]
/// rather than Material elevation so the color matches the comp exactly.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_ctaRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x520E7C86),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        // A minimum, not a fixed height: the button grows with large text
        // rather than clipping the label.
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.brandPrimary,
            foregroundColor: colors.onBrand,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(_ctaHeight),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: AppTypography.labelCta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_ctaRadius),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
