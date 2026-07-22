import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → `home`.
const double _scanRadius = 24;
const double _scanPaddingV = 26;
const double _scanPaddingH = 22;
const double _scanIconBox = 60;
const double _pickRadius = 18;
const double _pickIconBox = 44;
const double _pickBorderWidth = 1.5;

/// Endpoints of the design's 150° gradient, as unit offsets from the centre.
const Alignment _gradientBegin = Alignment(-0.5, -0.866);
const Alignment _gradientEnd = Alignment(0.5, 0.866);

/// The two ways into a scan, plus the promise about what happens to the photo.
///
/// The camera is the primary action and gets the full-bleed gradient card; the
/// gallery is a quieter outlined row beneath it. The privacy note is part of
/// the group by design — the user is told what happens to the image *before*
/// choosing one, not after.
class ScanActions extends StatelessWidget {
  const ScanActions({
    required this.onScan,
    required this.onPickImage,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScanCard(onTap: onScan),
        const SizedBox(height: AppSpacing.md),
        _PickImageRow(onTap: onPickImage),
        const SizedBox(height: 14),
        const _ImagePrivacyNote(),
      ],
    );
  }
}

/// The primary call to action: a teal gradient card.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;
    final radius = BorderRadius.circular(_scanRadius);

    return Semantics(
      button: true,
      label: s.homeScanTitle,
      hint: s.homeScanSubtitle,
      // Excluding the subtree stops the title and subtitle being read twice,
      // but it also drops the InkWell's own semantics — so the tap action has
      // to be re-declared here, or the card is unusable with a screen reader.
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x570E7C86),
              blurRadius: 34,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                // The design's `linear-gradient(150deg, …)`. CSS measures the
                // angle clockwise from "to top", so 150° points down-right:
                // (sin150, -cos150) = (0.5, 0.866) in screen coordinates.
                // Plain [Alignment], not the directional variant — a CSS
                // gradient angle does not flip in an RTL container.
                begin: _gradientBegin,
                end: _gradientEnd,
                colors: [colors.brandPrimary, colors.brandDeep],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _scanPaddingV,
                  horizontal: _scanPaddingH,
                ),
                child: Row(
                  children: [
                    Container(
                      width: _scanIconBox,
                      height: _scanIconBox,
                      decoration: BoxDecoration(
                        color: colors.onBrand.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Center(
                        child: StrokeIcon(
                          StrokeGlyph.camera,
                          color: colors.onBrand,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.homeScanTitle,
                            style: AppTypography.titleAction.copyWith(
                              color: colors.onBrand,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.homeScanSubtitle,
                            style: AppTypography.labelActionSubtitle.copyWith(
                              color: colors.onBrand.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const _ForwardChevron(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's chevron points toward the start of the line, so it has to be
/// mirrored when the app runs left-to-right.
class _ForwardChevron extends StatelessWidget {
  const _ForwardChevron();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Transform.scale(
      scaleX: isRtl ? 1 : -1,
      child: StrokeIcon(
        StrokeGlyph.chevronForward,
        color: colors.onBrand.withValues(alpha: 0.7),
        size: 22,
        strokeWidth: 2.2,
      ),
    );
  }
}

/// The secondary action: pick an existing photo.
class _PickImageRow extends StatelessWidget {
  const _PickImageRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;
    final radius = BorderRadius.circular(_pickRadius);

    return Material(
      color: colors.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: colors.borderCool,
              width: _pickBorderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: 18,
            ),
            child: Row(
              children: [
                Container(
                  width: _pickIconBox,
                  height: _pickIconBox,
                  decoration: BoxDecoration(
                    color: colors.surfaceTeal,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: StrokeIcon(
                      StrokeGlyph.gallery,
                      color: colors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s.homePickImage,
                    style: AppTypography.labelAction.copyWith(
                      color: colors.ink,
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

/// "Your photo is not saved unless you agree to it."
class _ImagePrivacyNote extends StatelessWidget {
  const _ImagePrivacyNote();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: StrokeIcon(
              StrokeGlyph.shield,
              color: colors.iconSubtle,
              size: 16,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              s.homeImagePrivacyNote,
              style: AppTypography.labelMedium.copyWith(
                color: colors.textCaption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
