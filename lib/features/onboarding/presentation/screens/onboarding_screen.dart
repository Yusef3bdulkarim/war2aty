import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../widgets/primary_cta.dart';

// Measurements taken from `Waraqti.dc.html` → `intro`; the ones that fall off
// the 4-based spacing scale live here rather than as raw numbers inline.
//
// The design's 64px top padding is measured from the physical top of the
// screen, so it already contains the 52px status bar. Inside a [SafeArea] the
// inset is applied for us, and only the remainder is padding — otherwise the
// status bar would be counted twice and the heading would sit too low.
const double _pageTop = 64 - 52;
const double _pageSide = 26;
const double _pageBottom = 26;
const double _gridGap = 14;
const double _cardPaddingV = 20;
const double _iconBox = 46;

/// First-run intro: what the app is for, and the kinds of paper it explains.
///
/// Matches the design's `intro` page. Direction follows the locale, so the
/// grid and text flip for English without any manual RTL handling. Content
/// scrolls when it no longer fits (large text / short screens) while the call
/// to action stays reachable at the bottom.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

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
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      // Centres the block when it fits, scrolls when it does not.
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            s.onboardingTitle,
                            style: AppTypography.displayMedium.copyWith(
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            s.onboardingSubtitle,
                            style: AppTypography.bodyLead.copyWith(
                              color: colors.textBodySoft,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const _DocumentKindGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryCta(
                label: s.onboardingStart,
                onPressed: () => context.go(AppRoutes.privacy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 2×2 grid of document kinds.
///
/// Built from rows of [Expanded] cards inside an [IntrinsicHeight] rather than
/// a [GridView]: a fixed aspect ratio would clip the labels once the user
/// turns text size up, whereas this lets each row grow to its tallest card.
class _DocumentKindGrid extends StatelessWidget {
  const _DocumentKindGrid();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Column(
      children: [
        _GridRow(
          start: _KindCard(
            glyph: StrokeGlyph.appointment,
            tint: colors.surfaceTealAlt,
            iconColor: colors.brandPrimary,
            label: s.onboardingKindAppointment,
          ),
          end: _KindCard(
            glyph: StrokeGlyph.invoice,
            tint: colors.warningTint,
            iconColor: colors.warning,
            label: s.onboardingKindInvoice,
          ),
        ),
        const SizedBox(height: _gridGap),
        _GridRow(
          start: _KindCard(
            glyph: StrokeGlyph.government,
            tint: colors.accentBlueTint,
            iconColor: colors.accentBlue,
            label: s.onboardingKindGovernment,
          ),
          end: _KindCard(
            glyph: StrokeGlyph.education,
            tint: colors.successTint,
            iconColor: colors.success,
            label: s.onboardingKindEducation,
          ),
        ),
      ],
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.start, required this.end});

  final Widget start;
  final Widget end;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: start),
          const SizedBox(width: _gridGap),
          Expanded(child: end),
        ],
      ),
    );
  }
}

/// One document-kind card: tinted icon tile above a label.
class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.glyph,
    required this.tint,
    required this.iconColor,
    required this.label,
  });

  final StrokeGlyph glyph;
  final Color tint;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _cardPaddingV,
          horizontal: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _iconBox,
              height: _iconBox,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Center(child: StrokeIcon(glyph, color: iconColor)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: AppTypography.labelCard.copyWith(color: colors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
