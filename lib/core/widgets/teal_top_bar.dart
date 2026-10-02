import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'top_bar_icon_button.dart';

// The owner's result-screen review, mockup A (F21 locked decisions #14, #19,
// #20). In the mockup the bar sits 56px from the physical top: a 52px status
// bar plus 4px. Here the status bar's height comes from [SafeArea], so only
// the 4px is a constant.
const double _barTop = 56 - 52;
const double _barBottom = 4;
const double _barSide = AppSpacing.screenHorizontal;
const double _barRadius = 28;

/// The slim teal bar at the top of the result page and of the pages shown
/// when there is no result (F23 #2): the back arrow on the teal, its bottom
/// corners rounded, and [trailing] at the end.
///
/// No title is drawn. [heading], when given, is announced as the page's
/// heading to a screen reader; a page that prints its own heading leaves it
/// out, so the name is not read twice.
class TealTopBar extends StatelessWidget {
  const TealTopBar({
    required this.backTooltip,
    this.heading,
    this.onBack,
    this.trailing,
    super.key,
  });

  /// The page's name, for screen readers only.
  final String? heading;

  final String backTooltip;

  /// Leaves the page. Absent in a widget test that pumps the page alone.
  final VoidCallback? onBack;

  /// Drawn at the bar's end, on the teal — so in white.
  final Widget? trailing;

  /// The bar's full height, status bar included — what a page scrolling
  /// under it holds back.
  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top +
      _barTop +
      TopBarIconButton.dimension +
      _barBottom;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;
    final heading = this.heading;

    // Light status-bar icons: they sit on the teal.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.brandPrimary,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(_barRadius),
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
                    child: heading == null
                        ? const SizedBox.expand()
                        : Semantics(
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
