import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'teal_top_bar.dart';

// The owner's result-screen review, mockup A (F21 locked decisions #14, #19,
// #20).
const double _heroRadius = 28;
const double _heroPaddingH = 20;
const double _heroPaddingTop = 4;
const double _heroPaddingBottom = 24;
const double _labelIconSize = 18;
const double _labelGap = 8;
const double _labelGapBelow = 10;
const double _labelSpacing = 0.4;
const double _summaryFontSize = 18;
const double _summaryHeight = 1.75;
const double _bodySide = 18;
const double _bodyBottom = 24;

/// A result page — the analysed paper, or a saved one — under its teal hero.
///
/// The hero is the summary, «ملخص المستند», on the page's loudest surface. A
/// slim teal bar holding the back arrow (and [trailing], e.g. the saved
/// paper's ⋮ menu) is pinned on top of it: at the top of the page the two
/// read as one block; as the page scrolls, the hero slides away underneath
/// and the bar stays, so the way back is always in reach. With no summary the
/// bar alone is the hero — no label, no empty teal.
///
/// The page's name is not printed, but a screen reader still announces
/// [heading] as the page's heading.
class ResultHeroScrollView extends StatelessWidget {
  const ResultHeroScrollView({
    required this.heading,
    required this.backTooltip,
    required this.children,
    this.summary,
    this.onBack,
    this.trailing,
    super.key,
  });

  /// The page's name, for screen readers only.
  final String heading;

  final String backTooltip;

  /// Leaves the page. Absent in a widget test that pumps the page alone.
  final VoidCallback? onBack;

  /// Drawn at the bar's end, on the teal — so in white.
  final Widget? trailing;

  /// The one-line summary, or `null` when the paper has none.
  final String? summary;

  /// The page's sections, below the hero.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final barHeight = TealTopBar.heightOf(context);
    final summary = this.summary?.trim() ?? '';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: _bodyBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary.isEmpty)
                // The pinned bar is the whole hero; hold its room.
                SizedBox(height: barHeight)
              else
                _HeroBody(barHeight: barHeight, summary: summary),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _bodySide,
                  AppSpacing.resultCardGap,
                  _bodySide,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: TealTopBar(
            heading: heading,
            backTooltip: backTooltip,
            onBack: onBack,
            trailing: trailing,
          ),
        ),
      ],
    );
  }
}

/// The teal block under the bar: «ملخص المستند» and the summary itself.
///
/// Its top [barHeight] is flat brand teal, behind the bar and its rounded
/// corners; the gradient starts below it at that same teal, so the two meet
/// without a seam.
class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.barHeight, required this.summary});

  final double barHeight;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: colors.brandPrimary,
          child: SizedBox(height: barHeight),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.brandPrimary, colors.brandDeep],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(_heroRadius),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _heroPaddingH,
              _heroPaddingTop,
              _heroPaddingH,
              _heroPaddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StrokeIcon(
                      StrokeGlyph.documentSteps,
                      color: colors.onBrand,
                      size: _labelIconSize,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: _labelGap),
                    Flexible(
                      child: Text(
                        strings.resultSummaryLabel,
                        style: AppTypography.caption.copyWith(
                          fontWeight: AppTypography.extraBold,
                          letterSpacing: _labelSpacing,
                          // White, not the mockup's mint: mint is 3.4:1 on
                          // brand teal, under AA for 13 px (F21 #18).
                          color: colors.onBrand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _labelGapBelow),
                Text(
                  summary,
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: _summaryFontSize,
                    fontWeight: AppTypography.bold,
                    height: _summaryHeight,
                    color: colors.onBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
