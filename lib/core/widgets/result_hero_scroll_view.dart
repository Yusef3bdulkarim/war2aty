import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'top_bar_icon_button.dart';

// The owner's result-screen review, mockup A (F21 locked decisions #14, #19,
// #20). The bar's 56px is measured from the physical screen top and already
// contains the 52px status bar, which [SafeArea] applies.
const double _barTop = 56 - 52;
const double _barBottom = 4;
const double _barSide = AppSpacing.screenHorizontal;
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
    final barHeight =
        MediaQuery.paddingOf(context).top +
        _barTop +
        TopBarIconButton.dimension +
        _barBottom;
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
          child: _PinnedBar(
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

/// The slim teal bar that never scrolls: the back arrow, the page's heading
/// for screen readers, and [trailing].
class _PinnedBar extends StatelessWidget {
  const _PinnedBar({
    required this.heading,
    required this.backTooltip,
    this.onBack,
    this.trailing,
  });

  final String heading;
  final String backTooltip;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    // Light status-bar icons: they sit on the teal.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.brandPrimary,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(_heroRadius),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _barSide,
              _barTop,
              _barSide,
              _barBottom,
            ),
            child: SizedBox(
              height: TopBarIconButton.dimension,
              child: Row(
                children: [
                  TopBarIconButton(
                    onPressed: onBack,
                    tooltip: backTooltip,
                    icon: Transform.flip(
                      flipX: mirror,
                      child: StrokeIcon(
                        StrokeGlyph.arrowBack,
                        color: colors.onBrand,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  // The rest of the row carries the page's heading, so it has
                  // real bounds for a screen reader to land on.
                  Expanded(
                    child: Semantics(
                      header: true,
                      label: heading,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
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
